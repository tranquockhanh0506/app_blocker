package com.khanhtq.app_blocker

import android.app.Activity
import android.content.Context
import com.khanhtq.app_blocker.blocking.BlockingServiceManager
import com.khanhtq.app_blocker.event.BlockEventStreamHandler
import com.khanhtq.app_blocker.persistence.BlockerPreferences
import com.khanhtq.app_blocker.scheduling.ProfileManager
import com.khanhtq.app_blocker.scheduling.ScheduleManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class AppBlockerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    companion object {
        private const val METHOD_CHANNEL = "com.khanhtq.app_blocker/methods"
        private const val EVENT_CHANNEL = "com.khanhtq.app_blocker/events"

        // Method names — must match Dart AppBlockerConstants exactly.
        private const val GET_CAPABILITIES = "getCapabilities"
        private const val CHECK_PERMISSION = "checkPermission"
        private const val REQUEST_PERMISSION = "requestPermission"
        private const val GET_APPS = "getApps"
        private const val BLOCK_APPS = "blockApps"
        private const val BLOCK_ALL = "blockAll"
        private const val UNBLOCK_APPS = "unblockApps"
        private const val UNBLOCK_ALL = "unblockAll"
        private const val GET_BLOCKED_APPS = "getBlockedApps"
        private const val GET_APP_STATUS = "getAppStatus"
        private const val SET_OVERLAY_CONFIG = "setOverlayConfig"
        private const val ADD_SCHEDULE = "addSchedule"
        private const val UPDATE_SCHEDULE = "updateSchedule"
        private const val REMOVE_SCHEDULE = "removeSchedule"
        private const val GET_SCHEDULES = "getSchedules"
        private const val ENABLE_SCHEDULE = "enableSchedule"
        private const val DISABLE_SCHEDULE = "disableSchedule"
        private const val CREATE_PROFILE = "createProfile"
        private const val UPDATE_PROFILE = "updateProfile"
        private const val DELETE_PROFILE = "deleteProfile"
        private const val GET_PROFILES = "getProfiles"
        private const val ACTIVATE_PROFILE = "activateProfile"
        private const val DEACTIVATE_PROFILE = "deactivateProfile"
        private const val GET_ACTIVE_PROFILE = "getActiveProfile"

        // Error codes — must match Dart AppBlockerConstants exactly.
        const val ERROR_PERMISSION_DENIED = "PERMISSION_DENIED"
        const val ERROR_SERVICE_UNAVAILABLE = "SERVICE_UNAVAILABLE"
        const val ERROR_SCHEDULE_CONFLICT = "SCHEDULE_CONFLICT"
        const val ERROR_PROFILE_NOT_FOUND = "PROFILE_NOT_FOUND"
        const val ERROR_INVALID_CONFIG = "INVALID_CONFIG"
    }

    // Channels
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel

    // Android references
    private lateinit var context: Context
    private var activity: Activity? = null

    // Managers
    private lateinit var permissionManager: PermissionManager
    private lateinit var appResolver: AppResolver
    private lateinit var blockingServiceManager: BlockingServiceManager
    private lateinit var scheduleManager: ScheduleManager
    private lateinit var profileManager: ProfileManager
    private lateinit var preferences: BlockerPreferences

    // Coroutine scope bound to the plugin lifecycle.
    private val job = Job()
    private val scope = CoroutineScope(Dispatchers.Default + job)

    // ---------------------------------------------------------------
    // FlutterPlugin
    // ---------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        preferences = BlockerPreferences(context)

        // Wire method channel.
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        // Wire event channel.
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(BlockEventStreamHandler.instance)

        // Instantiate managers.
        permissionManager = PermissionManager(context)
        appResolver = AppResolver(context)
        blockingServiceManager = BlockingServiceManager(context)
        scheduleManager = ScheduleManager(context)
        profileManager = ProfileManager(context)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        job.cancel()
    }

    // ---------------------------------------------------------------
    // ActivityAware
    // ---------------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ---------------------------------------------------------------
    // MethodCallHandler
    // ---------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            // -- Capabilities --

            GET_CAPABILITIES -> {
                val capabilities = mapOf(
                    "canBlockApps" to true,
                    "canShowOverlay" to true,
                    "canUseSystemShield" to false,
                    "canSchedule" to true,
                    "canGetInstalledApps" to true,
                    "canShowActivityPicker" to false,
                )
                result.success(capabilities)
            }

            // -- Permissions --

            CHECK_PERMISSION -> {
                val status = permissionManager.checkAllPermissions()
                result.success(status)
            }

            REQUEST_PERMISSION -> {
                val currentActivity = activity
                if (currentActivity == null) {
                    result.error(ERROR_SERVICE_UNAVAILABLE, "Activity is not available.", null)
                    return
                }
                val status = permissionManager.requestAllPermissions(currentActivity)
                result.success(status)
            }

            // -- App Discovery --

            GET_APPS -> {
                scope.launch {
                    try {
                        val apps = appResolver.getInstalledApps()
                        withContext(Dispatchers.Main) {
                            result.success(apps)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error(ERROR_SERVICE_UNAVAILABLE, e.message, null)
                        }
                    }
                }
            }

            // -- Blocking --

            BLOCK_APPS -> {
                val identifiers = call.argument<List<String>>("identifiers")
                if (identifiers == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'identifiers' argument.", null)
                    return
                }
                try {
                    blockingServiceManager.startBlocking(identifiers)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_SERVICE_UNAVAILABLE, e.message, null)
                }
            }

            BLOCK_ALL -> {
                try {
                    blockingServiceManager.startBlockingAll()
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_SERVICE_UNAVAILABLE, e.message, null)
                }
            }

            UNBLOCK_APPS -> {
                val identifiers = call.argument<List<String>>("identifiers")
                if (identifiers == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'identifiers' argument.", null)
                    return
                }
                blockingServiceManager.stopBlockingApps(identifiers)
                result.success(null)
            }

            UNBLOCK_ALL -> {
                blockingServiceManager.stopBlocking()
                result.success(null)
            }

            GET_BLOCKED_APPS -> {
                val apps = blockingServiceManager.getBlockedApps().toList()
                result.success(apps)
            }

            GET_APP_STATUS -> {
                val identifier = call.argument<String>("identifier")
                if (identifier == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'identifier' argument.", null)
                    return
                }
                val blocked = blockingServiceManager.getBlockedApps()
                val isBlockAll = preferences.isBlockAll()
                val isBlocking = preferences.isBlocking()

                val status = when {
                    isBlocking && isBlockAll -> "blocked"
                    isBlocking && blocked.contains(identifier) -> "blocked"
                    else -> "unblocked"
                }
                result.success(status)
            }

            // -- Overlay --

            SET_OVERLAY_CONFIG -> {
                val title = call.argument<String>("title")
                val subtitle = call.argument<String>("subtitle")
                val message = call.argument<String>("message")
                val backgroundColor = call.argument<Long>("backgroundColor")
                val iconAssetPath = call.argument<String>("iconAssetPath")

                val configMap = mutableMapOf<String, Any?>()
                configMap["title"] = title
                configMap["subtitle"] = subtitle
                configMap["message"] = message
                configMap["backgroundColor"] = backgroundColor
                configMap["iconAssetPath"] = iconAssetPath

                val gson = com.google.gson.Gson()
                preferences.overlayConfig = gson.toJson(configMap)
                result.success(null)
            }

            // -- Scheduling --

            ADD_SCHEDULE -> {
                @Suppress("UNCHECKED_CAST")
                val scheduleMap = call.arguments as? Map<String, Any?>
                if (scheduleMap == null) {
                    result.error(ERROR_INVALID_CONFIG, "Invalid schedule data.", null)
                    return
                }
                try {
                    scheduleManager.addSchedule(scheduleMap)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_SCHEDULE_CONFLICT, e.message, null)
                }
            }

            UPDATE_SCHEDULE -> {
                @Suppress("UNCHECKED_CAST")
                val scheduleMap = call.arguments as? Map<String, Any?>
                if (scheduleMap == null) {
                    result.error(ERROR_INVALID_CONFIG, "Invalid schedule data.", null)
                    return
                }
                try {
                    scheduleManager.updateSchedule(scheduleMap)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_SCHEDULE_CONFLICT, e.message, null)
                }
            }

            REMOVE_SCHEDULE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                scheduleManager.removeSchedule(id)
                result.success(null)
            }

            GET_SCHEDULES -> {
                val schedules = scheduleManager.getSchedules()
                result.success(schedules)
            }

            ENABLE_SCHEDULE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                scheduleManager.enableSchedule(id)
                result.success(null)
            }

            DISABLE_SCHEDULE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                scheduleManager.disableSchedule(id)
                result.success(null)
            }

            // -- Profiles --

            CREATE_PROFILE -> {
                @Suppress("UNCHECKED_CAST")
                val profileMap = call.arguments as? Map<String, Any?>
                if (profileMap == null) {
                    result.error(ERROR_INVALID_CONFIG, "Invalid profile data.", null)
                    return
                }
                try {
                    profileManager.createProfile(profileMap)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_INVALID_CONFIG, e.message, null)
                }
            }

            UPDATE_PROFILE -> {
                @Suppress("UNCHECKED_CAST")
                val profileMap = call.arguments as? Map<String, Any?>
                if (profileMap == null) {
                    result.error(ERROR_INVALID_CONFIG, "Invalid profile data.", null)
                    return
                }
                try {
                    profileManager.updateProfile(profileMap)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_PROFILE_NOT_FOUND, e.message, null)
                }
            }

            DELETE_PROFILE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                profileManager.deleteProfile(id)
                result.success(null)
            }

            GET_PROFILES -> {
                val profiles = profileManager.getProfiles()
                result.success(profiles)
            }

            ACTIVATE_PROFILE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                try {
                    profileManager.activateProfile(id)
                    result.success(null)
                } catch (e: Exception) {
                    result.error(ERROR_PROFILE_NOT_FOUND, e.message, null)
                }
            }

            DEACTIVATE_PROFILE -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error(ERROR_INVALID_CONFIG, "Missing 'id' argument.", null)
                    return
                }
                profileManager.deactivateProfile(id)
                result.success(null)
            }

            GET_ACTIVE_PROFILE -> {
                val profile = profileManager.getActiveProfile()
                result.success(profile)
            }

            else -> result.notImplemented()
        }
    }
}
