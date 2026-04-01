# app_blocker

[![pub package](https://img.shields.io/pub/v/app_blocker.svg)](https://pub.dev/packages/app_blocker)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/tranquockhanh0506/app_blocker/blob/main/LICENSE)

A Flutter plugin to block apps on Android and iOS.

- **Android:** AccessibilityService + overlay window to detect and block apps
- **iOS:** Screen Time API
  - **FamilyControls** — request user authorization to manage Screen Time
  - **ManagedSettings** — apply shield restrictions on selected apps (required for blocking specific apps, not needed for `blockAll()`)

## Supported Functions

**Permissions & capabilities**
- `checkPermission()` — Check if required permissions are granted
- `requestPermission()` — Request permissions from user
- `getCapabilities()` — Check which features are available on the current platform

**App discovery**
- `getApps()` — List installed apps (Android) or show FamilyActivityPicker (iOS)

**Blocking**
- `blockApps(List<String>)` — Block specific apps
- `blockAll()` — Block all apps
- `unblockApps(List<String>)` — Unblock specific apps
- `unblockAll()` — Unblock all apps
- `getBlockedApps()` — List currently blocked app identifiers
- `getAppStatus(String)` — Get block status of a specific app
- `setOverlayConfig(OverlayConfig)` — Customize the block overlay (Android only)
- `getOverlayConfig()` — Get current overlay configuration (Android only)

**Schedules (Android only)**
- `addSchedule(BlockSchedule)` — Add a time-based blocking schedule
- `updateSchedule(BlockSchedule)` — Update an existing schedule
- `removeSchedule(String)` — Remove a schedule
- `getSchedules()` — List all schedules
- `enableSchedule(String)` — Enable a schedule
- `disableSchedule(String)` — Disable a schedule without removing it

**Profiles**
- `createProfile(BlockProfile)` — Create a profile grouping apps to block together
- `updateProfile(BlockProfile)` — Update an existing profile
- `deleteProfile(String)` — Delete a profile
- `getProfiles()` — List all profiles
- `activateProfile(String)` — Activate a profile (blocks its apps)
- `deactivateProfile(String)` — Deactivate a profile
- `getActiveProfile()` — Get the currently active profile

**Events**
- `onBlockEvent` — Stream of block/unblock/schedule events

## Platform Support

| Feature              | Android | iOS |
|----------------------|---------|-----|
| Block / Unblock apps | ✅      | ✅  |
| Block all apps       | ✅      | ✅  |
| Get installed apps   | ✅      | -   |
| Custom overlay       | ✅      | -   |
| Screen Time Shield   | -       | ✅  |
| Schedules            | ✅      | -   |
| Profiles             | ✅      | ✅  |
| Block events stream  | ✅      | ✅  |
| Boot persistence     | ✅      | -   |

## Installation

```yaml
dependencies:
  app_blocker: ^2.0.0
```

## Setup

### Android

**Minimum SDK:** 24 (Android 7.0)

No additional setup required. The plugin automatically adds these permissions:

- `SCHEDULE_EXACT_ALARM` — Time-based blocking (requires `requestPermission()`, might get auto-granted on Android 12 & 13 ([source](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)))
- `QUERY_ALL_PACKAGES` — List installed apps
- `RECEIVE_BOOT_COMPLETED` — Restore schedules after reboot

During runtime, by calling `requestPermission()`, the user will be prompted to grant:
- SCHEDULE_EXACT_ALARM (if not auto-granted)
- Accessibility Service permission (opens system settings)

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
// must be called multiple times on Android until all permissions are granted
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

### Schedules (Android only)

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

> **Note:** Scheduling is not supported on iOS (`canSchedule` returns `false`). iOS lacks the background execution mechanism needed to enforce time-based blocking reliably without the DeviceActivity framework (not yet integrated).

### Profiles

```dart
// Create a profile grouping apps to block together
await blocker.createProfile(BlockProfile(
  id: 'social-media',
  name: 'Social Media',
  appIdentifiers: ['com.instagram.android', 'com.twitter.android'],
));

// Activate (blocks the profile's apps); deactivates any previously active profile
await blocker.activateProfile('social-media');
await blocker.deactivateProfile('social-media');

final profiles = await blocker.getProfiles();
final active = await blocker.getActiveProfile(); // null if none active
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
