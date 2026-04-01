import Flutter
import UIKit

/// Flutter plugin entry-point for app_blocker on iOS.
///
/// Managers that require newer iOS versions are stored as `AnyObject?` because
/// Swift does not allow properties annotated with `@available` at the class
/// level when the class itself targets an earlier deployment target. Each usage
/// site casts back to the concrete type inside an `#available` check, so the
/// cast is always safe at runtime.
public class AppBlockerPlugin: NSObject, FlutterPlugin {

    // Managers typed as AnyObject? due to @available constraints; see class doc.
    private var permissionManager: AnyObject?   // PermissionManager  (iOS 16+)
    var shieldManager: AnyObject?               // ShieldManager      (iOS 15+)
    private var activityPickerCoordinator: AnyObject? // ActivityPickerCoordinator (iOS 16+)
    private var scheduleManager: AnyObject?     // ScheduleManager    (iOS 15+)
    private var profileManager: AnyObject?      // ProfileManager     (iOS 15+)
    private var eventStreamHandler: BlockEventStreamHandler?

    /// Shared instance exposed to `ActivityPickerCoordinator` for callbacks.
    static var shared: AppBlockerPlugin?

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.khanhtq.app_blocker/methods",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.khanhtq.app_blocker/events",
            binaryMessenger: registrar.messenger()
        )

        let instance = AppBlockerPlugin()
        AppBlockerPlugin.shared = instance

        if #available(iOS 15.0, *) {
            let shield = ShieldManager()
            instance.shieldManager = shield
            instance.scheduleManager = ScheduleManager()
            instance.profileManager = ProfileManager(shieldManager: shield)
        }
        if #available(iOS 16.0, *) {
            instance.permissionManager = PermissionManager()
            instance.activityPickerCoordinator = ActivityPickerCoordinator()
        }

        instance.eventStreamHandler = BlockEventStreamHandler()
        eventChannel.setStreamHandler(instance.eventStreamHandler)

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method dispatch

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCapabilities":     handleGetCapabilities(result: result)
        case "checkPermission":     handleCheckPermission(result: result)
        case "requestPermission":   handleRequestPermission(result: result)
        case "getApps":             handleGetApps(result: result)
        case "blockApps":           handleBlockApps(call: call, result: result)
        case "blockAll":            handleBlockAll(result: result)
        case "unblockApps":         handleUnblockApps(call: call, result: result)
        case "unblockAll":          handleUnblockAll(result: result)
        case "getBlockedApps":      handleGetBlockedApps(result: result)
        case "getAppStatus":        handleGetAppStatus(call: call, result: result)
        case "setOverlayConfig":
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "Overlay configuration is not supported on iOS.",
                details: nil
            ))
        case "addSchedule":         handleAddSchedule(call: call, result: result)
        case "updateSchedule":      handleUpdateSchedule(call: call, result: result)
        case "removeSchedule":      handleRemoveSchedule(call: call, result: result)
        case "getSchedules":        handleGetSchedules(result: result)
        case "enableSchedule":      handleEnableSchedule(call: call, result: result)
        case "disableSchedule":     handleDisableSchedule(call: call, result: result)
        case "createProfile":       handleCreateProfile(call: call, result: result)
        case "updateProfile":       handleUpdateProfile(call: call, result: result)
        case "deleteProfile":       handleDeleteProfile(call: call, result: result)
        case "getProfiles":         handleGetProfiles(result: result)
        case "activateProfile":     handleActivateProfile(call: call, result: result)
        case "deactivateProfile":   handleDeactivateProfile(call: call, result: result)
        case "getActiveProfile":    handleGetActiveProfile(result: result)
        default:                    result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Capabilities

    private func handleGetCapabilities(result: @escaping FlutterResult) {
        result([
            "canBlockApps": true,
            "canShowOverlay": false,
            "canUseSystemShield": true,
            "canSchedule": false,
            "canGetInstalledApps": false,
            "canShowActivityPicker": {
                if #available(iOS 16.0, *) { return true }
                return false
            }(),
        ] as [String: Any])
    }

    // MARK: - Permissions

    private func handleCheckPermission(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let manager = permissionManager as? PermissionManager else {
                return result(unavailableError("Permission manager"))
            }
            result(manager.checkPermission())
        } else {
            result(ios16Required())
        }
    }

    private func handleRequestPermission(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let manager = permissionManager as? PermissionManager else {
                return result(unavailableError("Permission manager"))
            }
            manager.requestPermission(result: result)
        } else {
            result(ios16Required())
        }
    }

    // MARK: - App Discovery

    private func handleGetApps(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let coordinator = activityPickerCoordinator as? ActivityPickerCoordinator else {
                return result(unavailableError("Activity picker coordinator"))
            }
            guard let rootVC = Self.findRootViewController() else {
                return result(unavailableError("Root view controller"))
            }
            coordinator.showPicker(from: rootVC, result: result)
        } else {
            result(ios16Required())
        }
    }

    // MARK: - Blocking

    private func handleBlockApps(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            guard let args = call.arguments as? [String: Any],
                  let identifiers = args["identifiers"] as? [String] else {
                return result(invalidConfigError("Missing 'identifiers' argument."))
            }
            shield.blockApps(identifiers: identifiers)
            eventStreamHandler?.sendEvent(type: "blocked", packageName: identifiers.first, scheduleId: nil)
            result(nil)
        } else {
            result(ios15Required())
        }
    }

    private func handleBlockAll(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            shield.blockAll()
            eventStreamHandler?.sendEvent(type: "blocked", packageName: nil, scheduleId: nil)
            result(nil)
        } else {
            result(ios15Required())
        }
    }

    private func handleUnblockApps(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            guard let args = call.arguments as? [String: Any],
                  let identifiers = args["identifiers"] as? [String] else {
                return result(invalidConfigError("Missing 'identifiers' argument."))
            }
            shield.unblockApps(identifiers: identifiers)
            eventStreamHandler?.sendEvent(type: "unblocked", packageName: identifiers.first, scheduleId: nil)
            result(nil)
        } else {
            result(ios15Required())
        }
    }

    private func handleUnblockAll(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            shield.unblockAll()
            eventStreamHandler?.sendEvent(type: "unblocked", packageName: nil, scheduleId: nil)
            result(nil)
        } else {
            result(ios15Required())
        }
    }

    private func handleGetBlockedApps(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            result(shield.getBlockedApps())
        } else {
            result(ios15Required())
        }
    }

    private func handleGetAppStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                return result(unavailableError("Shield manager"))
            }
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                return result(invalidConfigError("Missing 'identifier' argument."))
            }
            let blocked = shield.getBlockedApps()
            if blocked.contains(identifier) {
                result("blocked")
            } else if let schedMgr = scheduleManager as? ScheduleManager {
                let isScheduled = schedMgr.getSchedules().contains { schedule in
                    (schedule["enabled"] as? Bool == true) &&
                    (schedule["appIdentifiers"] as? [String] ?? []).contains(identifier)
                }
                result(isScheduled ? "scheduled" : "unblocked")
            } else {
                result("unblocked")
            }
        } else {
            result(ios15Required())
        }
    }

    // MARK: - Scheduling (unsupported on iOS)
    // Schedule enforcement requires time-based background wakeups that are not
    // available without the DeviceActivity framework. All schedule methods return
    // PLATFORM_UNSUPPORTED. Check canSchedule via getCapabilities() before use.

    private func schedulingUnsupportedError() -> FlutterError {
        FlutterError(
            code: "PLATFORM_UNSUPPORTED",
            message: "Schedule-based blocking is not supported on iOS.",
            details: nil
        )
    }

    private func handleAddSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    private func handleUpdateSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    private func handleRemoveSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    private func handleGetSchedules(result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    private func handleEnableSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    private func handleDisableSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(schedulingUnsupportedError())
    }

    // MARK: - Profiles

    private func handleCreateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        guard let data = call.arguments as? [String: Any] else {
            return result(invalidConfigError("Invalid profile data."))
        }
        manager.createProfile(data: data)
        result(nil)
    }

    private func handleUpdateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        guard let data = call.arguments as? [String: Any] else {
            return result(invalidConfigError("Invalid profile data."))
        }
        manager.updateProfile(data: data)
        result(nil)
    }

    private func handleDeleteProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
            return result(invalidConfigError("Missing 'id' argument."))
        }
        manager.deleteProfile(id: id)
        result(nil)
    }

    private func handleGetProfiles(result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        result(manager.getProfiles())
    }

    private func handleActivateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
            return result(invalidConfigError("Missing 'id' argument."))
        }
        // Capture app identifiers before activating so we can emit per-app blocked events.
        let appIdentifiers = (manager.getProfiles()
            .first { ($0["id"] as? String) == id }?["appIdentifiers"] as? [String]) ?? []
        if manager.activateProfile(id: id) {
            for identifier in appIdentifiers {
                eventStreamHandler?.sendEvent(type: "blocked", packageName: identifier, scheduleId: nil, profileId: id)
            }
            eventStreamHandler?.sendEvent(type: "profileActivated", packageName: nil, scheduleId: nil, profileId: id)
            result(nil)
        } else {
            result(FlutterError(
                code: "PROFILE_NOT_FOUND",
                message: "Profile '\(id)' not found.",
                details: nil
            ))
        }
    }

    private func handleDeactivateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
            return result(invalidConfigError("Missing 'id' argument."))
        }
        // Capture app identifiers before deactivating so we can emit per-app unblocked events.
        let appIdentifiers = (manager.getProfiles()
            .first { ($0["id"] as? String) == id }?["appIdentifiers"] as? [String]) ?? []
        
        manager.deactivateProfile(id: id)
        
        for identifier in appIdentifiers {
            eventStreamHandler?.sendEvent(type: "unblocked", packageName: identifier, scheduleId: nil, profileId: id)
        }
        eventStreamHandler?.sendEvent(type: "profileDeactivated", packageName: nil, scheduleId: nil, profileId: id)
        result(nil)
    }

    private func handleGetActiveProfile(result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            return result(unavailableError("Profile manager"))
        }
        result(manager.getActiveProfile())
    }

    // MARK: - Error helpers

    private func unavailableError(_ component: String) -> FlutterError {
        FlutterError(
            code: "SERVICE_UNAVAILABLE",
            message: "\(component) is not available.",
            details: nil
        )
    }

    private func invalidConfigError(_ message: String) -> FlutterError {
        FlutterError(code: "INVALID_CONFIG", message: message, details: nil)
    }

    private func ios15Required() -> FlutterError {
        FlutterError(
            code: "PLATFORM_UNSUPPORTED",
            message: "ManagedSettings requires iOS 15.0 or later.",
            details: nil
        )
    }

    private func ios16Required() -> FlutterError {
        FlutterError(
            code: "PLATFORM_UNSUPPORTED",
            message: "FamilyControls authorization requires iOS 16.0 or later.",
            details: nil
        )
    }

    // MARK: - Utilities

    private static func findRootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .rootViewController
        } else {
            return UIApplication.shared.delegate?.window??.rootViewController
        }
    }
}
