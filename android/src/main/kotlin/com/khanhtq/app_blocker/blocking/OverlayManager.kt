package com.khanhtq.app_blocker.blocking

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Manages a full-screen system overlay that blocks interaction with the
 * underlying app when a blocked app is detected in the foreground.
 *
 * The overlay is created lazily on [showOverlay] and removed immediately on
 * [hideOverlay]. All methods must be called from the main thread; the
 * [com.khanhtq.app_blocker.blocking.AppBlockerAccessibilityService] satisfies
 * this because [android.view.accessibility.AccessibilityEvent] callbacks are
 * delivered on the main thread.
 *
 * **Requires** `SYSTEM_ALERT_WINDOW` permission.
 */
class OverlayManager(private val context: Context) {

    private var overlayView: FrameLayout? = null
    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    /** `true` while the overlay is attached to the window. */
    @Volatile
    var isShowing: Boolean = false
        private set

    private var title: String = "App Blocked"
    private var subtitle: String = "This app is currently blocked."
    private var message: String = ""
    private var backgroundColor: Int = Color.parseColor("#CC000000")

    // ------------------------------------------------------------------
    // Public API
    // ------------------------------------------------------------------

    /** Adds the overlay to the window if not already showing. */
    fun showOverlay() {
        if (isShowing) return

        val rootLayout = buildOverlayLayout()

        @Suppress("ClickableViewAccessibility")
        rootLayout.setOnTouchListener { _, _ -> true } // consume all touches

        try {
            windowManager.addView(rootLayout, buildLayoutParams())
            overlayView = rootLayout
            isShowing = true
        } catch (_: Exception) {
            // SYSTEM_ALERT_WINDOW not yet granted; silently no-op.
            // The permission check in PermissionManager should prevent
            // reaching this state under normal operation.
        }
    }

    /** Removes the overlay from the window if currently showing. */
    fun hideOverlay() {
        if (!isShowing) return
        try {
            overlayView?.let { windowManager.removeView(it) }
        } catch (_: Exception) {
            // View was already removed (e.g., process death). Safe to ignore.
        }
        overlayView = null
        isShowing = false
    }

    /**
     * Updates display properties from a config map and re-renders the overlay
     * if it is currently showing.
     *
     * Recognised keys: `"title"`, `"subtitle"`, `"message"`, `"backgroundColor"`.
     * `"backgroundColor"` may be an [Int], a [Long] (ARGB32), or a color string
     * parseable by [Color.parseColor].
     */
    fun updateConfig(config: Map<String, Any?>) {
        (config["title"] as? String)?.let { title = it }
        (config["subtitle"] as? String)?.let { subtitle = it }
        (config["message"] as? String)?.let { message = it }
        config["backgroundColor"]?.let { value ->
            backgroundColor = when (value) {
                is Int -> value
                is Long -> value.toInt()
                is String -> runCatching { Color.parseColor(value) }.getOrDefault(backgroundColor)
                else -> backgroundColor
            }
        }

        if (isShowing) {
            hideOverlay()
            showOverlay()
        }
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    private fun buildOverlayLayout(): FrameLayout {
        val root = FrameLayout(context).apply {
            setBackgroundColor(backgroundColor)
        }

        val content = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val horizontalMargin = dpToPx(32f).toInt()
        val contentParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            gravity = Gravity.CENTER
            setMargins(horizontalMargin, 0, horizontalMargin, 0)
        }

        content.addView(
            buildTextView(title, 28f, Typeface.BOLD),
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dpToPx(12f).toInt() }
        )

        content.addView(
            buildTextView(subtitle, 18f, Typeface.NORMAL),
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { bottomMargin = dpToPx(8f).toInt() }
        )

        if (message.isNotEmpty()) {
            content.addView(
                buildTextView(message, 14f, Typeface.NORMAL),
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                )
            )
        }

        root.addView(content, contentParams)
        return root
    }

    private fun buildTextView(text: String, spSize: Float, style: Int): TextView {
        return TextView(context).apply {
            this.text = text
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, spSize)
            setTypeface(null, style)
            gravity = Gravity.CENTER
        }
    }

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        )
    }

    private fun dpToPx(dp: Float): Float = dp * context.resources.displayMetrics.density
}
