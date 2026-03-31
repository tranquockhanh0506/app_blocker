package com.khanhtq.app_blocker.blocking

import android.content.Context
import com.khanhtq.app_blocker.event.BlockEventStreamHandler
import com.khanhtq.app_blocker.persistence.BlockerPreferences

/**
 * Manages the blocking state stored in [BlockerPreferences].
 *
 * With the accessibility-service architecture, there is no foreground service
 * to start or stop. [AppBlockerAccessibilityService] reads from [BlockerPreferences]
 * on every window-change event. This class is the single writer of that state,
 * ensuring all updates go through one place and emit the corresponding
 * [BlockEventStreamHandler] events to the Flutter side.
 */
class BlockingServiceManager(private val context: Context) {

    private val preferences = BlockerPreferences(context)

    // ------------------------------------------------------------------
    // Blocking
    // ------------------------------------------------------------------

    /**
     * Marks [packages] as blocked and enables the blocking gate.
     * Emits a `"blocked"` event for each package.
     */
    fun startBlocking(packages: List<String>) {
        preferences.setBlockedApps(packages.toSet())
        preferences.setIsBlocking(true)
        preferences.setBlockAll(false)

        val timestamp = System.currentTimeMillis()
        for (packageName in packages) {
            BlockEventStreamHandler.sendEvent(
                mapOf(
                    "type" to "blocked",
                    "packageName" to packageName,
                    "timestamp" to timestamp,
                )
            )
        }
    }

    /**
     * Enables "block all user apps" mode. The accessibility service will
     * block every non-system app that comes to the foreground.
     */
    fun startBlockingAll() {
        preferences.setIsBlocking(true)
        preferences.setBlockAll(true)
    }

    /**
     * Disables all blocking and clears the blocked-apps set.
     * Emits a single `"unblocked"` event.
     */
    fun stopBlocking() {
        preferences.setIsBlocking(false)
        preferences.setBlockAll(false)

        BlockEventStreamHandler.sendEvent(
            mapOf(
                "type" to "unblocked",
                "timestamp" to System.currentTimeMillis(),
            )
        )
    }

    /**
     * Removes [packages] from the blocked set. If the set becomes empty,
     * blocking is fully disabled.
     */
    fun stopBlockingApps(packages: List<String>) {
        val remaining = preferences.getBlockedApps().toMutableSet()
        remaining.removeAll(packages.toSet())
        preferences.setBlockedApps(remaining)

        if (remaining.isEmpty()) {
            preferences.setIsBlocking(false)
        }
    }

    // ------------------------------------------------------------------
    // Queries
    // ------------------------------------------------------------------

    /** Returns the current set of explicitly blocked package names. */
    fun getBlockedApps(): Set<String> = preferences.getBlockedApps()

    /** Returns `true` if the blocking gate is active. */
    fun isBlocking(): Boolean = preferences.isBlocking()
}
