package com.khanhtq.app_blocker

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings

/**
 * Manages Android permission checks and requests for overlay drawing
 * and usage-stats access.
 */
class PermissionManager(private val context: Context) {

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    /**
     * Returns the aggregate permission status.
     *
     * - "granted"    — both overlay and usage-stats permissions are granted.
     * - "restricted" — the device/OS version does not support the required APIs.
     * - "denied"     — one or more required permissions are missing.
     */
    fun checkAllPermissions(): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Overlay and usage-stats APIs behave differently pre-M; treat as granted.
            return "granted"
        }
        val overlay = checkOverlayPermission()
        val usage = checkUsageStatsPermission()
        return if (overlay && usage) "granted" else "denied"
    }

    /**
     * Requests all required permissions by opening the appropriate system
     * settings screens.  Returns the *current* status string after the
     * request intent has been fired (the user still needs to grant
     * permissions in the system UI).
     */
    fun requestAllPermissions(activity: Activity): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return "granted"
        }

        if (!checkOverlayPermission()) {
            requestOverlayPermission(activity)
            return "denied"
        }

        if (!checkUsageStatsPermission()) {
            requestUsageStatsPermission(activity)
            return "denied"
        }

        return "granted"
    }

    // ------------------------------------------------------------------
    // Overlay Permission
    // ------------------------------------------------------------------

    /**
     * Checks whether the app is allowed to draw overlays.
     */
    fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    /**
     * Opens the system "Display over other apps" settings page for this
     * application so the user can grant overlay permission.
     */
    fun requestOverlayPermission(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(activity)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            activity.startActivity(intent)
        }
    }

    // ------------------------------------------------------------------
    // Usage Stats Permission
    // ------------------------------------------------------------------

    /**
     * Checks whether the app has been granted usage-stats access.
     */
    fun checkUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Opens the system "Usage access" settings page so the user can grant
     * usage-stats permission.
     */
    fun requestUsageStatsPermission(activity: Activity) {
        if (!checkUsageStatsPermission()) {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            activity.startActivity(intent)
        }
    }
}
