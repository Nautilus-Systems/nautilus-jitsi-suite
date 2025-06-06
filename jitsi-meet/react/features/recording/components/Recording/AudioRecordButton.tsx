/* eslint-disable lines-around-comment */
import React, { useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useDispatch } from 'react-redux';

import { createToolbarEvent } from '../../../analytics/AnalyticsEvents';
import { sendAnalytics } from '../../../analytics/functions';
import { IReduxState } from '../../../app/types';
import { IconMicrophone } from '../../../base/icons/svg';
import Button from '../../../base/ui/components/web/Button';
import { BUTTON_TYPES } from '../../../base/ui/constants.web';
import { useSelector } from '../../../base/util/reactUtils';
// @ts-ignore
import { JitsiRecordingConstants } from '../../../base/lib-jitsi-meet';

import { useAudioRecordingButton } from '../../hooks.web';

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

    const {
        isRecording,
        isSupported,
        onClick
    } = useAudioRecordingButton();

    const handleClick = useCallback(() => {
        sendAnalytics(createToolbarEvent('audiorecording'));
        onClick();
    }, [ onClick ]);

    if (!isSupported) {
        return <></>;
    }

    const tooltip = _tooltip || (isRecording 
        ? t('recording.stopAudioRecording') 
        : t('recording.startAudioRecording'));

    return (
        <Button
            accessibilityLabel = { tooltip }
            disabled = { disabled }
            icon = { IconMicrophone }
            onClick = { handleClick }
            toggled = { isRecording }
            tooltip = { tooltip }
            type = { BUTTON_TYPES.PRIMARY } />
    );
};

export default AudioRecordButton; 