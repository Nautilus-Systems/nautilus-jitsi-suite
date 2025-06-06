/*
 * Copyright @ 2024 Atlassian Pty Ltd
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

package org.jitsi.jibri.service.impl

import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import org.jitsi.jibri.capture.ffmpeg.FfmpegCapturer
import org.jitsi.jibri.config.Config
import org.jitsi.jibri.config.XmppCredentials
import org.jitsi.jibri.error.JibriError
import org.jitsi.jibri.selenium.CallParams
import org.jitsi.jibri.selenium.JibriSelenium
import org.jitsi.jibri.selenium.RECORDING_URL_OPTIONS
import org.jitsi.jibri.service.ErrorSettingPresenceFields
import org.jitsi.jibri.service.JibriService
import org.jitsi.jibri.service.JibriServiceFinalizer
import org.jitsi.jibri.sink.impl.FileSink
import org.jitsi.jibri.status.ComponentState
import org.jitsi.jibri.status.ErrorScope
import org.jitsi.jibri.util.ProcessFactory
import org.jitsi.jibri.util.createIfDoesNotExist
import org.jitsi.jibri.util.whenever
import org.jitsi.metaconfig.config
import org.jitsi.xmpp.extensions.jibri.JibriIq
import java.nio.file.FileSystem
import java.nio.file.FileSystems
import java.nio.file.Files
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Parameters needed for starting an [AudioRecordingJibriService]
 */
data class AudioRecordingParams(
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
    val callLoginParams: XmppCredentials,
    /**
     * Audio recording quality settings
     */
    val audioQuality: AudioQualitySettings = AudioQualitySettings()
)

/**
 * Audio quality configuration
 */
data class AudioQualitySettings(
    val sampleRate: Int = 44100,
    val channels: Int = 2,
    val codec: String = "pcm_s16le",
    val format: String = "wav"
)

/**
 * Custom errors for audio recording
 */
object ErrorCreatingAudioRecordingsDirectory : JibriError(ErrorScope.SESSION, "Unable to create audio recordings directory")
object AudioRecordingsDirectoryNotWritable : JibriError(ErrorScope.SESSION, "Audio recordings directory is not writable")
object ErrorStartingAudioRecording : JibriError(ErrorScope.SESSION, "Error starting audio recording")

/**
 * [AudioRecordingJibriService] is a specialized [JibriService] responsible for joining
 * a web call and capturing only its audio to a file. This service is optimized for
 * audio-only recording scenarios.
 */
class AudioRecordingJibriService(
    private val audioRecordingParams: AudioRecordingParams,
    jibriSelenium: JibriSelenium? = null,
    capturer: FfmpegCapturer? = null,
    processFactory: ProcessFactory = ProcessFactory(),
    fileSystem: FileSystem = FileSystems.getDefault(),
    private var jibriServiceFinalizer: JibriServiceFinalizer? = null
) : StatefulJibriService("Audio recording") {
    
    init {
        logger.addContext("session_id", audioRecordingParams.sessionId)
        logger.addContext("recording_type", "audio_only")
    }

    private val capturer = capturer ?: FfmpegCapturer(logger)
    private val jibriSelenium = jibriSelenium ?: JibriSelenium(logger)

    /**
     * The [FileSink] this class will use to model the file on the filesystem
     */
    private var sink: FileSink
    
    private val recordingsDirectory: String by config {
        "JibriConfig::recordingDirectory" { Config.legacyConfigSource.recordingDirectory!! }
        "jibri.recording.recordings-directory".from(Config.configSource)
    }
    
    private val finalizeScriptPath: String by config {
        "JibriConfig::finalizeRecordingScriptPath" {
            Config.legacyConfigSource.finalizeRecordingScriptPath!!
        }
        "jibri.recording.finalize-script".from(Config.configSource)
    }

    /**
     * The directory in which we'll store audio recordings for this particular session
     */
    private val sessionRecordingDirectory =
        fileSystem.getPath(recordingsDirectory).resolve("audio_recordings").resolve(audioRecordingParams.sessionId)

    init {
        logger.info("Writing audio recording to $sessionRecordingDirectory, finalize script path $finalizeScriptPath")
        
        // Create filename with timestamp
        val timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss"))
        val filename = "${audioRecordingParams.callParams.callUrlInfo.callName}_${timestamp}.${audioRecordingParams.audioQuality.format}"
        
        sink = FileSink(
            sessionRecordingDirectory,
            filename
        )

        registerSubComponent(JibriSelenium.COMPONENT_ID, this.jibriSelenium)
        registerSubComponent(FfmpegCapturer.COMPONENT_ID, this.capturer)

        jibriServiceFinalizer = JibriServiceFinalizeCommandRunner(
            processFactory,
            listOf(
                finalizeScriptPath,
                sessionRecordingDirectory.toString()
            )
        )
    }

    override fun start() {
        if (!createIfDoesNotExist(sessionRecordingDirectory, logger)) {
            publishStatus(ComponentState.Error(ErrorCreatingAudioRecordingsDirectory))
            return
        }
        if (!Files.isWritable(sessionRecordingDirectory)) {
            logger.error("Unable to write to audio recordings directory $sessionRecordingDirectory")
            publishStatus(ComponentState.Error(AudioRecordingsDirectoryNotWritable))
            return
        }

        logger.info("Starting audio-only recording session")
        
        // Join the call with recording URL options but in audio-only mode
        val audioOnlyParams = RECORDING_URL_OPTIONS + listOf(
            "config.startAudioOnly=true"
        )
        
        jibriSelenium.joinCall(
            audioRecordingParams.callParams.callUrlInfo.copy(urlParams = audioOnlyParams),
            audioRecordingParams.callLoginParams
        )

        whenever(jibriSelenium).transitionsTo(ComponentState.Running) {
            logger.info("Selenium joined the call, starting audio capturer")
            try {
                jibriSelenium.addToPresence("session_id", audioRecordingParams.sessionId)
                jibriSelenium.addToPresence("mode", JibriIq.RecordingMode.FILE.toString())
                jibriSelenium.addToPresence("recording_type", "audio_only")
                jibriSelenium.sendPresence()
                
                // Start audio-only capturing
                startAudioOnlyCapture()
            } catch (t: Throwable) {
                logger.error("Error while setting fields in presence", t)
                publishStatus(ComponentState.Error(ErrorSettingPresenceFields))
            }
        }
    }

    /**
     * Start audio-only capture with FFmpeg
     */
    private fun startAudioOnlyCapture() {
        try {
            // Start the capturer with the configured sink
            capturer.start(sink)
        } catch (t: Throwable) {
            logger.error("Error starting audio capture", t)
            publishStatus(ComponentState.Error(ErrorStartingAudioRecording))
        }
    }

    override fun stop() {
        logger.info("Stopping audio capturer")
        capturer.stop()
        logger.info("Quitting selenium")

        // Check if we actually recorded any audio
        val recordedAudio = Files.exists(sink.file)
        if (!recordedAudio) {
            logger.info("No audio was recorded, deleting directory and skipping finalize")
            try {
                Files.delete(sessionRecordingDirectory)
            } catch (t: Throwable) {
                logger.error("Problem deleting session recording directory", t)
            }
            jibriSelenium.leaveCallAndQuitBrowser()
            return
        }

        logger.info("Audio recording completed, file saved to ${sink.file}")
        
        // Write simple metadata file for audio recording
        writeAudioMetadata()
        
        jibriSelenium.leaveCallAndQuitBrowser()
        
        // Run finalize script if configured
        jibriServiceFinalizer?.let { finalizer ->
            logger.info("Running finalize script")
            try {
                finalizer.doFinalize()
            } catch (t: Throwable) {
                logger.error("Error running finalize script", t)
            }
        }
    }

    /**
     * Write metadata about the audio recording
     */
    private fun writeAudioMetadata() {
        try {
            val metadataFile = sessionRecordingDirectory.resolve("metadata.json")
            val metadata = mapOf(
                "session_id" to audioRecordingParams.sessionId,
                "recording_type" to "audio_only",
                "meeting_url" to audioRecordingParams.callParams.callUrlInfo.baseUrl,
                "audio_quality" to audioRecordingParams.audioQuality,
                "timestamp" to LocalDateTime.now().toString(),
                "file_name" to sink.file.fileName.toString()
            )
            
            Files.write(
                metadataFile,
                jacksonObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsBytes(metadata)
            )
            logger.info("Audio recording metadata written to $metadataFile")
        } catch (t: Throwable) {
            logger.error("Error writing audio recording metadata", t)
        }
    }
} 