package com.safex.app.guardian

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class GuardianNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        Log.d("SafeX-Guardian", "Notification listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val n = sbn.notification ?: return
        val extras = n.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString().orEmpty()

        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.joinToString("\n") { it.toString() }
            .orEmpty()

        val combined = listOf(title, text, bigText, subText, lines)
            .filter { it.isNotBlank() }
            .joinToString("\n")
            .trim()

        if (combined.isBlank()) return

        Log.d("SafeX-Guardian", "From=${sbn.packageName} Text=$combined")

        // ✅ Hook point:
        // Here you call your local TFLite risk checker (FeatureExtractor -> TFLite -> threshold)
        // If risk >= threshold, show alert notification.
        //
        // For now we just log. Next step you will connect this to your risk pipeline.
    }
}