#!/usr/bin/python3
"""
=============================================================================
notifications.py - SmartSec Push Notification Sender
=============================================================================

This file handles sending push notifications to the Android mobile app.

HOW IT WORKS:
  When something happens (door opens, intruder detected, etc.), this file
  sends a message through Google's Firebase Cloud Messaging (FCM) service.
  Firebase then delivers that message as a push notification to every phone
  that has the SmartSec app installed.

  Think of it like a text message system:
    1. Something happens on the Raspberry Pi (e.g., intruder detected)
    2. This file sends a message to Firebase (Google's server in the cloud)
    3. Firebase forwards that message to all phones with the SmartSec app
    4. The phone shows a notification (like a text message alert)

WHY BACKGROUND THREADS?
  Sending a notification requires an internet connection and takes a moment.
  We don't want the security system to pause while waiting for the notification
  to send, so we send it in a "background thread" (like doing it in the
  background while the main system keeps running).

SETUP REQUIRED:
  - A Firebase project (free at console.firebase.google.com)
  - A service account key file (firebase-service-account.json)
  - The file path is set in the .env file
"""

import os          # For finding the Firebase credentials file
import threading   # For sending notifications in the background
from datetime import datetime  # For adding timestamps to notifications

# --- Firebase state ---
# These variables track whether Firebase has been set up yet.
# "Lazy initialization" means we only set up Firebase the first time
# we actually need to send a notification (not when the program starts).
_firebase_initialized = False  # Has Firebase been set up yet?
_fcm_topic = None              # The "topic" (channel) to send notifications to


def _init_firebase():
    """
    Set up the connection to Firebase (only runs once).

    This function:
      1. Finds the Firebase credentials file on disk
      2. Uses those credentials to authenticate with Google
      3. Marks Firebase as ready to send notifications

    Returns True if setup succeeded, False if it failed.
    """
    global _firebase_initialized, _fcm_topic

    # If already initialized, don't do it again
    if _firebase_initialized:
        return True

    # Find the Firebase credentials file
    # First checks the .env setting, then falls back to the default location
    creds_path = os.environ.get(
        "FIREBASE_CREDENTIALS_PATH",
        os.path.join(os.path.dirname(__file__), "firebase-service-account.json")
    )

    # Read which "topic" to send notifications to (like a channel name)
    # All phones subscribed to this topic will receive the notifications
    _fcm_topic = os.environ.get("FCM_TOPIC", "office_security")

    # Check if the credentials file exists
    if not os.path.exists(creds_path):
        print(f"[NOTIFY] Firebase credentials not found at {creds_path}")
        print("[NOTIFY] Push notifications disabled. Place your firebase-service-account.json in the SmartSec folder.")
        return False

    # Try to initialize Firebase with the credentials
    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(creds_path)  # Load the key file
        firebase_admin.initialize_app(cred)          # Connect to Firebase
        _firebase_initialized = True
        print(f"[NOTIFY] Firebase initialized. Notifications will be sent to topic: {_fcm_topic}")
        return True
    except Exception as e:
        print(f"[NOTIFY] Failed to initialize Firebase: {e}")
        return False


def send_push(title, body, event_type="info"):
    """
    Send a push notification to all phones with the SmartSec app.
    This runs in a background thread so it doesn't slow down the security system.

    Arguments:
        title      - The notification title shown on the phone (e.g., "Door Opened")
        body       - The notification message (e.g., "John accessed the office at 14:30")
        event_type - What kind of event this is (door_open, intruder, unauthorized, motion)
    """
    # Start a background thread to send the notification
    # "daemon=True" means this thread will stop automatically when the main program stops
    thread = threading.Thread(target=_send_push_worker, args=(title, body, event_type), daemon=True)
    thread.start()


def _send_push_worker(title, body, event_type):
    """
    The actual function that sends the notification (runs in background).

    This builds a Firebase Cloud Message with:
      - A visible notification (title + body text)
      - Hidden data (event type, timestamp) that the app can use
      - Android-specific settings (priority, sound, color)
    """
    # Make sure Firebase is set up before trying to send
    if not _init_firebase():
        return

    try:
        from firebase_admin import messaging

        # Build the notification message
        message = messaging.Message(
            # The visible notification the user sees on their phone
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            # Hidden data that the app receives (not shown to the user directly)
            data={
                "event_type": event_type,
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "click_action": "FLUTTER_NOTIFICATION_CLICK",  # Opens the app when tapped
            },
            # Send to all phones subscribed to this topic
            topic=_fcm_topic,
            # Android-specific settings
            android=messaging.AndroidConfig(
                priority="high",  # Deliver immediately, even if phone is in doze mode
                notification=messaging.AndroidNotification(
                    icon="notification_icon",
                    # Red color for intruder alerts, green for everything else
                    color="#FF0000" if event_type == "intruder" else "#4CAF50",
                    sound="default",                # Use the phone's default notification sound
                    channel_id="security_alerts",    # Android notification channel
                ),
            ),
        )

        # Send the message through Firebase
        response = messaging.send(message)
        print(f"[NOTIFY] Sent: '{title}' -> {response}")

    except Exception as e:
        print(f"[NOTIFY] Failed to send notification: {e}")
        # Important: we catch the error and continue - a failed notification
        # should NEVER crash the security system


# =============================================================================
# CONVENIENCE FUNCTIONS
# These are shortcut functions for common notification types.
# Instead of building the title and body each time, you just call one function.
# =============================================================================

def send_door_opened(person_name="Authorized User"):
    """Send a notification when someone opens the door with a valid card."""
    now = datetime.now().strftime("%H:%M:%S")
    send_push(
        title="🚪 Door Opened",
        body=f"{person_name} accessed the office at {now}",
        event_type="door_open"
    )


def send_intruder_alert():
    """Send an urgent notification when the IR sensor detects an intruder."""
    now = datetime.now().strftime("%H:%M:%S")
    send_push(
        title="🚨 INTRUDER ALERT",
        body=f"Intruder detected at {now}! Check immediately.",
        event_type="intruder"
    )


def send_unauthorized_access(card_id=None):
    """Send a notification when someone tries to use an unrecognized card."""
    now = datetime.now().strftime("%H:%M:%S")
    body = f"Unauthorized card attempted access at {now}"
    if card_id:
        body += f" (Card: {card_id})"  # Include the card number for investigation
    send_push(
        title="⚠️ Unauthorized Access Attempt",
        body=body,
        event_type="unauthorized"
    )


def send_system_online():
    """Send a notification when the security system starts up."""
    now = datetime.now().strftime("%H:%M:%S")
    send_push(
        title="✅ Security System Online",
        body=f"Office security system started at {now}",
        event_type="system_start"
    )
