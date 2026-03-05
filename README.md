# SmartSec - Smart Office Security System

## What is SmartSec?

SmartSec is a **complete office security system** built with a Raspberry Pi and a mobile phone app. It protects an office by:

- **Controlling door access** with RFID cards (like a key card for a building)
- **Detecting intruders** with an infrared (IR) sensor
- **Detecting motion** with a PIR (passive infrared) sensor
- **Sending instant alerts** to your phone when something happens
- **Keeping a log** of every security event (who entered, when, any alerts)

The system has two main parts:

1. **The Raspberry Pi** (the brain) - runs Python code that reads sensors, controls the door lock (servo motor), displays messages on an LCD screen, and stores all events in a database.
2. **The Android App** (the remote monitor) - built with Flutter, it connects to the Raspberry Pi over Wi-Fi to show you a live dashboard, the full event log, and sends push notifications to your phone.

---

## How It Works (Simple Overview)

```
[RFID Card Reader] ---\
[IR Sensor]        ----\
[PIR Motion Sensor] -----> [Raspberry Pi] ----> [Database (SQLite)]
[LCD Display]      <----/                  \---> [Flask API Server]
[Servo Motor/Door] <---/                          |
[Buzzer + LEDs]    <--/                           v
                                           [Android App on Phone]
                                                  |
                                           [Push Notifications via Firebase]
```

1. Someone scans their RFID card at the door.
2. The Raspberry Pi checks if the card is authorized.
3. If YES: the green LED turns on, the LCD says "Access Granted", and the servo motor opens the door. A notification is sent to your phone.
4. If NO: the red LED turns on, the LCD says "Incorrect Card", and an "unauthorized access" alert is sent to your phone.
5. If the IR sensor detects someone passing through (possible intruder), the buzzer sounds and an intruder alert is sent.
6. All events are saved to a database and can be viewed in the mobile app.

---

## Project Files Explained

### Python Files (run on the Raspberry Pi)

| File | What it does |
|------|-------------|
| `main.py` | **The starting point.** When you run `sudo python3 main.py`, it sets everything up: loads settings, creates the database, starts the web server, and launches the security system. |
| `Smart security system4.py` | **The hardware controller.** This is the core file that talks to all the physical components: reads RFID cards, checks sensors, controls the door motor, turns LEDs on/off, sounds the buzzer, and writes messages to the LCD screen. |
| `api_server.py` | **The web server.** Creates a small web server (using Flask) that the mobile app connects to. It provides URLs (called "endpoints") where the app can request data like "give me today's events" or "what's the system status". |
| `notifications.py` | **The notification sender.** Sends push notifications to the Android app through Firebase Cloud Messaging (FCM). When something happens (door opens, intruder detected), this file sends an alert to your phone. |
| `database.py` | **The database manager.** Handles storing and retrieving security events in a SQLite database file. Every time something happens, it gets saved here. *(Note: this file is imported by other files but may need to be created.)* |
| `requirements.txt` | **The shopping list for Python.** Lists all the extra Python packages (libraries) that need to be installed for the system to work. |
| `.env` | **The settings file.** Contains configuration values like the database file path, the server port number, and Firebase credentials location. Think of it as the system's settings menu. |
| `firebase-service-account.json` | **The Firebase key.** A secret key file that allows the Raspberry Pi to send push notifications through Google's Firebase service. You download this from the Firebase website. |

### Flutter/Dart Files (the Android mobile app)

These files are inside the `smartsec_app/` folder.

| File | What it does |
|------|-------------|
| `lib/main.dart` | **The app's starting point.** Sets up Firebase, initializes notifications, creates the app's visual theme (colors, fonts), and builds the main navigation with 3 tabs: Dashboard, Access Log, and Settings. |
| `lib/screens/dashboard_screen.dart` | **The home screen.** Shows a live overview: whether the system is online, today's statistics (how many entries, alerts, motion events), the last event that happened, and a list of recent activity. |
| `lib/screens/log_screen.dart` | **The history screen.** Shows a scrollable list of ALL security events with filters. You can filter by type (door opened, intruder, unauthorized, motion). It loads more events as you scroll down (infinite scroll). |
| `lib/screens/settings_screen.dart` | **The settings screen.** Lets you enter the Raspberry Pi's IP address so the app knows where to connect. Has a "Test Connection" button and a setup guide. |
| `lib/models/event.dart` | **The event data model.** Defines what a "security event" looks like in the app: it has an ID, timestamp, event type, card ID, person name, and details. Also has helper functions to display the right icon and label for each event type. |
| `lib/services/api_service.dart` | **The API communicator.** Handles all communication between the app and the Raspberry Pi's web server. It fetches events, stats, and system status. It saves the Pi's IP address so you don't have to re-enter it every time. |
| `lib/services/notification_service.dart` | **The notification handler.** Sets up the app to receive push notifications from Firebase. Asks for permission, subscribes to the security topic, and shows notifications on the phone even when the app is open. |
| `pubspec.yaml` | **The app's shopping list.** Lists all the packages (libraries) the Flutter app needs: HTTP for web requests, Firebase for notifications, Provider for state management, etc. |

### Android Configuration Files

| File | What it does |
|------|-------------|
| `android/app/google-services.json` | Firebase configuration file for the Android app. Downloaded from the Firebase Console. |
| `android/app/build.gradle.kts` | Android build configuration. Specifies the app's package name (`com.smartsec.smartsec_app`), Android SDK version, and dependencies like Firebase. |

---

## Hardware Components Needed

| Component | What it does in the system |
|-----------|---------------------------|
| **Raspberry Pi** | The main computer that runs everything |
| **MFRC522 RFID Reader** | Reads RFID key cards to identify who's at the door |
| **RFID Cards/Tags** | The key cards that people carry to open the door |
| **Servo Motor (SG90)** | Acts as the door lock mechanism - rotates to open/close |
| **IR Sensor** | Infrared sensor that detects if someone passes through (intruder detection) |
| **PIR Sensor** | Passive infrared sensor that detects motion nearby |
| **LCD Display (20x4, I2C)** | Shows messages like "Scan your card...", "Access Granted", "Intruder!" |
| **Green LED** | Lights up when access is granted (door opening) |
| **Red LED** | Lights up when access is denied or an alert triggers |
| **Buzzer** | Makes a sound when an intruder or motion is detected |

### GPIO Pin Assignments

| Component | GPIO Pin (BCM) |
|-----------|---------------|
| Green LED | GPIO 24 |
| Red LED | GPIO 16 |
| PIR Sensor | GPIO 5 |
| Servo Motor | GPIO 6 |
| IR Sensor | GPIO 17 |
| Buzzer | GPIO 27 |
| RFID Reader | SPI (default pins) |
| LCD Display | I2C (address 0x27) |

---

## How to Set Up

### Step 1: Set up the Raspberry Pi

1. Install Python 3 on your Raspberry Pi (usually pre-installed).
2. Copy all the Python files to a folder on the Pi.
3. Install the required Python packages:
   ```bash
   pip install -r requirements.txt
   ```
4. Wire up all the hardware components to the GPIO pins listed above.

### Step 2: Set up Firebase (for push notifications)

1. Go to [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. Enable **Cloud Messaging (FCM)** in the project settings.
3. Download the **service account key** (a JSON file) and save it as `firebase-service-account.json` in the SmartSec folder on the Pi.
4. Add an Android app to your Firebase project and download `google-services.json` into the `smartsec_app/android/app/` folder.

### Step 3: Configure the system

Edit the `.env` file to adjust settings if needed:
- `FIREBASE_CREDENTIALS_PATH` - path to your Firebase key file
- `FCM_TOPIC` - the notification topic (default: `office_security`)
- `DATABASE_PATH` - where to store the event database (default: `./security.db`)
- `API_PORT` - the web server port (default: `5000`)

### Step 4: Run the security system

```bash
sudo python3 main.py
```

This needs `sudo` because accessing the Raspberry Pi's GPIO pins requires administrator permissions.

### Step 5: Build and install the mobile app

1. Install [Flutter](https://flutter.dev/docs/get-started/install) on your computer.
2. Navigate to the `smartsec_app/` folder.
3. Run:
   ```bash
   flutter pub get
   flutter build apk
   ```
4. Install the APK on your Android phone.
5. Open the app, go to Settings, enter your Raspberry Pi's IP address, and test the connection.

---

## API Endpoints (for developers)

The Flask server provides these URLs for the mobile app to fetch data:

| Endpoint | What it returns |
|----------|----------------|
| `GET /api/health` | Simple check to see if the server is running |
| `GET /api/status` | System status: online/offline, last event, today's stats |
| `GET /api/events` | List of security events (supports pagination with `limit` and `offset`, and filtering with `type`) |
| `GET /api/events/today` | All events from today only |
| `GET /api/stats/today` | Count of each event type for today |
