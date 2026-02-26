# SafeX - User Feedback and Iteration (KitaHack 2026)

This document summarizes real user testing feedback gathered via Google Form and documents how SafeX iterated based on those insights.

KitaHack rubric mapping:
- User Feedback and Iteration (Impact)
- Success Metrics and Scalability (Impact), supported by measurable UX signals

---

## 1) Test overview

- Collection method: Google Form ("SafeX User Test (KitaHack 2026) - Feedback Form")
- Responses: 11 participants
- Collection window: 2026-02-25 22:46 -> 2026-02-26 12:47
- Consent: 11/11 agreed feedback may be used; 11/11 allowed anonymized quotes
- Primary goals tested:
  1. Users understand what SafeX detected
  2. Users know what to do next (block/report/verify)
  3. Users trust SafeX's privacy posture

Recruitment:
- Participants were recruited from family members and friends
- Relationship to team: outside-team users

Test setup:
- Devices: Android 14.0 and above

---

## 2) Participants (anonymous)

We label participants as Tester A-K.

Age groups (n=11):
- 45-54 (n=4), 55+ (n=3), 18-24 (n=2), 35-44 (n=1), 25-34 (n=1)

Phone language:
- English (n=6), Chinese (n=3), Mixed (n=2)

Self-reported scam spotting confidence:
- Confident (n=6), Moderate (n=2), Not confident (n=2), Slightly (n=1)

Features tested (multi-select):
- Guardian Mode (notification warning) (n=6)
- Insights screen (n=5)
- Manual message scan (n=3)
- Link check (n=3)
- Image/QR scan (n=3)

---

## 3) Quantitative signals (1-5 scale)

Higher is better.

| Metric | Mean | Median | Range | Interpretation |
|---|---:|---:|---:|---|
| Understand what SafeX detected | 3.18 | 3 | 1-5 | Improving, but "why flagged" still needs to be clearer. |
| Know what to do next | 3.45 | 4 | 1-5 | Moderate; action steps should be more visible. |
| Speed felt fast enough | 4.27 | 4 | 3-5 | Strong; performance is acceptable. |
| Trust privacy posture | 4.27 | 4 | 3-5 | Strong overall, but users still ask "what data is sent?" |

Adoption intent:
- 10/11 Yes
- 1/11 Maybe

---

## 4) What users expect on high-risk alerts

Most requested elements (multi-select):
- Clear reason(s) why it is risky: 10/11
- Recommended action buttons (block/report/verify): 6/11
- Confidence level/risk score: 5/11
- Similar scam examples: 5/11
- Official reporting links: 3/11

Top improvement priorities:
- More accurate detection (fewer false alarms): n=5
- Better action guidance (what to do next): n=2
- Better UI/visual clarity: n=2
- More privacy controls: n=1
- Clearer explanation ("why flagged"): n=1

---

## 5) Key insights -> changes (iteration log)

### Insight #1 - "Need clearer and more consistent scam decisions"
What users experienced:
- Some users felt explanation text was not always decisive enough.
- This reduced trust when users expected a clearer final verdict.

Change made:
- Upgraded to a hybrid final-judge flow:
  - On-device heuristics + TFLite do fast triage.
  - Guardian escalates to Gemini at combined score >= 0.30.
  - Gemini returns structured fields (`riskLevel`, `category`, reasons, actions, confidence).
  - Gemini result is cached so alert detail opens with immediate explanation.

Evidence:
- [insight_1_before](./screenshots/insight_1(before).jpg)
- [insight_1_after](./screenshots/insight_1(after).jpg)

Why this matters:
- Improves consistency, actionability, and trust.
- Strengthens AI Integration and User Feedback and Iteration criteria.

---

### Insight #2 - "News feed relevance was too broad"
What users experienced:
- Scam news felt too general and less actionable.
- This reduced awareness impact.

Change made:
- Switched from broad GDELT feed strategy to Google News RSS + Gemini relevance filtering.
- Kept only mobile-targeted scam content and summarized it into practical warnings.

Evidence:
- [insight_2_before](./screenshots/insight_2(before).jpg)
- [insight_2_after](./screenshots/insight_2(after).jpg)

Why this matters:
- Increases practical usefulness of the Insights experience.
- Demonstrates direct iteration from user feedback.

---

### Insight #3 - "Link checks need stronger semantic analysis"
What users experienced:
- Users wanted deeper reasoning for suspicious links, not only a binary safe/unsafe label.

Change made:
- Moved to Gemini-led link analysis, with URL heuristic context (typosquat/suspicious domain patterns).
- Output now includes clear risk reasons and safer next actions.

Evidence:
- [insight_3_before](./screenshots/insight_3(before).jpg)
- [insight_3_after](./screenshots/insight_3(after).jpg)

Why this matters:
- Improves practical protection for new or previously unseen scam domains.
- Better aligns model output with user decision needs.

---

## 6) Summary: what improved and what still needs work

What improved from feedback-driven iteration:
- More consistent AI outcomes (structured verdict + reasons + actions)
- More relevant scam awareness content (RSS + Gemini filtering)
- Better link-risk explanation quality (Gemini + URL heuristics)

This improves alignment with:
- SDG 16 (fraud reduction)
- SDG 10 (protecting vulnerable users through clarity and relevance)

Main gaps (ranked by frequency and importance):
1. Explainability ("why flagged" clarity and confidence cues)
2. False-positive reduction while preserving recall
3. Clear next-step actions and official reporting guidance
4. Accessibility improvements (font/contrast/loading feedback)
5. Continued tuning of news relevance

---

## Appendix: raw exports

- [Form export](./user_feedback/SafeX%20User%20Test%20%28KitaHack%202026%29%20%E2%80%94%20Feedback%20Form%20%28Responses%29%20%281%29.xlsx)
- [Analytics export](./user_feedback/feedback.pdf)
