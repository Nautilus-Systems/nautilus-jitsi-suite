#!/bin/bash

# Nautilus Jitsi Suite - Rebase from Upstream Script
# This script helps pull updates from the original jitsi-meet and jibri repositories

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 Nautilus Jitsi Suite - Rebase from Upstream"
echo "Usage: ./scripts/rebase-from-upstream.sh [jitsi-meet|jibri|all]"

# Function to show usage
show_usage() {
    echo "Usage: $0 [jitsi-meet|jibri|all]"
    echo ""
    echo "Options:"
    echo "  jitsi-meet  - Pull updates from jitsi-meet upstream only"
    echo "  jibri       - Pull updates from jibri upstream only"
    echo "  all         - Pull updates from both repositories (default)"
    echo ""
}

# Function to backup current modifications
backup_modifications() {
    local component=$1
    echo "📦 Backing up $component modifications..."
    mkdir -p backups/$component
    if [ "$component" = "jitsi-meet" ]; then
        cp jitsi-meet/react/features/recording/components/Recording/AudioRecordButton.tsx backups/jitsi-meet/ 2>/dev/null || true
    elif [ "$component" = "jibri" ]; then
        cp jibri/src/main/kotlin/org/jitsi/jibri/service/impl/AudioRecordingJibriService.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/JibriManager.kt backups/jibri/ 2>/dev/null || true
        cp jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/XmppApi.kt backups/jibri/ 2>/dev/null || true
    fi
}

# Function to restore modifications
restore_modifications() {
    local component=$1
    echo "🔧 Restoring $component modifications..."
    if [ "$component" = "jitsi-meet" ]; then
        cp backups/jitsi-meet/AudioRecordButton.tsx jitsi-meet/react/features/recording/components/Recording/ 2>/dev/null || true
    elif [ "$component" = "jibri" ]; then
        cp backups/jibri/AudioRecordingJibriService.kt jibri/src/main/kotlin/org/jitsi/jibri/service/impl/ 2>/dev/null || true
        cp backups/jibri/JibriManager.kt jibri/src/main/kotlin/org/jitsi/jibri/ 2>/dev/null || true
        cp backups/jibri/XmppApi.kt jibri/src/main/kotlin/org/jitsi/jibri/api/xmpp/ 2>/dev/null || true
    fi
}

# Function to pull updates from upstream
pull_updates() {
    local component=$1
    echo "🔄 Pulling updates from $component upstream..."
    if [ "$component" = "jitsi-meet" ]; then
        git fetch jitsi-meet-upstream
        git subtree pull --prefix=jitsi-meet jitsi-meet-upstream/master --squash
    elif [ "$component" = "jibri" ]; then
        git fetch jibri-upstream
        git subtree pull --prefix=jibri jibri-upstream/master --squash
    fi
}

# Function to check for conflicts
check_conflicts() {
    if git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
        echo "⚠️  Merge conflicts detected! Please resolve them manually:"
        echo ""
        git status
        echo ""
        echo "After resolving conflicts, run:"
        echo "  git add ."
        echo "  git commit"
        echo ""
        return 1
    fi
    return 0
}

# Main function
main() {
    cd "$ROOT_DIR"
    
    local component=${1:-all}
    
    case $component in
        "jitsi-meet"|"jibri")
            echo "📋 Updating $component only..."
            backup_modifications "$component"
            pull_updates "$component"
            if check_conflicts; then
                restore_modifications "$component"
                echo "✅ $component updated successfully!"
            fi
            ;;
        "all")
            echo "📋 Updating both jitsi-meet and jibri..."
            backup_modifications "jitsi-meet"
            backup_modifications "jibri"
            
            pull_updates "jitsi-meet"
            if ! check_conflicts; then
                return 1
            fi
            
            pull_updates "jibri"
            if ! check_conflicts; then
                return 1
            fi
            
            restore_modifications "jitsi-meet"
            restore_modifications "jibri"
            echo "✅ Both repositories updated successfully!"
            ;;
        "-h"|"--help")
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Invalid option: $component"
            show_usage
            exit 1
            ;;
    esac
    
    echo ""
    echo "🎉 Rebase complete! Your audio recording modifications have been preserved."
    echo ""
    echo "Next steps:"
    echo "1. Test your modifications still work"
    echo "2. Run: npm test (in jitsi-meet directory)"
    echo "3. Run: mvn compile (in jibri directory)"
    echo "4. Commit any additional changes if needed"
}

# Run main function with all arguments
main "$@" 