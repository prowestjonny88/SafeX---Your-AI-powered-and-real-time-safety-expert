package com.safex.app

import android.content.Context
import android.util.Log
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.safex.app.guardian.HeuristicTriageEngine
import com.safex.app.ml.ScamDetector
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class FprDatasetTest {

    private lateinit var context: Context
    private lateinit var testContext: Context
    private lateinit var heuristicEngine: HeuristicTriageEngine
    private lateinit var mlEngine: ScamDetector

    data class Row(
        val sampleId: String,
        val expectedLabelId: Int,
        val expectedLabel: String,
        val text: String
    )

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        testContext = InstrumentationRegistry.getInstrumentation().context
        heuristicEngine = HeuristicTriageEngine()
        mlEngine = ScamDetector(context)
        mlEngine.predictScore("warmup")
    }

    @Test
    fun evaluateCsvConfusionMatrix() {
        val rows = loadRowsFromAsset("fpr_test_200.csv")
        require(rows.isNotEmpty()) { "CSV dataset is empty." }
        require(mlEngine.isAvailable) {
            "TFLite model unavailable: ${mlEngine.initError ?: "unknown error"}"
        }

        var tp = 0
        var fp = 0
        var tn = 0
        var fn = 0

        val threshold = 0.30f

        for (row in rows) {
            val tScore = mlEngine.predictScore(row.text).coerceIn(0f, 1f)
            val (hScore, _) = heuristicEngine.scoreText(row.text)
            val combined = (hScore * 0.20f) + (tScore * 0.80f)
            val predictedScam = combined >= threshold
            val expectedScam = row.expectedLabelId == 1 || row.expectedLabel.equals("scam", ignoreCase = true)

            when {
                predictedScam && expectedScam -> tp++
                predictedScam && !expectedScam -> fp++
                !predictedScam && !expectedScam -> tn++
                !predictedScam && expectedScam -> fn++
            }

            Log.i(
                TAG,
                "ROW id=${row.sampleId} expected=${row.expectedLabel} predicted=${if (predictedScam) "scam" else "benign"} " +
                    "h=$hScore t=$tScore combined=$combined"
            )
        }

        val total = tp + fp + tn + fn
        val fpr = if (fp + tn > 0) fp.toFloat() / (fp + tn).toFloat() else 0f
        val tpr = if (tp + fn > 0) tp.toFloat() / (tp + fn).toFloat() else 0f
        val accuracy = if (total > 0) (tp + tn).toFloat() / total.toFloat() else 0f

        Log.i(TAG, "=== CONFUSION_MATRIX ===")
        Log.i(TAG, "TP=$tp FP=$fp TN=$tn FN=$fn TOTAL=$total")
        Log.i(TAG, "FPR=$fpr TPR=$tpr ACCURACY=$accuracy THRESHOLD=$threshold")
    }

    private fun loadRowsFromAsset(assetName: String): List<Row> {
        val lines = testContext.assets.open(assetName).bufferedReader(Charsets.UTF_8).use { it.readLines() }
        if (lines.size <= 1) return emptyList()

        val rows = mutableListOf<Row>()
        for (line in lines.drop(1)) {
            if (line.isBlank()) continue
            val cols = parseCsvLine(line)
            if (cols.size < 7) continue
            val sampleId = cols[0].trim()
            val expectedLabelId = cols[1].trim().toIntOrNull() ?: continue
            val expectedLabel = cols[2].trim()
            val text = cols[6]
            rows += Row(sampleId, expectedLabelId, expectedLabel, text)
        }
        return rows
    }

    private fun parseCsvLine(line: String): List<String> {
        val out = mutableListOf<String>()
        val sb = StringBuilder()
        var inQuotes = false
        var i = 0
        while (i < line.length) {
            val c = line[i]
            if (c == '"') {
                if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
                    sb.append('"')
                    i += 2
                    continue
                }
                inQuotes = !inQuotes
                i++
                continue
            }
            if (c == ',' && !inQuotes) {
                out += sb.toString()
                sb.clear()
            } else {
                sb.append(c)
            }
            i++
        }
        out += sb.toString()
        return out
    }

    companion object {
        private const val TAG = "SafeX-FPRTest"
    }
}
