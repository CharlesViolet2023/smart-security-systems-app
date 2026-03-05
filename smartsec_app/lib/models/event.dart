// =============================================================================
// event.dart - Security Event Data Model
// =============================================================================
//
// This file defines what a "security event" looks like in the app.
//
// Every time something happens on the Raspberry Pi (someone scans a card,
// motion is detected, an intruder is spotted), it creates a "SecurityEvent"
// and stores it in the database. This file defines the structure of that event
// so the app knows how to read and display it.
//
// A SecurityEvent has:
//   - id:         A unique number identifying this event
//   - timestamp:  When it happened (date and time)
//   - eventType:  What type of event (door_open, intruder, unauthorized, motion, system_start)
//   - cardId:     The RFID card number (if a card was scanned)
//   - personName: The name of the person (if known)
//   - details:    Extra information about what happened
//
// This file also has helper functions to convert event types into
// user-friendly labels (e.g., "door_open" becomes "Door Opened")
// and emoji icons (e.g., "intruder" becomes the alarm emoji).
// =============================================================================

/// Represents a single security event from the SmartSec system.
/// Each event is one thing that happened: a door opening, an intruder alert, etc.
class SecurityEvent {
  final int id;              // Unique ID number for this event
  final String timestamp;    // When it happened (e.g., "2025-03-05 14:30:00")
  final String eventType;    // Type: "door_open", "intruder", "unauthorized", "motion", "system_start"
  final String? cardId;      // The RFID card number (null if no card was involved)
  final String? personName;  // Name of the person (null if unknown or not applicable)
  final String? details;     // Extra info (null if none)

  SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    this.cardId,
    this.personName,
    this.details,
  });

  /// Create a SecurityEvent from JSON data received from the API.
  /// JSON is the format the Raspberry Pi's web server sends data in.
  /// This converts that raw data into a SecurityEvent object the app can use.
  factory SecurityEvent.fromJson(Map<String, dynamic> json) {
    return SecurityEvent(
      id: json['id'] as int,
      timestamp: json['timestamp'] as String,
      eventType: json['event_type'] as String,
      cardId: json['card_id'] as String?,
      personName: json['person_name'] as String?,
      details: json['details'] as String?,
    );
  }

  /// Convert the technical event type into a human-readable label.
  /// For example: "door_open" -> "Door Opened", "intruder" -> "Intruder Alert"
  String get eventLabel {
    switch (eventType) {
      case 'door_open':
        return 'Door Opened';
      case 'unauthorized':
        return 'Unauthorized';
      case 'intruder':
        return 'Intruder Alert';
      case 'motion':
        return 'Motion Detected';
      case 'system_start':
        return 'System Started';
      default:
        return eventType; // If unknown type, just show the raw type name
    }
  }

  /// Get the appropriate emoji icon for this event type.
  /// These icons are shown next to each event in the app's lists.
  String get eventIcon {
    switch (eventType) {
      case 'door_open':
        return '🚪';      // Door emoji for door access
      case 'unauthorized':
        return '⚠️';      // Warning sign for unauthorized attempts
      case 'intruder':
        return '🚨';      // Police light for intruder alerts
      case 'motion':
        return '👤';      // Person silhouette for motion detection
      case 'system_start':
        return '✅';      // Checkmark for system startup
      default:
        return '📋';      // Clipboard for unknown event types
    }
  }

  /// Check if this event is an alert (something that needs attention).
  /// Intruder alerts and unauthorized access are considered alert-level events.
  /// The app shows these in red to draw attention.
  bool get isAlert =>
      eventType == 'intruder' || eventType == 'unauthorized';

  /// Convert the timestamp string into a DateTime object for date/time operations.
  DateTime get dateTime => DateTime.parse(timestamp);

  /// Format the time portion as HH:MM:SS (e.g., "14:30:05").
  /// Used to show when the event happened in the event lists.
  String get timeFormatted {
    final dt = dateTime;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  /// Format the date portion as YYYY-MM-DD (e.g., "2025-03-05").
  /// Used alongside timeFormatted to show the full date and time.
  String get dateFormatted {
    final dt = dateTime;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
