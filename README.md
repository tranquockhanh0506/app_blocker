# app_blocker

[![pub package](https://img.shields.io/pub/v/app_blocker.svg)](https://pub.dev/packages/app_blocker)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/khanhtq/app_blocker/blob/main/LICENSE)

Cross-platform Flutter plugin for blocking apps with overlay (Android) and Screen Time Shield (iOS).

## Features

- Block specific apps or all apps at once
- Real-time blocking events via `Stream`
- Schedule-based blocking with configurable weekdays and time ranges
- Focus profiles for grouping blocked apps and schedules
- Customizable overlay UI (Android)
- System-level Screen Time Shield (iOS)
- App discovery (installed apps list on Android, FamilyActivityPicker on iOS)
- Permission management with status checking
- Boot persistence (Android)

## Platform Support

| Feature                  | Android | iOS   |
|--------------------------|---------|-------|
| Block / Unblock apps     | ✅      | ✅    |
| Overlay UI               | ✅      | -     |
| Screen Time Shield       | -       | ✅    |
| Installed apps list      | ✅      | -     |
| FamilyActivityPicker     | -       | ✅    |
| Schedules                | ✅      | ✅    |
| Profiles                 | ✅      | ✅    |
| Block events stream      | ✅      | ✅    |
| Boot persistence         | ✅      | -     |

## Getting Started

### Installation

Add `app_blocker` to your `pubspec.yaml`:

```yaml
dependencies:
  app_blocker: ^1.0.0
```

Then run:

```bash
flutter pub get
```

### Android Setup

**Minimum SDK:** 24 (Android 7.0)

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Required for detecting foreground apps -->
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />

    <!-- Required for showing overlay on blocked apps -->
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />

    <!-- Required for listing installed apps (API 30+) -->
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission" />

    <!-- Required for foreground service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />

    <!-- Required for restoring block state after reboot -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <!-- Required for scheduling -->
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <!-- ... -->
</manifest>
```

Add the `tools` namespace to the `<manifest>` tag:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```

### iOS Setup

**Minimum iOS:** 15.0 (iOS 16.0+ recommended for full feature support)

1. Enable the **FamilyControls** capability in your Xcode project:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select the Runner target > Signing & Capabilities
   - Click **+ Capability** and add **Family Controls**

2. Add the entitlement to your `ios/Runner/Runner.entitlements`:

```xml
<key>com.apple.developer.family-controls</key>
<true/>
```

3. Set the minimum deployment target in `ios/Podfile`:

```ruby
platform :ios, '15.0'
```

> **Note:** Full Screen Time API features (ManagedSettingsStore, DeviceActivityMonitor) require iOS 16.0+. On iOS 15.x, only FamilyControls authorization is available.

## Usage

### Quick Start

```dart
import 'package:app_blocker/app_blocker.dart';

final blocker = AppBlocker.instance;

// 1. Request permissions
await blocker.requestPermission();

// 2. Get available apps
final apps = await blocker.getApps();

// 3. Block selected apps
await blocker.blockApps(['com.instagram.android', 'com.twitter.android']);

// 4. Listen to events
blocker.onBlockEvent.listen((event) {
  print('${event.type}: ${event.packageName}');
});
```

### Permission Handling

```dart
final status = await blocker.checkPermission();

switch (status) {
  case BlockerPermissionStatus.granted:
    // Ready to block
    break;
  case BlockerPermissionStatus.denied:
    // Request permission
    final result = await blocker.requestPermission();
    break;
  case BlockerPermissionStatus.restricted:
    // Cannot request - restricted by system policy
    break;
}
```

### Blocking Apps

```dart
// Block specific apps
await blocker.blockApps(['com.example.app1', 'com.example.app2']);

// Block all user apps
await blocker.blockAll();

// Unblock specific apps
await blocker.unblockApps(['com.example.app1']);

// Unblock everything
await blocker.unblockAll();

// Check what's blocked
final blockedApps = await blocker.getBlockedApps();

// Check a specific app
final status = await blocker.getAppStatus('com.example.app1');
// Returns: BlockStatus.blocked, BlockStatus.unblocked, or BlockStatus.scheduled
```

### Listening to Events

```dart
blocker.onBlockEvent.listen((event) {
  switch (event.type) {
    case BlockEventType.blocked:
      print('Blocked: ${event.packageName}');
      break;
    case BlockEventType.unblocked:
      print('Unblocked: ${event.packageName}');
      break;
    case BlockEventType.attemptedAccess:
      print('Attempted access: ${event.packageName}');
      break;
    case BlockEventType.scheduleActivated:
      print('Schedule activated: ${event.scheduleId}');
      break;
    case BlockEventType.scheduleDeactivated:
      print('Schedule deactivated: ${event.scheduleId}');
      break;
  }
});
```

### Scheduling

```dart
// Create a schedule to block apps on weekdays from 9 AM to 5 PM
final schedule = BlockSchedule(
  id: 'work-hours',
  name: 'Work Hours',
  appIdentifiers: ['com.instagram.android', 'com.twitter.android'],
  weekdays: [1, 2, 3, 4, 5], // Monday to Friday (ISO 8601)
  startTime: const TimeOfDay(hour: 9, minute: 0),
  endTime: const TimeOfDay(hour: 17, minute: 0),
);

await blocker.addSchedule(schedule);

// Get all schedules
final schedules = await blocker.getSchedules();

// Enable / disable
await blocker.disableSchedule('work-hours');
await blocker.enableSchedule('work-hours');

// Remove
await blocker.removeSchedule('work-hours');
```

### Profiles

```dart
// Create a profile
final profile = BlockProfile(
  id: 'work-mode',
  name: 'Work Mode',
  appIdentifiers: ['com.instagram.android', 'com.twitter.android'],
  schedules: [schedule],
);

await blocker.createProfile(profile);

// Activate (only one profile can be active at a time)
await blocker.activateProfile('work-mode');

// Get active profile
final active = await blocker.getActiveProfile();

// Deactivate
await blocker.deactivateProfile('work-mode');

// List all profiles
final profiles = await blocker.getProfiles();

// Delete
await blocker.deleteProfile('work-mode');
```

### Overlay Configuration (Android Only)

```dart
await blocker.setOverlayConfig(
  const OverlayConfig(
    title: 'Stay Focused!',
    subtitle: 'This app is blocked',
    message: 'Get back to work.',
    backgroundColor: Color(0xDD000000),
    iconAssetPath: 'assets/icons/lock.png',
  ),
);
```

> On iOS, the system Screen Time Shield is used instead and cannot be customized.

## API Reference

See the full [API documentation on pub.dev](https://pub.dev/documentation/app_blocker/latest/).

## Platform-Specific Notes

### Android

- Uses a foreground service with `UsageStatsManager` to detect foreground apps.
- Shows a `TYPE_APPLICATION_OVERLAY` window over blocked apps.
- Schedules are implemented with `AlarmManager` for precise timing.
- Block state persists across reboots via `RECEIVE_BOOT_COMPLETED`.
- Requires `minSdkVersion 24` (Android 7.0 Nougat).

### iOS

- Uses the Screen Time API (`FamilyControls`, `ManagedSettings`, `DeviceActivityMonitor`).
- App selection is done via the native `FamilyActivityPicker` — apps are represented by opaque tokens, not bundle identifiers.
- Shields are managed by `ManagedSettingsStore` and survive app termination.
- Schedules use `DeviceActivitySchedule` (iOS 16+) or `UserDefaults` persistence with background refresh (iOS 15).
- Requires the **Family Controls** entitlement and user authorization.

## License

MIT License. See [LICENSE](LICENSE) for details.
