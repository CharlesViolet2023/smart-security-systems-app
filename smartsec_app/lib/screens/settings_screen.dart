// =============================================================================
// settings_screen.dart - Settings Screen
// =============================================================================
//
// This screen lets the user configure the app and provides helpful information.
// It has three sections:
//
//   1. RASPBERRY PI CONNECTION
//      - A text field where the user enters the Pi's IP address and port
//        (e.g., "192.168.1.100:5000")
//      - A "Test Connection" button that tries to reach the Pi
//      - Shows green checkmark if connected, red X if failed
//      - The IP address is saved permanently so you don't re-enter it each time
//
//   2. ABOUT SMARTSEC
//      - Shows app version, platform, and notification method
//      - A brief description of what SmartSec does
//
//   3. SETUP GUIDE
//      - Step-by-step instructions for first-time setup
//      - Covers Firebase setup, Pi configuration, and app connection
//
// WHY IS THE IP ADDRESS NEEDED?
//   The app needs to know the Raspberry Pi's network address to fetch data.
//   Since every home/office network assigns different IP addresses, the user
//   must tell the app where to find the Pi. The IP address looks like
//   "192.168.1.100" and the port is usually "5000".
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

/// The Settings screen - configure Pi connection and view app info.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController; // Controls the IP address text field
  bool _isTesting = false;   // Is a connection test currently running?
  String? _testResult;        // Result message after testing ("Connected!" or "Failed")

  @override
  void initState() {
    super.initState();
    // Pre-fill the text field with the currently saved Pi address
    final api = context.read<ApiService>();
    final uri = Uri.tryParse(api.baseUrl);
    _ipController = TextEditingController(
      text: uri != null ? '${uri.host}:${uri.port}' : '192.168.1.100:5000',
    );
  }

  @override
  void dispose() {
    _ipController.dispose(); // Clean up the text controller
    super.dispose();
  }

  /// Test the connection to the Raspberry Pi.
  /// Saves the entered IP address, then tries to fetch the system status.
  /// Shows success or failure message based on the result.
  Future<void> _testConnection() async {
    // Show loading state
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    // Save the new IP address and try to connect
    final url = 'http://${_ipController.text}';
    final api = context.read<ApiService>();
    await api.setBaseUrl(url);   // Save the URL to phone storage
    await api.loadStatus();       // Try to fetch status from the Pi

    // Show the result
    setState(() {
      _isTesting = false;
      _testResult = api.isOnline
          ? 'Connected successfully!'
          : 'Connection failed. Check IP and ensure Pi is running.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =================================================================
          // SECTION 1: Raspberry Pi Connection Settings
          // =================================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header with router icon
                  Row(
                    children: [
                      const Icon(Icons.router, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Raspberry Pi Connection',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // IP address input field
                  TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      labelText: 'Pi IP Address : Port',
                      hintText: '192.168.1.100:5000',
                      prefixText: 'http://',  // Shows "http://" before the input
                      border: OutlineInputBorder(),
                      helperText:
                          'Enter the IP address and port of your Raspberry Pi',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),

                  // Test Connection button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          // Disable the button while testing
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              // Show a small spinner while testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_find),
                          label: Text(
                              _isTesting ? 'Testing...' : 'Test Connection'),
                        ),
                      ),
                    ],
                  ),

                  // Connection test result (shown after testing)
                  if (_testResult != null) ...[
                    const SizedBox(height: 8),
                    Consumer<ApiService>(
                      builder: (context, api, _) => Row(
                        children: [
                          // Green checkmark or red X icon
                          Icon(
                            api.isOnline ? Icons.check_circle : Icons.error,
                            size: 16,
                            color: api.isOnline ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          // Result message text
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color:
                                    api.isOnline ? Colors.green : Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // =================================================================
          // SECTION 2: About SmartSec (app info)
          // =================================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'About SmartSec',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // App information rows
                  _infoRow('Version', '1.0.0'),
                  _infoRow('Platform', 'Android'),
                  _infoRow('Notifications', 'FCM (Firebase)'),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Short description of the app
                  Text(
                    'SmartSec monitors office access using RFID cards, '
                    'IR and PIR sensors on a Raspberry Pi. This app receives '
                    'real-time push notifications and displays the access log.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // =================================================================
          // SECTION 3: Setup Guide (step-by-step instructions)
          // =================================================================
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  Row(
                    children: [
                      const Icon(Icons.help_outline, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Setup Guide',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Step-by-step setup instructions
                  _setupStep('1', 'Create a Firebase project at console.firebase.google.com'),
                  _setupStep('2', 'Enable Cloud Messaging (FCM) in the project'),
                  _setupStep('3', 'Download google-services.json into the Flutter app\'s android/app/ folder'),
                  _setupStep('4', 'Download the service account key and place it in the SmartSec folder on the Pi as firebase-service-account.json'),
                  _setupStep('5', 'Run "sudo python3 main.py" on the Raspberry Pi'),
                  _setupStep('6', 'Enter the Pi\'s IP address above and test the connection'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: builds a single row with a label on the left and value on the right.
  /// Used in the "About SmartSec" section for displaying app info.
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(153))),
        ],
      ),
    );
  }

  /// Helper: builds a single numbered step in the Setup Guide.
  /// Shows a circled number on the left and the instruction text on the right.
  Widget _setupStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            child: Text(number, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
