// =============================================================================
// dashboard_screen.dart - The Home Screen (Dashboard)
// =============================================================================
//
// This is the FIRST screen users see when they open the app.
// It provides a quick overview of the security system's current state:
//
//   1. STATUS CARD (top) - Shows whether the Raspberry Pi is online or offline
//      - Green with a shield icon = system is running and monitoring
//      - Red with a wifi-off icon = can't connect to the Pi
//
//   2. TODAY'S STATS - Three tiles showing today's counts:
//      - Entries: how many times the door was opened today
//      - Alerts: how many intruder + unauthorized events today
//      - Motion: how many motion detection events today
//
//   3. LAST EVENT - Shows the most recent thing that happened
//      (e.g., "Door Opened - John - 2025-03-05 at 14:30:05")
//
//   4. RECENT ACTIVITY - A list of the 10 most recent events from today
//
// Users can REFRESH the data by:
//   - Tapping the refresh icon in the top-right corner
//   - Pulling down on the screen (pull-to-refresh gesture)
//
// This screen uses "Consumer<ApiService>" which means it automatically
// rebuilds whenever the ApiService data changes (e.g., after a refresh).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/event.dart';

/// The main dashboard screen - shows a live overview of the security system.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar with title and refresh button
      appBar: AppBar(
        title: const Text('SmartSec Dashboard'),
        actions: [
          // Refresh button - fetches latest data from the Raspberry Pi
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ApiService>().loadStatus();
              context.read<ApiService>().loadEventsToday();
            },
          ),
        ],
      ),

      // The main content - listens to ApiService for data changes
      // "Consumer" means: rebuild this section whenever ApiService data updates
      body: Consumer<ApiService>(
        builder: (context, api, _) {
          // Show a loading spinner if data is being fetched for the first time
          if (api.isLoading && api.todayEvents.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Pull-to-refresh: user can swipe down to refresh all data
          return RefreshIndicator(
            onRefresh: () async {
              await api.loadStatus();
              await api.loadEventsToday();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section 1: Online/Offline status card
                _buildStatusCard(context, api),
                const SizedBox(height: 16),

                // Section 2: Today's statistics (Entries, Alerts, Motion)
                _buildStatsSection(context, api),
                const SizedBox(height: 16),

                // Section 3: The most recent event (if there is one)
                if (api.lastEvent != null) ...[
                  _buildLastEventCard(context, api.lastEvent!),
                  const SizedBox(height: 16),
                ],

                // Section 4: List of recent activity (up to 10 events)
                _buildRecentActivity(context, api),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS CARD - Shows if the system is online or offline
  // Green background + shield icon = online
  // Red background + wifi-off icon = offline
  // ---------------------------------------------------------------------------
  Widget _buildStatusCard(BuildContext context, ApiService api) {
    final isOnline = api.isOnline;
    final theme = Theme.of(context);

    return Card(
      // Light green or light red background depending on status
      color: isOnline
          ? Colors.green.withAlpha(25)
          : Colors.red.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon (shield or wifi-off)
            Icon(
              isOnline ? Icons.security : Icons.wifi_off,
              size: 40,
              color: isOnline ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status title
                  Text(
                    isOnline ? 'System Online' : 'System Offline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.red,
                    ),
                  ),
                  // Status description or error message
                  Text(
                    isOnline
                        ? 'Security system is active and monitoring'
                        : api.error ?? 'Cannot connect to Raspberry Pi',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATS SECTION - Three tiles showing today's event counts
  // Shows: Entries (door opens), Alerts (intruders + unauthorized), Motion
  // ---------------------------------------------------------------------------
  Widget _buildStatsSection(BuildContext context, ApiService api) {
    final theme = Theme.of(context);
    final stats = api.todayStats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Activity",
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Tile 1: Door entries (green)
            _buildStatTile(
              context,
              icon: Icons.door_front_door,
              label: 'Entries',
              count: stats['door_open'] ?? 0,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            // Tile 2: Alerts = intruder events + unauthorized events (red)
            _buildStatTile(
              context,
              icon: Icons.warning_amber,
              label: 'Alerts',
              count: (stats['intruder'] ?? 0) + (stats['unauthorized'] ?? 0),
              color: Colors.red,
            ),
            const SizedBox(width: 8),
            // Tile 3: Motion detection events (blue)
            _buildStatTile(
              context,
              icon: Icons.directions_walk,
              label: 'Motion',
              count: stats['motion'] ?? 0,
              color: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAT TILE - A single statistic card (used 3 times in the stats section)
  // Shows an icon, a count number, and a label
  // ---------------------------------------------------------------------------
  Widget _buildStatTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              // The count number (displayed large and bold)
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              // The label below the number
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAST EVENT CARD - Shows the most recent security event
  // Displays: emoji icon, event type, person name (if known), date and time
  // Alert events (intruder, unauthorized) are shown in red
  // ---------------------------------------------------------------------------
  Widget _buildLastEventCard(BuildContext context, SecurityEvent event) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last Event',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Event emoji icon (large)
                Text(event.eventIcon, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event type label (red for alerts, green for normal)
                      Text(
                        event.eventLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              event.isAlert ? Colors.red : Colors.green,
                        ),
                      ),
                      // Person name (if this event has one)
                      if (event.personName != null)
                        Text(event.personName!,
                            style: theme.textTheme.bodyMedium),
                      // Date and time of the event
                      Text(
                        '${event.dateFormatted} at ${event.timeFormatted}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withAlpha(153),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT ACTIVITY - Shows up to 10 of today's most recent events
  // If no events today, shows a "No activity today" placeholder
  // ---------------------------------------------------------------------------
  Widget _buildRecentActivity(BuildContext context, ApiService api) {
    final theme = Theme.of(context);
    // Only show the 10 most recent events (not all of them)
    final events = api.todayEvents.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // If no events today, show a placeholder message
        if (events.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_available,
                        size: 48,
                        color: theme.colorScheme.onSurface
                            .withAlpha(77)),
                    const SizedBox(height: 8),
                    Text(
                      'No activity today',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        // Otherwise, show each event as a list tile
        else
          ...events.map(
            (event) => _EventListTile(event: event),
          ),
      ],
    );
  }
}

// =============================================================================
// _EventListTile - A single event row in the Recent Activity list
// =============================================================================
// Shows: emoji icon | event type label | person name or details | time
// Alert events (intruder, unauthorized) have red text to stand out.
// =============================================================================

class _EventListTile extends StatelessWidget {
  final SecurityEvent event;

  const _EventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        // Left side: event emoji icon
        leading: Text(event.eventIcon, style: const TextStyle(fontSize: 24)),
        // Title: event type (e.g., "Door Opened", "Intruder Alert")
        title: Text(
          event.eventLabel,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: event.isAlert ? Colors.red : null, // Red for alerts
          ),
        ),
        // Subtitle: person name or event details
        subtitle: Text(
          event.personName ?? event.details ?? '',
          style: theme.textTheme.bodySmall,
        ),
        // Right side: time of the event
        trailing: Text(
          event.timeFormatted,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(153),
          ),
        ),
      ),
    );
  }
}
