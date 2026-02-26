# Measuring Impact and Scalability (SafeX)

This document defines how SafeX measures impact, baseline vs target KPIs, and scalability under KitaHack 2026 judging criteria (Success Metrics and Scalability).

Why these metrics:
1. Fast enough to intervene before the user acts.
2. Accurate enough to be trusted.
3. Clear enough for users to act correctly.
4. Cost-efficient enough to scale.

---

## 1) KPI summary: baseline vs target

| Metric | Baseline (current) | Target (next iteration) | Why it matters |
|---|---:|---:|---|
| On-device latency (heuristics + TFLite) | Median 6 ms, p95 11.1 ms (measured) | < 50 ms | Must feel instant during notification interception. |
| Guardian Gemini escalation rate | Pending final measurement (current placeholder: ~20%) | < 15% | Controls cloud cost and privacy exposure; most triage stays on-device. |
| False positive rate | ~10% (pilot estimate) | < 5% | High false alarms reduce trust and adoption. |
| User comprehension ("why flagged" + "what next") | 3.182/5 and 3.455/5 means (n=11, measured) | >= 4.0/5 mean | Users must understand risk and next actions. |

Important note:
If any baseline value is not measured with the methods below, mark it as `estimate` and replace it with measured data before submission.

---

## 1.1 Current evidence snapshot (2026-02-26)

Measured now:
- On-device benchmark timing:
  - median per-message loop duration: 6 ms
  - p95 per-message loop duration: 11.1 ms
  - source: `docs/evidence/android_metrics_20260226_171039.*`
- User feedback metrics from XLSX export:
  - understand what SafeX detected: mean 3.182/5
  - knew what to do next: mean 3.455/5
  - source: `docs/evidence/feedback_metrics_20260226_171347.*`

Pending:
- Guardian Gemini escalation rate (true production ratio)
- False positive rate (confusion matrix over labeled set)

---

## 2) Measurement methodology

### 2.1 On-device latency (ms)
Definition:
Time from input text -> heuristic + TFLite scoring -> combined score output.

How to measure:
- Instrument triage with timestamps:
  - `tStart = SystemClock.elapsedRealtimeNanos()`
  - `tEnd = SystemClock.elapsedRealtimeNanos()`
  - `latencyMs = (tEnd - tStart) / 1e6`
- Run at least `N >= 200` samples across:
  - short (<80 chars)
  - medium (80-200 chars)
  - long (>200 chars)
  - mixed-language samples (en/ms/zh/mixed)

Report:
- median latency
- p95 latency

Data source:
- local debug logs
- optional Room performance table

---

### 2.2 Guardian Gemini escalation rate (%)
Definition:
Fraction of Guardian triage events that trigger `explainAlert` after on-device scoring.

Current architecture alignment:
- Guardian path: call Gemini when combined score `>= 0.30`.
- Manual scans: user-initiated direct Gemini calls (tracked separately).
- Alert detail: uses cached Gemini first; fallback Gemini call only if cache is missing.

How to measure:
- Count Guardian triage events on device.
- Count Guardian-origin `explainAlert` calls.
- Compute:
  - `guardian_escalation_rate = guardian_explain_calls / guardian_triage_events`

Recommended instrumentation:
- Include a call-origin tag in `explainAlert` requests:
  - `guardian_auto`
  - `manual_scan`
  - `detail_fallback`

Data source:
- Firebase Cloud Functions logs
- Room/device counters for total Guardian triage events

---

### 2.3 False positive rate (FPR)
Definition:
Percent of benign messages flagged as scam (MEDIUM/HIGH final verdict).

How to measure:
- Use labeled dataset:
  - `BENIGN` and `SCAM` classes
- Run full pipeline and compute:
  - `FPR = benign_flagged / total_benign`
- Also track:
  - false negative rate
  - precision
  - recall

Minimum evaluation size (prototype):
- at least 50 benign + 50 scam
- mixed language set

Evidence:
- evaluation notebook output
- confusion matrix artifact

---

### 2.4 User comprehension
Definition:
How well users understand why a message was flagged and what to do next.

How to measure:
- From feedback form (Likert 1-5):
  - "I could understand what SafeX detected."
  - "I knew what to do next."
- Track:
  - mean score
  - median score
  - percent of responses >= 4

Data source:
- Google Form export
- qualitative tags (for example: "reason unclear", "needs clearer actions")

---

## 3) Cost efficiency strategy (scalable by design)

SafeX uses a funnel strategy:
- 100% Guardian notifications/images are triaged on-device first.
- Only combined score `>= 0.30` escalates to Gemini in Guardian mode.
- Manual scan flows are user-initiated and call Gemini directly.
- Alert detail reads cached Gemini analysis first; network fallback only when cache is missing.

Why this scales:
- Most benign content is filtered quickly on-device.
- Cloud calls are focused on suspicious or explicitly user-requested analysis.
- Redacted payloads (max 500 chars) limit sensitive data transfer.

Target cost controls:
- Keep Guardian escalation < 15%
- Cache Gemini analysis per alert
- Deduplicate repeated content where possible

---

## 4) Scalability roadmap

### Next 3 months
- Reduce FPR via threshold tuning and multilingual pattern refinement.
- Improve per-category performance (investment, impersonation, delivery, romance, job).
- Improve explanation UX: clearer top reasons + direct action buttons.
- Add automated evaluation and regression tests for threshold behavior.

### Next 12 months
- Improve on-device model efficiency (quantization/distillation) without latency regression.
- Add official reporting workflow integrations.
- Expand privacy controls (per-feature toggles, deletion controls, transparency prompts).
- Explore user-approved anonymous telemetry for model improvement.

---

## 5) Evidence checklist for judges

- Latency chart (median + p95)
- Confusion matrix (benign vs scam)
- User feedback summary (sample size, insights, iteration actions)
- Cloud Function invocation evidence (escalation rate split by call origin)

---

## 6) Evidence links and current limitations

Primary evidence files:
- `docs/evidence/android_metrics_20260226_171039.md`
- `docs/evidence/android_metrics_20260226_171039.json`
- `docs/evidence/feedback_metrics_20260226_171347.md`
- `docs/evidence/feedback_metrics_20260226_171347.json`
- `docs/evidence/METRICS_EVIDENCE_SUMMARY.md`

Limitations (current tooling run):
1. `ModelThresholdTest` currently prints escaped placeholders for score values, so it is valid for timing/volume evidence but not for exact score-distribution plots.
2. Guardian escalation-rate cannot be finalized from benchmark test alone because that test path does not execute real Guardian `HybridTriageEngine` traffic in the field.
3. FPR is pending a labeled benign/scam evaluation set run and confusion matrix export.
4. Graph plotting was not auto-generated in this run; raw numeric artifacts are generated and ready for plotting in Excel/Sheets.
