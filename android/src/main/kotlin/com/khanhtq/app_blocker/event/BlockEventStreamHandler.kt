package com.khanhtq.app_blocker.event

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Singleton [EventChannel.StreamHandler] that allows any component (including
 * the blocking service) to push events to the Flutter side.
 *
 * Events are always dispatched on the main thread so that the Flutter
 * engine's [EventChannel.EventSink] is called from the correct looper.
 *
 * Supports two calling conventions:
 *
 * 1. **Instance-based** (preferred, from the plugin):
 *    ```
 *    BlockEventStreamHandler.instance.sendEvent("blocked", packageName = "com.example")
 *    ```
 *
 * 2. **Static map-based** (used by BlockingService and other components):
 *    ```
 *    BlockEventStreamHandler.sendEvent(mapOf("type" to "blocked", "packageName" to "com.example", "timestamp" to millis))
 *    ```
 */
class BlockEventStreamHandler private constructor() : EventChannel.StreamHandler {

    companion object {
        /** Single shared instance. */
        val instance: BlockEventStreamHandler by lazy { BlockEventStreamHandler() }

        private val mainHandler = Handler(Looper.getMainLooper())

        /**
         * Static convenience method for sending a pre-built event map.
         * Used by [com.khanhtq.app_blocker.blocking.BlockingService] and
         * other components that construct their own event maps.
         */
        @JvmStatic
        fun sendEvent(event: Map<String, Any?>) {
            val sink = instance.eventSink ?: return
            if (Looper.myLooper() == Looper.getMainLooper()) {
                sink.success(event)
            } else {
                mainHandler.post {
                    sink.success(event)
                }
            }
        }
    }

    private var eventSink: EventChannel.EventSink? = null

    // ------------------------------------------------------------------
    // StreamHandler
    // ------------------------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // ------------------------------------------------------------------
    // Instance-based API
    // ------------------------------------------------------------------

    /**
     * Sends a block event to the Flutter side.
     *
     * @param type        One of the [BlockEventType] name strings understood
     *                    by the Dart `BlockEventType.values.byName()` call:
     *                    `"blocked"`, `"unblocked"`, `"attemptedAccess"`,
     *                    `"scheduleActivated"`, `"scheduleDeactivated"`.
     * @param packageName The package name of the affected app, or `null`.
     * @param scheduleId  The schedule id that triggered this event, or `null`.
     */
    fun sendEvent(type: String, packageName: String? = null, scheduleId: String? = null) {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "packageName" to packageName,
            "scheduleId" to scheduleId,
            "timestamp" to System.currentTimeMillis(),
        )

        Companion.sendEvent(event)
    }
}
