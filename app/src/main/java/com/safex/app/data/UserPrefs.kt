package com.safex.app.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore by preferencesDataStore(name = "safex_prefs")

class UserPrefs(private val context: Context) {

    private val KEY_LANGUAGE = stringPreferencesKey("language_tag") // "en" / "ms" / "zh"
    private val KEY_MODE = stringPreferencesKey("mode") // "guardian" / "companion"
    private val KEY_ONBOARDED = booleanPreferencesKey("onboarded")

    val languageTag: Flow<String> =
        context.dataStore.data.map { prefs -> prefs[KEY_LANGUAGE] ?: "" }

    val mode: Flow<String> =
        context.dataStore.data.map { prefs -> prefs[KEY_MODE] ?: "" }

    val onboarded: Flow<Boolean> =
        context.dataStore.data.map { prefs -> prefs[KEY_ONBOARDED] ?: false }

    suspend fun setLanguageTag(tag: String) {
        context.dataStore.edit { it[KEY_LANGUAGE] = tag }
    }

    suspend fun setMode(mode: String) {
        context.dataStore.edit { it[KEY_MODE] = mode }
    }

    suspend fun setOnboarded(done: Boolean) {
        context.dataStore.edit { it[KEY_ONBOARDED] = done }
    }
}