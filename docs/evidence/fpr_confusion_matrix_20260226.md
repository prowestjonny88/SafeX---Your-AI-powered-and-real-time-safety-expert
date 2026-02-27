# SafeX FPR + Confusion Matrix Evidence

Generated on: 2026-02-26

## Test run

- Device: `RMX3890` (Android 14)
- Test class: `com.safex.app.FprDatasetTest`
- Command:
  - `.\gradlew.bat :app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=com.safex.app.FprDatasetTest" --no-daemon`
- Threshold rule used in test:
  - `combined = (heuristic * 0.20) + (tflite * 0.80)`
  - predict scam if `combined >= 0.30`
- Dataset loaded by instrumentation test:
  - `app/src/androidTest/assets/fpr_test_200.csv`

## Main result (all rows in this run)

- Total rows: `300`
- Labeled benign: `250`
- Labeled scam: `50`

Confusion matrix:
- `TP = 45`
- `FP = 78`
- `TN = 172`
- `FN = 5`

Derived metrics:
- `FPR = FP / (FP + TN) = 78 / 250 = 0.312` (31.2%)
- `TPR (Recall) = TP / (TP + FN) = 45 / 50 = 0.900` (90.0%)
- `Precision = TP / (TP + FP) = 45 / 123 = 0.3659` (36.59%)
- `Accuracy = (TP + TN) / Total = 217 / 300 = 0.7233` (72.33%)

## Benign-only slice for original 200-row FPR set

For rows with IDs not matching `mXXXX` (the original benign set):
- `FP = 56`
- `TN = 144`
- `FPR = 56 / 200 = 0.28` (28.0%)

## Raw log source (local build artifact)

- `app/build/outputs/androidTest-results/connected/debug/RMX3890 - 14/logcat-com.safex.app.FprDatasetTest-evaluateCsvConfusionMatrix.txt`

