SmartSec Mobile App - Remote Security Monitor
What is SmartSec App?
SmartSec is a mobile companion app for the SmartSec Office Security System. It lets you monitor and control your office security from your Android phone. The app provides:

Live Dashboard – See real-time system status, today's activity stats, and the most recent security event.

Complete Event Log – Browse a searchable, filterable history of all security events (door openings, intruder alerts, motion detections, unauthorized attempts).

Push Notifications – Receive instant alerts on your phone whenever an important security event occurs (door opened, intruder detected, unauthorized access).

Simple Setup – Enter your Raspberry Pi's IP address once, and the app remembers it.

The app is built with Flutter, so it's fast, modern, and works smoothly on Android devices.

How It Works (Simple Overview)
text
[SmartSec System on Raspberry Pi] <--(Wi-Fi/REST API)--> [SmartSec Android App]
         (Flask Server)                                     (Flutter App)
               |                                                     |
         [SQLite Database]                                     [Local Storage]
               |                                                     |
         [Hardware Sensors]                                   [Firebase Cloud]
               |                                                     |
         [Physical Security]                                  [Push Notifications]
The Raspberry Pi runs a small web server (Flask) that provides a REST API.

The mobile app connects to this API over your local Wi-Fi network.

The app fetches live status, event logs, and statistics from the Pi.

When a security event occurs, the Pi sends a push notification via Firebase Cloud Messaging (FCM) to all subscribed devices.

Your phone displays the notification, even when the app is closed.

App Features
📊 Dashboard Screen
System Status – Shows if the Raspberry Pi is online.

Today's Summary – Displays counts of entries, intruder alerts, motion events, and unauthorized attempts.

Latest Event – Highlights the most recent security event with details.

Recent Activity – Lists the last few events for quick viewing.

📜 Log Screen
Complete History – Scroll through every security event ever recorded.

Filter by Type – Tap filter buttons to see only specific event types (door openings, intruder, unauthorized, motion).

Infinite Scroll – Events load automatically as you scroll down.

Event Details – Each entry shows time, event type, person name (if known), and card ID.

⚙️ Settings Screen
Pi IP Address – Enter the IP address of your Raspberry Pi (the app saves it securely).

Test Connection – Verify that the app can reach the Pi.

Setup Guide – Quick instructions for first-time users.

🔔 Push Notifications
Instant alerts for:

Door Opened (with person's name)

Intruder Detected

Unauthorized Access Attempt

Motion Detected

Notifications work even when the app is in the background.

App Files Explained
All app files are inside the smartsec_app/ folder.

File	What it does
lib/main.dart	App entry point. Initializes Firebase, sets up the app theme (colors, fonts), and creates the main bottom navigation bar with three tabs (Dashboard, Log, Settings).
lib/screens/dashboard_screen.dart	Dashboard UI. Displays system status, today's stats, and recent events. Periodically refreshes data from the Pi.
lib/screens/log_screen.dart	Event log UI. Shows a paginated list of events with filter buttons. Loads more events as the user scrolls.
lib/screens/settings_screen.dart	Settings UI. Lets the user input and save the Pi's IP address, test the connection, and view setup help.
lib/models/event.dart	Data model for security events. Defines an Event class with fields like id, timestamp, type, cardId, personName, and details. Includes helper methods to get display text and icons for each event type.
lib/services/api_service.dart	Handles all communication with the Raspberry Pi's REST API. Fetches events, stats, and system status. Saves the Pi's IP address using shared preferences.
lib/services/notification_service.dart	Manages push notifications. Requests permissions, subscribes to the FCM topic (office_security), and handles incoming notifications (shows them as popups or in the notification tray).
pubspec.yaml	Project dependencies. Lists all Flutter packages used: http for API calls, firebase_messaging for push, provider for state management, shared_preferences for storing settings, etc.
Android-Specific Files
File	What it does
android/app/google-services.json	Firebase configuration file for the Android app. Downloaded from the Firebase Console. It enables push notifications.
android/app/build.gradle.kts	Android build configuration. Specifies the app's package name (com.smartsec.smartsec_app), SDK versions, and includes the Firebase plugins.
How to Build and Install the App
Prerequisites
Flutter SDK installed on your computer.

An Android device (or emulator) running Android 5.0 (API 21) or newer.

A Firebase project with Cloud Messaging enabled (for push notifications).

Steps
Clone or download the project files.

Place Firebase config – Copy the google-services.json file from your Firebase project into smartsec_app/android/app/.

Open a terminal in the smartsec_app/ folder.

Get dependencies:

bash
flutter pub get
Build the APK:

bash
flutter build apk --release
Install the generated APK (found at build/app/outputs/flutter-apk/app-release.apk) on your Android phone.

First-Time Setup
Open the app on your phone.

Go to the Settings tab.

Enter the IP address of your Raspberry Pi (e.g., 192.168.1.100).

Tap Test Connection – you should see a success message.

The app is now ready. Grant notification permission when prompted.

API Endpoints (Used by the App)
The app communicates with the Raspberry Pi's Flask server via these REST endpoints:

Endpoint	Purpose
GET /api/health	Check if the server is reachable.
GET /api/status	Get current system status (online, last event, today's stats).
GET /api/events	Fetch paginated list of events (supports limit, offset, and type filters).
GET /api/stats/today	Get counts for today's events by type.
All responses are in JSON format. The app handles parsing and displaying this data.

Push Notification Setup (Firebase)
To receive push notifications:

The Raspberry Pi sends notifications using a service account key (JSON file) configured on the Pi.

The Android app includes the google-services.json file and uses the firebase_messaging package to listen for messages.

When the app starts, it subscribes to the FCM topic office_security (or whatever topic is set in the Pi's .env file).

Any notification sent to that topic is delivered to all devices running the app.

Troubleshooting
Cannot connect to Pi – Make sure your phone is on the same Wi-Fi network as the Raspberry Pi. Verify the IP address is correct and that the Pi's Flask server is running (you can test by visiting http://<pi-ip>:5000/api/health in a browser).

No push notifications – Check that the Firebase service account JSON is correctly placed on the Pi and that the app's google-services.json is correct. Also ensure your phone has internet access.

App crashes on start – Make sure you've run flutter pub get and that all dependencies are correctly installed.

SmartSec Mobile App – Stay connected to your office security, anywhere.

