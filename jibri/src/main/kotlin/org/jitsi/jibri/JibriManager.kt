/*
 * Copyright @ 2018 Atlassian Pty Ltd
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package org.jitsi.jibri

import org.jitsi.jibri.config.Config
import org.jitsi.jibri.config.XmppCredentials
import org.jitsi.jibri.health.EnvironmentContext
import org.jitsi.jibri.metrics.JibriMetrics
import org.jitsi.jibri.selenium.CallParams
import org.jitsi.jibri.service.JibriService
import org.jitsi.jibri.service.JibriServiceStatusHandler
import org.jitsi.jibri.service.ServiceParams
import org.jitsi.jibri.service.impl.AudioRecordingJibriService
import org.jitsi.jibri.service.impl.AudioRecordingParams
import org.jitsi.jibri.service.impl.FileRecordingJibriService
import org.jitsi.jibri.service.impl.FileRecordingParams
import org.jitsi.jibri.service.impl.SipGatewayJibriService
import org.jitsi.jibri.service.impl.SipGatewayServiceParams
import org.jitsi.jibri.service.impl.StreamingJibriService
import org.jitsi.jibri.service.impl.StreamingParams
import org.jitsi.jibri.status.ComponentBusyStatus
import org.jitsi.jibri.status.ComponentHealthStatus
import org.jitsi.jibri.status.ComponentState
import org.jitsi.jibri.status.ErrorScope
import org.jitsi.jibri.util.StatusPublisher
import org.jitsi.jibri.util.TaskPools
import org.jitsi.jibri.util.extensions.schedule
import org.jitsi.metaconfig.config
import org.jitsi.utils.logging2.createLogger
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

class JibriBusyException : Exception()

/**
 * Some of the values in [FileRecordingParams] come from the configuration
 * file, so the incoming request won't contain all of them.  This class
 * models the subset of values which will come in the request.
 */
data class FileRecordingRequestParams(
    /**
     * Which call we'll join
     */
    val callParams: CallParams,
    /**
     * The ID of this session
     */
    val sessionId: String,
    /**
     * The login information needed to appear invisible in
     * the call
     */
    val callLoginParams: XmppCredentials
)

/**
 * Similar to [FileRecordingRequestParams] but for audio-only recording requests
 */
data class AudioRecordingRequestParams(
    /**
     * Which call we'll join
     */
    val callParams: CallParams,
    /**
     * The ID of this session
     */
    val sessionId: String,
    /**
     * The login information needed to appear invisible in
     * the call
     */
    val callLoginParams: XmppCredentials
)

/**
 * [JibriManager] is responsible for managing the various services Jibri
 * provides, as well as providing an API to query the health of this Jibri
 * instance.  NOTE: currently Jibri only runs a single service at a time, so
 * if one is running, the Jibri will describe itself as busy
 *
 * TODO: we mark 'Any' as the status type we publish because we have 2 different status types we want to publish:
 * ComponentBusyStatus and ComponentState and i was unable to think of a better solution for that (yet...)
 */
class JibriManager : StatusPublisher<Any>() {
    private val logger = createLogger()
    private var currentActiveService: JibriService? = null

    /**
     * Store some arbitrary context optionally sent in the start service request so that we can report it in our
     * status
     */
    var currentEnvironmentContext: EnvironmentContext? = null

    /**
     * A function which will be executed the next time this Jibri is idle.  This can be used to schedule work that
     * can't be run while a Jibri session is active
     */
    private var pendingIdleFunc: () -> Unit = {}
    private var serviceTimeoutTask: ScheduledFuture<*>? = null

    private val singleUseMode: Boolean by config {
        "JibriConfig::singleUseMode" { Config.legacyConfigSource.singleUseMode!! }
        "jibri.single-use-mode".from(Config.configSource)
    }

    val jibriMetrics = JibriMetrics()

    /**
     * Note: should only be called if the instance-wide lock is held (i.e. called from
     * one of the synchronized methods)
     * TODO: instead of the synchronized decorators, use a synchronized(this) block
     * which we can also use here
     */
    private fun throwIfBusy(sinkType: RecordingSinkType) {
        if (busy()) {
            logger.info("Jibri is busy, can't start service")
            jibriMetrics.requestWhileBusy(sinkType)
            throw JibriBusyException()
        }
    }

    /**
     * Starts a [FileRecordingJibriService] to record the call described
     * in the params to a file.
     */
    @Synchronized
    fun startFileRecording(
        serviceParams: ServiceParams,
        fileRecordingRequestParams: FileRecordingRequestParams,
        environmentContext: EnvironmentContext? = null,
        serviceStatusHandler: JibriServiceStatusHandler? = null
    ) {
        throwIfBusy(RecordingSinkType.FILE)
        logger.info("Starting a file recording with params: $fileRecordingRequestParams")
        val service = FileRecordingJibriService(
            FileRecordingParams(
                fileRecordingRequestParams.callParams,
                fileRecordingRequestParams.sessionId,
                fileRecordingRequestParams.callLoginParams,
                serviceParams.appData?.fileRecordingMetadata
            )
        )
        jibriMetrics.start(RecordingSinkType.FILE)
        startService(service, serviceParams, environmentContext, serviceStatusHandler)
    }

    /**
     * Starts an [AudioRecordingJibriService] to record only the audio
     * of the call described in the params to a file.
     */
    @Synchronized
    fun startAudioRecording(
        serviceParams: ServiceParams,
        audioRecordingRequestParams: AudioRecordingRequestParams,
        environmentContext: EnvironmentContext? = null,
        serviceStatusHandler: JibriServiceStatusHandler? = null
    ) {
        throwIfBusy(RecordingSinkType.FILE)
        logger.info("Starting an audio recording with params: $audioRecordingRequestParams")
        val service = AudioRecordingJibriService(
            AudioRecordingParams(
                audioRecordingRequestParams.callParams,
                audioRecordingRequestParams.sessionId,
                audioRecordingRequestParams.callLoginParams
            )
        )
        jibriMetrics.start(RecordingSinkType.FILE)
        startService(service, serviceParams, environmentContext, serviceStatusHandler)
    }

    /**
     * Starts a [StreamingJibriService] to capture the call according
     * to [streamingParams].
     */
    @Synchronized
    fun startStreaming(
        serviceParams: ServiceParams,
        streamingParams: StreamingParams,
        environmentContext: EnvironmentContext? = null,
        serviceStatusHandler: JibriServiceStatusHandler? = null
    ) {
        logger.info("Starting a stream with params: $serviceParams $streamingParams")
        throwIfBusy(RecordingSinkType.STREAM)
        val service = StreamingJibriService(streamingParams)
        jibriMetrics.start(RecordingSinkType.STREAM)
        startService(service, serviceParams, environmentContext, serviceStatusHandler)
    }

    @Synchronized
    fun startSipGateway(
        serviceParams: ServiceParams,
        sipGatewayServiceParams: SipGatewayServiceParams,
        environmentContext: EnvironmentContext? = null,
        serviceStatusHandler: JibriServiceStatusHandler? = null
    ) {
        logger.info("Starting a SIP gateway with params: $serviceParams $sipGatewayServiceParams")
        throwIfBusy(RecordingSinkType.GATEWAY)
        val service = SipGatewayJibriService(
            SipGatewayServiceParams(
                sipGatewayServiceParams.callParams,
                sipGatewayServiceParams.callLoginParams,
                sipGatewayServiceParams.sipClientParams
            )
        )
        jibriMetrics.start(RecordingSinkType.GATEWAY)
        return startService(service, serviceParams, environmentContext, serviceStatusHandler)
    }

    /**
     * Helper method to handle the boilerplate of starting a [JibriService].
     */
    private fun startService(
        jibriService: JibriService,
        serviceParams: ServiceParams,
        environmentContext: EnvironmentContext?,
        serviceStatusHandler: JibriServiceStatusHandler? = null
    ) {
        publishStatus(ComponentBusyStatus.BUSY)
        if (serviceStatusHandler != null) {
            jibriService.addStatusHandler(serviceStatusHandler)
        }
        // The manager adds its own status handler so that it can stop
        // the error'd service and update presence appropriately
        jibriService.addStatusHandler {
            when (it) {
                is ComponentState.Error -> {
                    if (it.error.scope == ErrorScope.SYSTEM) {
                        jibriMetrics.error(jibriService.getSinkType())
                        publishStatus(ComponentHealthStatus.UNHEALTHY)
                    }
                    stopService()
                }
                is ComponentState.Finished -> {
                    // If a 'stop' was received externally, then this stopService call
                    // will be redundant, but we need to make it anyway as the service
                    // can also signal that it has finished (based on its own checks)
                    // and needs to be stopped (cleaned up)
                    stopService()
                }
                else -> { /* No op */ }
            }
        }

        currentActiveService = jibriService
        currentEnvironmentContext = environmentContext
        if (serviceParams.usageTimeoutMinutes != 0) {
            logger.info("This service will have a usage timeout of ${serviceParams.usageTimeoutMinutes} minute(s)")
            serviceTimeoutTask =
                TaskPools.recurringTasksPool.schedule(serviceParams.usageTimeoutMinutes.toLong(), TimeUnit.MINUTES) {
                    logger.info("The usage timeout has elapsed, stopping the currently active service")
                    try {
                        stopService()
                    } catch (t: Throwable) {
                        logger.error("Error while stopping service due to usage timeout", t)
                    }
                }
        }
        TaskPools.ioPool.submit {
            jibriService.start()
        }
    }

    /**
     * Stop the currently active [JibriService], if there is one
     */
    @Synchronized
    fun stopService() {
        val currentService = currentActiveService ?: run {
            // After an initial call to 'stopService', we'll stop ffmpeg and it will transition
            // to 'finished', causing the entire service to transition to 'finished' and trigger
            // another call to stopService (see the note above when installing the status handler
            // on the jibri service).  A more complete fix for this is much larger, so for now
            // we'll just check if the currentActiveService has already been cleared to prevent
            // doing a double stop (which is mostly harmless, but does fire an extra 'stop'
            // statsd event with an empty service tag)
            logger.info("No service active, ignoring stop")
            return
        }
        jibriMetrics.stop(currentService.getSinkType())
        logger.info("Stopping the current service")
        serviceTimeoutTask?.cancel(false)
        // Note that this will block until the service is completely stopped
        currentService.stop()
        currentActiveService = null
        currentEnvironmentContext = null
        // Invoke the function we've been told to next time we're idle
        // and reset it
        pendingIdleFunc()
        pendingIdleFunc = {}
        if (singleUseMode) {
            logger.info("Jibri is in single-use mode, not returning to IDLE")
            publishStatus(ComponentBusyStatus.EXPIRED)
        } else {
            publishStatus(ComponentBusyStatus.IDLE)
        }
    }

    /**
     * Returns whether or not this Jibri is currently "busy".   "Busy" is
     * is defined as "does not currently have the capacity to spin up another
     * service"
     */
    @Synchronized
    fun busy(): Boolean = currentActiveService != null

    /**
     * Execute the given function the next time Jibri is idle
     */
    @Synchronized
    fun executeWhenIdle(func: () -> Unit) {
        if (!busy()) {
            func()
        } else {
            pendingIdleFunc = func
        }
    }
}

private fun JibriService.getSinkType() = when (this) {
    is AudioRecordingJibriService -> RecordingSinkType.FILE
    is FileRecordingJibriService -> RecordingSinkType.FILE
    is StreamingJibriService -> RecordingSinkType.GATEWAY
    is SipGatewayJibriService -> RecordingSinkType.GATEWAY
    else -> throw IllegalArgumentException("JibriService of unsupported type: ${JibriService::class.java.name}")
}
