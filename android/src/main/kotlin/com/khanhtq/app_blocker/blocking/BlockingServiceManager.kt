package com.khanhtq.app_blocker.blocking

import android.content.Context
import android.content.Intent
import android.os.Build
import com.khanhtq.app_blocker.event.BlockEventStreamHandler
import com.khanhtq.app_blocker.persistence.BlockerPreferences

class BlockingServiceManager(private val context: Context) {

    private val preferences = BlockerPreferences(context)

    fun startBlocking(packages: List<String>) {
        preferences.setBlockedApps(packages.toSet())
        preferences.setIsBlocking(true)
        preferences.setBlockAll(false)

        startService()

        for (packageName in packages) {
            BlockEventStreamHandler.sendEvent(
                mapOf(
                    "type" to "blocked",
                    "packageName" to packageName,
                    "timestamp" to System.currentTimeMillis()
                )
            )
        }
    }

    fun startBlockingAll() {
        preferences.setIsBlocking(true)
        preferences.setBlockAll(true)

        startService()
    }

    fun stopBlocking() {
        preferences.setIsBlocking(false)

        stopService()

        BlockEventStreamHandler.sendEvent(
            mapOf(
                "type" to "unblocked",
                "timestamp" to System.currentTimeMillis()
            )
        )
    }

    fun stopBlockingApps(packages: List<String>) {
        val currentBlocked = preferences.getBlockedApps().toMutableSet()
        currentBlocked.removeAll(packages.toSet())
        preferences.setBlockedApps(currentBlocked)

        if (currentBlocked.isEmpty()) {
            preferences.setIsBlocking(false)
            stopService()
        }
    }

    fun getBlockedApps(): Set<String> {
        return preferences.getBlockedApps()
    }

    fun isBlocking(): Boolean {
        return preferences.isBlocking()
    }

    fun restoreBlocking() {
        if (preferences.isBlocking()) {
            startService()
        }
    }

    private fun startService() {
        val intent = Intent(context, BlockingService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopService() {
        val intent = Intent(context, BlockingService::class.java)
        context.stopService(intent)
    }
}
