// =============================================================================
// api_service.dart - Communication with the Raspberry Pi
// =============================================================================
//
// This file handles ALL communication between the mobile app and the
// Raspberry Pi's web server (Flask API).
//
// Think of it as the app's "messenger":
//   - It sends requests to the Pi asking for data
//   - It receives the responses and stores them
//   - It tells the screens when new data is available so they can update
//
// KEY FEATURES:
//   - Fetches system status (online/offline, last event, today's stats)
//   - Fetches event lists (all events, today's events, filtered events)
//   - Saves the Pi's IP address so you don't have to re-enter it every time
//   - Handles errors gracefully (shows "offline" if Pi is unreachable)
//   - Uses "ChangeNotifier" so screens automatically refresh when data changes
//
// HOW IT CONNECTS TO THE PI:
//   The app sends HTTP GET requests to the Pi's IP address (e.g.,
//   http://192.168.1.100:5000/api/status). The Pi's Flask server
//   (api_server.py) processes the request and sends back JSON data.
// =============================================================================

import 'dart:convert';  // For converting JSON text into Dart objects
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;  // For making HTTP web requests
import 'package:shared_preferences/shared_preferences.dart';  // For saving settings to phone storage
import '../models/event.dart';

/// The main service that talks to the Raspberry Pi's web server.
/// "ChangeNotifier" means: when data changes, all screens that are
/// listening will automatically rebuild to show the new data.
class ApiService extends ChangeNotifier {
  // --- Stored data ---
  String _baseUrl = 'http://192.168.1.100:5000'; // The Pi's address (default value)
  bool _isLoading = false;              // Are we currently waiting for a response?
  String? _error;                        // Error message if something went wrong
  List<SecurityEvent> _events = [];      // Full list of events (for the Log screen)
  List<SecurityEvent> _todayEvents = []; // Today's events only (for the Dashboard)
  Map<String, int> _todayStats = {};     // Count of each event type today (e.g., {"door_open": 3})
  int _todayTotal = 0;                   // Total number of events today
  SecurityEvent? _lastEvent;             // The most recent event that happened
  bool _isOnline = false;               // Is the Pi reachable right now?

  // --- Public getters ---
  // These let screens READ the data but not directly modify it.
  // Only this service can update the data (through its methods).
  String get baseUrl => _baseUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SecurityEvent> get events => _events;
  List<SecurityEvent> get todayEvents => _todayEvents;
  Map<String, int> get todayStats => _todayStats;
  int get todayTotal => _todayTotal;
  SecurityEvent? get lastEvent => _lastEvent;
  bool get isOnline => _isOnline;

  /// When the service is created, load any previously saved Pi IP address.
  ApiService() {
    _loadSavedUrl();
  }

  /// Load the Pi's IP address from the phone's saved settings.
  /// This way, the user only needs to enter the IP once - it's remembered.
  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('pi_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      notifyListeners(); // Tell screens to update with the new URL
    }
  }

  /// Save a new Pi IP address (called from the Settings screen).
  /// Stores it both in memory and in the phone's permanent storage.
  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pi_base_url', url);
    notifyListeners();
  }

  /// Internal helper: send a GET request to the Pi and return the JSON response.
  /// Handles errors (timeout, connection refused, etc.) and updates the
  /// online/offline status accordingly.
  ///
  /// Returns the parsed JSON data, or null if the request failed.
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      // Send the HTTP GET request with a 10-second timeout
      final response = await http
          .get(Uri.parse('$_baseUrl$endpoint'))
          .timeout(const Duration(seconds: 10));

      // 200 = success (standard HTTP code for "OK")
      if (response.statusCode == 200) {
        _isOnline = true;
        _error = null;
        // Parse the JSON text into a Dart Map (dictionary)
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _error = 'Server error: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      // If anything goes wrong (no internet, Pi is off, wrong IP, etc.)
      _isOnline = false;
      _error = 'Cannot connect to Pi. Check IP and network.';
      return null;
    }
  }

  /// Fetch the system status from the Pi.
  /// Gets: online/offline status, the last event, and today's statistics.
  /// Called when the app starts and when the user pulls to refresh.
  Future<void> loadStatus() async {
    _isLoading = true;
    notifyListeners(); // Tell screens "we're loading"

    final data = await _get('/api/status');
    if (data != null) {
      _isOnline = data['system'] == 'online';

      // Parse the last event (if there is one)
      if (data['last_event'] != null) {
        _lastEvent = SecurityEvent.fromJson(data['last_event']);
      }

      // Parse today's stats (convert from JSON to a Map<String, int>)
      final stats = data['today_stats'] as Map<String, dynamic>? ?? {};
      _todayStats = stats.map((k, v) => MapEntry(k, v as int));
      _todayTotal = data['today_total'] as int? ?? 0;
    }

    _isLoading = false;
    notifyListeners(); // Tell screens "we're done loading, here's the new data"
  }

  /// Fetch all of today's events from the Pi.
  /// Used by the Dashboard to show the "Recent Activity" list.
  Future<void> loadEventsToday() async {
    _isLoading = true;
    notifyListeners();

    final data = await _get('/api/events/today');
    if (data != null) {
      final eventList = data['events'] as List<dynamic>;
      // Convert each JSON object into a SecurityEvent
      _todayEvents =
          eventList.map((e) => SecurityEvent.fromJson(e)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch a page of events from the Pi (used by the Log screen).
  ///
  /// Parameters:
  ///   limit:     How many events to fetch (default 50)
  ///   offset:    How many events to skip (for pagination / "load more")
  ///   eventType: Filter by type (e.g., "door_open" to only show door events)
  ///   append:    If true, ADD to the existing list (for infinite scroll).
  ///              If false, REPLACE the list (for a fresh load).
  Future<void> loadEvents({
    int limit = 50,
    int offset = 0,
    String? eventType,
    bool append = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Build the URL with query parameters
    String endpoint = '/api/events?limit=$limit&offset=$offset';
    if (eventType != null) {
      endpoint += '&type=$eventType';
    }

    final data = await _get(endpoint);
    if (data != null) {
      final eventList = data['events'] as List<dynamic>;
      final newEvents =
          eventList.map((e) => SecurityEvent.fromJson(e)).toList();

      if (append) {
        // Add new events to the end of the existing list (infinite scroll)
        _events.addAll(newEvents);
      } else {
        // Replace the entire list with fresh data
        _events = newEvents;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh everything at once (status + today's events + all events).
  /// Runs all three requests in parallel for speed.
  Future<void> refreshAll() async {
    await Future.wait([
      loadStatus(),
      loadEventsToday(),
      loadEvents(),
    ]);
  }
}
