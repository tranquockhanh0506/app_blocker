/// Cross-platform app blocking plugin for Flutter.
///
/// Block applications on Android (overlay) and iOS (Screen Time Shield).
/// Supports scheduling, focus profiles, and real-time blocking events.
library app_blocker;

export 'src/app_blocker.dart';
export 'src/app_blocker_platform_interface.dart';
export 'src/exceptions/app_blocker_exception.dart';
export 'src/models/app_info.dart';
export 'src/models/block_event.dart';
export 'src/models/block_status.dart';
export 'src/models/blocker_capabilities.dart';
export 'src/models/overlay_config.dart';
export 'src/models/permission_status.dart';
export 'src/models/profile.dart';
export 'src/models/schedule.dart';
