package com.khanhtq.app_blocker.blocking

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class OverlayManager(private val context: Context) {

    private var overlayView: View? = null
    private val windowManager: WindowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    var isShowing: Boolean = false
        private set

    private var title: String = "App Blocked"
    private var subtitle: String = "This app is currently blocked."
    private var message: String = ""
    private var backgroundColor: Int = Color.parseColor("#CC000000")

    fun showOverlay() {
        if (isShowing) return

        val rootLayout = FrameLayout(context).apply {
            setBackgroundColor(backgroundColor)
        }

        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        val contentParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            gravity = Gravity.CENTER
            val horizontalMargin = dpToPx(32f).toInt()
            setMargins(horizontalMargin, 0, horizontalMargin, 0)
        }

        val titleView = TextView(context).apply {
            text = title
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        contentLayout.addView(
            titleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(12f).toInt()
            }
        )

        val subtitleView = TextView(context).apply {
            text = subtitle
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
        }
        contentLayout.addView(
            subtitleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dpToPx(8f).toInt()
            }
        )

        if (message.isNotEmpty()) {
            val messageView = TextView(context).apply {
                text = message
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                gravity = Gravity.CENTER
            }
            contentLayout.addView(
                messageView,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
        }

        rootLayout.addView(contentLayout, contentParams)

        @Suppress("ClickableViewAccessibility")
        rootLayout.setOnTouchListener { _, _ -> true }

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        try {
            windowManager.addView(rootLayout, params)
            overlayView = rootLayout
            isShowing = true
        } catch (e: Exception) {
            // Failed to add overlay, likely missing SYSTEM_ALERT_WINDOW permission
        }
    }

    fun hideOverlay() {
        if (!isShowing) return

        try {
            overlayView?.let { windowManager.removeView(it) }
        } catch (e: Exception) {
            // View may have already been removed
        }

        overlayView = null
        isShowing = false
    }

    fun updateConfig(config: Map<String, Any?>) {
        config["title"]?.let { title = it as String }
        config["subtitle"]?.let { subtitle = it as String }
        config["message"]?.let { message = it as String }
        config["backgroundColor"]?.let { value ->
            backgroundColor = when (value) {
                is Int -> value
                is Long -> value.toInt()
                is String -> Color.parseColor(value)
                else -> backgroundColor
            }
        }

        if (isShowing) {
            hideOverlay()
            showOverlay()
        }
    }

    private fun dpToPx(dp: Float): Float {
        return dp * context.resources.displayMetrics.density
    }
}
