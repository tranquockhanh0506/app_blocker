package com.khanhtq.app_blocker.blocking

import android.accessibilityservice.AccessibilityService
import android.content.pm.ApplicationInfo
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import com.khanhtq.app_blocker.event.BlockEventStreamHandler
import com.khanhtq.app_blocker.persistence.BlockerPreferences

/**
 * Accessibility service that detects foreground app changes and triggers the
 * overlay when a blocked app comes to the foreground.
 *
 * **Battery efficiency:** This service replaces the previous 200 ms polling loop.
 * Instead of querying UsageStatsManager on a timer, we react to
 * [AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED] events which are fired by the
 * Android system exactly when the foreground window changes — zero idle CPU cost.
 *
 * **Setup:** The user must enable this service in
 * Settings → Accessibility → App Blocker. [PermissionManager.checkAccessibilityPermission]
 * checks whether it is enabled, and [PermissionManager.requestAccessibilityPermission]
 * opens the system settings page.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        /** Events we care about — window transitions only. */
        private const val TARGET_EVENTS =
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED

        /** System packages we never want to block. */
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"
    }

    private lateinit var overlayManager: OverlayManager
    private lateinit var preferences: BlockerPreferences

    /**
     * Last package seen in the foreground. Used to skip duplicate events for
     * the same app — the accessibility subsystem fires multiple events per
     * window transition.
     */
    @Volatile
    private var lastPackage: String = ""

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    override fun onServiceConnected() {
        super.onServiceConnected()
        overlayManager = OverlayManager(this)
        preferences = BlockerPreferences(this)
    }

    override fun onInterrupt() {
        // Required override; hide the overlay so it doesn't get stuck.
        overlayManager.hideOverlay()
    }

    override fun onDestroy() {
        overlayManager.hideOverlay()
        super.onDestroy()
    }

    // ------------------------------------------------------------------
    // Event handling
    // ------------------------------------------------------------------

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if ((event.eventType and TARGET_EVENTS) == 0) return

        val packageName = event.packageName?.toString() ?: return

        // Skip our own package, system UI, and repeated events for the same app.
        if (packageName == this.packageName ||
            packageName == SYSTEM_UI_PACKAGE ||
            packageName == lastPackage
        ) return

        lastPackage = packageName
        checkAndBlock(packageName)
    }

    // ------------------------------------------------------------------
    // Blocking logic
    // ------------------------------------------------------------------

    private fun checkAndBlock(packageName: String) {
        if (!preferences.isBlocking()) {
            overlayManager.hideOverlay()
            return
        }

        val shouldBlock = when {
            preferences.isBlockAll() -> isUserApp(packageName)
            else -> preferences.getBlockedApps().contains(packageName)
        }

        if (shouldBlock) {
            overlayManager.updateConfig(loadOverlayConfig())
            overlayManager.showOverlay()
            BlockEventStreamHandler.sendEvent(
                mapOf(
                    "type" to "attemptedAccess",
                    "packageName" to packageName,
                    "timestamp" to System.currentTimeMillis(),
                )
            )
        } else {
            overlayManager.hideOverlay()
        }
    }

    /**
     * Reads the persisted overlay config JSON and converts it to a map
     * that [OverlayManager.updateConfig] can consume.
     */
    private fun loadOverlayConfig(): Map<String, Any?> {
        return try {
            val obj = org.json.JSONObject(preferences.overlayConfig)
            buildMap {
                if (obj.has("title") && !obj.isNull("title")) put("title", obj.getString("title"))
                if (obj.has("subtitle") && !obj.isNull("subtitle")) put("subtitle", obj.getString("subtitle"))
                if (obj.has("message") && !obj.isNull("message")) put("message", obj.getString("message"))
                if (obj.has("backgroundColor") && !obj.isNull("backgroundColor")) put("backgroundColor", obj.getLong("backgroundColor"))
            }
        } catch (_: Exception) {
            emptyMap()
        }
    }

    /**
     * Returns true if [packageName] belongs to a user-installed app (not a
     * system app). Used when blocking all apps to avoid blocking system components.
     */
    private fun isUserApp(packageName: String): Boolean {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    android.content.pm.PackageManager.ApplicationInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0
        } catch (_: Exception) {
            false
        }
    }
}
