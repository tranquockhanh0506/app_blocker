/// Channel and method name constants for platform communication.
class AppBlockerConstants {
  AppBlockerConstants._();

  /// The method channel name.
  static const String methodChannel = 'com.khanhtq.app_blocker/methods';

  /// The event channel name for block events.
  static const String eventChannel = 'com.khanhtq.app_blocker/events';

  // -- Method names --

  static const String getCapabilities = 'getCapabilities';
  static const String checkPermission = 'checkPermission';
  static const String requestPermission = 'requestPermission';
  static const String getApps = 'getApps';
  static const String blockApps = 'blockApps';
  static const String blockAll = 'blockAll';
  static const String unblockApps = 'unblockApps';
  static const String unblockAll = 'unblockAll';
  static const String getBlockedApps = 'getBlockedApps';
  static const String getAppStatus = 'getAppStatus';
  static const String setOverlayConfig = 'setOverlayConfig';
  static const String getOverlayConfig = 'getOverlayConfig';
  static const String addSchedule = 'addSchedule';
  static const String updateSchedule = 'updateSchedule';
  static const String removeSchedule = 'removeSchedule';
  static const String getSchedules = 'getSchedules';
  static const String enableSchedule = 'enableSchedule';
  static const String disableSchedule = 'disableSchedule';
  static const String createProfile = 'createProfile';
  static const String updateProfile = 'updateProfile';
  static const String deleteProfile = 'deleteProfile';
  static const String getProfiles = 'getProfiles';
  static const String activateProfile = 'activateProfile';
  static const String deactivateProfile = 'deactivateProfile';
  static const String getActiveProfile = 'getActiveProfile';

  // -- Error codes --

  static const String errorPermissionDenied = 'PERMISSION_DENIED';
  static const String errorPermissionRestricted = 'PERMISSION_RESTRICTED';
  static const String errorServiceUnavailable = 'SERVICE_UNAVAILABLE';
  static const String errorPlatformUnsupported = 'PLATFORM_UNSUPPORTED';
  static const String errorScheduleConflict = 'SCHEDULE_CONFLICT';
  static const String errorProfileNotFound = 'PROFILE_NOT_FOUND';
  static const String errorInvalidConfig = 'INVALID_CONFIG';
}
