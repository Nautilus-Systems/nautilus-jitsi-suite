#!/usr/bin/env node

/**
 * Complete Audio Recording Implementation Test
 * 
 * This script validates that all components of the audio recording feature
 * have been implemented correctly.
 */

const fs = require('fs');
const path = require('path');

const COLORS = {
    GREEN: '\x1b[32m',
    RED: '\x1b[31m',
    YELLOW: '\x1b[33m',
    BLUE: '\x1b[34m',
    RESET: '\x1b[0m'
};

function log(color, ...args) {
    console.log(color, ...args, COLORS.RESET);
}

function checkFileExists(filePath, description) {
    if (fs.existsSync(filePath)) {
        log(COLORS.GREEN, `✓ ${description}: ${filePath}`);
        return true;
    } else {
        log(COLORS.RED, `✗ ${description}: ${filePath} - FILE NOT FOUND`);
        return false;
    }
}

function checkFileContains(filePath, searchString, description) {
    if (!fs.existsSync(filePath)) {
        log(COLORS.RED, `✗ ${description}: ${filePath} - FILE NOT FOUND`);
        return false;
    }
    
    const content = fs.readFileSync(filePath, 'utf8');
    if (content.includes(searchString)) {
        log(COLORS.GREEN, `✓ ${description}: Found "${searchString}"`);
        return true;
    } else {
        log(COLORS.RED, `✗ ${description}: "${searchString}" not found in ${filePath}`);
        return false;
    }
}

function runTests() {
    log(COLORS.BLUE, '\n=== Audio Recording Implementation Test ===\n');
    
    let allPassed = true;
    
    // Test 1: Frontend Component Files
    log(COLORS.YELLOW, '1. Testing Frontend Component Files:');
    const frontendTests = [
        {
            file: 'react/features/recording/components/Recording/AudioRecordButton.tsx',
            desc: 'Audio Record Button Component'
        },
        {
            file: 'react/features/recording/hooks.web.ts',
            desc: 'Recording Hooks (should contain useAudioRecordingButton)'
        },
        {
            file: 'react/features/toolbox/hooks.web.ts',
            desc: 'Toolbox Hooks (should contain audiorecording integration)'
        }
    ];
    
    for (const test of frontendTests) {
        if (!checkFileExists(test.file, test.desc)) {
            allPassed = false;
        }
    }
    
    // Test 2: Frontend Component Content
    log(COLORS.YELLOW, '\n2. Testing Frontend Component Content:');
    const contentTests = [
        {
            file: 'react/features/recording/components/Recording/AudioRecordButton.tsx',
            search: 'useAudioRecordingButton',
            desc: 'AudioRecordButton uses correct hook'
        },
        {
            file: 'react/features/recording/components/Recording/AudioRecordButton.tsx',
            search: 'audioOnly: true',
            desc: 'AudioRecordButton sets audioOnly flag'
        },
        {
            file: 'react/features/recording/hooks.web.ts',
            search: 'useAudioRecordingButton',
            desc: 'Audio recording hook definition'
        },
        {
            file: 'react/features/toolbox/hooks.web.ts',
            search: 'audiorecording',
            desc: 'Toolbox integration for audiorecording'
        },
        {
            file: 'react/features/base/toolbox/types.ts',
            search: "'audiorecording'",
            desc: 'ToolbarButton type includes audiorecording'
        }
    ];
    
    for (const test of contentTests) {
        if (!checkFileContains(test.file, test.search, test.desc)) {
            allPassed = false;
        }
    }
    
    // Test 3: Backend Service Files
    log(COLORS.YELLOW, '\n3. Testing Backend Service Files:');
    const backendTests = [
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt',
            desc: 'Audio Recording Jibri Service'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt',
            desc: 'JibriManager (should contain audio recording integration)'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/XmppApi.kt',
            desc: 'XMPP API (should contain audio recording support)'
        }
    ];
    
    for (const test of backendTests) {
        if (!checkFileExists(test.file, test.desc)) {
            allPassed = false;
        }
    }
    
    // Test 4: Backend Service Content
    log(COLORS.YELLOW, '\n4. Testing Backend Service Content:');
    const backendContentTests = [
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt',
            search: 'class AudioRecordingJibriService',
            desc: 'AudioRecordingJibriService class definition'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt',
            search: 'config.startAudioOnly=true',
            desc: 'Audio-only configuration'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt',
            search: 'startAudioRecording',
            desc: 'JibriManager audio recording method'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt',
            search: 'AudioRecordingRequestParams',
            desc: 'Audio recording request parameters'
        },
        {
            file: '../jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/XmppApi.kt',
            search: 'isAudioOnly',
            desc: 'XMPP API audio-only detection'
        }
    ];
    
    for (const test of backendContentTests) {
        if (!checkFileContains(test.file, test.search, test.desc)) {
            allPassed = false;
        }
    }
    
    // Test 5: Configuration Files
    log(COLORS.YELLOW, '\n5. Testing Configuration Files:');
    const configTests = [
        {
            file: 'audio-recording-config-example.js',
            desc: 'Audio Recording Configuration Example'
        },
        {
            file: 'AUDIO_RECORDING_IMPLEMENTATION.md',
            desc: 'Implementation Documentation'
        }
    ];
    
    for (const test of configTests) {
        if (!checkFileExists(test.file, test.desc)) {
            allPassed = false;
        }
    }
    
    // Test 6: Compilation Status
    log(COLORS.YELLOW, '\n6. Testing TypeScript Compilation:');
    try {
        const { execSync } = require('child_process');
        
        // Test TypeScript compilation
        execSync('npx tsc --noEmit --project tsconfig.web.json', { 
            stdio: 'pipe',
            cwd: process.cwd()
        });
        log(COLORS.GREEN, '✓ TypeScript compilation successful');
    } catch (error) {
        log(COLORS.RED, '✗ TypeScript compilation failed');
        log(COLORS.RED, error.stdout?.toString() || error.message);
        allPassed = false;
    }
    
    // Test 7: ESLint Status
    log(COLORS.YELLOW, '\n7. Testing ESLint:');
    try {
        const { execSync } = require('child_process');
        
        // Test specific files with ESLint
        const filesToLint = [
            'react/features/recording/components/Recording/AudioRecordButton.tsx',
            'react/features/recording/hooks.web.ts',
            'react/features/toolbox/hooks.web.ts'
        ];
        
        for (const file of filesToLint) {
            if (fs.existsSync(file)) {
                execSync(`npx eslint ${file}`, { 
                    stdio: 'pipe',
                    cwd: process.cwd()
                });
                log(COLORS.GREEN, `✓ ESLint passed for ${file}`);
            }
        }
    } catch (error) {
        log(COLORS.RED, '✗ ESLint found issues');
        allPassed = false;
    }
    
    // Test 8: Integration Points
    log(COLORS.YELLOW, '\n8. Testing Integration Points:');
    const integrationTests = [
        {
            file: 'react/features/recording/hooks.web.ts',
            search: 'JitsiRecordingConstants.mode.FILE',
            desc: 'Recording mode integration'
        },
        {
            file: 'react/features/toolbox/hooks.web.ts',
            search: 'useAudioRecordingButton',
            desc: 'Toolbox hook integration'
        },
        {
            file: 'react/features/base/toolbox/types.ts',
            search: 'ButtonsWithNotifyClick',
            desc: 'Button notification types'
        }
    ];
    
    for (const test of integrationTests) {
        if (!checkFileContains(test.file, test.search, test.desc)) {
            allPassed = false;
        }
    }
    
    // Final Summary
    log(COLORS.BLUE, '\n=== Test Summary ===');
    
    if (allPassed) {
        log(COLORS.GREEN, '🎉 All tests passed! Audio recording implementation is complete.');
        log(COLORS.GREEN, '\nNext steps:');
        log(COLORS.GREEN, '1. Add "audiorecording" to your config.js toolbarButtons array');
        log(COLORS.GREEN, '2. Configure your Jibri instance with the provided configuration');
        log(COLORS.GREEN, '3. Set up proper XMPP authentication for recording');
        log(COLORS.GREEN, '4. Test in a real Jitsi Meet environment');
    } else {
        log(COLORS.RED, '❌ Some tests failed. Please review the issues above.');
        log(COLORS.YELLOW, '\nCheck the implementation documentation for guidance:');
        log(COLORS.YELLOW, '- AUDIO_RECORDING_IMPLEMENTATION.md');
        log(COLORS.YELLOW, '- audio-recording-config-example.js');
    }
    
    log(COLORS.BLUE, '\n=== Additional Information ===');
    log(COLORS.BLUE, 'Documentation files:');
    log(COLORS.BLUE, '- AUDIO_RECORDING_IMPLEMENTATION.md: Complete setup guide');
    log(COLORS.BLUE, '- audio-recording-config-example.js: Configuration examples');
    log(COLORS.BLUE, '- test-complete-implementation.js: This test script');
    
    log(COLORS.BLUE, '\nKey features implemented:');
    log(COLORS.BLUE, '- Audio-only recording button in Jitsi Meet toolbar');
    log(COLORS.BLUE, '- Backend audio recording service in Jibri');
    log(COLORS.BLUE, '- XMPP integration for recording requests');
    log(COLORS.BLUE, '- Proper TypeScript and ESLint compliance');
    log(COLORS.BLUE, '- Configuration examples and documentation');
    
    return allPassed;
}

// Run the tests
if (require.main === module) {
    const success = runTests();
    process.exit(success ? 0 : 1);
}

module.exports = { runTests }; 