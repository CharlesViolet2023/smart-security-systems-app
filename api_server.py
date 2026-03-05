#!/usr/bin/python3
"""
=============================================================================
api_server.py - SmartSec Web Server (REST API)
=============================================================================

This file creates a small web server that the mobile app talks to.

Think of it like a waiter in a restaurant:
  - The mobile app (customer) asks for something (e.g., "show me today's events")
  - This server (waiter) goes to the database (kitchen), gets the data, and
    brings it back to the app in a format it can understand (JSON)

The server provides several "endpoints" (URLs) that the app can visit:
  - /api/events       -> Get a list of security events (with pagination)
  - /api/events/today -> Get only today's events
  - /api/stats/today  -> Get a count summary of today's events
  - /api/status       -> Get the overall system status
  - /api/health       -> Simple check to see if the server is running

This server runs in the background while the security system monitors sensors.
It uses Flask, a popular Python framework for building web servers.
"""

import os  # For reading environment variables (like the port number)
from flask import Flask, jsonify, request  # Flask tools for building the web server

# Import database functions that fetch stored security events
from database import get_events, get_events_today, get_event_count_today, get_last_event

# Create the Flask web application
app = Flask(__name__)


# -----------------------------------------------------------------------------
# ENDPOINT: Get a list of security events (with pagination and filtering)
# URL: GET /api/events?limit=50&offset=0&type=door_open
#
# Pagination means: instead of sending ALL events at once (could be thousands),
# we send them in small chunks. "limit" = how many to send, "offset" = how many
# to skip (so you can get the next page).
#
# Example: limit=50, offset=0  -> events 1-50 (first page)
#          limit=50, offset=50 -> events 51-100 (second page)
# -----------------------------------------------------------------------------
@app.route("/api/events", methods=["GET"])
def api_get_events():
    # Read the parameters from the URL (with default values if not provided)
    limit = request.args.get("limit", 50, type=int)      # How many events to return
    offset = request.args.get("offset", 0, type=int)      # How many events to skip
    event_type = request.args.get("type", None)            # Filter: only show this type

    # Safety check: don't allow more than 200 events at once (prevents overload)
    limit = min(limit, 200)

    # Fetch events from the database and send them back as JSON
    events = get_events(limit=limit, offset=offset, event_type=event_type)
    return jsonify({
        "success": True,
        "count": len(events),
        "events": events
    })


# -----------------------------------------------------------------------------
# ENDPOINT: Get all events from today only
# URL: GET /api/events/today
#
# Useful for the dashboard to show "what happened today".
# -----------------------------------------------------------------------------
@app.route("/api/events/today", methods=["GET"])
def api_get_events_today():
    events = get_events_today()
    return jsonify({
        "success": True,
        "count": len(events),
        "events": events
    })


# -----------------------------------------------------------------------------
# ENDPOINT: Get a summary count of today's events by type
# URL: GET /api/stats/today
#
# Returns something like: {"door_open": 5, "intruder": 0, "motion": 12}
# The app uses this to show the stats tiles on the dashboard.
# -----------------------------------------------------------------------------
@app.route("/api/stats/today", methods=["GET"])
def api_get_stats_today():
    counts = get_event_count_today()
    return jsonify({
        "success": True,
        "stats": counts,
        "total": sum(counts.values())  # Total number of all events today
    })


# -----------------------------------------------------------------------------
# ENDPOINT: Get the full system status
# URL: GET /api/status
#
# Returns whether the system is online, the last event that happened,
# and today's statistics. The app's dashboard uses this to show the
# "System Online/Offline" indicator and the latest activity.
# -----------------------------------------------------------------------------
@app.route("/api/status", methods=["GET"])
def api_get_status():
    last_event = get_last_event()       # The most recent event
    counts = get_event_count_today()    # Today's stats by type
    return jsonify({
        "success": True,
        "system": "online",             # If this server is responding, the system is online
        "last_event": last_event,
        "today_stats": counts,
        "today_total": sum(counts.values())
    })


# -----------------------------------------------------------------------------
# ENDPOINT: Health check (is the server alive?)
# URL: GET /api/health
#
# The simplest endpoint - just returns "ok". The mobile app uses this to
# quickly test if the Raspberry Pi is reachable on the network.
# -----------------------------------------------------------------------------
@app.route("/api/health", methods=["GET"])
def api_health():
    return jsonify({"status": "ok"})


# -----------------------------------------------------------------------------
# Function to start the web server
# Called from main.py in a background thread
#
# host="0.0.0.0" means: accept connections from any device on the network
#   (not just the Pi itself). This is needed so your phone can connect.
# port=5000 means: the server listens on port 5000 (like a channel number).
#   The app connects to http://<pi-ip-address>:5000
# -----------------------------------------------------------------------------
def start_api_server(host="0.0.0.0", port=None):
    # Use the port from the .env file, or default to 5000
    if port is None:
        port = int(os.environ.get("API_PORT", 5000))

    print(f"[API] Starting Flask server on {host}:{port}")
    # debug=False and use_reloader=False because this runs in a background thread
    app.run(host=host, port=port, debug=False, use_reloader=False)


# -----------------------------------------------------------------------------
# If you run this file directly (python3 api_server.py), it starts the server
# on its own. Useful for testing the API without running the full security system.
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    from database import init_db
    init_db()
    start_api_server()
