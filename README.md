# app_blocker

[![pub package](https://img.shields.io/pub/v/app_blocker.svg)](https://pub.dev/packages/app_blocker)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/tranquockhanh0506/app_blocker/blob/main/LICENSE)

A Flutter plugin to block apps on Android and iOS.

- **Android:** Foreground service + overlay window to detect and block apps
- **iOS:** Screen Time API
  - **FamilyControls** — request user authorization to manage Screen Time
  - **ManagedSettings** — apply shield restrictions on selected apps (required for blocking specific apps, not needed for `blockAll()`)

## Supported Functions

- `checkPermission()` — Check if required permissions are granted
- `requestPermission()` — Request permissions from user
- `getApps()` — Get list of installed apps (Android) or show app picker (iOS)
- `blockApps(List<String>)` — Block specific apps
- `blockAll()` — Block all apps
- `unblockApps(List<String>)` — Unblock specific apps
- `unblockAll()` — Unblock all apps
- `getBlockedApps()` — Get list of currently blocked apps
- `getAppStatus(String)` — Check block status of a specific app
- `setOverlayConfig(OverlayConfig)` — Customize block overlay (Android only)
- `addSchedule(BlockSchedule)` — Add a blocking schedule
- `onBlockEvent` — Stream of block/unblock events
- `getCapabilities()` — Check available features on current platform

## Platform Support

| Feature              | Android | iOS |
|----------------------|---------|-----|
| Block / Unblock apps | ✅      | ✅  |
| Block all apps       | ✅      | ✅  |
| Get installed apps   | ✅      | -   |
| Custom overlay       | ✅      | -   |
| Screen Time Shield   | -       | ✅  |
| Schedules            | ✅      | ✅  |
| Block events stream  | ✅      | ✅  |
| Boot persistence     | ✅      | -   |

## Installation

```yaml
dependencies:
  app_blocker: ^1.0.6
```

## Setup

### Android

**Minimum SDK:** 24 (Android 7.0)

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">

    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
</manifest>
```

### iOS

**Minimum iOS:** 16.0

1. Open `ios/Runner.xcworkspace` in Xcode
2. Runner target > **Signing & Capabilities** > add **Family Controls**
3. Set deployment target in `ios/Podfile`:

```ruby
platform :ios, '16.0'
```

## Usage

```dart
import 'package:app_blocker/app_blocker.dart';

final blocker = AppBlocker.instance;
```

### Permission

```dart
// Check permission status
final status = await blocker.checkPermission();
// Returns: BlockerPermissionStatus.granted / .denied / .restricted

// Request permission (opens system settings on Android, shows dialog on iOS)
await blocker.requestPermission();
```

### Get Apps & Block

**Android:**

```dart
// Get all installed apps (returns list with appName, packageName, icon)
final apps = await blocker.getApps();

// Block using package names
await blocker.blockApps(apps.map((a) => a.packageName).toList());
```

**iOS:**

```dart
// Opens FamilyActivityPicker — user selects apps → automatically blocked
await blocker.getApps();
```

**Common:**

```dart
await blocker.blockAll();
await blocker.unblockAll();
final blocked = await blocker.getBlockedApps();
```

### Overlay Config (Android only)

```dart
await blocker.setOverlayConfig(
  const OverlayConfig(
    title: 'Stay Focused!',
    subtitle: 'This app is blocked',
    message: 'Get back to work.',
    backgroundColor: Color(0xDD000000),
  ),
);
// iOS uses system Screen Time Shield automatically
```

### Schedules

```dart
// Add a schedule
await blocker.addSchedule(BlockSchedule(
  id: 'work-hours',
  name: 'Work Hours',
  appIdentifiers: ['com.instagram.android'],
  weekdays: [1, 2, 3, 4, 5], // Mon-Fri (ISO 8601)
  startTime: const TimeOfDay(hour: 9, minute: 0),
  endTime: const TimeOfDay(hour: 17, minute: 0),
));

await blocker.enableSchedule('work-hours');
await blocker.disableSchedule('work-hours');
await blocker.removeSchedule('work-hours');
final schedules = await blocker.getSchedules();
```

### Block Events

```dart
blocker.onBlockEvent.listen((event) {
  print('${event.type}: ${event.packageName}');
});
// Event types: blocked, unblocked, attemptedAccess,
//              scheduleActivated, scheduleDeactivated
```

### Capabilities

```dart
// Check what features are available on current platform
final caps = await blocker.getCapabilities();
```

## Example

See the [example app](https://github.com/tranquockhanh0506/app_blocker/tree/master/example) for a complete working demo.

## License

MIT — see [LICENSE](LICENSE).
