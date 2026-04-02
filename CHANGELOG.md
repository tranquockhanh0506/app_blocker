## 2.0.0

### ⚠️ Breaking Changes

**General:**
- getBlockedApps() now returns a list of all currently blocked app IDs, including those blocked by schedules and profiles (previously only directly blocked apps).
- unblockAll() now also deactivates any active profile and disables all schedules (otherwise leads to inconsistent state with all apps unblocked but potentially active schedules/profiles).

**Android:**
- Replaced foreground service with AccessibilityService (better battery efficiency than polling)
- **Important:** Users must now enable Settings → Accessibility → App Blocker - checkPermission() and requestPermission() correctly handle this
- `FOREGROUND_SERVICE` and `PACKAGE_USAGE_STATS` permissions no longer needed, can be removed from AndroidManifest if manually added

**iOS:**
- Minimum version bumped to iOS 16.0
- App token format changed for stability
  - before (indexed: "app_token_0"): same id could refer to different apps
  - now (JWT: "eyJkXR..."): stable unique identifier for each app
  - APIs stay the same but old app tokens will no longer work if stored from previous versions

---

### Features
- Added `getOverlayConfig()` API
- New events: `profileActivated`, `profileDeactivated`
- Improved `getBlockedApps()` to include schedules and profiles

### Fixes
- Fixed custom Android overlay not working
- Fixed `SCHEDULE_EXACT_ALARM` permission not requested
- Fixed iOS token stability issues
- Fixed schedules not activating when enabled during active time
- Fixed schedules lost after app restart

### Changes
- Improved error handling in native code
- Clarified iOS schedule limitations in docs
- Extended example app to demonstrate all features

## 1.0.6

- Fix installation version in README

## 1.0.0

- Initial release
- Cross-platform app blocking (Android overlay + iOS Screen Time Shield)
- Permission management
- App discovery (Android installed apps list, iOS FamilyActivityPicker)
- Real-time blocking events via Stream
- Customizable overlay (Android)
- Schedule-based blocking with AlarmManager (Android) and UserDefaults (iOS)
- Focus profiles for grouping blocked apps and schedules
- Boot persistence (Android)
