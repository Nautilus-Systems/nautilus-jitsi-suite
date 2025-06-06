/* eslint-disable lines-around-comment */
import React, { useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useDispatch, useSelector } from 'react-redux';

import { createToolbarEvent } from '../../../analytics/AnalyticsEvents';
import { sendAnalytics } from '../../../analytics/functions';
import { IReduxState } from '../../../app/types';
import { getCurrentConference } from '../../../base/conference/functions';
import { IconMic, IconRecord, IconStop } from '../../../base/icons/svg';
import { JitsiRecordingConstants } from '../../../base/lib-jitsi-meet';
import Button from '../../../base/ui/components/web/Button';
import { BUTTON_TYPES } from '../../../base/ui/constants.web';

/**
 * The type of the React {@code Component} props of {@link AudioRecordButton}.
 */
interface IProps {

    /**
     * The tooltip to display for the audio record button.
     */
    _tooltip?: string;

    /**
     * Whether the button is disabled.
     */
    disabled?: boolean;
}

/**
 * Button for starting and stopping audio-only recording.
 *
 * @param {IProps} props - The props of the component.
 * @returns {ReactElement}
 */
const AudioRecordButton = ({ _tooltip, disabled }: IProps): JSX.Element => {
    const dispatch = useDispatch();
    const { t } = useTranslation();

    // Get recording state from Redux
    const { sessionDatas } = useSelector((state: IReduxState) => state['features/recording']);
    const conference = useSelector(getCurrentConference);
    
    const isRecording = sessionDatas.some(
        (recording: any) => recording.status === JitsiRecordingConstants.status.ON
    );

    const handleClick = useCallback(() => {
        sendAnalytics(createToolbarEvent('audiorecording'));
        
        if (isRecording) {
            // Stop the active recording session
            const activeSession = sessionDatas?.find((session: any) =>
                session.status === JitsiRecordingConstants.status.ON
            );

            if (activeSession && conference) {
                conference.stopRecording(activeSession.id);
            }
        } else {
            // Start audio-only recording
            if (conference) {
                conference.startRecording({
                    mode: JitsiRecordingConstants.mode.FILE,
                    audioOnly: true,
                    appData: JSON.stringify({
                        'file_recording_metadata': {
                            audioOnly: true
                        }
                    })
                });
            }
        }
    }, [isRecording, sessionDatas, conference]);

    // Don't render if no conference
    if (!conference) {
        return <></>;
    }

    const tooltip = _tooltip || (isRecording 
        ? t('dialog.stopAudioRecording') 
        : t('dialog.startAudioRecording'));

    return (
        <Button
            accessibilityLabel = { tooltip }
            disabled = { disabled }
            icon = { isRecording ? IconStop : IconRecord }
            onClick = { handleClick }
            toggled = { isRecording }
            tooltip = { tooltip }
            type = { BUTTON_TYPES.PRIMARY } />
    );
};

export default AudioRecordButton; 