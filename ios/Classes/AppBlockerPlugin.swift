import Flutter
import UIKit

public class AppBlockerPlugin: NSObject, FlutterPlugin {
    // Store managers as instance properties, NOT global
    private var permissionManager: AnyObject?
    var shieldManager: AnyObject?
    private var activityPickerCoordinator: AnyObject?
    private var scheduleManager: AnyObject?
    private var profileManager: AnyObject?
    private var eventStreamHandler: BlockEventStreamHandler?

    // Shared instance for callbacks
    static var shared: AppBlockerPlugin?

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

        // Initialize managers with availability checks
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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getCapabilities":
            handleGetCapabilities(result: result)
        case "checkPermission":
            handleCheckPermission(result: result)
        case "requestPermission":
            handleRequestPermission(result: result)
        case "getApps":
            handleGetApps(result: result)
        case "blockApps":
            handleBlockApps(call: call, result: result)
        case "blockAll":
            handleBlockAll(result: result)
        case "unblockApps":
            handleUnblockApps(call: call, result: result)
        case "unblockAll":
            handleUnblockAll(result: result)
        case "getBlockedApps":
            handleGetBlockedApps(result: result)
        case "getAppStatus":
            handleGetAppStatus(call: call, result: result)
        case "setOverlayConfig":
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "Overlay configuration is not supported on iOS. Use system shield instead.",
                details: nil
            ))
        case "addSchedule":
            handleAddSchedule(call: call, result: result)
        case "updateSchedule":
            handleUpdateSchedule(call: call, result: result)
        case "removeSchedule":
            handleRemoveSchedule(call: call, result: result)
        case "getSchedules":
            handleGetSchedules(result: result)
        case "enableSchedule":
            handleEnableSchedule(call: call, result: result)
        case "disableSchedule":
            handleDisableSchedule(call: call, result: result)
        case "createProfile":
            handleCreateProfile(call: call, result: result)
        case "updateProfile":
            handleUpdateProfile(call: call, result: result)
        case "deleteProfile":
            handleDeleteProfile(call: call, result: result)
        case "getProfiles":
            handleGetProfiles(result: result)
        case "activateProfile":
            handleActivateProfile(call: call, result: result)
        case "deactivateProfile":
            handleDeactivateProfile(call: call, result: result)
        case "getActiveProfile":
            handleGetActiveProfile(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Capabilities

    private func handleGetCapabilities(result: @escaping FlutterResult) {
        var canShowActivityPicker = false
        if #available(iOS 16.0, *) {
            canShowActivityPicker = true
        }

        let capabilities: [String: Any] = [
            "canBlockApps": true,
            "canShowOverlay": false,
            "canUseSystemShield": true,
            "canSchedule": true,
            "canGetInstalledApps": false,
            "canShowActivityPicker": canShowActivityPicker,
        ]
        result(capabilities)
    }

    // MARK: - Permissions

    private func handleCheckPermission(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let manager = permissionManager as? PermissionManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Permission manager not initialized.",
                    details: nil
                ))
                return
            }
            result(manager.checkPermission())
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "FamilyControls authorization requires iOS 16.0 or later.",
                details: nil
            ))
        }
    }

    private func handleRequestPermission(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let manager = permissionManager as? PermissionManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Permission manager not initialized.",
                    details: nil
                ))
                return
            }
            manager.requestPermission(result: result)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "FamilyControls authorization requires iOS 16.0 or later.",
                details: nil
            ))
        }
    }

    // MARK: - App Discovery

    private func handleGetApps(result: @escaping FlutterResult) {
        if #available(iOS 16.0, *) {
            guard let coordinator = activityPickerCoordinator as? ActivityPickerCoordinator else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Activity picker coordinator not initialized.",
                    details: nil
                ))
                return
            }
            guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Unable to find root view controller.",
                    details: nil
                ))
                return
            }
            coordinator.showPicker(from: rootViewController, result: result)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "FamilyActivityPicker requires iOS 16.0 or later.",
                details: nil
            ))
        }
    }

    // MARK: - Blocking

    private func handleBlockApps(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let identifiers = args["identifiers"] as? [String] else {
                result(FlutterError(
                    code: "INVALID_CONFIG",
                    message: "Missing 'identifiers' argument.",
                    details: nil
                ))
                return
            }
            shield.blockApps(identifiers: identifiers)
            eventStreamHandler?.sendEvent(type: "blocked", packageName: identifiers.first, scheduleId: nil)
            result(nil)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    private func handleBlockAll(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            shield.blockAll()
            eventStreamHandler?.sendEvent(type: "blocked", packageName: nil, scheduleId: nil)
            result(nil)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    private func handleUnblockApps(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let identifiers = args["identifiers"] as? [String] else {
                result(FlutterError(
                    code: "INVALID_CONFIG",
                    message: "Missing 'identifiers' argument.",
                    details: nil
                ))
                return
            }
            shield.unblockApps(identifiers: identifiers)
            eventStreamHandler?.sendEvent(type: "unblocked", packageName: identifiers.first, scheduleId: nil)
            result(nil)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    private func handleUnblockAll(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            shield.unblockAll()
            eventStreamHandler?.sendEvent(type: "unblocked", packageName: nil, scheduleId: nil)
            result(nil)
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    private func handleGetBlockedApps(result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            result(shield.getBlockedApps())
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    private func handleGetAppStatus(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 15.0, *) {
            guard let shield = shieldManager as? ShieldManager else {
                result(FlutterError(
                    code: "SERVICE_UNAVAILABLE",
                    message: "Shield manager not initialized.",
                    details: nil
                ))
                return
            }
            guard let args = call.arguments as? [String: Any],
                  let identifier = args["identifier"] as? String else {
                result(FlutterError(
                    code: "INVALID_CONFIG",
                    message: "Missing 'identifier' argument.",
                    details: nil
                ))
                return
            }
            let blockedApps = shield.getBlockedApps()
            if blockedApps.contains(identifier) {
                result("blocked")
            } else {
                // Check if the app is in a schedule
                if let scheduleManager = self.scheduleManager as? ScheduleManager {
                    let schedules = scheduleManager.getSchedules()
                    let isScheduled = schedules.contains { schedule in
                        let enabled = schedule["enabled"] as? Bool ?? false
                        let appIds = schedule["appIdentifiers"] as? [String] ?? []
                        return enabled && appIds.contains(identifier)
                    }
                    result(isScheduled ? "scheduled" : "unblocked")
                } else {
                    result("unblocked")
                }
            }
        } else {
            result(FlutterError(
                code: "PLATFORM_UNSUPPORTED",
                message: "ManagedSettings requires iOS 15.0 or later.",
                details: nil
            ))
        }
    }

    // MARK: - Scheduling

    private func handleAddSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        guard let data = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Invalid schedule data.",
                details: nil
            ))
            return
        }
        manager.addSchedule(data: data)
        result(nil)
    }

    private func handleUpdateSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        guard let data = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Invalid schedule data.",
                details: nil
            ))
            return
        }
        manager.updateSchedule(data: data)
        result(nil)
    }

    private func handleRemoveSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let scheduleId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        manager.removeSchedule(id: scheduleId)
        result(nil)
    }

    private func handleGetSchedules(result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        result(manager.getSchedules())
    }

    private func handleEnableSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let scheduleId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        manager.enableSchedule(id: scheduleId)
        eventStreamHandler?.sendEvent(type: "scheduleActivated", packageName: nil, scheduleId: scheduleId)
        result(nil)
    }

    private func handleDisableSchedule(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = scheduleManager as? ScheduleManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Schedule manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let scheduleId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        manager.disableSchedule(id: scheduleId)
        eventStreamHandler?.sendEvent(type: "scheduleDeactivated", packageName: nil, scheduleId: scheduleId)
        result(nil)
    }

    // MARK: - Profiles

    private func handleCreateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        guard let data = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Invalid profile data.",
                details: nil
            ))
            return
        }
        manager.createProfile(data: data)
        result(nil)
    }

    private func handleUpdateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        guard let data = call.arguments as? [String: Any] else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Invalid profile data.",
                details: nil
            ))
            return
        }
        manager.updateProfile(data: data)
        result(nil)
    }

    private func handleDeleteProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let profileId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        manager.deleteProfile(id: profileId)
        result(nil)
    }

    private func handleGetProfiles(result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        result(manager.getProfiles())
    }

    private func handleActivateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let profileId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        let activated = manager.activateProfile(id: profileId)
        if activated {
            result(nil)
        } else {
            result(FlutterError(
                code: "PROFILE_NOT_FOUND",
                message: "Profile with id '\(profileId)' not found.",
                details: nil
            ))
        }
    }

    private func handleDeactivateProfile(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        guard let args = call.arguments as? [String: Any],
              let profileId = args["id"] as? String else {
            result(FlutterError(
                code: "INVALID_CONFIG",
                message: "Missing 'id' argument.",
                details: nil
            ))
            return
        }
        manager.deactivateProfile(id: profileId)
        result(nil)
    }

    private func handleGetActiveProfile(result: @escaping FlutterResult) {
        guard let manager = profileManager as? ProfileManager else {
            result(FlutterError(
                code: "SERVICE_UNAVAILABLE",
                message: "Profile manager not initialized.",
                details: nil
            ))
            return
        }
        result(manager.getActiveProfile())
    }
}
