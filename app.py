#!/usr/bin/env python3
"""
Garage Door Controller REST API
Modern implementation using Flask and gpiozero
"""

from flask import Flask, request, jsonify, render_template_string
from functools import wraps
import json
import logging
from gpio_controller import GarageDoorController

# Initialize Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = 'change-this-to-random-string'

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Load configuration
try:
    with open('config.json', 'r') as f:
        config = json.load(f)
except FileNotFoundError:
    logger.error("config.json not found! Creating default...")
    config = {
        "api_tokens": ["CHANGE_THIS_TOKEN_IMMEDIATELY"],
        "gpio_pins": {"Right": 23, "Left": 4, "LED": 22},
        "pulse_duration": 1.0,
        "host": "0.0.0.0",
        "port": 5000
    }
    with open('config.json', 'w') as f:
        json.dump(config, f, indent=2)

# Initialize GPIO controller
controller = GarageDoorController(
    Right_pin=config['gpio_pins']['Right'],
    Left_pin=config['gpio_pins']['Left'],
    led_pin=config['gpio_pins']['LED'],
    pulse_duration=config['pulse_duration']
)

# Authentication decorator
def require_token(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        token = None
        
        # Check Authorization header
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header.split(' ')[1]
        
        # Check query parameter (for web interface)
        if not token:
            token = request.args.get('token')
        
        # Validate token
        if not token or token not in config['api_tokens']:
            logger.warning(f"Unauthorized access attempt from {request.remote_addr}")
            return jsonify({"error": "Unauthorized", "message": "Invalid or missing token"}), 401
        
        return f(*args, **kwargs)
    return decorated_function

# Routes
@app.route('/')
@require_token
def index():
    """Web interface for garage door control"""
    html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Garage Door Controller</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                background: #1a1a1a;
                color: #ffffff;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                padding: 20px;
            }
            .header {
                text-align: center;
                padding: 20px 0;
                border-bottom: 2px solid #333;
                margin-bottom: 40px;
            }
            h1 { font-size: 28px; margin-bottom: 10px; }
            .subtitle { color: #888; font-size: 14px; }
            .container {
                max-width: 600px;
                margin: 0 auto;
                width: 100%;
                flex: 1;
                display: flex;
                flex-direction: column;
                gap: 20px;
            }
            .door-button {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border: none;
                border-radius: 16px;
                padding: 40px;
                font-size: 24px;
                font-weight: 600;
                color: white;
                cursor: pointer;
                transition: all 0.3s ease;
                box-shadow: 0 8px 24px rgba(0,0,0,0.3);
                position: relative;
                overflow: hidden;
            }
            .door-button:hover {
                transform: translateY(-2px);
                box-shadow: 0 12px 32px rgba(0,0,0,0.4);
            }
            .door-button:active {
                transform: translateY(0);
                box-shadow: 0 4px 16px rgba(0,0,0,0.2);
            }
            .door-button.activating {
                background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                animation: pulse 1s ease-in-out;
            }
            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.7; }
            }
            .door-name {
                display: block;
                font-size: 32px;
                margin-bottom: 8px;
            }
            .door-status {
                display: block;
                font-size: 14px;
                opacity: 0.9;
                font-weight: 400;
            }
            .status-indicator {
                position: fixed;
                top: 20px;
                right: 20px;
                padding: 8px 16px;
                background: #2d2d2d;
                border-radius: 20px;
                font-size: 12px;
                display: flex;
                align-items: center;
                gap: 8px;
            }
            .status-dot {
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: #4caf50;
                animation: blink 2s infinite;
            }
            @keyframes blink {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.3; }
            }
            .footer {
                text-align: center;
                padding: 20px 0;
                color: #666;
                font-size: 12px;
                border-top: 1px solid #333;
                margin-top: 40px;
            }
            @media (max-width: 480px) {
                .door-button { padding: 30px; font-size: 20px; }
                .door-name { font-size: 28px; }
            }
        </style>
    </head>
    <body>
        <div class="status-indicator">
            <div class="status-dot"></div>
            <span>System Online</span>
        </div>
        
        <div class="header">
            <h1>🚗 Garage Door Controller</h1>
            <div class="subtitle">Tap a button to activate</div>
        </div>
        
        <div class="container">
            <button class="door-button" onclick="triggerDoor('Right')">
                <span class="door-name">Right Door</span>
                <span class="door-status">Ready</span>
            </button>
            
            <button class="door-button" onclick="triggerDoor('Left')">
                <span class="door-name">Left Door</span>
                <span class="door-status">Ready</span>
            </button>
        </div>
        
        <div class="footer">
            Raspberry Pi Garage Controller v2.0
        </div>
        
        <script>
            const token = new URLSearchParams(window.location.search).get('token');
            
            async function triggerDoor(door) {
                const button = event.target.closest('.door-button');
                const statusSpan = button.querySelector('.door-status');
                
                // Visual feedback
                button.classList.add('activating');
                statusSpan.textContent = 'Activating...';
                
                try {
                    const response = await fetch(`/api/trigger/${door}`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${token}`
                        }
                    });
                    
                    const data = await response.json();
                    
                    if (response.ok) {
                        statusSpan.textContent = 'Activated!';
                        setTimeout(() => {
                            statusSpan.textContent = 'Ready';
                            button.classList.remove('activating');
                        }, 2000);
                    } else {
                        statusSpan.textContent = 'Error!';
                        alert('Failed: ' + data.message);
                        setTimeout(() => {
                            statusSpan.textContent = 'Ready';
                            button.classList.remove('activating');
                        }, 2000);
                    }
                } catch (error) {
                    statusSpan.textContent = 'Connection Error';
                    alert('Network error: ' + error.message);
                    setTimeout(() => {
                        statusSpan.textContent = 'Ready';
                        button.classList.remove('activating');
                    }, 2000);
                }
            }
        </script>
    </body>
    </html>
    """
    return render_template_string(html)

@app.route('/api/status', methods=['GET'])
@require_token
def status():
    """Get system status"""
    return jsonify({
        "status": "ok",
        "doors": {
            "Right": "ready",
            "Left": "ready"
        },
        "gpio_pins": config['gpio_pins']
    })

@app.route('/api/trigger/Right', methods=['POST'])
@require_token
def trigger_Right():
    """Trigger Right garage door"""
    try:
        logger.info(f"Right door triggered by {request.remote_addr}")
        controller.trigger_Right()
        return jsonify({
            "status": "success",
            "message": "Right door activated",
            "door": "Right"
        })
    except Exception as e:
        logger.error(f"Error triggering Right door: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/api/trigger/Left', methods=['POST'])
@require_token
def trigger_Left():
    """Trigger Left garage door"""
    try:
        logger.info(f"Left door triggered by {request.remote_addr}")
        controller.trigger_Left()
        return jsonify({
            "status": "success",
            "message": "Left door activated",
            "door": "Left"
        })
    except Exception as e:
        logger.error(f"Error triggering Left door: {e}")
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint (no auth required)"""
    return jsonify({"status": "healthy", "service": "garage-door-controller"})

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Not found", "message": "Invalid endpoint"}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    logger.info("Starting Garage Door Controller API...")
    logger.info(f"Right door: GPIO {config['gpio_pins']['Right']}")
    logger.info(f"Left door: GPIO {config['gpio_pins']['Left']}")
    logger.info(f"Server starting on {config['host']}:{config['port']}")
    
    app.run(
        host=config['host'],
        port=config['port'],
        debug=False
    )
