package com.khanhtq.app_blocker.scheduling

import android.content.Context
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.khanhtq.app_blocker.blocking.BlockingServiceManager
import com.khanhtq.app_blocker.persistence.BlockerPreferences

data class ProfileData(
    val id: String,
    val name: String,
    val appIdentifiers: List<String>,
    val schedules: List<ScheduleData>,
    val isActive: Boolean
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "name" to name,
        "appIdentifiers" to appIdentifiers,
        "schedules" to schedules.map { it.toMap() },
        "isActive" to isActive
    )

    companion object {
        fun fromMap(data: Map<String, Any?>): ProfileData {
            @Suppress("UNCHECKED_CAST")
            val appIdentifiers = (data["appIdentifiers"] as? List<*>)
                ?.filterIsInstance<String>() ?: emptyList()

            @Suppress("UNCHECKED_CAST")
            val scheduleMaps = (data["schedules"] as? List<*>)
                ?.filterIsInstance<Map<String, Any?>>() ?: emptyList()

            val schedules = scheduleMaps.map { ScheduleData.fromMap(it) }

            return ProfileData(
                id = data["id"] as String,
                name = data["name"] as? String ?: "",
                appIdentifiers = appIdentifiers,
                schedules = schedules,
                isActive = data["isActive"] as? Boolean ?: false
            )
        }
    }
}

class ProfileManager(private val context: Context) {

    private val preferences: BlockerPreferences = BlockerPreferences(context)
    private val gson: Gson = Gson()
    private val scheduleManager: ScheduleManager = ScheduleManager(context)
    private val blockingServiceManager: BlockingServiceManager = BlockingServiceManager(context)

    companion object {
        private const val PREFS_KEY_PROFILES = "profiles"
    }

    fun createProfile(data: Map<String, Any?>) {
        val profile = ProfileData.fromMap(data)
        val profiles = loadProfiles().toMutableList()
        profiles.add(profile)
        saveProfiles(profiles)
    }

    fun updateProfile(data: Map<String, Any?>) {
        val updated = ProfileData.fromMap(data)
        val profiles = loadProfiles().toMutableList()
        val index = profiles.indexOfFirst { it.id == updated.id }

        if (index >= 0) {
            profiles[index] = updated
            saveProfiles(profiles)
        }
    }

    fun deleteProfile(id: String) {
        val profiles = loadProfiles().toMutableList()
        val profile = profiles.find { it.id == id }

        if (profile != null) {
            if (profile.isActive) {
                deactivateProfileInternal(profile)
            }
            profiles.removeAll { it.id == id }
            saveProfiles(profiles)
        }
    }

    fun getProfiles(): List<Map<String, Any?>> {
        return loadProfiles().map { it.toMap() }
    }

    fun activateProfile(id: String) {
        val profiles = loadProfiles().toMutableList()

        val activeIndex = profiles.indexOfFirst { it.isActive }
        if (activeIndex >= 0) {
            deactivateProfileInternal(profiles[activeIndex])
            profiles[activeIndex] = profiles[activeIndex].copy(isActive = false)
        }

        val targetIndex = profiles.indexOfFirst { it.id == id }
        if (targetIndex >= 0) {
            val target = profiles[targetIndex]
            profiles[targetIndex] = target.copy(isActive = true)
            saveProfiles(profiles)

            blockingServiceManager.startBlocking(ArrayList(target.appIdentifiers))

            for (schedule in target.schedules) {
                val scheduleData = schedule.toMap().toMutableMap()
                scheduleData["enabled"] = true
                scheduleManager.addSchedule(scheduleData)
            }
        }
    }

    fun deactivateProfile(id: String) {
        val profiles = loadProfiles().toMutableList()
        val index = profiles.indexOfFirst { it.id == id }

        if (index >= 0) {
            deactivateProfileInternal(profiles[index])
            profiles[index] = profiles[index].copy(isActive = false)
            saveProfiles(profiles)
        }
    }

    fun getActiveProfile(): Map<String, Any?>? {
        return loadProfiles().find { it.isActive }?.toMap()
    }

    private fun deactivateProfileInternal(profile: ProfileData) {
        blockingServiceManager.stopBlocking()

        for (schedule in profile.schedules) {
            scheduleManager.removeSchedule(schedule.id)
        }
    }

    private fun loadProfiles(): List<ProfileData> {
        val json = preferences.getString(PREFS_KEY_PROFILES, null) ?: return emptyList()
        val type = object : TypeToken<List<ProfileData>>() {}.type
        return try {
            gson.fromJson(json, type)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveProfiles(profiles: List<ProfileData>) {
        val json = gson.toJson(profiles)
        preferences.putString(PREFS_KEY_PROFILES, json)
    }
}
