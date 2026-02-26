# SafeX Metrics Evidence Pack (No App Logic Changes)

This folder stores generated evidence artifacts for `docs/metrics.md`.

All steps below avoid modifying production app logic.

---

## 1) Generate Android timing evidence

From repo root:

```powershell
.\scripts\metrics\Collect-AndroidMetrics.ps1 -RunTest
```

Outputs:
- `android_metrics_*.json`
- `android_metrics_*.md`

What it proves:
- Instrumentation test executed on device/emulator
- Per-message loop timing proxy (median, p95)
- Test runtime evidence files (logcat + JUnit XML paths)

Notes:
- Current `ModelThresholdTest` prints escaped placeholders for score values.
- This artifact is still valid for timing and execution volume evidence.

---

## 2) Generate user feedback evidence from XLSX

From repo root:

```powershell
.\scripts\metrics\Collect-FeedbackMetrics.ps1
```

Outputs:
- `feedback_metrics_*.json`
- `feedback_metrics_*.md`

What it proves:
- Response count
- Mean/median for task success, speed, trust
- `% >= 4` comprehension/actionability
- Consent + adoption intent counts

---

## 3) Collect Guardian escalation-rate evidence (cloud)

Use Firebase logs and filter `explainAlert` requests by call origin.

Recommended tags:
- `guardian_auto`
- `manual_scan`
- `detail_fallback`

If origin tags are not yet logged, report escalation-rate as a temporary estimate and mark limitation explicitly.

Example command:

```powershell
firebase functions:log --only explainAlert
```

Evidence to capture:
- Screenshot/export of invocation counts
- Date window used
- Formula used:
  - `guardian_escalation_rate = guardian_explain_calls / guardian_triage_events`

---

## 4) Collect false-positive-rate evidence (evaluation set)

Use a labeled benign/scam set and run the same detection path used in product.

Report:
- Confusion matrix
- `FPR = FP / (FP + TN)`
- Precision, recall

Minimum prototype set:
- 50 benign + 50 scam samples (mixed language)

---

## 5) Submission checklist

- Android timing artifact (`android_metrics_*.md/json`)
- Feedback artifact (`feedback_metrics_*.md/json`)
- Escalation-rate evidence (cloud logs + formula)
- FPR evidence (matrix + formulas)
