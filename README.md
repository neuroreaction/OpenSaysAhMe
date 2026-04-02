#  Modern Garage Door Controller

Better than a cloud solution-grade garage door controller for Raspberry Pi with iOS app support.
ersonal note: I originally hand-coded this in 2018 for the Raspberry Pi and iOS with the help of several online walkthroughs covering GPIO pinouts, WiringPi, and Apache. Then one day in 2021, the Pi updated and Apache was removed and replaced with NGINX. I did not use it much, so I did not notice until I went to show off my handiwork. Knowing nothing about NGINX at the time, I started reworking it over the next few years in my free time. Fast forward to 2025, I decided to have Claude help out, and this is the result. I will dig up the original code at some point, but I wanted to share this now. This should not be used from the internet since there is no SSL/TLS encryption, but by the time I am in my driveway my phone connects to Wi-Fi, so it works for me.
##  Features

- **Modern Technology**: Python 3 + Flask + gpiozero (no deprecated WiringPi)
- **Secure Authentication**: Token-based API access
- **Dual Interface**: iOS app + web fallback
- **Internet Ready**: HTTPS support for remote access
- **Auto-Start**: Systemd service runs on boot
- **Reliable**: Error handling and logging

##  What's Included

1. **Backend (Raspberry Pi)**
   - `app.py` - Flask REST API server
   - `gpio_controller.py` - Modern GPIO control
   - `config.json` - Configuration file
   - `setup.sh` - Automated installation script

2. **Frontend (iOS)**
   - `GarageDoorApp.swift` - Complete iOS app
   - Token authentication
   - Beautiful UI with haptic feedback

3. **Documentation**
   - `GARAGE_DOOR_SETUP_GUIDE.md` - Complete setup instructions
   - `QUICK_REFERENCE.md` - Commands and troubleshooting

##  Quick Start

### 1. Prepare Raspberry Pi
```bash
# Flash Raspberry Pi OS Lite
# SSH into Pi
# Run initial setup
sudo raspi-config
```

### 2. Install Controller
```bash
# Copy all files to Pi
# Make setup script executable
chmod +x setup.sh

# Run automated setup
./setup.sh
```

### 3. Configure iOS App
```swift
// Edit Config in GarageDoorApp.swift
struct Config {
    static let baseURL = "http://YOUR_PI_IP:5000"
    static let apiToken = "YOUR_GENERATED_TOKEN"
}
```

### 4. Test Everything
```bash
# Test API locally
curl -X POST http://localhost:5000/api/trigger/Right \
  -H "Authorization: Bearer YOUR_TOKEN"

# Open web interface
http://YOUR_PI_IP:5000?token=YOUR_TOKEN
```

##  Hardware Setup

### GPIO Connections (BCM Numbering)
- **GPIO 23** → Right door relay
- **GPIO 4** → Left door relay
- **GPIO 22** → LED
- **GND** → Common ground
#### there is a pin out screenshot in this collection.
### Relay Wiring
```
Garage Opener    Relay Board    Raspberry Pi
─────────────    ───────────    ────────────
Terminal 1   →   NO/COM    
Terminal 2   →   NO/COM         
                 Signal    →    GPIO 23 (Right)
                 Signal    →    GPIO 4 (Left)
                 VCC       →    5V
                 GND       →    GND

```
### Indicator Light Wire
LED   Raspberry Pi
   +      GPIO 22
   -      GPIO Ground (any unused Ground Pin)
...

##  API Reference

### Endpoints

**Trigger Right Door**
```bash
POST /api/trigger/Right
Authorization: Bearer YOUR_TOKEN
```

**Trigger Left Door**
```bash
POST /api/trigger/Left
Authorization: Bearer YOUR_TOKEN
```

**Check Status**
```bash
GET /api/status
Authorization: Bearer YOUR_TOKEN
```

**Health Check** (no auth)
```bash
GET /health
```

##  Security

### Essential Steps
1. Change default Pi password
2. Generate strong API tokens (32+ characters)
3. Use SSH keys, disable password auth
4. Configure firewall (ufw)
5. Use HTTPS for internet access
6. Store tokens securely (iOS Keychain)

### Generate Secure Token
```bash
openssl rand -hex 32
```

##  iOS App Features

- **Simple Interface**: Two large buttons for easy access
- **Visual Feedback**: Animated button states
- **Haptic Feedback**: Confirmation on successful trigger
- **Error Handling**: Clear error messages
- **Connection Status**: Real-time indicator
- **Secure**: Token stored in Keychain

##  Internet Access (Optional)

### Requirements
- Dynamic DNS or static IP
- Router port forwarding
- SSL certificate (Let's Encrypt)
- Nginx reverse proxy

##  Maintenance

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
# Edit files as needed
sudo systemctl restart garagedoor.service
```

### Backup Configuration
```bash
tar -czf ~/garage_backup.tar.gz /opt/garagedoor
```

## Troubleshooting

### Service Won't Start
- Check logs: `sudo journalctl -u garagedoor.service -n 50`
- Verify permissions: `ls -la /opt/garagedoor`
- Test manually: `cd /opt/garagedoor && source venv/bin/activate && python3 app.py`

### GPIO Not Working
- Run test: `python3 gpio_controller.py`
- Check pin numbers (BCM vs physical)
- Verify relay type (active HIGH/LOW)
- Check wiring with multimeter

### Can't Access from Network
- Verify service listening: `sudo netstat -tlnp | grep 5000`
- Check firewall: `sudo ufw status`
- Test from Pi: `curl http://localhost:5000/health`

## System Requirements

### Raspberry Pi
- **Model**: Pi 3 or newer
- **OS**: Raspberry Pi OS (32 or 64-bit)
- **Storage**: 8GB+ SD card
- **Network**: WiFi or Ethernet

### iOS Device
- **OS**: iOS 14 or later
- **Xcode**: 13+ for development
- **Network**: WiFi access to Pi (local or internet)

##  Roadmap

Future enhancements:
- [ ] Garage door open/closed sensors
- [ ] Activity history logging
- [ ] Multiple user tokens
- [ ] iOS widgets
- [ ] Push notifications
- [ ] HomeKit integration
- [ ] Voice control (Siri)

## Disclaimer

This system controls physical hardware. Always:
- Test thoroughly before connecting to garage doors
- Verify all connections with a multimeter
- Follow electrical safety guidelines
- Ensure proper relay ratings
- Keep backup manual opener
- Test emergency release functionality

## Contributing

Found a bug? Have a feature request? Open an issue or submit a pull request!

## Support

For detailed instructions, see:
- `GARAGE_DOOR_SETUP_GUIDE.md` - Complete setup
- `QUICK_REFERENCE.md` - Commands and tips

---



Version 2.0 | November 2025
