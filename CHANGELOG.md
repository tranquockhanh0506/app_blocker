## 2.0.7

- Remove badges from README

## 2.0.6

- Use `^2.0.0` in README installation for forward-compatible versioning

## 2.0.5

- Update LICENSE copyright year to 2024-2026

## 2.0.4

- Fix LICENSE badge link in README (main → master)

## 2.0.3

- Update installation version in README

## 2.0.2

- Add pub.dev topics for better discoverability
- Improve README structure with Features, Getting Started, and Additional Information sections
- Add pub points, popularity, and likes badges
- Add dartdoc comments to all public constants
- Enable `public_member_api_docs` lint rule

## 2.0.1

- Shorten package description to meet pub.dev guidelines

## 2.0.0

### ⚠️ Breaking Changes

**General:**
- getBlockedApps() now returns a list of all currently blocked app IDs, including those blocked by schedules and profiles (previously only directly blocked apps).
- unblockAll() now also deactivates any active profile and disables all schedules (otherwise leads to inconsistent state with all apps unblocked but potentially active schedules/profiles).
- Capability `canShowOverlay` renamed to `canCustomizeBlockScreen` in `BlockerCapabilities`.

**Android:**
- Replaced foreground service with AccessibilityService (better battery efficiency than polling)
- **Important:** Users must now enable Settings → Accessibility → App Blocker - checkPermission() and requestPermission() correctly handle this
- `FOREGROUND_SERVICE`, `PACKAGE_USAGE_STATS`, and `SYSTEM_ALERT_WINDOW` permissions no longer needed, can be removed from AndroidManifest if manually added
- Replaced overlay window with a normal Android Activity for the block screen (needed for robust behavior with AccessibilityService-based approach) `SYSTEM_ALERT_WINDOW` permission no longer required
- `setOverlayConfig()`/`getOverlayConfig()` renamed to `setBlockScreenConfig()`/`getBlockScreenConfig()`; `OverlayConfig` renamed to `BlockScreenConfig`.

**iOS:**
- Minimum version bumped to iOS 16.0
- App token format changed for stability
  - before (indexed: "app_token_0"): same id could refer to different apps
  - now (JWT: "eyJkXR..."): stable unique identifier for each app
  - APIs stay the same but old app tokens will no longer work if stored from previous versions

---

### Features
- Added `getBlockScreenConfig()` API
- New events: `profileActivated`, `profileDeactivated`
- Improved `getBlockedApps()` to include schedules and profiles

### Fixes
- Fixed custom Android block screen config not being applied
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
