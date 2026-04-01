package com.khanhtq.app_blocker.scheduling

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.khanhtq.app_blocker.blocking.BlockingServiceManager
import com.khanhtq.app_blocker.persistence.BlockerPreferences
import java.util.Calendar

/**
 * Represents a single time-based blocking schedule.
 *
 * Instances are serialised to / from JSON via Gson and stored in
 * [BlockerPreferences]. [toMap] converts to the wire format expected by
 * the Dart side.
 */
data class ScheduleData(
    val id: String,
    val name: String,
    val appIdentifiers: List<String>,
    /** ISO 8601 weekday numbers: 1 = Monday … 7 = Sunday. */
    val weekdays: List<Int>,
    val startHour: Int,
    val startMinute: Int,
    val endHour: Int,
    val endMinute: Int,
    val enabled: Boolean,
) {
    /** Converts this instance to the map format sent over the Flutter channel. */
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "appIdentifiers" to appIdentifiers,
        "weekdays" to weekdays,
        "startHour" to startHour,
        "startMinute" to startMinute,
        "endHour" to endHour,
        "endMinute" to endMinute,
        "enabled" to enabled,
    )

    companion object {
        /**
         * Constructs a [ScheduleData] from a Flutter channel map.
         *
         * List elements come across as heterogeneous [List<*>]; we use
         * [filterIsInstance] / [map] to recover type safety without
         * unchecked casts.
         *
         * @throws IllegalArgumentException if any weekday is outside the ISO 8601 range (1–7).
         */
        fun fromMap(data: Map<String, Any?>): ScheduleData {
            val appIdentifiers = (data["appIdentifiers"] as? List<*>)
                ?.filterIsInstance<String>()
                ?: emptyList()

            val weekdays = (data["weekdays"] as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() }
                ?: emptyList()

            // Validate weekdays are in ISO 8601 range (1 = Monday ... 7 = Sunday)
            for (day in weekdays) {
                if (day !in 1..7) {
                    throw IllegalArgumentException(
                        "Weekday must be an ISO 8601 value between 1 (Monday) and 7 (Sunday), got: $day"
                    )
                }
            }

            return ScheduleData(
                id = data["id"] as String,
                name = data["name"] as? String ?: "",
                appIdentifiers = appIdentifiers,
                weekdays = weekdays,
                startHour = (data["startHour"] as Number).toInt(),
                startMinute = (data["startMinute"] as Number).toInt(),
                endHour = (data["endHour"] as Number).toInt(),
                endMinute = (data["endMinute"] as Number).toInt(),
                enabled = data["enabled"] as? Boolean ?: true,
            )
        }
    }
}

/**
 * Creates, updates, removes, and alarms-manages time-based blocking schedules.
 *
 * Schedules are persisted as a JSON array in [BlockerPreferences]. When a
 * schedule is enabled, [registerAlarms] programs [AlarmManager] to fire
 * [ScheduleAlarmReceiver] at the start and end times for each configured
 * weekday. Alarms are exact (`setExactAndAllowWhileIdle`) so they fire even
 * in Doze mode.
 */
class ScheduleManager(private val context: Context) {

    companion object {
        private const val PREFS_KEY_SCHEDULES = "schedules"

        const val ACTION_SCHEDULE_START = "com.khanhtq.app_blocker.SCHEDULE_START"
        const val ACTION_SCHEDULE_END = "com.khanhtq.app_blocker.SCHEDULE_END"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_APP_IDENTIFIERS = "app_identifiers"

        // Request-code bases used to generate unique alarm request codes per
        // schedule+weekday+start/end combination.
        private const val REQUEST_CODE_START_BASE = 10_000
        private const val REQUEST_CODE_END_BASE = 20_000
        private const val MAX_WEEKDAYS = 7
    }

    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val preferences = BlockerPreferences(context)
    private val gson = Gson()
    private val blockingServiceManager = BlockingServiceManager(context)

    // ------------------------------------------------------------------
    // CRUD
    // ------------------------------------------------------------------

    /** Persists [data] as a new schedule and registers its alarms if enabled. */
    fun addSchedule(data: Map<String, Any?>) {
        val schedule = ScheduleData.fromMap(data)
        val schedules = loadSchedules().toMutableList()
        schedules.add(schedule)
        saveSchedules(schedules)
        if (schedule.enabled) {
            registerAlarms(schedule)
            if (isCurrentlyActive(schedule)) blockingServiceManager.startBlocking(schedule.appIdentifiers)
        }
    }

    /** Replaces the schedule with the same id and refreshes its alarms. */
    fun updateSchedule(data: Map<String, Any?>) {
        val updated = ScheduleData.fromMap(data)
        val schedules = loadSchedules().toMutableList()
        val index = schedules.indexOfFirst { it.id == updated.id }
        if (index < 0) return

        cancelAlarms(schedules[index].id)
        schedules[index] = updated
        saveSchedules(schedules)
        if (updated.enabled) {
            registerAlarms(updated)
            if (isCurrentlyActive(updated)) blockingServiceManager.startBlocking(updated.appIdentifiers)
        }
    }

    /** Removes the schedule with [id] and cancels its alarms. */
    fun removeSchedule(id: String) {
        val schedules = loadSchedules().toMutableList()
        val schedule = schedules.find { it.id == id } ?: return

        // Cancel alarms and unblock apps if schedule is currently active
        cancelAlarms(id)
        if (schedule.enabled && isCurrentlyActive(schedule)) {
            blockingServiceManager.stopBlocking()
        }

        schedules.removeAll { it.id == id }
        saveSchedules(schedules)
    }

    /** Returns all schedules as wire-format maps. */
    fun getSchedules(): List<Map<String, Any?>> = loadSchedules().map { it.toMap() }

    /** Returns the union of app identifiers from all enabled schedules that are currently within their active window. */
    fun getActivelyBlockedApps(): Set<String> =
        loadSchedules()
            .filter { it.enabled && isCurrentlyActive(it) }
            .flatMap { it.appIdentifiers }
            .toSet()

    /** Enables the schedule with [id] and registers its alarms. */
    fun enableSchedule(id: String) {
        updateEnabledState(id, enabled = true)
    }

    /** Disables the schedule with [id] and cancels its alarms. */
    fun disableSchedule(id: String) {
        updateEnabledState(id, enabled = false)
    }

    /** Re-registers alarms for all enabled schedules and activates any that are currently active. Called on device boot and plugin attach. */
    fun rescheduleAll() {
        for (schedule in loadSchedules()) {
            if (!schedule.enabled) continue
            registerAlarms(schedule)
            if (isCurrentlyActive(schedule)) blockingServiceManager.startBlocking(schedule.appIdentifiers)
        }
    }

    // ------------------------------------------------------------------
    // Alarm management
    // ------------------------------------------------------------------

    private fun registerAlarms(schedule: ScheduleData) {
        for (weekday in schedule.weekdays) {
            val startMillis = nextAlarmTimeMillis(weekday, schedule.startHour, schedule.startMinute)
            val endMillis = nextAlarmTimeMillis(weekday, schedule.endHour, schedule.endMinute)

            scheduleExactAlarm(
                action = ACTION_SCHEDULE_START,
                scheduleId = schedule.id,
                appIdentifiers = schedule.appIdentifiers,
                requestCode = requestCode(schedule.id, weekday, isStart = true),
                triggerAtMillis = startMillis,
            )
            scheduleExactAlarm(
                action = ACTION_SCHEDULE_END,
                scheduleId = schedule.id,
                appIdentifiers = schedule.appIdentifiers,
                requestCode = requestCode(schedule.id, weekday, isStart = false),
                triggerAtMillis = endMillis,
            )
        }
    }

    private fun cancelAlarms(scheduleId: String) {
        for (weekday in 1..MAX_WEEKDAYS) {
            cancelAlarm(ACTION_SCHEDULE_START, scheduleId, emptyList(), requestCode(scheduleId, weekday, isStart = true))
            cancelAlarm(ACTION_SCHEDULE_END, scheduleId, emptyList(), requestCode(scheduleId, weekday, isStart = false))
        }
    }

    private fun scheduleExactAlarm(
        action: String,
        scheduleId: String,
        appIdentifiers: List<String>,
        requestCode: Int,
        triggerAtMillis: Long,
    ) {
        val pending = buildPendingIntent(action, scheduleId, appIdentifiers, requestCode)
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
    }

    private fun cancelAlarm(
        action: String,
        scheduleId: String,
        appIdentifiers: List<String>,
        requestCode: Int,
    ) {
        alarmManager.cancel(buildPendingIntent(action, scheduleId, appIdentifiers, requestCode))
    }

    private fun buildPendingIntent(
        action: String,
        scheduleId: String,
        appIdentifiers: List<String>,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            this.action = action
            putExtra(EXTRA_SCHEDULE_ID, scheduleId)
            putStringArrayListExtra(EXTRA_APP_IDENTIFIERS, ArrayList(appIdentifiers))
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    // ------------------------------------------------------------------
    // Private helpers
    // ------------------------------------------------------------------

    /**
     * Returns true if [schedule] has a window that covers the current day and time.
     */
    private fun isCurrentlyActive(schedule: ScheduleData): Boolean {
        val now = Calendar.getInstance()
        val isoToCalendar = mapOf(1 to 2, 2 to 3, 3 to 4, 4 to 5, 5 to 6, 6 to 7, 7 to 1)
        val todayDow = now.get(Calendar.DAY_OF_WEEK)

        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val startMinutes = schedule.startHour * 60 + schedule.startMinute
        val endMinutes = schedule.endHour * 60 + schedule.endMinute

        return schedule.weekdays.any { weekday ->
            isoToCalendar[weekday] == todayDow && nowMinutes in startMinutes until endMinutes
        }
    }

    private fun updateEnabledState(id: String, enabled: Boolean) {
        val schedules = loadSchedules().toMutableList()
        val index = schedules.indexOfFirst { it.id == id }
        if (index < 0) return

        schedules[index] = schedules[index].copy(enabled = enabled)
        saveSchedules(schedules)

        if (enabled) {
            registerAlarms(schedules[index])
            if (isCurrentlyActive(schedules[index])) blockingServiceManager.startBlocking(schedules[index].appIdentifiers)
        } else {
            cancelAlarms(id)
            if (isCurrentlyActive(schedules[index])) blockingServiceManager.stopBlocking()
        }
    }

    /**
     * Calculates the next future [Calendar] time for the given [weekday] (ISO 8601)
     * and time of day. If the time has already passed today (or is now), it moves
     * to the same time in the following week.
     */
    private fun nextAlarmTimeMillis(weekday: Int, hour: Int, minute: Int): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)

            // Calendar.DAY_OF_WEEK uses 1=Sunday…7=Saturday;
            // weekday parameter uses ISO 8601 (1=Monday…7=Sunday).
            val isoToCalendar = mapOf(1 to 2, 2 to 3, 3 to 4, 4 to 5, 5 to 6, 6 to 7, 7 to 1)
            val targetDow = isoToCalendar[weekday] ?: return@apply

            var daysAhead = targetDow - get(Calendar.DAY_OF_WEEK)
            if (daysAhead < 0 || (daysAhead == 0 && timeInMillis <= System.currentTimeMillis())) {
                daysAhead += 7
            }
            add(Calendar.DAY_OF_MONTH, daysAhead)
        }
        return cal.timeInMillis
    }

    /**
     * Generates a unique [PendingIntent] request code for a schedule+weekday+start/end
     * combination. Uses the lower 15 bits of the schedule id's hash to avoid
     * collisions with other intents.
     */
    private fun requestCode(scheduleId: String, weekday: Int, isStart: Boolean): Int {
        val base = if (isStart) REQUEST_CODE_START_BASE else REQUEST_CODE_END_BASE
        return base + (scheduleId.hashCode() and 0x7FFF) * MAX_WEEKDAYS * 2 + weekday
    }

    private fun loadSchedules(): List<ScheduleData> {
        val json = preferences.getString(PREFS_KEY_SCHEDULES, null) ?: return emptyList()
        val type = object : TypeToken<List<ScheduleData>>() {}.type
        return try {
            gson.fromJson(json, type) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun saveSchedules(schedules: List<ScheduleData>) {
        preferences.putString(PREFS_KEY_SCHEDULES, gson.toJson(schedules))
    }
}
