package com.safex.app.guardian

import android.content.Context

/**
 * Triage engine that currently delegates to HeuristicTriageEngine.
 * Can be extended to use TFLite in the future.
 */
class HybridTriageEngine(private val context: Context) : TriageEngine {

    private val heuristicEngine = HeuristicTriageEngine()

    override fun analyze(text: String): TriageResult {
        // Future: Try TFLite model here
        return heuristicEngine.analyze(text)
    }
}
