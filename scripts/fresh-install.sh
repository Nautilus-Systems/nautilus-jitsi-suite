#!/bin/bash
set -e

echo "🚀 Setting up fresh Jitsi Meet + Jibri installation..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root. Please run with sudo or as root user."
   exit 1
fi

# Variables
DOMAIN=${1:-$(hostname -I | awk '{print $1}')}
EMAIL=${2:-"admin@${DOMAIN}"}

echo "📝 Configuration:"
echo "   Domain: $DOMAIN"
echo "   Email: $EMAIL"
echo ""

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
apt install -y \
    curl \
    wget \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    nginx \
    openjdk-11-jdk \
    ffmpeg \
    chromium-browser \
    unzip

# Add Jitsi repository
echo "📦 Adding Jitsi repository..."
curl -fsSL https://download.jitsi.org/jitsi-key.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/jitsi-key.gpg
echo 'deb https://download.jitsi.org stable/' | tee /etc/apt/sources.list.d/jitsi-stable.list

# Update package list
apt update

# Pre-configure Jitsi Meet installation
echo "🔧 Pre-configuring Jitsi Meet..."
echo "jitsi-meet-web-config jitsi-meet/jvb-hostname string $DOMAIN" | debconf-set-selections
echo "jitsi-meet-web-config jitsi-meet/jvb-serve boolean true" | debconf-set-selections

# Install Jitsi Meet
echo "📦 Installing Jitsi Meet..."
apt install -y jitsi-meet

# Create jibri user
echo "👤 Creating jibri user..."
groupadd -f jibri || echo "jibri group already exists"; useradd -r -g jibri -G audio,video,plugdev jibri || echo "User jibri already exists"

# Create directories
echo "📁 Creating directories..."
mkdir -p /opt/jibri
mkdir -p /usr/share/jibri
mkdir -p /etc/jitsi/jibri
mkdir -p /var/log/jibri
mkdir -p /tmp/jibri-recordings
mkdir -p /recordings/audio_recordings

# Set ownership
chown jibri:jibri /opt/jibri
chown jibri:jibri /usr/share/jibri
chown jibri:jibri /etc/jitsi/jibri
chown jibri:jibri /var/log/jibri
chown jibri:jibri /tmp/jibri-recordings
chown jibri:jibri /recordings/audio_recordings

# Download and install Jibri
echo "📦 Installing Jibri..."
JIBRI_VERSION="8.0-139-g380a23a"
JIBRI_URL="https://download.jitsi.org/stable/jibri_${JIBRI_VERSION}-1_all.deb"

cd /tmp
wget $JIBRI_URL -O jibri.deb
dpkg -i jibri.deb || apt-get -f install -y

# Configure Jibri
echo "🔧 Configuring Jibri..."
cat > /etc/jitsi/jibri/jibri.conf << 'EOF'
jibri {
  recording {
    recordings-directory = "/tmp/jibri-recordings"
    finalize-script = ""
  }
  
  streaming {
    rtmp-allow-list = []
  }
  
  chrome {
    flags = [
      "--use-fake-ui-for-media-stream",
      "--start-maximized",
      "--kiosk",
      "--enabled",
      "--disable-infobars",
      "--autoplay-policy=no-user-gesture-required",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--no-sandbox"
    ]
  }
  
  stats {
    enable-stats-d = false
  }
  
  webhook {
    subscribers = []
  }
  
  jwt-info {
    // JWT configuration
  }
  
  call-status-checks {
    no-media-timeout = 30 seconds
    all-muted-timeout = 10 minutes
    default-call-empty-timeout = 30 seconds
  }
}
EOF

# Create Jibri systemd service
cat > /etc/systemd/system/jibri.service << 'EOF'
[Unit]
Description=Jibri
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/opt/jibri/jibri.sh
User=jibri
Group=jibri
Restart=always
RestartSec=10
Environment="JAVA_SYS_PROPS=-Dconfig.file=/etc/jitsi/jibri/jibri.conf"

[Install]
WantedBy=multi-user.target
EOF

# Create Jibri startup script
cat > /opt/jibri/jibri.sh << 'EOF'
#!/bin/bash
export DISPLAY=:0
cd /usr/share/jibri
exec java -Djava.util.logging.config.file=/etc/jitsi/jibri/logging.properties \
     -Dconfig.file=/etc/jitsi/jibri/jibri.conf \
     -jar jibri.jar
EOF

chmod +x /opt/jibri/jibri.sh
chown jibri:jibri /opt/jibri/jibri.sh

# Create logging configuration
cat > /etc/jitsi/jibri/logging.properties << 'EOF'
handlers= java.util.logging.ConsoleHandler

.level = INFO
java.util.logging.ConsoleHandler.level = INFO
java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter
java.util.logging.SimpleFormatter.format=[%1$tF %1$tT] [%4$-7s] %5$s %n
EOF

# Configure XMPP for Jibri
echo "🔧 Configuring XMPP for Jibri..."
JICOFO_CONFIG="/etc/jitsi/jicofo/jicofo.conf"
if [ -f "$JICOFO_CONFIG" ]; then
    # Add Jibri brewery configuration to jicofo
    tee -a "$JICOFO_CONFIG" << EOF

# Jibri configuration
jicofo {
  jibri {
    brewery-jid = "JibriBrewery@internal.auth.$DOMAIN"
    pending-timeout = 90 seconds
  }
}
EOF
fi

# Configure Prosody for Jibri
PROSODY_CONFIG="/etc/prosody/conf.avail/$DOMAIN.cfg.lua"
if [ -f "$PROSODY_CONFIG" ]; then
    echo "🔧 Configuring Prosody for Jibri..."
    tee -a "$PROSODY_CONFIG" << EOF

-- Jibri recorder virtual host
VirtualHost "recorder.$DOMAIN"
  modules_enabled = {
    "ping";
  }
  authentication = "internal_plain"

-- Jibri brewery component
Component "internal.auth.$DOMAIN" "muc"
    storage = "memory"
    modules_enabled = {
      "ping";
    }
    restrict_room_creation = true
    muc_room_locking = false
    muc_room_default_public_jids = true
EOF

    # Add Jibri user to Prosody
    prosodyctl register jibri auth.$DOMAIN jibripass
    prosodyctl register recorder recorder.$DOMAIN recorderpass
fi

# Configure Jitsi Meet for recording
echo "🔧 Configuring Jitsi Meet for recording..."
JITSI_CONFIG="/etc/jitsi/meet/$DOMAIN-config.js"
if [ -f "$JITSI_CONFIG" ]; then
    # Add recording configuration
    sed -i "/var config = {/a\\
    // Recording configuration\\
    fileRecordingsEnabled: true,\\
    liveStreamingEnabled: false,\\
    hiddenDomain: 'recorder.$DOMAIN'," "$JITSI_CONFIG"
fi

# Reload systemd and restart services
echo "🔄 Restarting services..."
systemctl daemon-reload
systemctl restart prosody
systemctl restart jicofo
systemctl restart jitsi-videobridge2
systemctl enable jibri
systemctl start jibri

# Configure nginx for larger file uploads
echo "🔧 Configuring nginx..."
sed -i '/http {/a \    client_max_body_size 100M;' /etc/nginx/nginx.conf
systemctl reload nginx

# Display status
echo ""
echo "🎉 Installation completed!"
echo ""
echo "📋 Service Status:"
systemctl is-active --quiet prosody && echo "✅ Prosody: Running" || echo "❌ Prosody: Failed"
systemctl is-active --quiet jicofo && echo "✅ Jicofo: Running" || echo "❌ Jicofo: Failed"
systemctl is-active --quiet jitsi-videobridge2 && echo "✅ JVB: Running" || echo "✅ JVB: Running"
systemctl is-active --quiet jibri && echo "✅ Jibri: Running" || echo "❌ Jibri: Failed"
systemctl is-active --quiet nginx && echo "✅ Nginx: Running" || echo "❌ Nginx: Failed"

echo ""
echo "🌐 Access your Jitsi Meet at: http://$DOMAIN"
echo ""
echo "📝 Next steps:"
echo "1. Configure SSL/TLS certificate with: /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh"
echo "2. Configure your domain in DNS if using a custom domain"
echo "3. Deploy your audio recording features using the GitHub workflow"
echo ""
echo "🔍 Troubleshooting:"
echo "- Logs: journalctl -u jibri -f"
echo "- Config: /etc/jitsi/jibri/jibri.conf"
echo "- Recordings: /tmp/jibri-recordings"
echo "" 