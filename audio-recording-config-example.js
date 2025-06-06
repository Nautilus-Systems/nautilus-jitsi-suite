/**
 * Audio Recording Configuration Example
 * 
 * This file shows how to configure Jitsi Meet to enable the audio recording button.
 * Copy the relevant sections to your config.js file.
 */

// Example config.js configuration for audio recording
var config = {
    // ... other config options ...

    // Enable recording feature
    fileRecordingsEnabled: true,
    liveStreamingEnabled: false, // Set to true if you also want live streaming

    // Configure toolbar buttons to include audio recording
    toolbarButtons: [
        'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
        'fodeviceselection', 'hangup', 'profile', 'chat', 'recording',
        'audiorecording', // Add this line to enable audio recording button
        'livestreaming', 'etherpad', 'sharedvideo', 'settings', 'raisehand',
        'videoquality', 'filmstrip', 'invite', 'feedback', 'stats', 'shortcuts',
        'tileview', 'videobackgroundblur', 'download', 'help', 'mute-everyone',
        'security'
    ],

    // Hide unused buttons (optional)
    toolbarConfig: {
        alwaysVisible: ['microphone', 'camera', 'audiorecording'],
        initiallyVisible: [
            'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
            'fodeviceselection', 'hangup', 'profile', 'recording', 'audiorecording',
            'chat', 'etherpad', 'sharedvideo', 'settings', 'raisehand', 'videoquality'
        ]
    },

    // Recording configuration
    recordingService: {
        enabled: true,
        sharingEnabled: true,
        hideStorageWarning: false
    },

    // For development/testing, you can enable these debug options
    // Remove in production
    debug: false,
    analytics: {
        disabled: true
    },

    // Example of how to customize the recording metadata
    recordingMetadata: {
        audioOnly: true, // This flag can be used to trigger audio-only recording
        quality: 'high',
        format: 'wav'
    }
};

// Example interface_config.js customization for better audio recording UX
var interfaceConfig = {
    // ... other interface config options ...

    // Customize toolbar layout
    TOOLBAR_ALWAYS_VISIBLE: false,
    TOOLBAR_TIMEOUT: 4000,

    // Show recording button prominently
    TOOLBAR_BUTTONS: [
        'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
        'fodeviceselection', 'hangup', 'profile', 'chat', 'recording',
        'audiorecording', // Audio recording button
        'etherpad', 'sharedvideo', 'settings', 'raisehand',
        'videoquality', 'filmstrip', 'invite', 'feedback', 'stats',
        'shortcuts', 'tileview', 'download', 'help'
    ],

    // Customize button appearance
    AUDIO_RECORDING_BUTTON_ENABLED: true,
    
    // Show recording status
    SHOW_RECORDING_LABEL: true,
    
    // Recording notifications
    DISABLE_RECORDING_NOTIFICATIONS: false,

    // App name customization
    APP_NAME: 'Jitsi Meet with Audio Recording',
    
    // Optional: Custom branding
    BRAND_WATERMARK_LINK: '',
    
    // Disable features that are not needed for audio recording
    DISABLE_VIDEO_BACKGROUND: false,
    
    // Optimize for audio
    DEFAULT_BACKGROUND: '#474747',
    
    // Recording-related UI elements
    RECORDING_LABEL: 'REC',
    LIVE_STREAMING_LABEL: 'LIVE'
};

/**
 * Backend Configuration (for Jibri)
 * 
 * Example jibri.conf sections to enable audio recording:
 */

/*
jibri {
    recording {
        recordings-directory = "/opt/jitsi/jibri/recordings"
        finalize-script = "/opt/jitsi/jibri/finalize.sh"
        
        # Audio recording specific settings
        audio-only {
            enabled = true
            format = "wav"
            sample-rate = 44100
            channels = 2
            codec = "pcm_s16le"
        }
    }
    
    ffmpeg {
        # Audio-only recording command for Linux
        command-linux-audio-recording = [
            "ffmpeg", "-y", "-v", "info",
            "-f", "pulse", "-i", "default",
            "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2"
        ]
        
        # Audio-only recording command for Mac
        command-mac-audio-recording = [
            "ffmpeg", "-y", "-v", "info", 
            "-f", "avfoundation", "-i", ":default",
            "-acodec", "pcm_s16le", "-ar", "44100", "-ac", "2"
        ]
    }
    
    api {
        xmpp {
            environments = [
                {
                    name = "your-domain.com"
                    xmpp-server-hosts = ["your-prosody-server"]
                    xmpp-domain = "your-domain.com"
                    
                    control-login {
                        domain = "auth.your-domain.com"
                        username = "jibri"
                        password = "your-jibri-password"
                    }
                    
                    control-muc {
                        domain = "internal.auth.your-domain.com"
                        room-name = "JibriBrewery"
                        nickname = "jibri-audio-recorder"
                    }
                    
                    call-login {
                        domain = "recorder.your-domain.com"
                        username = "recorder"
                        password = "your-recorder-password"
                    }
                }
            ]
        }
    }
}
*/

/**
 * Prosody Configuration Example
 * 
 * Add these sections to your Prosody configuration:
 */

/*
-- Enable recording component
Component "recorder.your-domain.com"
    component_secret = "your-recorder-password"

-- Internal MUC for jibri communication  
Component "internal.auth.your-domain.com" "muc"
    storage = "memory"
    modules_enabled = { "ping" }
    restrict_room_creation = true
    admins = { "focus@auth.your-domain.com", "jibri@auth.your-domain.com" }

-- Authentication for jibri
VirtualHost "auth.your-domain.com"
    ssl = { protocol = "tlsv1_2+"; }
    authentication = "internal_plain"
    admins = { "focus@auth.your-domain.com", "jibri@auth.your-domain.com" }
*/

/**
 * Jicofo Configuration Example
 * 
 * Add to your jicofo.conf:
 */

/*
jicofo {
    jibri {
        brewery-jid = "jibribrewery@internal.auth.your-domain.com"
        pending-timeout = 90 seconds
        
        # Enable audio recording requests
        audio-recording {
            enabled = true
            default-sharing = true
        }
    }
    
    # Bridge selection strategy
    bridge {
        selection-strategy = "SplitBridgeSelectionStrategy"
    }
}
*/ 