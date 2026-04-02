# Modern Garage Door Controller - Complete Setup Guide

## Overview
Secure REST API-based garage door controller using Python Flask and gpiozero.

**Features:**
- iOS app control with token authentication
- Web interface fallback (authenticated)
- Modern GPIO control (no deprecated WiringPi)
- HTTPS ready for internet access
- Auto-start on boot

**Hardware:**
- Raspberry Pi 3
- GPIO Pin 7 (BCM) = Sara's door
- GPIO Pin 4 (BCM) = David's door

---

## PART 1: FRESH RASPBERRY PI SETUP

### Step 1: Install Raspberry Pi OS
1. Download Raspberry Pi Imager: https://www.raspberrypi.com/software/
2. Flash "Raspberry Pi OS Lite (64-bit)" to SD card
3. Enable SSH before first boot:
   - Create empty file named `ssh` in boot partition
4. Boot Pi and SSH in: `ssh pi@raspberrypi.local`
5. Default password: `raspberry`

### Step 2: Initial Configuration
```bash
sudo raspi-config
```
- Change password
- Set hostname to "GDO"
- Enable VNC (optional)
- Expand filesystem
- Set locale/timezone
- Reboot

### Step 3: Update System
```bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install python3 python3-pip python3-venv git -y
```

---

## PART 2: INSTALL GARAGE DOOR CONTROLLER

### Step 1: Create Project Directory
```bash
sudo mkdir -p /opt/garagedoor
sudo chown pi:pi /opt/garagedoor
cd /opt/garagedoor
```

### Step 2: Create Python Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask gpiozero flask-cors
```

### Step 3: Create Application Files
Files will be provided separately (see PART 3 below).

---

## PART 3: APPLICATION FILES

You'll create these files in `/opt/garagedoor/`:

### File 1: `app.py` (Main Application)
The Flask REST API server with authentication.

### File 2: `config.json` (Configuration)
Store API tokens and settings.

### File 3: `gpio_controller.py` (GPIO Control)
Hardware interface using gpiozero.

### File 4: `templates/index.html` (Web Interface)
Browser-based control panel.

---

## PART 4: SYSTEMD SERVICE (AUTO-START)

### Create Service File
```bash
sudo nano /etc/systemd/system/garagedoor.service
```

Paste:
```ini
[Unit]
Description=Garage Door Controller API
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/garagedoor
Environment="PATH=/opt/garagedoor/venv/bin"
ExecStart=/opt/garagedoor/venv/bin/python /opt/garagedoor/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Enable and Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable garagedoor.service
sudo systemctl start garagedoor.service
sudo systemctl status garagedoor.service
```

---

## PART 5: SECURITY & INTERNET ACCESS

### Option A: Local Network Only (Recommended Start)
1. Access via local IP: `http://192.168.x.x:5000`
2. Test thoroughly before exposing to internet

### Option B: Internet Access with HTTPS
1. **Port Forward on Router:**
   - Forward external port (e.g., 8443) to Pi port 5000
   
2. **Dynamic DNS (if no static IP):**
   - Use No-IP, DuckDNS, or similar
   - Update config with your domain

3. **HTTPS with Let's Encrypt:**
   - Install nginx as reverse proxy
   - Use certbot for SSL certificates
   - (Detailed steps provided after basic testing)

4. **Firewall:**
   ```bash
   sudo apt-get install ufw
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 5000/tcp  # API (local only)
   sudo ufw enable
   ```

---

## PART 6: API ENDPOINTS

### Authentication
All requests require header:
```
Authorization: Bearer YOUR_TOKEN_HERE
```

### Endpoints

**1. Trigger Sara's Door**
```
POST /api/trigger/sara
Authorization: Bearer YOUR_TOKEN
```

**2. Trigger David's Door**
```
POST /api/trigger/dave
Authorization: Bearer YOUR_TOKEN
```

**3. Status Check**
```
GET /api/status
Authorization: Bearer YOUR_TOKEN
```
Returns: `{"status": "ok", "sara": "ready", "dave": "ready"}`

**4. Web Interface**
```
GET /
Authorization: Bearer YOUR_TOKEN (in URL or form)
```

---

## PART 7: iOS APP INTEGRATION

### App Requirements
- Swift 5+
- Store token securely in Keychain

### Example Swift Request
```swift
func triggerDoor(door: String, token: String) {
    let url = URL(string: "http://YOUR_PI_IP:5000/api/trigger/\(door)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error)")
            return
        }
        print("Door triggered successfully")
    }.resume()
}
```

---

## PART 8: TESTING PROCEDURE

### Step 1: Test API Locally
```bash
# Get your Pi's IP
hostname -I

# Test from Mac terminal (replace IP and TOKEN)
curl -X POST http://192.168.x.x:5000/api/trigger/sara \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Step 2: Test Web Interface
Open browser: `http://192.168.x.x:5000`
Enter token when prompted.

### Step 3: Test GPIO (WITHOUT GARAGE CONNECTED)
Verify GPIO pins activate correctly before connecting to garage door opener.

### Step 4: Connect to Garage
1. Wire GPIO pins to garage door relay
2. Test with short pulse duration first
3. Verify both doors work independently

---

## PART 9: MAINTENANCE

### View Logs
```bash
sudo journalctl -u garagedoor.service -f
```

### Restart Service
```bash
sudo systemctl restart garagedoor.service
```

### Update Code
```bash
cd /opt/garagedoor
# Edit files
sudo systemctl restart garagedoor.service
```

### Backup Configuration
```bash
# Backup tokens and settings
cp /opt/garagedoor/config.json ~/garagedoor_backup.json
```

---

## PART 10: SECURITY BEST PRACTICES

1. **Change default Pi password immediately**
2. **Use strong, unique API tokens** (32+ random characters)
3. **Disable password SSH**, use keys only
4. **Keep system updated:**
   ```bash
   sudo apt-get update && sudo apt-get upgrade
   ```
5. **Monitor logs regularly**
6. **Don't expose port 22 (SSH) to internet**
7. **Use HTTPS for internet access** (not HTTP)
8. **Rotate tokens periodically**

---

## TROUBLESHOOTING

### Service Won't Start
```bash
sudo journalctl -u garagedoor.service -n 50
```
Check for Python errors in output.

### GPIO Permission Denied
```bash
sudo usermod -a -G gpio pi
sudo reboot
```

### Can't Access from Network
1. Check firewall: `sudo ufw status`
2. Verify service running: `sudo systemctl status garagedoor.service`
3. Check Pi IP: `hostname -I`

### Door Doesn't Activate
1. Test GPIO manually:
   ```bash
   python3
   >>> from gpiozero import LED
   >>> door = LED(7)
   >>> door.on()
   >>> door.off()
   ```
2. Check wiring connections
3. Verify relay voltage compatibility

---

## NEXT STEPS

After completing this guide:
1. ✅ Test all API endpoints locally
2. ✅ Build iOS app with token authentication
3. ✅ Set up HTTPS if internet access needed
4. ✅ Configure router port forwarding
5. ✅ Test from outside network
6. ✅ Set up monitoring/alerts (optional)

---

**⚠️ CRITICAL REMINDERS:**
- READ ALL STEPS before starting
- Test locally before internet exposure
- NEVER commit tokens to version control
- Keep backups of working configurations
