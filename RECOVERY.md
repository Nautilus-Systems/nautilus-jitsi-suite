# 🚑 Server Recovery Guide

This guide helps you recover from failed Jitsi Meet + Jibri deployments.

## Quick Recovery Steps

### 1. **Immediate Recovery**
If your deployment just failed, run the recovery script:

```bash
# Download and run the recovery script
wget -O recover-server.sh https://raw.githubusercontent.com/yourusername/Nautilus/main/scripts/recover-server.sh
chmod +x recover-server.sh
./recover-server.sh
```

### 2. **Fresh Installation** 
If recovery doesn't work, start fresh:

```bash
# Download and run the fresh installation script
wget -O fresh-install.sh https://raw.githubusercontent.com/yourusername/Nautilus/main/scripts/fresh-install.sh
chmod +x fresh-install.sh
./fresh-install.sh your-domain.com
```

## Common Issues and Solutions

### ❌ `chown: invalid user: 'jibri:jibri'`
**Problem**: The jibri user doesn't exist
**Solution**: 
```bash
sudo useradd -r -g audio -G audio,video,plugdev jibri
sudo mkdir -p /opt/jibri /usr/share/jibri /etc/jitsi/jibri
sudo chown jibri:jibri /opt/jibri /usr/share/jibri /etc/jitsi/jibri
```

### ❌ `Failed to stop jibri.service: Unit jibri.service not loaded`
**Problem**: Jibri service doesn't exist yet
**Solution**: This is normal for fresh installations. The error can be ignored.

### ❌ Services won't start
**Problem**: Missing dependencies or configurations
**Solution**: 
```bash
# Check logs
sudo journalctl -u prosody -f
sudo journalctl -u jicofo -f
sudo journalctl -u jitsi-videobridge2 -f

# Restart in order
sudo systemctl restart prosody
sudo systemctl restart jicofo  
sudo systemctl restart jitsi-videobridge2
```

### ❌ Web interface not accessible
**Problem**: Nginx not configured or not running
**Solution**:
```bash
# Check nginx status
sudo systemctl status nginx

# Test nginx config
sudo nginx -t

# Restart nginx
sudo systemctl restart nginx
```

## Recovery Script Options

The recovery script provides several options:

1. **Clean restart all services** - Stops and restarts all Jitsi services
2. **Fix jibri user and permissions** - Creates jibri user and sets proper permissions
3. **Run fresh installation** - Completely removes and reinstalls everything
4. **Just check logs** - Shows recent logs from all services
5. **Exit** - Quit without changes

## Manual Recovery Steps

If the automated scripts don't work, follow these manual steps:

### Step 1: Check Service Status
```bash
# Check what's running
systemctl status prosody jicofo jitsi-videobridge2 jibri nginx

# Check what's installed
dpkg -l | grep jitsi
dpkg -l | grep jibri
```

### Step 2: Create Missing User
```bash
# Create jibri user if missing
sudo useradd -r -g audio -G audio,video,plugdev jibri

# Create required directories
sudo mkdir -p /opt/jibri /usr/share/jibri /etc/jitsi/jibri /var/log/jibri
sudo mkdir -p /tmp/jibri-recordings /recordings/audio_recordings

# Set ownership
sudo chown jibri:jibri /opt/jibri /usr/share/jibri /etc/jitsi/jibri /var/log/jibri
sudo chown jibri:jibri /tmp/jibri-recordings /recordings/audio_recordings
```

### Step 3: Fix Service Files
```bash
# Check if service files exist
ls -la /etc/systemd/system/ | grep jibri

# If missing, create basic service file
sudo tee /etc/systemd/system/jibri.service << 'EOF'
[Unit]
Description=Jibri
After=network.target

[Service]
Type=simple
User=jibri
Group=jibri
ExecStart=/usr/bin/java -jar /usr/share/jibri/jibri.jar
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jibri
```

### Step 4: Restart Services in Order
```bash
# Stop everything
sudo systemctl stop jibri jitsi-videobridge2 jicofo prosody nginx

# Start in dependency order
sudo systemctl start prosody
sleep 2
sudo systemctl start jicofo
sleep 2
sudo systemctl start jitsi-videobridge2
sleep 2
sudo systemctl start jibri
sudo systemctl start nginx
```

## Prevention

To avoid deployment failures in the future:

1. **Always run fresh installations on clean servers**
2. **Test the server setup before deploying custom code**
3. **Keep backups of working configurations**
4. **Monitor service logs during deployment**

## Getting Help

If you're still having issues:

1. **Check logs**: `sudo journalctl -u [service-name] -f`
2. **Test connectivity**: `curl -I http://localhost`
3. **Verify DNS**: `nslookup your-domain.com`
4. **Check firewall**: `sudo ufw status`

## Next Steps After Recovery

Once your server is recovered:

1. **Test basic Jitsi Meet functionality**
2. **Configure SSL/TLS certificates**
3. **Set up proper DNS records**
4. **Re-run the deployment with the updated workflow**

The updated deployment workflow now includes proper error handling and will detect fresh installations vs. existing deployments automatically. 