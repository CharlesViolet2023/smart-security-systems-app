// =============================================================================
// main.dart - SmartSec Mobile App Entry Point
// =============================================================================
//
// This is the FIRST file that runs when the Android app starts.
// It does the following setup steps:
//
//   1. Initializes Firebase (needed for push notifications)
//   2. Sets up the notification service (so the phone can receive alerts)
//   3. Creates "providers" (shared data containers that all screens can access)
//   4. Builds the app with its visual theme (colors, fonts) and navigation
//
// The app has 3 main screens accessible via a bottom navigation bar:
//   - Dashboard: live overview of the security system
//   - Access Log: full history of all events
//   - Settings: configure the Raspberry Pi connection
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_screen.dart';
import 'screens/settings_screen.dart';

/// The main function - the very first thing that runs when the app launches.
void main() async {
  // Tell Flutter to wait for setup to finish before showing the app
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to Firebase (Google's cloud service for push notifications)
  // Wrapped in try/catch so the app still works even if Firebase fails
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Set up the notification system (ask permission, subscribe to alerts)
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Launch the app with "providers" - these are shared data containers
  // that any screen in the app can access. Think of them as shared storage:
  //   - ApiService: handles all communication with the Raspberry Pi
  //   - NotificationService: handles receiving push notifications
  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider: when ApiService data changes, screens auto-update
        ChangeNotifierProvider(create: (_) => ApiService()),
        // Provider.value: makes the notification service available to all screens
        Provider.value(value: notificationService),
      ],
      child: const SmartSecApp(),
    ),
  );
}

// =============================================================================
// SmartSecApp - The App's Visual Configuration
// =============================================================================
// This sets up what the app LOOKS like: colors, fonts, and overall style.
// It supports both light mode and dark mode (follows the phone's setting).
// =============================================================================

class SmartSecApp extends StatelessWidget {
  const SmartSecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSec',
      debugShowCheckedModeBanner: false, // Hide the "DEBUG" banner in the corner

      // Light theme (when phone is in light mode) - uses dark green as primary color
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), // Dark green
          brightness: Brightness.light,
        ),
        useMaterial3: true, // Use Google's latest Material Design 3 style
        appBarTheme: const AppBarTheme(
          centerTitle: true,  // Center the title text in the top bar
          elevation: 0,       // No shadow under the top bar
        ),
      ),

      // Dark theme (when phone is in dark mode) - uses lighter green
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Medium green
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),

      // Automatically switch between light/dark based on the phone's setting
      themeMode: ThemeMode.system,

      // The main screen of the app (contains the bottom navigation)
      home: const MainNavigation(),
    );
  }
}

// =============================================================================
// MainNavigation - The Bottom Navigation Bar
// =============================================================================
// This creates the bottom bar with 3 tabs: Dashboard, Access Log, and Settings.
// Tapping a tab switches which screen is shown.
//
// When the app first loads, it automatically fetches the latest data from
// the Raspberry Pi (system status and today's events).
// =============================================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Which tab is currently selected (0 = Dashboard, 1 = Log, 2 = Settings)
  int _currentIndex = 0;

  // The three screens the user can navigate between
  final _screens = const [
    DashboardScreen(),  // Tab 0: Dashboard (home screen)
    LogScreen(),        // Tab 1: Access Log (event history)
    SettingsScreen(),   // Tab 2: Settings (Pi connection)
  ];

  @override
  void initState() {
    super.initState();
    // Once the app is fully loaded, fetch the latest data from the Pi
    // "addPostFrameCallback" waits for the screen to finish building first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ApiService>().loadStatus();      // Get system status
      context.read<ApiService>().loadEventsToday();  // Get today's events
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Show the currently selected screen
      body: _screens[_currentIndex],

      // The bottom navigation bar with 3 tabs
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        // When a tab is tapped, switch to that screen
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),    // Outline icon when not selected
            selectedIcon: Icon(Icons.dashboard),      // Filled icon when selected
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Access Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
