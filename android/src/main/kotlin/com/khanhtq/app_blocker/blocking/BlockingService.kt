package com.khanhtq.app_blocker.blocking

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.khanhtq.app_blocker.event.BlockEventStreamHandler
import com.khanhtq.app_blocker.persistence.BlockerPreferences

class BlockingService : Service() {

    companion object {
        const val CHANNEL_ID = "app_blocker_channel"
        const val NOTIFICATION_ID = 1001
        private const val POLLING_INTERVAL_MS = 200L
    }

    private lateinit var foregroundAppDetector: ForegroundAppDetector
    private lateinit var overlayManager: OverlayManager
    private lateinit var preferences: BlockerPreferences
    private val handler = Handler(Looper.getMainLooper())
    private var blockingRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        startForegroundImmediate()

        foregroundAppDetector = ForegroundAppDetector(this)
        overlayManager = OverlayManager(this)
        preferences = BlockerPreferences(this)

        startBlockingLoop()

        return START_STICKY
    }

    private fun startForegroundImmediate() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("App Blocker")
            .setContentText("Blocking apps in background")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification channel for app blocking service"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startBlockingLoop() {
        blockingRunnable?.let { handler.removeCallbacks(it) }

        val runnable = object : Runnable {
            override fun run() {
                checkAndBlockApps()
                handler.postDelayed(this, POLLING_INTERVAL_MS)
            }
        }

        blockingRunnable = runnable
        handler.post(runnable)
    }

    private fun checkAndBlockApps() {
        val isBlocking = preferences.isBlocking()
        if (!isBlocking) {
            overlayManager.hideOverlay()
            return
        }

        if (isDeviceLocked()) {
            overlayManager.hideOverlay()
            return
        }

        val foregroundApp = foregroundAppDetector.getCurrentForegroundApp() ?: return

        val blockedApps = preferences.getBlockedApps()
        val blockAll = preferences.isBlockAll()

        val shouldBlock = if (blockAll) {
            foregroundApp != packageName && isUserApp(foregroundApp)
        } else {
            blockedApps.contains(foregroundApp)
        }

        if (shouldBlock) {
            overlayManager.showOverlay()
            BlockEventStreamHandler.sendEvent(
                mapOf(
                    "type" to "attemptedAccess",
                    "packageName" to foregroundApp,
                    "timestamp" to System.currentTimeMillis()
                )
            )
        } else {
            overlayManager.hideOverlay()
        }
    }

    private fun isUserApp(packageName: String): Boolean {
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getApplicationInfo(
                    packageName,
                    android.content.pm.PackageManager.ApplicationInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getApplicationInfo(packageName, 0)
            }
            (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0
        } catch (e: Exception) {
            false
        }
    }

    private fun isDeviceLocked(): Boolean {
        val keyguardManager =
            getSystemService(KEYGUARD_SERVICE) as? android.app.KeyguardManager
        return keyguardManager?.isKeyguardLocked ?: false
    }

    override fun onDestroy() {
        blockingRunnable?.let { handler.removeCallbacks(it) }
        blockingRunnable = null
        overlayManager.hideOverlay()
        super.onDestroy()
    }
}
