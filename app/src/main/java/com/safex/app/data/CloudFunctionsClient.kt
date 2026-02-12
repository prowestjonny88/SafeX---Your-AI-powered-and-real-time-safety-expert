package com.safex.app.data

import com.google.firebase.FirebaseApp
import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

class CloudFunctionsClient(
    region: String = "asia-southeast1"
) {
    // IMPORTANT: match your deployed region
    private val functions: FirebaseFunctions =
        FirebaseFunctions.getInstance(FirebaseApp.getInstance(), region)

    @Suppress("UNCHECKED_CAST")
    suspend fun explainAlert(payload: Map<String, Any?>): Map<String, Any?> {
        val result = functions
            .getHttpsCallable("explainAlert")
            .call(payload)
            .await()
        return result.data as Map<String, Any?>
    }

    @Suppress("UNCHECKED_CAST")
    suspend fun reportAlert(payload: Map<String, Any?>): Map<String, Any?> {
        val result = functions
            .getHttpsCallable("reportAlert")
            .call(payload)
            .await()
        return result.data as Map<String, Any?>
    }
}