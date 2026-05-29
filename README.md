# mango_health

Personal health companion.

## Features - Phase 1

Tracks daily steps. Earn rewards.

- **Daily step tracking** via Android Health Connect / Apple HealthKit.
- **Rewards system** — users earn points based on steps walked each day.
- Self-hosted & works completely offline for privacy; optional cloud sync via PocketBase.

## Future features (Phase 2+)

Store medical documents safely.

## Stack

Flutter (Material 3) on Android / iOS / desktop / **web**, with:

- `image_picker` — capture from camera or import from gallery (web uses file picker).
- `sqflite` + `sqflite_common_ffi` (desktop) + `sqflite_common_ffi_web` (web, via sqlite3.wasm + IndexedDB) — local SQLite store for documents, episodes and tags.
- `health` — reads daily step count from Android Health Connect (API 26+) and Apple HealthKit.
- `pocketbase` — optional self-hosted backend for user accounts, step sync, and rewards.
- Image bytes are stored as `BLOB` inside SQLite, so no platform-specific filesystem code is needed.

All data stays on the device / browser by default; nothing leaves the client unless you configure a PocketBase server.

> **Note on web**: SQLite runs in a shared worker via `sqlite3.wasm` and persists to IndexedDB. Health data is not available on web.

## PocketBase setup (optional)

PocketBase is a single-binary self-hosted backend. To enable cloud sync and rewards:

1. [Download PocketBase](https://pocketbase.io/docs/) and run it:
   ```
   ./pocketbase serve
   ```
2. In the Admin UI (`http://127.0.0.1:8090/_/`), create these collections:

   | Collection | Fields |
   |---|---|
   | `users` (built-in) | add `reward_points` (number, default 0) |
   | `steps` | `user` (relation→users), `date` (text), `steps` (number) |

3. Set your PocketBase URL in the app settings.

### Rewards logic

Steps per day are synced to PocketBase. The server (or a scheduled job) can apply any reward formula, e.g.:

- < 5 000 steps → 0 pts
- 5 000 – 9 999 steps → 10 pts
- ≥ 10 000 steps → 25 pts

## Health permissions

### Android
Health Connect must be installed (pre-installed on Android 14+, available on Play Store for Android 9+). The app requests `READ_STEPS` permission at runtime.

### iOS
HealthKit `NSHealthShareUsageDescription` is declared in `Info.plist`. The app requests read-only access to step count at runtime.

## Project layout

```
lib/
  main.dart                       # App entry, theme, routing, sqlite factory wiring
  models/document.dart            # MedicalDocument model (image stored as bytes)
  platform/
    desktop_sqlite.dart           # FFI init for macOS/Linux/Windows
    desktop_sqlite_web.dart       # No-op stub for web (conditional import)
  services/
    database_service.dart         # SQLite persistence
    health_service.dart           # Step count via Health Connect / HealthKit
    pocketbase_service.dart       # PocketBase auth, step sync, rewards
  screens/
    home_screen.dart              # Documents grouped by episode
    capture_screen.dart           # Take photo, OCR, save
    document_detail_screen.dart   # View / edit / delete a document
```

## Running

```
flutter pub get
# One-time, only needed for web:
dart run sqflite_common_ffi_web:setup

flutter run                       # mobile / desktop
flutter run -d chrome             # web
```

The Android build requires `minSdk >= 21` for ML Kit (already configured). Health Connect requires `minSdk >= 26`.
