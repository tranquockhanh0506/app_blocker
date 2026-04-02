# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`app_blocker` is a Flutter plugin (v2.0.0) that provides cross-platform app blocking on Android and iOS. It is published as a pub.dev package.

- **Android**: Min SDK 24 (Android 7.0) — uses AccessibilityService + a full-screen Activity for the block screen
- **iOS**: Min iOS 16.0 — uses Screen Time API (FamilyControls + ManagedSettings)

## Common Commands

```bash
# Dependencies
flutter pub get

# Tests
flutter test                                    # all tests
flutter test test/app_blocker_test.dart         # single file

# Static analysis
flutter analyze

# Run example app on a connected device
cd example && flutter run

# Android native build (from repo root)
cd android && ./gradlew build

# iOS pods (from repo root)
cd ios && pod install
```

## Architecture

The plugin follows Flutter's standard **platform channel** architecture.

```
AppBlocker (Dart singleton)
    └── AppBlockerPlatform (abstract interface)
            └── MethodChannelAppBlocker
                    ├── Android (Kotlin) — AppBlockerPlugin.kt
                    └── iOS (Swift)      — AppBlockerPlugin.swift
```

### Dart Layer (`lib/src/`)

| File | Role |
|------|------|
| `app_blocker.dart` | Public `AppBlocker` singleton — the only API surface consumers use |
| `app_blocker_platform_interface.dart` | Abstract interface all platform implementations must satisfy |
| `app_blocker_method_channel.dart` | Sends calls over `MethodChannel`; receives events from `EventChannel` |
| `constants.dart` | Channel names and method name strings |
| `models/` | `BlockSchedule`, `AppInfo`, `BlockEvent`, `BlockStatus`, `BlockProfile`, `BlockScreenConfig`, `BlockerCapabilities` |

### Android Layer (`android/src/main/kotlin/com/khanhtq/app_blocker/`)

| File/Directory | Role |
|----------------|------|
| `AppBlockerPlugin.kt` | Entry point; routes method calls to managers |
| `AppResolver.kt` | Resolves installed apps; converts metadata for platform channel |
| `PermissionManager.kt` | Accessibility service + exact-alarm permission checks (`SYSTEM_ALERT_WINDOW` no longer required) |
| `blocking/AppBlockerAccessibilityService.kt` | Detects foreground app changes; presses HOME then launches `BlockedAppActivity` |
| `blocking/BlockedAppActivity.kt` | Full-screen block screen Activity (no overlay permission needed) |
| `blocking/BlockingServiceManager.kt` | Core blocking state management; emits events; sends dismiss broadcast to `BlockedAppActivity` |
| `event/BlockEventStreamHandler.kt` | Delivers block events to Flutter via `EventChannel` |
| `scheduling/ScheduleManager.kt` | Time-based blocking via `AlarmManager` |
| `scheduling/ScheduleAlarmReceiver.kt` | Receives `AlarmManager` broadcasts to activate/deactivate schedules |
| `scheduling/ProfileManager.kt` | Groups apps + schedules into profiles |
| `persistence/BlockerPreferences.kt` | `SharedPreferences` wrapper |
| `receiver/BootReceiver.kt` | Restores blocking state after device reboot |

Required permissions in `AndroidManifest.xml`: `PACKAGE_USAGE_STATS`, `QUERY_ALL_PACKAGES`, `RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`. (`SYSTEM_ALERT_WINDOW` is no longer needed — the block screen is a regular Activity.)

### iOS Layer (`ios/Classes/`)

| File | Role |
|------|------|
| `AppBlockerPlugin.swift` | Entry point; routes method calls to managers |
| `PermissionManager.swift` | `FamilyControls` authorization (iOS 16+) |
| `ShieldManager.swift` | Applies `ManagedSettings` shield restrictions |
| `ActivityPickerCoordinator.swift` | Presents `FamilyActivityPicker` UI for app selection |
| `Views/ActivityPickerView.swift` | SwiftUI view wrapping `FamilyActivityPicker` |
| `BlockEventStreamHandler.swift` | Delivers block events to Flutter via `EventChannel` |
| `ScheduleManager.swift` | Persists schedules to `UserDefaults` |
| `ProfileManager.swift` | Groups apps + schedules into profiles |

iOS managers are typed as `AnyObject?` due to `@available` version constraints.

## Key Patterns

- **Singleton**: `AppBlocker.instance` — enforced in Dart; one instance per process.
- **Platform capabilities**: Call `getCapabilities()` before using platform-specific features (e.g. `setBlockScreenConfig` is Android-only).
- **Profile/Schedule system**: Profiles group app lists with schedules; only one profile can be active at a time.
- **Event streaming**: `AppBlocker.instance.onBlockEvent` is an `EventChannel` stream emitting `BlockEvent` objects (`blocked`, `unblocked`, `attemptedAccess`, `scheduleActivated`, `scheduleDeactivated`).

## Testing

Tests live in `test/`. They use a `MockAppBlockerPlatform` that replaces the real method channel.

```bash
flutter test                                   # run all
flutter test test/app_blocker_test.dart        # unit tests
flutter test test/models_test.dart             # model serialization
flutter test test/exceptions_test.dart         # exception types
```

## Lint Rules (`analysis_options.yaml`)

Uses `package:flutter_lints/flutter.yaml` plus: `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_locals`, `avoid_print`, `prefer_single_quotes`, `sort_child_properties_last`, `unawaited_futures`, `unnecessary_lambdas`.
