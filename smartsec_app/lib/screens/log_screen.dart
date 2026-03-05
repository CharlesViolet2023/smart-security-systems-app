// =============================================================================
// log_screen.dart - Access Log Screen (Event History)
// =============================================================================
//
// This screen shows the COMPLETE history of all security events, not just today.
// Think of it as a detailed logbook that records everything that has ever
// happened with the security system.
//
// KEY FEATURES:
//
//   1. FILTER BAR (top) - Horizontal scrollable chips to filter events by type:
//      - All Events, Door Opened, Unauthorized, Intruder, Motion, System Start
//      - Tapping a filter only shows events of that type
//
//   2. EVENT LIST - A scrollable list of event cards, each showing:
//      - A colored bar on the left (green=door, red=intruder, orange=unauthorized, blue=motion)
//      - An emoji icon for the event type
//      - The event label, person name, details
//      - The time and date on the right side
//
//   3. INFINITE SCROLL - When you scroll near the bottom, it automatically
//      loads more events (pagination). Events are loaded 50 at a time.
//
//   4. PULL TO REFRESH - Swipe down to reload the latest events.
//
//   5. ERROR HANDLING - If the Pi is offline, shows a "wifi off" icon
//      with a Retry button.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/event.dart';

/// The Access Log screen - shows the full history of security events.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  String? _selectedFilter;   // Currently active filter (null = show all)
  final ScrollController _scrollController = ScrollController(); // Tracks scroll position
  int _currentOffset = 0;           // How many events we've loaded so far (for pagination)
  static const int _pageSize = 50;  // Load 50 events at a time
  bool _hasMore = true;             // Are there more events to load?

  // The filter options shown as chips at the top of the screen
  // The key is the event type (sent to the API), the value is the display label
  final _filterOptions = const {
    null: 'All Events',
    'door_open': 'Door Opened',
    'unauthorized': 'Unauthorized',
    'intruder': 'Intruder',
    'motion': 'Motion',
    'system_start': 'System Start',
  };

  @override
  void initState() {
    super.initState();
    _loadEvents(); // Load the first page of events

    // Set up INFINITE SCROLL: when the user scrolls near the bottom
    // (within 200 pixels), automatically load the next page of events
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          _hasMore &&
          !context.read<ApiService>().isLoading) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Clean up the scroll controller
    super.dispose();
  }

  /// Load the first page of events (resets to the beginning).
  /// Called on initial load, when a filter changes, or when refreshing.
  void _loadEvents() {
    _currentOffset = 0;  // Reset to the first page
    _hasMore = true;      // Assume there are more events until proven otherwise
    context
        .read<ApiService>()
        .loadEvents(limit: _pageSize, offset: 0, eventType: _selectedFilter);
  }

  /// Load the NEXT page of events (appends to the existing list).
  /// Called automatically by the infinite scroll listener.
  void _loadMore() {
    _currentOffset += _pageSize; // Move to the next page
    context.read<ApiService>().loadEvents(
          limit: _pageSize,
          offset: _currentOffset,
          eventType: _selectedFilter,
          append: true, // Add to existing list instead of replacing
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Top bar with title and refresh button
      appBar: AppBar(
        title: const Text('Access Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents, // Reload from the beginning
          ),
        ],
      ),
      body: Column(
        children: [
          // Top section: horizontal filter bar (All, Door Opened, etc.)
          _buildFilterBar(),
          const Divider(height: 1),

          // Main section: the scrollable list of events
          Expanded(
            child: Consumer<ApiService>(
              builder: (context, api, _) {
                // State 1: Loading for the first time (no events yet)
                if (api.isLoading && api.events.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // State 2: Error occurred and no events to show
                if (api.error != null && api.events.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(api.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadEvents,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // State 3: No events found (empty database or no matching filter)
                if (api.events.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No events found',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                // State 4: Events loaded - show the list
                return RefreshIndicator(
                  onRefresh: () async => _loadEvents(),
                  child: ListView.builder(
                    controller: _scrollController, // For infinite scroll detection
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    // Show one extra item at the bottom if loading more (spinner)
                    itemCount: api.events.length + (api.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // If this is the extra item, show a loading spinner
                      if (index == api.events.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // Otherwise, show the event card
                      final event = api.events[index];
                      return _EventCard(event: event);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER BAR - Horizontal row of filter chips
  // Tapping a chip filters the event list to only show that event type.
  // Tapping the active chip again removes the filter (shows all events).
  // ---------------------------------------------------------------------------
  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal, // Scroll left-right, not up-down
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _filterOptions.entries.map((entry) {
          final isSelected = _selectedFilter == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),  // Display label (e.g., "Door Opened")
              selected: isSelected,       // Highlight if this filter is active
              onSelected: (selected) {
                // Toggle the filter on/off and reload events
                setState(() {
                  _selectedFilter = selected ? entry.key : null;
                });
                _loadEvents();
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================================
// _EventCard - A single event card in the log list
// =============================================================================
// Each card has:
//   - A thin colored bar on the left (color indicates event type)
//   - An emoji icon
//   - Event type label (bold, red for alerts)
//   - Person name and/or details
//   - Time and date on the right side
//
// Color coding:
//   Green  = door opened (normal access)
//   Red    = intruder detected (urgent!)
//   Orange = unauthorized card (warning)
//   Blue   = motion detected (informational)
//   Grey   = other events (system start, etc.)
// =============================================================================

class _EventCard extends StatelessWidget {
  final SecurityEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Choose the color based on event type
    Color tileColor;
    switch (event.eventType) {
      case 'door_open':
        tileColor = Colors.green;   // Normal access = green
        break;
      case 'intruder':
        tileColor = Colors.red;     // Intruder = red (danger)
        break;
      case 'unauthorized':
        tileColor = Colors.orange;  // Unauthorized = orange (warning)
        break;
      case 'motion':
        tileColor = Colors.blue;    // Motion = blue (info)
        break;
      default:
        tileColor = Colors.grey;    // Everything else = grey
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Thin colored bar on the left edge of the card
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            // Main content of the card
            Expanded(
              child: ListTile(
                // Left: emoji icon for the event type
                leading: Text(
                  event.eventIcon,
                  style: const TextStyle(fontSize: 28),
                ),
                // Title: event type label
                title: Text(
                  event.eventLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: event.isAlert ? tileColor : null,
                  ),
                ),
                // Subtitle: person name and/or details
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.personName != null)
                      Text(event.personName!,
                          style: theme.textTheme.bodySmall),
                    if (event.details != null)
                      Text(event.details!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withAlpha(128),
                          )),
                  ],
                ),
                // Right side: time and date
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      event.timeFormatted,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      event.dateFormatted,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withAlpha(128),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
