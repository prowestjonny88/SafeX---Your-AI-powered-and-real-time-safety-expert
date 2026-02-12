package com.safex.app

import com.google.firebase.functions.FirebaseFunctions
import kotlinx.coroutines.tasks.await

object BackendFunctions {
    private val functions by lazy { FirebaseFunctions.getInstance() }

    suspend fun ping(): String {
        // Calls your deployed HTTPS function named "ping"
        val result = functions
            .getHttpsCallable("ping")
            .call()
            .await()

        // The function returns plain text, it will arrive as Any?
        return result.data?.toString() ?: "(no data)"
    }
}

