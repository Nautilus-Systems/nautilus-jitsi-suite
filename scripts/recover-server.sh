#!/bin/bash
set -e

echo "🚑 Server Recovery Script for Failed Jitsi Deployment"
echo "This script will help recover from deployment failures"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "❌ This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

echo "🔍 Analyzing server state..."

# Check what's installed
JITSI_INSTALLED=false
JIBRI_INSTALLED=false
NGINX_INSTALLED=false

if dpkg -l | grep -q jitsi-meet; then
    JITSI_INSTALLED=true
    echo "✅ Jitsi Meet packages are installed"
else
    echo "❌ Jitsi Meet packages not found"
fi

if dpkg -l | grep -q jibri; then
    JIBRI_INSTALLED=true
    echo "✅ Jibri packages are installed"
else
    echo "❌ Jibri packages not found"
fi

if dpkg -l | grep -q nginx; then
    NGINX_INSTALLED=true
    echo "✅ Nginx is installed"
else
    echo "❌ Nginx not found"
fi

# Check services
echo ""
echo "🔍 Checking service status..."
services=("prosody" "jicofo" "jitsi-videobridge2" "jibri" "nginx")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "✅ $service: Running"
    elif systemctl is-enabled --quiet $service 2>/dev/null; then
        echo "⚠️ $service: Installed but not running"
    else
        echo "❌ $service: Not found/enabled"
    fi
done

# Check jibri user
echo ""
echo "🔍 Checking jibri user..."
if id "jibri" &>/dev/null; then
    echo "✅ jibri user exists"
else
    echo "❌ jibri user does not exist"
    echo "🔧 Creating jibri user..."
    sudo useradd -r -g audio -G audio,video,plugdev jibri || echo "Failed to create jibri user"
fi

echo ""
echo "🛠️ Recovery Options:"
echo "1. Clean restart all services"
echo "2. Fix jibri user and permissions"
echo "3. Run fresh installation (will remove current setup)"
echo "4. Just check logs"
echo "5. Exit"

read -p "Choose an option (1-5): " choice

case $choice in
    1)
        echo "🔄 Cleaning and restarting all services..."
        
        # Stop all services
        for service in "${services[@]}"; do
            if systemctl is-active --quiet $service 2>/dev/null; then
                echo "Stopping $service..."
                sudo systemctl stop $service || true
            fi
        done
        
        # Clean temporary files
        sudo rm -rf /tmp/jibri-* /tmp/jitsi-* || true
        
        # Restart core services
        if [ "$JITSI_INSTALLED" = true ]; then
            echo "Starting Jitsi services..."
            sudo systemctl start prosody || echo "Failed to start prosody"
            sleep 2
            sudo systemctl start jicofo || echo "Failed to start jicofo"
            sleep 2
            sudo systemctl start jitsi-videobridge2 || echo "Failed to start jitsi-videobridge2"
        fi
        
        if [ "$JIBRI_INSTALLED" = true ]; then
            echo "Starting Jibri..."
            sudo systemctl start jibri || echo "Failed to start jibri"
        fi
        
        if [ "$NGINX_INSTALLED" = true ]; then
            echo "Starting nginx..."
            sudo systemctl start nginx || echo "Failed to start nginx"
        fi
        
        echo "✅ Service restart complete"
        ;;
        
    2)
        echo "🔧 Fixing jibri user and permissions..."
        
        # Create jibri user if needed
        if ! id "jibri" &>/dev/null; then
            sudo useradd -r -g audio -G audio,video,plugdev jibri
        fi
        
        # Create directories
        sudo mkdir -p /opt/jibri /usr/share/jibri /etc/jitsi/jibri /var/log/jibri /tmp/jibri-recordings /recordings/audio_recordings
        
        # Fix ownership
        sudo chown jibri:jibri /opt/jibri /usr/share/jibri /etc/jitsi/jibri /var/log/jibri /tmp/jibri-recordings /recordings/audio_recordings 2>/dev/null || true
        
        echo "✅ jibri user and permissions fixed"
        ;;
        
    3)
        echo "⚠️ This will remove the current installation and start fresh."
        read -p "Are you sure? (y/N): " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            echo "🗑️ Removing current installation..."
            
            # Stop services
            for service in "${services[@]}"; do
                sudo systemctl stop $service || true
                sudo systemctl disable $service || true
            done
            
            # Remove packages
            sudo apt remove --purge -y jitsi-meet jibri prosody jicofo jitsi-videobridge2 || true
            sudo apt autoremove -y || true
            
            # Remove configurations
            sudo rm -rf /etc/jitsi /etc/prosody /usr/share/jitsi-meet /opt/jibri /usr/share/jibri || true
            
            # Remove jibri user
            sudo userdel jibri || true
            
            echo "✅ Cleanup complete"
            echo "📝 Run the fresh installation script next:"
            echo "   ./scripts/fresh-install.sh [your-domain]"
        else
            echo "❌ Cancelled"
        fi
        ;;
        
    4)
        echo "📋 Checking logs..."
        echo ""
        echo "=== Prosody logs ==="
        sudo journalctl -u prosody --no-pager -n 20 || echo "No prosody logs"
        echo ""
        echo "=== Jicofo logs ==="
        sudo journalctl -u jicofo --no-pager -n 20 || echo "No jicofo logs"
        echo ""
        echo "=== JVB logs ==="
        sudo journalctl -u jitsi-videobridge2 --no-pager -n 20 || echo "No JVB logs"
        echo ""
        echo "=== Jibri logs ==="
        sudo journalctl -u jibri --no-pager -n 20 || echo "No jibri logs"
        echo ""
        echo "=== Nginx logs ==="
        sudo tail -20 /var/log/nginx/error.log 2>/dev/null || echo "No nginx error logs"
        ;;
        
    5)
        echo "👋 Exiting..."
        exit 0
        ;;
        
    *)
        echo "❌ Invalid option"
        exit 1
        ;;
esac

echo ""
echo "🏥 Final status check:"
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
    fi
done

echo ""
echo "🌐 Testing web access..."
if curl -f -s "http://localhost" > /dev/null; then
    echo "✅ Web server is responding"
    echo "🌐 Try accessing: http://$(hostname -I | awk '{print $1}')"
else
    echo "❌ Web server is not responding"
fi

echo ""
echo "📝 Recovery complete!"
echo "If issues persist, consider running a fresh installation." 