package com.safex.app.ui.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import com.safex.app.data.AlertRepository
import com.safex.app.data.local.AlertEntity
import com.safex.app.data.local.SafeXDatabase
import kotlinx.coroutines.flow.Flow

class AlertViewModel(context: Context) : ViewModel() {
    private val database = SafeXDatabase.getInstance(context)
    private val repository = AlertRepository.getInstance(database)

    val alerts: Flow<List<AlertEntity>> = repository.alerts
    val weeklyCount: Flow<Int> = repository.weeklyAlertCount()
}
