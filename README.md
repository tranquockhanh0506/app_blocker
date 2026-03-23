# app_blocker

[![pub package](https://img.shields.io/pub/v/app_blocker.svg)](https://pub.dev/packages/app_blocker)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/tranquockhanh0506/app_blocker/blob/main/LICENSE)

A Flutter plugin to block apps on Android and iOS.

- **Android:** Foreground service + overlay window
- **iOS:** Screen Time API (FamilyControls + ManagedSettings)

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
  app_blocker: ^1.0.0
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

### Get Installed Apps

```dart
// Android: returns all installed user apps with name & icon
// iOS: shows FamilyActivityPicker, returns selected apps
final apps = await blocker.getApps();
// Each app has: appName, packageName, icon (Uint8List?, Android only)
```

### Block / Unblock Apps

```dart
// Block specific apps
await blocker.blockApps(['com.instagram.android', 'com.twitter.android']);

// Block all apps
await blocker.blockAll();

// Unblock specific apps
await blocker.unblockApps(['com.instagram.android']);

// Unblock all
await blocker.unblockAll();

// Get list of currently blocked apps
final blocked = await blocker.getBlockedApps();

// Check status of a specific app
final status = await blocker.getAppStatus('com.instagram.android');
// Returns: BlockStatus.blocked / .unblocked / .scheduled
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
