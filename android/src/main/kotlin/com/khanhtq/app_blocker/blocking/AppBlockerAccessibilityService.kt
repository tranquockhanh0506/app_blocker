package com.khanhtq.app_blocker.blocking

import android.accessibilityservice.AccessibilityService
import android.content.pm.ApplicationInfo
import android.os.Build
import android.util.Log
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
        private const val TAG = "AppBlockerService"

        /** Events we care about — window transitions and content changes. */
        private const val TARGET_EVENTS =
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED

        /** System packages we never want to block. */
        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"

        /**
         * Grace period after the host app's own window fires a
         * TYPE_WINDOW_STATE_CHANGED event. Blocked-app events that arrive within
         * this window are treated as spurious dismiss-events (Android fires
         * TYPE_WINDOW_STATE_CHANGED for a blocked app's window while it is being
         * animated out of the recents overview) and suppressed.
         *
         * Best-effort heuristic — no guaranteed correct value exists.
         */
        private const val OWN_PACKAGE_GRACE_MS = 500L
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

    /**
     * Timestamp of the last TYPE_WINDOW_STATE_CHANGED event from our own package.
     * Updated when the host app comes to the foreground or when the overlay is
     * shown/hidden (Android fires one for any window owned by this process).
     * Used to suppress spurious blocked-app events during recents navigation
     * (see [OWN_PACKAGE_GRACE_MS]).
     */
    @Volatile
    private var lastOwnPackageEventTime: Long = 0L

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

        val packageName = event.packageName?.toString() ?: return

        if ((event.eventType and TARGET_EVENTS) == 0) {
            Log.v(TAG, "SKIP (type=${AccessibilityEvent.eventTypeToString(event.eventType)}) pkg=$packageName")
            return
        }

        if (packageName == SYSTEM_UI_PACKAGE) {
            Log.v(TAG, "SKIP (systemui) pkg=$packageName")
            return
        }

        // Overlay windows owned by this process fire TYPE_WINDOW_STATE_CHANGED with
        // our own package. Processing them as a foreground change would immediately
        // hide the overlay we just showed (infinite show/hide loop). Record the
        // timestamp instead so we can filter the spurious blocked-app event that
        // follows during recents navigation (see checkAndBlock).
        if (packageName == this.packageName) {
            lastOwnPackageEventTime = System.currentTimeMillis()
            Log.v(TAG, "SKIP (own package) pkg=$packageName")
            return
        }

        if (packageName == lastPackage) {
            Log.v(TAG, "SKIP (duplicate) pkg=$packageName")
            return
        }

        Log.d(TAG, "EVENT pkg=$packageName lastPkg=$lastPackage overlayShowing=${overlayManager.isShowing}")
        lastPackage = packageName
        checkAndBlock(packageName)
    }

    // ------------------------------------------------------------------
    // Blocking logic
    // ------------------------------------------------------------------

    private fun checkAndBlock(packageName: String) {
        if (!preferences.isBlocking()) {
            Log.d(TAG, "checkAndBlock: blocking inactive pkg=$packageName")
            overlayManager.hideOverlay()
            return
        }

        val blockAll = preferences.isBlockAll()
        val blockedApps = preferences.getBlockedApps()
        val shouldBlock = when {
            blockAll -> isUserApp(packageName)
            else -> blockedApps.contains(packageName)
        }

        Log.d(TAG, "checkAndBlock: pkg=$packageName blockAll=$blockAll blockedApps=$blockedApps shouldBlock=$shouldBlock")

        if (shouldBlock) {
            // When navigating to the host app via recents while the overlay is visible,
            // Android fires our own-package event (filtered above, so lastPackage is not
            // updated) then immediately a blocked-app event as that window animates out.
            // Suppress it if the overlay is already hidden and a recent own-package event
            // was seen — it's a spurious recents-dismiss, not a real foreground change.
            if (!overlayManager.isShowing) {
                val elapsed = System.currentTimeMillis() - lastOwnPackageEventTime
                if (elapsed < OWN_PACKAGE_GRACE_MS) {
                    Log.d(TAG, "checkAndBlock: SKIP spurious dismiss pkg=$packageName (${elapsed}ms after own-package event)")
                    return
                }
            }

            overlayManager.updateConfig(loadOverlayConfig())
            overlayManager.showOverlay()
            Log.d(TAG, "checkAndBlock: SHOW pkg=$packageName")
            BlockEventStreamHandler.sendEvent(
                mapOf(
                    "type" to "attemptedAccess",
                    "packageName" to packageName,
                    "timestamp" to System.currentTimeMillis(),
                )
            )
        } else {
            overlayManager.hideOverlay()
            Log.d(TAG, "checkAndBlock: HIDE pkg=$packageName")
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
