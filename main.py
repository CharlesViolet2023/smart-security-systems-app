#!/usr/bin/python3
"""
=============================================================================
main.py - SmartSec Main Entry Point (THE FILE YOU RUN TO START EVERYTHING)
=============================================================================

This is the first file that runs when you start the SmartSec security system.
Think of it as the "power button" - it turns on all the different parts of the
system in the right order:

  1. Loads settings from the .env file (like database path, server port, etc.)
  2. Creates/initializes the SQLite database (where all events are stored)
  3. Starts the web server (Flask API) in the background so the mobile app
     can connect and fetch data
  4. Launches the main security loop that reads sensors and controls the door

HOW TO RUN:
    sudo python3 main.py

WHY "sudo"?
    The Raspberry Pi's GPIO pins (the pins that connect to sensors, LEDs, etc.)
    require administrator (root) access. "sudo" gives the program those permissions.
"""

# --- Import built-in Python tools ---
import os       # For working with file paths and environment variables
import sys      # For system-level operations
import threading  # For running the web server in the background (like multitasking)

# --- Load settings from the .env file ---
# The .env file contains configuration like database path, server port, etc.
# "load_dotenv" reads that file and makes those settings available to the program.
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

# --- Set up the database ---
# This creates the SQLite database file (if it doesn't exist yet) and ensures
# the table structure is ready to store security events.
from database import init_db
init_db()

# --- Start the web server in the background ---
# The Flask API server runs in a separate "thread" (like a background task).
# This allows the security system to keep running while the web server
# simultaneously handles requests from the mobile app.
# "daemon=True" means this thread will automatically stop when the main program stops.
from api_server import start_api_server

api_thread = threading.Thread(target=start_api_server, daemon=True)
api_thread.start()
print("[MAIN] API server started in background thread")

# --- Launch the security system (the main loop) ---
# This is where the real work happens: reading RFID cards, checking sensors,
# controlling the door, etc. This runs on the main thread and keeps going
# forever until you press Ctrl+C to stop it.
print("[MAIN] Starting security system...")
print("=" * 50)

# We use "exec" to run the security script in the current context.
# This way, the security system has access to all the settings and modules
# that were loaded above.
security_script = os.path.join(os.path.dirname(__file__), "Smart security system4.py")
exec(open(security_script).read())
