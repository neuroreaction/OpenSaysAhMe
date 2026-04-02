#!/bin/bash
#
# Garage Door Controller - Quick Setup Script
# Run this on your Raspberry Pi after fresh OS install
#

set -e  # Exit on any error

echo "======================================"
echo "Garage Door Controller - Quick Setup"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "⚠️  Don't run as root. Run as pi user."
   exit 1
fi

echo "📦 Step 1: Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git

echo ""
echo "📁 Step 2: Creating project directory..."
sudo mkdir -p /opt/garagedoor
sudo chown $USER:$USER /opt/garagedoor

echo ""
echo "🐍 Step 3: Setting up Python virtual environment..."
cd /opt/garagedoor
python3 -m venv venv
source venv/bin/activate

echo ""
echo "📚 Step 4: Installing Python packages..."
pip install --upgrade pip
pip install flask gpiozero flask-cors

echo ""
echo "📝 Step 5: Setting up application files..."
echo "You need to copy these files to /opt/garagedoor/:"
echo "  - app.py"
echo "  - gpio_controller.py"
echo "  - config.json"
echo ""
read -p "Have you copied all files? (yes/no): " files_copied

if [ "$files_copied" != "yes" ]; then
    echo ""
    echo "Please copy the files first, then run this script again."
    exit 1
fi

echo ""
echo "🔐 Step 6: Generating secure API token..."
TOKEN=$(openssl rand -hex 32)
echo "Your new API token: $TOKEN"
echo ""
echo "⚠️  IMPORTANT: Save this token securely!"
echo "Add it to config.json under api_tokens array"
echo ""
read -p "Press Enter after updating config.json with the token..."

echo ""
echo "🧪 Step 7: Testing GPIO (optional)..."
read -p "Do you want to test GPIO pins now? (yes/no): " test_gpio

if [ "$test_gpio" = "yes" ]; then
    echo "Make sure garage door is NOT connected yet!"
    read -p "Press Enter to continue with GPIO test..."
    python3 gpio_controller.py
fi

echo ""
echo "🔧 Step 8: Creating systemd service..."
sudo bash -c 'cat > /etc/systemd/system/garagedoor.service << EOF
[Unit]
Description=Garage Door Controller API
After=network.target

[Service]
Type=simple
User='$USER'
WorkingDirectory=/opt/garagedoor
Environment="PATH=/opt/garagedoor/venv/bin"
ExecStart=/opt/garagedoor/venv/bin/python /opt/garagedoor/app.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF'

echo ""
echo "🚀 Step 9: Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable garagedoor.service
sudo systemctl start garagedoor.service

echo ""
echo "⏳ Waiting for service to start..."
sleep 3

echo ""
echo "📊 Checking service status..."
sudo systemctl status garagedoor.service --no-pager || true

echo ""
echo "======================================"
echo "✅ Setup Complete!"
echo "======================================"
echo ""
echo "📱 Access Information:"
echo "   Local IP: $(hostname -I | awk '{print $1}')"
echo "   Port: 5000"
echo "   Web Interface: http://$(hostname -I | awk '{print $1}'):5000?token=YOUR_TOKEN"
echo ""
echo "🔧 Useful Commands:"
echo "   View logs: sudo journalctl -u garagedoor.service -f"
echo "   Restart: sudo systemctl restart garagedoor.service"
echo "   Stop: sudo systemctl stop garagedoor.service"
echo ""
echo "🔐 Your API Token: $TOKEN"
echo "   Save this token for your iOS app!"
echo ""
echo "⚠️  Next Steps:"
echo "   1. Test the web interface from your browser"
echo "   2. Build the iOS app with your token"
echo "   3. Test both doors work correctly"
echo "   4. Connect to garage door opener ONLY after testing"
echo ""
