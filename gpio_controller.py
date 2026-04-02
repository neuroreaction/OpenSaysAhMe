#!/usr/bin/env python3
"""
GPIO Controller for Garage Door
Uses modern gpiozero library (replaces deprecated WiringPi)
"""

from gpiozero import OutputDevice
import time
import logging

logger = logging.getLogger(__name__)

class GarageDoorController:
    """
    Controls garage door GPIO pins using gpiozero.
    
    GPIO pins use BCM numbering:
    - Pin 7 (BCM) = Sara's door
    - Pin 4 (BCM) = David's door
    """
    
    def __init__(self, sara_pin=7, dave_pin=4, pulse_duration=1.0):
        """
        Initialize garage door controller.
        
        Args:
            sara_pin (int): BCM GPIO pin number for Sara's door (default: 7)
            dave_pin (int): BCM GPIO pin number for David's door (default: 4)
            pulse_duration (float): Duration of relay activation in seconds (default: 1.0)
        """
        self.sara_pin = sara_pin
        self.dave_pin = dave_pin
        self.pulse_duration = pulse_duration
        
        # Initialize GPIO pins
        # active_high=False means the relay is triggered by setting pin LOW
        # If your relay triggers on HIGH, change to active_high=True
        try:
            self.sara_relay = OutputDevice(sara_pin, active_high=True, initial_value=False)
            self.dave_relay = OutputDevice(dave_pin, active_high=True, initial_value=False)
            logger.info(f"GPIO initialized: Sara=GPIO{sara_pin}, Dave=GPIO{dave_pin}")
        except Exception as e:
            logger.error(f"Failed to initialize GPIO: {e}")
            raise
    
    def trigger_sara(self):
        """
        Trigger Sara's garage door.
        Sends a pulse to the relay for the configured duration.
        """
        try:
            logger.info(f"Triggering Sara's door (GPIO {self.sara_pin})")
            self.sara_relay.on()
            time.sleep(self.pulse_duration)
            self.sara_relay.off()
            logger.info("Sara's door pulse complete")
        except Exception as e:
            logger.error(f"Error triggering Sara's door: {e}")
            # Ensure relay is off even if error occurs
            try:
                self.sara_relay.off()
            except:
                pass
            raise
    
    def trigger_dave(self):
        """
        Trigger David's garage door.
        Sends a pulse to the relay for the configured duration.
        """
        try:
            logger.info(f"Triggering David's door (GPIO {self.dave_pin})")
            self.dave_relay.on()
            time.sleep(self.pulse_duration)
            self.dave_relay.off()
            logger.info("David's door pulse complete")
        except Exception as e:
            logger.error(f"Error triggering David's door: {e}")
            # Ensure relay is off even if error occurs
            try:
                self.dave_relay.off()
            except:
                pass
            raise
    
    def cleanup(self):
        """
        Clean up GPIO resources.
        Called when shutting down the application.
        """
        try:
            logger.info("Cleaning up GPIO resources")
            self.sara_relay.close()
            self.dave_relay.close()
        except Exception as e:
            logger.error(f"Error during GPIO cleanup: {e}")
    
    def test_relays(self):
        """
        Test both relays with a short pulse.
        Useful for verification during setup.
        """
        logger.info("Testing relays...")
        
        logger.info("Testing Sara's relay...")
        self.sara_relay.on()
        time.sleep(0.5)
        self.sara_relay.off()
        time.sleep(1)
        
        logger.info("Testing David's relay...")
        self.dave_relay.on()
        time.sleep(0.5)
        self.dave_relay.off()
        
        logger.info("Relay test complete")

# Test script - run this file directly to test GPIO
if __name__ == "__main__":
    import sys
    
    # Setup logging for test
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    print("=" * 50)
    print("Garage Door GPIO Test")
    print("=" * 50)
    print("\n⚠️  WARNING: This will activate the GPIO pins!")
    print("Make sure garage door opener is NOT connected yet.\n")
    
    response = input("Continue with GPIO test? (yes/no): ")
    if response.lower() != 'yes':
        print("Test cancelled.")
        sys.exit(0)
    
    try:
        # Initialize controller
        controller = GarageDoorController(sara_pin=7, dave_pin=4, pulse_duration=0.5)
        
        print("\n📍 GPIO Pins Initialized:")
        print(f"   Sara's door: GPIO 7 (BCM)")
        print(f"   David's door: GPIO 4 (BCM)")
        
        # Test Sara's door
        print("\n🚗 Testing Sara's door in 3 seconds...")
        time.sleep(3)
        controller.trigger_sara()
        print("✅ Sara's door test complete")
        
        time.sleep(2)
        
        # Test Dave's door
        print("\n🚗 Testing David's door in 3 seconds...")
        time.sleep(3)
        controller.trigger_dave()
        print("✅ David's door test complete")
        
        print("\n✅ All tests passed!")
        print("If you saw/heard the relays activate, GPIO is working correctly.")
        
    except KeyboardInterrupt:
        print("\n\nTest interrupted by user.")
    except Exception as e:
        print(f"\n❌ Error during test: {e}")
        print("\nTroubleshooting:")
        print("1. Make sure you're running as root or in gpio group")
        print("2. Check if gpiozero is installed: pip install gpiozero")
        print("3. Verify pin numbers are correct (BCM numbering)")
    finally:
        try:
            controller.cleanup()
        except:
            pass

"""
RELAY WIRING NOTES:
===================

Most garage door opener relay boards use one of these configurations:

1. ACTIVE HIGH (Common):
   - Set active_high=True in OutputDevice()
   - Relay activates when pin goes HIGH (3.3V)
   
2. ACTIVE LOW:
   - Set active_high=False in OutputDevice()
   - Relay activates when pin goes LOW (0V)

If the relay doesn't activate or is stuck on, try changing active_high parameter.

GPIO Pin Reference (BCM numbering):
- Physical Pin 7  = GPIO 4  (David's door in this setup)
- Physical Pin 26 = GPIO 7  (Sara's door in this setup)

Always verify with a multimeter before connecting to garage door!
"""
