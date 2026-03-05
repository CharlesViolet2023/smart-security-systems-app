#!/usr/bin/python3
"""
=============================================================================
Smart security system4.py - The Hardware Controller (THE BRAIN)
=============================================================================

This is the CORE file of the SmartSec system. It directly controls all the
physical hardware components connected to the Raspberry Pi:

  - RFID Card Reader: reads key cards to identify who is at the door
  - Servo Motor: physically opens and closes the door lock
  - IR Sensor: detects if someone passes through (intruder detection)
  - PIR Sensor: detects motion nearby
  - LCD Display: shows messages like "Scan your card..." or "Access Granted"
  - Green LED: lights up when access is granted
  - Red LED: lights up when access is denied or an alert is active
  - Buzzer: sounds an alarm when intruder/motion is detected

HOW THE MAIN LOOP WORKS:
  The program runs in an infinite loop (runs forever until you press Ctrl+C).
  Each cycle of the loop does three checks:
    1. Is the IR sensor triggered? (intruder detection)
    2. Is the PIR sensor triggered? (motion detection)
    3. Has someone scanned an RFID card? (door access)

  Each check happens very quickly (every 0.1 seconds), so the system
  feels responsive to the user.

NOTE: This file is executed by main.py using exec(), so it shares the
same environment (database, notifications, etc. are already loaded).
"""

import time                     # For adding delays (e.g., keep door open for 3 seconds)
import RPi.GPIO as GPIO         # Library to control the Raspberry Pi's GPIO pins
from mfrc522 import SimpleMFRC522   # Library to read RFID cards via the MFRC522 reader
from RPLCD.i2c import CharLCD      # Library to write text to the LCD display
from datetime import datetime       # For getting the current date/time

# Import SmartSec's own modules for logging events and sending notifications
from database import log_event
from notifications import (
    send_door_opened,
    send_intruder_alert,
    send_unauthorized_access,
    send_system_online,
)

# =============================================================================
# GPIO PIN SETUP
# =============================================================================
# GPIO = "General Purpose Input/Output" - these are the physical pins on the
# Raspberry Pi that connect to sensors, LEDs, motors, etc.
#
# BCM mode means we use the Broadcom pin numbering (the GPIO numbers printed
# on Raspberry Pi pinout diagrams), not the physical pin positions on the board.
# =============================================================================

GPIO.setwarnings(False)     # Don't show warnings if pins are already in use
GPIO.setmode(GPIO.BCM)      # Use BCM pin numbering (GPIO numbers, not board positions)

# --- LED Setup ---
# LEDs are OUTPUT devices (we send signals TO them to turn them on/off)
Green_led = 24               # Green LED is connected to GPIO pin 24
Red_led = 16                 # Red LED is connected to GPIO pin 16
GPIO.setup(Green_led, GPIO.OUT)   # Set green LED pin as output
GPIO.setup(Red_led, GPIO.OUT)     # Set red LED pin as output

# --- PIR Motion Sensor Setup ---
# The PIR sensor is an INPUT device (we READ signals FROM it)
# It sends a HIGH (1) signal when it detects motion, LOW (0) when no motion
sensor = 5                   # PIR motion sensor is connected to GPIO pin 5
state = 0                    # Tracks the current motion state (0 = no motion, 1 = motion)
GPIO.setup(sensor, GPIO.IN)  # Set PIR pin as input (we read from it)

# =============================================================================
# SERVO MOTOR SETUP (Door Lock Mechanism)
# =============================================================================
# The servo motor rotates to physically open and close the door.
# It uses PWM (Pulse Width Modulation) - a technique where we send rapid
# on/off signals to control the motor's position.
#
# PWM at 50Hz means we send 50 pulses per second.
# The "duty cycle" (how long each pulse is ON) determines the angle:
#   - ~2% duty = 0 degrees (door closed)
#   - ~7% duty = 90 degrees (door open)
# =============================================================================

SERVO_PIN = 6                     # Servo motor is connected to GPIO pin 6
GPIO.setup(SERVO_PIN, GPIO.OUT)   # Set servo pin as output

servo = GPIO.PWM(SERVO_PIN, 50)   # Create a PWM signal at 50Hz on the servo pin
servo.start(0)                     # Start with 0% duty cycle (servo idle)


def set_angle(angle):
    """
    Move the servo motor to a specific angle (0 to 180 degrees).

    The formula converts an angle to a PWM duty cycle:
      duty = 2 + (angle / 18)
    For example: 0 degrees = 2% duty, 90 degrees = 7% duty
    """
    duty = 2 + (angle / 18)
    servo.ChangeDutyCycle(duty)


def door_open():
    """
    Smoothly open the door by rotating the servo from 0 to 90 degrees.
    The small delay between each degree makes the movement smooth
    instead of jumping instantly to the open position.
    """
    print("Opening door...")
    for angle in range(0, 91):       # Move from 0 degrees to 90 degrees
        set_angle(angle)
        time.sleep(0.002)            # Tiny delay for smooth movement
    time.sleep(0.5)                  # Short pause once fully open


def door_close():
    """
    Smoothly close the door by rotating the servo from 90 back to 0 degrees.
    Same smooth movement as door_open, but in reverse.
    """
    print("Closing door...")
    for angle in range(90, -1, -1):  # Move from 90 degrees back to 0 degrees
        set_angle(angle)
        time.sleep(0.002)            # Tiny delay for smooth movement
    time.sleep(0.5)                  # Short pause once fully closed


# =============================================================================
# IR SENSOR AND BUZZER SETUP
# =============================================================================
# The IR (infrared) sensor detects when something passes in front of it.
# Used here for intruder detection - if someone breaks through without
# using a card, this sensor triggers an alarm.
#
# The buzzer is a small speaker that makes a beeping/alarm sound.
# =============================================================================

IR_PIN = 17                       # IR sensor is connected to GPIO pin 17
BUZZER_PIN = 27                   # Buzzer is connected to GPIO pin 27
GPIO.setup(IR_PIN, GPIO.IN)       # IR sensor is input (we read from it)
GPIO.setup(BUZZER_PIN, GPIO.OUT)  # Buzzer is output (we send signals to it)

# =============================================================================
# LCD DISPLAY SETUP
# =============================================================================
# The LCD is a small screen (20 characters wide, 4 rows tall) that shows
# status messages to people at the door.
#
# It uses I2C communication (a simple 2-wire protocol) through a PCF8574
# chip. The address 0x27 is the default I2C address for this type of LCD.
# =============================================================================

lcd = CharLCD('PCF8574', 0x27, cols=20, rows=4)

# =============================================================================
# RFID CARD READER SETUP
# =============================================================================
# The MFRC522 is an RFID reader that can read contactless cards/tags.
# When someone holds their card near the reader, it reads a unique ID number
# from the card. We then check if that ID is in our list of authorized cards.
# =============================================================================

reader = SimpleMFRC522()

# =============================================================================
# AUTHORIZED CARDS DATABASE
# =============================================================================
# Each RFID card has a unique ID number (like a serial number).
# We store the authorized card IDs here so the system knows who to let in.
#
# CORRECT_CARD: The ID of a card that IS allowed to open the door
# WRONG_CARD: An example of a card that is NOT allowed (for testing)
# CARD_OWNERS: A lookup table that maps card IDs to the person's name
# =============================================================================

CORRECT_CARD = 14579938651        # This card number opens the door
WRONG_CARD = 632846259404         # This card number is denied access

# Map card IDs to person names so we can log WHO opened the door
CARD_OWNERS = {
    CORRECT_CARD: "Authorized User",
}

# =============================================================================
# STARTUP SEQUENCE
# =============================================================================
# When the system first starts, show initialization messages on the LCD
# so the person at the door knows the system is booting up.
# =============================================================================

lcd.clear()                              # Clear any old text from the LCD
lcd.write_string("Security System")      # Show "Security System" on line 1
lcd.cursor_pos = (1, 0)                  # Move cursor to line 2 (row 1, column 0)
lcd.write_string("Initializing....")     # Show loading message on line 2
time.sleep(2)                            # Wait 2 seconds so the user can read it

lcd.clear()                              # Clear the screen
lcd.write_string("System is ready")      # Show ready message
lcd.cursor_pos = (1, 0)
time.sleep(2)                            # Wait 2 seconds

lcd.clear()
lcd.write_string("Scan your card...")    # Show the main prompt

print("Security system started...")

# Save a "system started" event to the database and notify all phones
log_event("system_start", details="Security system initialized")
send_system_online()

# =============================================================================
# MAIN LOOP - This runs forever until Ctrl+C is pressed
# =============================================================================
# The system continuously checks three things in order:
#   1. IR Sensor -> Is there an intruder? (highest priority)
#   2. PIR Sensor -> Is there motion? (medium priority)
#   3. RFID Reader -> Has someone scanned a card? (normal operation)
#
# The loop runs every 0.1 seconds (10 times per second).
# =============================================================================

try:
    while True:

        # =====================================================================
        # CHECK 1: IR SENSOR - INTRUDER DETECTION
        # =====================================================================
        # The IR sensor outputs LOW when something is blocking its beam.
        # If triggered, this means someone may have broken in without a card.
        #
        # What happens:
        #   - Buzzer sounds the alarm
        #   - Red LED turns on
        #   - LCD shows "Intruder!"
        #   - Event is logged and push notification is sent
        #   - System waits until the IR beam is clear again before resuming
        # =====================================================================
        if GPIO.input(IR_PIN) == GPIO.LOW:

            # Sound the alarm and turn on the red LED
            GPIO.output(BUZZER_PIN, GPIO.HIGH)
            GPIO.output(Red_led, GPIO.HIGH)

            # Show warning on the LCD screen
            lcd.clear()
            lcd.write_string("Intruder!")
            print("Intruder detected!")

            # Save to database and send alert to phones
            log_event("intruder", details="IR sensor triggered")
            send_intruder_alert()

            # Keep the alarm going as long as the IR sensor is triggered
            # (something is still blocking the beam)
            while GPIO.input(IR_PIN) == GPIO.LOW:
                time.sleep(0.1)

            # Once the intruder is gone, turn off the alarm and reset
            GPIO.output(BUZZER_PIN, GPIO.LOW)
            GPIO.output(Red_led, GPIO.LOW)
            lcd.clear()
            lcd.write_string("Scan your card...")
            continue  # Skip the rest of the loop and start over

        # =====================================================================
        # CHECK 2: PIR SENSOR - MOTION DETECTION
        # =====================================================================
        # The PIR sensor detects body heat (infrared radiation from people).
        # It outputs HIGH (1) when motion is detected, LOW (0) when still.
        #
        # We use a "state" variable to avoid triggering repeatedly while
        # motion is ongoing. We only react to the CHANGE (no motion -> motion
        # and motion -> no motion), not the continuous state.
        # =====================================================================

        val = GPIO.input(sensor)  # Read the PIR sensor value (1 = motion, 0 = no motion)

        if val == 1:
            # Motion is detected right now
            if state == 0:
                # This is a NEW motion event (was still, now moving)
                print("Motion detected")
                lcd.clear()
                lcd.write_string("Motion detected")
                state = 1  # Remember that we're in "motion" state

                # Turn on buzzer and red LED as a warning
                GPIO.output(BUZZER_PIN, GPIO.HIGH)
                GPIO.output(Red_led, GPIO.HIGH)

                # Log the event (no push notification to avoid spamming the phone)
                log_event("motion", details="PIR sensor triggered")
        else:
            # No motion detected
            if state == 1:
                # Motion just STOPPED (was moving, now still)
                print("Motion stopped")
                lcd.clear()
                lcd.write_string("Scan your card...")
                state = 0  # Reset to "no motion" state

                # Turn off the buzzer and red LED
                GPIO.output(BUZZER_PIN, GPIO.LOW)
                GPIO.output(Red_led, GPIO.LOW)

        # =====================================================================
        # CHECK 3: RFID CARD READER - DOOR ACCESS
        # =====================================================================
        # Check if someone has tapped an RFID card on the reader.
        # "read_no_block" means: check quickly and move on if no card is present
        # (instead of waiting forever for a card).
        #
        # If a card is detected:
        #   - Check if it's an authorized card
        #   - If YES: open the door, turn on green LED, log access, send notification
        #   - If NO: show "Incorrect Card", turn on red LED, log attempt, send alert
        # =====================================================================
        id, text = reader.read_no_block()  # Try to read a card (returns None if no card)

        if id:
            # A card was scanned! Show the card's unique ID number
            print("Card detected:", id)
            lcd.clear()

            if id == CORRECT_CARD:
                # ---- AUTHORIZED CARD - GRANT ACCESS ----
                person_name = CARD_OWNERS.get(id, "Unknown")  # Look up who owns this card

                # Show success message on the LCD
                lcd.write_string("Access Granted")
                lcd.cursor_pos = (1, 0)          # Move to line 2
                lcd.write_string("Door Opening...")

                # Save event to database and send notification to phones
                log_event("door_open", card_id=id, person_name=person_name,
                          details="Access granted, door opened")
                send_door_opened(person_name)

                # Physically open the door
                door_open()                       # Rotate servo to 90 degrees (open)
                GPIO.output(Green_led, GPIO.HIGH) # Turn on green LED
                time.sleep(3)                     # Keep door open for 3 seconds
                door_close()                      # Rotate servo back to 0 degrees (close)
                GPIO.output(Green_led, GPIO.LOW)  # Turn off green LED

                # Show door closed message
                lcd.clear()
                lcd.write_string("Door Closed")
                time.sleep(2)

            else:
                # ---- UNAUTHORIZED CARD - DENY ACCESS ----

                # Show rejection message on the LCD
                lcd.write_string("Incorrect Card")
                GPIO.output(Red_led, GPIO.HIGH)    # Turn on red LED as warning
                lcd.cursor_pos = (1, 0)            # Move to line 2
                lcd.write_string("Door Not Opening")

                # Save the unauthorized attempt and alert phone
                log_event("unauthorized", card_id=id,
                          details="Unauthorized card scanned")
                send_unauthorized_access(card_id=id)

                time.sleep(3)                      # Show the message for 3 seconds
                GPIO.output(Red_led, GPIO.LOW)     # Turn off red LED

            # Reset the LCD back to the default message
            lcd.clear()
            lcd.write_string("Scan your card...")

        # Small delay before the next loop cycle (prevents the CPU from running at 100%)
        time.sleep(0.1)

# =============================================================================
# SHUTDOWN - What happens when you press Ctrl+C to stop the program
# =============================================================================
# "KeyboardInterrupt" is the signal sent when you press Ctrl+C in the terminal.
# The "finally" block ALWAYS runs, even if the program crashes, ensuring we
# properly clean up the hardware (turn off buzzer, release GPIO pins, clear LCD).
# =============================================================================

except KeyboardInterrupt:
    print("Program stopped")

finally:
    servo.stop()                       # Stop the servo motor PWM signal
    GPIO.output(BUZZER_PIN, GPIO.LOW)  # Make sure the buzzer is turned off
    GPIO.cleanup()                     # Release all GPIO pins back to the system
    lcd.clear()                        # Clear the LCD screen
