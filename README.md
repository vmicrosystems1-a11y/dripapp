# Drip Irrigation 2 — Screenshot-style dashboard

Android package: `com.vmicrosystems.drip_irrigation2`. Firebase project: `drip-f280e`.

## Screens
System status, soil humidity, valve ON/OFF, manual/auto, morning/evening schedules. No temperature/tank/pump widgets.

## Firebase Realtime Database contract

```json
{
  "irrigation": {
    "device": {"online": false, "time": "12:26:30 PM", "date": "30-07-2026"},
    "sensors": {"soilMoisture": 20},
    "controls": {"autoMode": true, "valveOn": false},
    "schedule": {
      "morningEnabled": true, "morningOn": "08:00", "morningOff": "08:02",
      "eveningEnabled": true, "eveningOn": "16:20", "eveningOff": "16:22"
    }
  }
}
```

App writes to `irrigation/controls/autoMode`, `irrigation/controls/valveOn`, and `irrigation/schedule/*`. ESP32 should publish `irrigation/device/*`, `irrigation/sensors/soilMoisture`, and the actual `controls/valveOn` state. App does not autonomously open/close valves based on soil data; implement sensor-based decisions and schedules in ESP32 firmware. The DRY/GOOD/WET thresholds (30%,70%) are visual labels only.

Schedule changes are written immediately; Save Schedule confirms current values. Configure Firebase Realtime Database security rules to allow authorized user reads/writes to these paths. Device online requires ESP32 publishing status; add heartbeat/timeout logic in firmware for reliable status.

## Build
Upload contents (including `.github`) to GitHub repo root, commit, run GitHub Actions **Build Drip Irrigation 2 APK**, download artifact ZIP, extract `app-release.apk` and install. No Flutter SDK build was run in this environment.
