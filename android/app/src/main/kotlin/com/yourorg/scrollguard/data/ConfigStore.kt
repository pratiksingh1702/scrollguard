package com.yourorg.scrollguard.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.yourorg.scrollguard.core.model.GuardConfig
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import org.json.JSONArray

val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "guard_config")

class ConfigStore(private val context: Context) {

    private object Keys {
        val DAILY_BUDGET_SECONDS = longPreferencesKey("daily_budget_seconds")
        val RESET_HOUR = intPreferencesKey("reset_hour")
        val COOLDOWN_MINUTES = longPreferencesKey("cooldown_minutes")
        val MAX_EMERGENCY_UNLOCKS = intPreferencesKey("max_emergency_unlocks")
        val GUARDED_APPS_JSON = stringPreferencesKey("guarded_apps_json")
    }

    suspend fun loadConfig(): GuardConfig {
        return context.dataStore.data.map { prefs ->
            val budget = prefs[Keys.DAILY_BUDGET_SECONDS] ?: 1800L
            val resetHour = prefs[Keys.RESET_HOUR] ?: 4
            val cooldown = prefs[Keys.COOLDOWN_MINUTES] ?: 30L
            val unlocks = prefs[Keys.MAX_EMERGENCY_UNLOCKS] ?: 1

            val appsJson = prefs[Keys.GUARDED_APPS_JSON]
            val guardedApps = if (appsJson != null) {
                val array = JSONArray(appsJson)
                val list = ArrayList<String>()
                for (i in 0 until array.length()) {
                    list.add(array.getString(i))
                }
                list
            } else {
                listOf(
                    "com.google.android.youtube",
                    "com.instagram.android",
                    "com.zhiliaoapp.musically"
                )
            }

            GuardConfig(
                dailyBudgetSeconds = budget,
                cooldownMinutes = cooldown,
                resetHour = resetHour,
                maxEmergencyUnlocksPerDay = unlocks,
                guardedApps = guardedApps
            )
        }.first()
    }

    suspend fun saveConfig(config: GuardConfig) {
        context.dataStore.edit { prefs ->
            prefs[Keys.DAILY_BUDGET_SECONDS] = config.dailyBudgetSeconds
            prefs[Keys.RESET_HOUR] = config.resetHour
            prefs[Keys.COOLDOWN_MINUTES] = config.cooldownMinutes
            prefs[Keys.MAX_EMERGENCY_UNLOCKS] = config.maxEmergencyUnlocksPerDay

            val appsArray = JSONArray()
            for (app in config.guardedApps) {
                appsArray.put(app)
            }
            prefs[Keys.GUARDED_APPS_JSON] = appsArray.toString()
        }
    }
}
