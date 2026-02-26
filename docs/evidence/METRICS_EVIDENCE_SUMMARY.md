# SafeX Metrics Evidence Summary

Generated on: 2026-02-26

This summary maps each KPI in `docs/metrics.md` to concrete evidence artifacts.

---

## 1) On-device latency

Status: Measured (no app logic changes)

Artifacts:
- [android_metrics_20260226_171039.md](./android_metrics_20260226_171039.md)
- [android_metrics_20260226_171039.json](./android_metrics_20260226_171039.json)

Latest values from artifact:
- Message markers observed: 11
- Median per-message loop duration: 6 ms
- P95 per-message loop duration: 11.1 ms
- JUnit test duration: 0.059 s

Notes:
- Current benchmark log prints escaped placeholders for score values, but timing evidence remains valid.

---

## 2) User comprehension

Status: Measured from form export

Artifacts:
- [feedback_metrics_20260226_171347.md](./feedback_metrics_20260226_171347.md)
- [feedback_metrics_20260226_171347.json](./feedback_metrics_20260226_171347.json)
- [feedback.pdf](../user_feedback/feedback.pdf)
- [Responses XLSX](../user_feedback/SafeX%20User%20Test%20%28KitaHack%202026%29%20%E2%80%94%20Feedback%20Form%20%28Responses%29%20%281%29.xlsx)

Latest values from artifact:
- Understand what SafeX detected: mean 3.182/5
- Knew what to do next: mean 3.455/5
- Percent scoring >= 4:
  - Understand: 45.45%
  - Knew what to do next: 63.64%

---

## 3) Guardian Gemini escalation rate

Status: Partially measurable locally, final KPI requires production/real Guardian logs

Current local artifact:
- `android_metrics_20260226_171039.*` shows Hybrid escalation count is `0` for this benchmark test.
- Reason: `ModelThresholdTest` does not execute Guardian `HybridTriageEngine` path.

How to finalize evidence:
1. Capture real Guardian triage run logs (device flow with NotificationListener/Worker active), or
2. Parse Cloud Function invocation logs for `explainAlert` with call-origin tags.

Formula:
- `guardian_escalation_rate = guardian_explain_calls / guardian_triage_events`

---

## 4) False positive rate (FPR)

Status: Pending dedicated labeled evaluation run

How to finalize evidence:
1. Use labeled set (benign + scam, mixed language).
2. Run full detection pipeline.
3. Build confusion matrix and compute:
   - `FPR = FP / (FP + TN)`

Current blockers without app-code changes:
- Existing benchmark output does not emit concrete score/decision values due escaped placeholders.

---

## Repro commands

From repo root:

```powershell
.\scripts\metrics\Collect-AndroidMetrics.ps1 -RunTest
.\scripts\metrics\Collect-FeedbackMetrics.ps1
```
