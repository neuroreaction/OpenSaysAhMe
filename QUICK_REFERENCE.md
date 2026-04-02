# Garage Door Controller - Quick Reference

## 🚀 Quick Start Commands

### Start/Stop Service
```bash
sudo systemctl start garagedoor.service
sudo systemctl stop garagedoor.service
sudo systemctl restart garagedoor.service
sudo systemctl status garagedoor.service
```

### View Logs
```bash
# Live logs
sudo journalctl -u garagedoor.service -f

# Last 50 lines
sudo journalctl -u garagedoor.service -n 50

# Today's logs
sudo journalctl -u garagedoor.service --since today
```

### Edit Configuration
```bash
cd /opt/garagedoor
nano config.json
# After editing:
sudo systemctl restart garagedoor.service
```

## 🧪 Testing Checklist

### 1. GPIO Test (Hardware Disconnected)
```bash
cd /opt/garagedoor
source venv/bin/activate
python3 gpio_controller.py
```
✅ Should activate GPIO pins with 0.5s pulse

### 2. API Service Test
```bash
# Check if service is running
curl http://localhost:5000/health

# Should return: {"status":"healthy","service":"garage-door-controller"}
```

### 3. Authentication Test
```bash
# Get your token from config.json
TOKEN="your_token_here"

# Test Sara's door
curl -X POST http://localhost:5000/api/trigger/sara \
  -H "Authorization: Bearer $TOKEN"

# Should return: {"status":"success","message":"Sara's door activated","door":"sara"}
```

### 4. Web Interface Test
Open browser:
```
http://YOUR_PI_IP:5000?token=YOUR_TOKEN
```
✅ Should see garage door control page

### 5. Network Access Test (from Mac)
```bash
# Replace with your Pi's IP and token
curl -X POST http://192.168.1.XXX:5000/api/trigger/sara \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 6. iOS App Test
1. Build app in Xcode
2. Update Config with Pi IP and token
3. Run on device (simulator won't reach local network)
4. Tap buttons to trigger doors

## 🔐 Security Checklist

- [ ] Changed default Pi password
- [ ] Generated strong API token (32+ chars)
- [ ] Token stored securely in iOS Keychain
- [ ] SSH password login disabled (keys only)
- [ ] Firewall configured (ufw)
- [ ] Regular system updates scheduled
- [ ] Logs monitored for unauthorized access
- [ ] HTTPS configured for internet access

## 🛠️ Common Issues & Fixes

### Service Won't Start
```bash
# Check for errors
sudo journalctl -u garagedoor.service -n 50

# Common causes:
# - Permission issues: sudo chown -R pi:pi /opt/garagedoor
# - Missing dependencies: source venv/bin/activate && pip install flask gpiozero
# - Config syntax error: validate config.json
```

### GPIO Permission Denied
```bash
sudo usermod -a -G gpio pi
sudo reboot
```

### Can't Access from Network
```bash
# Check if service is listening
sudo netstat -tlnp | grep 5000

# Check firewall
sudo ufw status

# Allow port 5000
sudo ufw allow 5000/tcp
```

### 502 Bad Gateway
```bash
# Usually means Python app crashed
sudo journalctl -u garagedoor.service -n 50

# Restart service
sudo systemctl restart garagedoor.service
```

### Door Doesn't Activate
1. Check GPIO test works: `python3 gpio_controller.py`
2. Verify wiring connections
3. Check relay type (active HIGH vs LOW)
4. Test with multimeter
5. Review logs: `sudo journalctl -u garagedoor.service -f`

## 📊 Monitoring

### Check System Status
```bash
# Service health
curl http://localhost:5000/health

# System resources
top
htop

# Disk space
df -h

# Temperature (important for Pi)
vcgencmd measure_temp
```

### Set Up Auto-Monitoring (Optional)
```bash
# Create monitoring script
nano /home/pi/monitor_garage.sh
```

```bash
#!/bin/bash
# Simple monitoring script

while true; do
    STATUS=$(curl -s http://localhost:5000/health | grep healthy)
    if [ -z "$STATUS" ]; then
        echo "$(date): Service down!" >> /home/pi/garage_monitor.log
        sudo systemctl restart garagedoor.service
    fi
    sleep 300  # Check every 5 minutes
done
```

## 🌐 Internet Access Setup

### Port Forwarding
1. Log into router admin
2. Forward external port (e.g., 8443) to Pi IP port 5000
3. Test from external network

### Dynamic DNS (if no static IP)
```bash
# Install DuckDNS client (example)
sudo apt-get install curl

# Create update script
mkdir ~/duckdns
cd ~/duckdns
nano duck.sh
```

```bash
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -
```

```bash
chmod +x duck.sh
# Add to crontab
crontab -e
# Add line: */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
```

### HTTPS with Nginx (Production)
```bash
# Install nginx and certbot
sudo apt-get install nginx certbot python3-certbot-nginx

# Configure nginx as reverse proxy
sudo nano /etc/nginx/sites-available/garagedoor
```

## 📱 iOS App Updates

### Update API Endpoint
Edit GarageDoorApp.swift:
```swift
struct Config {
    static let baseURL = "https://yourdomain.com"  // HTTPS for internet
    static let apiToken = "YOUR_API_TOKEN"
}
```

### Add to Keychain (Production)
```swift
import Security

class KeychainService {
    static func saveToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "garage_api_token",
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "garage_api_token",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
```

## 🔄 Backup & Recovery

### Backup Configuration
```bash
# Backup config and code
tar -czf ~/garage_backup_$(date +%Y%m%d).tar.gz /opt/garagedoor
```

### Restore Configuration
```bash
# Extract backup
tar -xzf ~/garage_backup_YYYYMMDD.tar.gz -C /

# Restart service
sudo systemctl restart garagedoor.service
```

### SD Card Image (Full Backup)
```bash
# On Mac, backup entire SD card
sudo dd if=/dev/diskN of=~/garage_pi_backup.img bs=1m

# Restore
sudo dd if=~/garage_pi_backup.img of=/dev/diskN bs=1m
```

## 📞 Support Resources

- **Raspberry Pi Documentation**: https://www.raspberrypi.com/documentation/
- **Flask Documentation**: https://flask.palletsprojects.com/
- **gpiozero Documentation**: https://gpiozero.readthedocs.io/
- **Swift Documentation**: https://swift.org/documentation/

## 🎯 Performance Tips

1. **Reduce API response time**: Use async GPIO operations
2. **Add caching**: Cache status checks
3. **Optimize logging**: Rotate logs regularly
4. **Monitor temperature**: Add cooling if needed
5. **Use wired connection**: More reliable than WiFi

---

**Last Updated**: November 2025
**Version**: 2.0
