#!/bin/bash
# Nautilus Jitsi Suite - Rebase from Upstream Script
set -e

echo "🚀 Nautilus Jitsi Suite - Rebase from Upstream"
echo "Usage: ./scripts/rebase-upstream.sh [jitsi-meet|jibri|all]"

component=${1:-all}

case $component in
    "jitsi-meet")
        echo "📦 Backing up jitsi-meet modifications..."
        mkdir -p backups/jitsi-meet
        cp jitsi-meet/react/features/recording/components/Recording/AudioRecordButton.tsx backups/jitsi-meet/ 2>/dev/null || true
        
        echo "🔄 Pulling jitsi-meet updates..."
        git fetch jitsi-meet-upstream
        git subtree pull --prefix=jitsi-meet jitsi-meet-upstream/master --squash
        
        echo "🔧 Restoring modifications..."
        cp backups/jitsi-meet/AudioRecordButton.tsx jitsi-meet/react/features/recording/components/Recording/ 2>/dev/null || true
        echo "✅ jitsi-meet updated successfully!"
        ;;
    "jibri")
        echo "📦 Backing up jibri modifications..."
        mkdir -p backups/jibri
        cp jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/XmppApi.kt backups/jibri/ 2>/dev/null || true
        
        echo "🔄 Pulling jibri updates..."
        git fetch jibri-upstream
        git subtree pull --prefix=jibri jibri-upstream/master --squash
        
        echo "🔧 Restoring modifications..."
        cp backups/jibri/AudioRecordingJibriService.kt jibri/src/main/kotlin/org/jitsi/jibri/service/impl/ 2>/dev/null || true
        cp backups/jibri/JibriManager.kt jibri/src/main/kotlin/org/jitsi/jibri/ 2>/dev/null || true
        cp backups/jibri/XmppApi.kt jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/ 2>/dev/null || true
        echo "✅ jibri updated successfully!"
        ;;
    "all")
        echo "📦 Backing up all modifications..."
        mkdir -p backups/jitsi-meet backups/jibri
        cp jitsi-meet/react/features/recording/components/Recording/AudioRecordButton.tsx backups/jitsi-meet/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/XmppApi.kt backups/jibri/ 2>/dev/null || true
        
        echo "🔄 Pulling both repositories..."
        git fetch jitsi-meet-upstream
        git subtree pull --prefix=jitsi-meet jitsi-meet-upstream/master --squash
        git fetch jibri-upstream
        git subtree pull --prefix=jibri jibri-upstream/master --squash
        
        echo "🔧 Restoring all modifications..."
        cp backups/jitsi-meet/AudioRecordButton.tsx jitsi-meet/react/features/recording/components/Recording/ 2>/dev/null || true
        cp backups/jibri/AudioRecordingJibriService.kt jibri/src/main/kotlin/org/jitsi/jibri/service/impl/ 2>/dev/null || true
        cp backups/jibri/JibriManager.kt jibri/src/main/kotlin/org/jitsi/jibri/ 2>/dev/null || true
        cp backups/jibri/XmppApi.kt jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/ 2>/dev/null || true
        echo "✅ Both repositories updated successfully!"
        ;;
    *)
        echo "❌ Invalid option. Use: jitsi-meet, jibri, or all"
        exit 1
        ;;
esac

echo ""
echo "🎉 Rebase complete! Your audio recording modifications have been preserved." 