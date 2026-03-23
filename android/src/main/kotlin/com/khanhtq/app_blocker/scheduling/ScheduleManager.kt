package com.khanhtq.app_blocker.scheduling

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.khanhtq.app_blocker.persistence.BlockerPreferences
import java.util.Calendar

data class ScheduleData(
    val id: String,
    val name: String,
    val appIdentifiers: List<String>,
    val weekdays: List<Int>,
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
    val enabled: Boolean
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "appIdentifiers" to appIdentifiers,
        "weekdays" to weekdays,
        "startHour" to startHour,
        "startMinute" to startMinute,
        "endHour" to endHour,
        "endMinute" to endMinute,
        "enabled" to enabled
    )

    companion object {
        fun fromMap(data: Map<String, Any?>): ScheduleData {
            @Suppress("UNCHECKED_CAST")
            val appIdentifiers = (data["appIdentifiers"] as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()

            @Suppress("UNCHECKED_CAST")
            val weekdays = (data["weekdays"] as? List<*>)
                ?.map { (it as Number).toInt() } ?: emptyList()

            return ScheduleData(
                id = data["id"] as String,
                name = data["name"] as? String ?: "",
                appIdentifiers = appIdentifiers,
                weekdays = weekdays,
                startHour = (data["startHour"] as Number).toInt(),
                startMinute = (data["startMinute"] as Number).toInt(),
                endHour = (data["endHour"] as Number).toInt(),
                endMinute = (data["endMinute"] as Number).toInt(),
                enabled = data["enabled"] as? Boolean ?: true
            )
        }
    }
}

class ScheduleManager(private val context: Context) {

    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val preferences: BlockerPreferences = BlockerPreferences(context)
    private val gson: Gson = Gson()

    companion object {
        private const val PREFS_KEY_SCHEDULES = "schedules"
        const val ACTION_SCHEDULE_START = "com.khanhtq.app_blocker.SCHEDULE_START"
        const val ACTION_SCHEDULE_END = "com.khanhtq.app_blocker.SCHEDULE_END"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_APP_IDENTIFIERS = "app_identifiers"
        private const val REQUEST_CODE_START_BASE = 10000
        private const val REQUEST_CODE_END_BASE = 20000
        private const val MAX_WEEKDAYS = 7
    }

    fun addSchedule(data: Map<String, Any?>) {
        val schedule = ScheduleData.fromMap(data)
        val schedules = loadSchedules().toMutableList()
        schedules.add(schedule)
        saveSchedules(schedules)

        if (schedule.enabled) {
            registerAlarms(schedule)
        }
    }

    fun updateSchedule(data: Map<String, Any?>) {
        val updated = ScheduleData.fromMap(data)
        val schedules = loadSchedules().toMutableList()
        val index = schedules.indexOfFirst { it.id == updated.id }

        if (index >= 0) {
            cancelAlarms(schedules[index].id)
            schedules[index] = updated
            saveSchedules(schedules)

            if (updated.enabled) {
                registerAlarms(updated)
            }
        }
    }

    fun removeSchedule(id: String) {
        val schedules = loadSchedules().toMutableList()
        val removed = schedules.removeAll { it.id == id }

        if (removed) {
            cancelAlarms(id)
            saveSchedules(schedules)
        }
    }

    fun getSchedules(): List<Map<String, Any?>> {
        return loadSchedules().map { it.toMap() }
    }

    fun enableSchedule(id: String) {
        val schedules = loadSchedules().toMutableList()
        val index = schedules.indexOfFirst { it.id == id }

        if (index >= 0) {
            schedules[index] = schedules[index].copy(enabled = true)
            saveSchedules(schedules)
            registerAlarms(schedules[index])
        }
    }

    fun disableSchedule(id: String) {
        val schedules = loadSchedules().toMutableList()
        val index = schedules.indexOfFirst { it.id == id }

        if (index >= 0) {
            schedules[index] = schedules[index].copy(enabled = false)
            saveSchedules(schedules)
            cancelAlarms(id)
        }
    }

    fun rescheduleAll() {
        val schedules = loadSchedules()
        for (schedule in schedules) {
            if (schedule.enabled) {
                registerAlarms(schedule)
            }
        }
    }

    private fun registerAlarms(schedule: ScheduleData) {
        for (weekday in schedule.weekdays) {
            val startTime = calculateNextAlarmTime(weekday, schedule.startHour, schedule.startMinute)
            val endTime = calculateNextAlarmTime(weekday, schedule.endHour, schedule.endMinute)

            val startIntent = createAlarmIntent(
                ACTION_SCHEDULE_START,
                schedule.id,
                schedule.appIdentifiers,
                requestCode = generateRequestCode(schedule.id, weekday, isStart = true)
            )

            val endIntent = createAlarmIntent(
                ACTION_SCHEDULE_END,
                schedule.id,
                schedule.appIdentifiers,
                requestCode = generateRequestCode(schedule.id, weekday, isStart = false)
            )

            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                startTime,
                startIntent
            )

            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                endTime,
                endIntent
            )
        }
    }

    private fun cancelAlarms(scheduleId: String) {
        for (weekday in 1..MAX_WEEKDAYS) {
            val startRequestCode = generateRequestCode(scheduleId, weekday, isStart = true)
            val endRequestCode = generateRequestCode(scheduleId, weekday, isStart = false)

            val startIntent = createAlarmIntent(
                ACTION_SCHEDULE_START,
                scheduleId,
                emptyList(),
                startRequestCode
            )

            val endIntent = createAlarmIntent(
                ACTION_SCHEDULE_END,
                scheduleId,
                emptyList(),
                endRequestCode
            )

            alarmManager.cancel(startIntent)
            alarmManager.cancel(endIntent)
        }
    }

    private fun createAlarmIntent(
        action: String,
        scheduleId: String,
        appIdentifiers: List<String>,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_SCHEDULE_ID, scheduleId)
            putStringArrayListExtra(EXTRA_APP_IDENTIFIERS, ArrayList(appIdentifiers))
        }

        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun calculateNextAlarmTime(weekday: Int, hour: Int, minute: Int): Long {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)

            val currentDayOfWeek = get(Calendar.DAY_OF_WEEK)
            var daysUntilTarget = weekday - currentDayOfWeek

            if (daysUntilTarget < 0) {
                daysUntilTarget += 7
            } else if (daysUntilTarget == 0 && timeInMillis <= System.currentTimeMillis()) {
                daysUntilTarget = 7
            }

            add(Calendar.DAY_OF_MONTH, daysUntilTarget)
        }

        return calendar.timeInMillis
    }

    private fun generateRequestCode(scheduleId: String, weekday: Int, isStart: Boolean): Int {
        val baseCode = scheduleId.hashCode() and 0x7FFF
        val weekdayOffset = weekday * 2
        val startOffset = if (isStart) 0 else 1
        return baseCode + weekdayOffset + startOffset
    }

    private fun loadSchedules(): List<ScheduleData> {
        val json = preferences.getString(PREFS_KEY_SCHEDULES, null) ?: return emptyList()
        val type = object : TypeToken<List<ScheduleData>>() {}.type
        return try {
            gson.fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveSchedules(schedules: List<ScheduleData>) {
        val json = gson.toJson(schedules)
        preferences.putString(PREFS_KEY_SCHEDULES, json)
    }
}
