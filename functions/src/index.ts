import { onCall, HttpsError } from "firebase-functions/v2/https";
import { setGlobalOptions } from "firebase-functions/v2";
import { defineSecret, defineString } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { GoogleGenAI } from "@google/genai";

admin.initializeApp();

// Set default region close to Malaysia.
setGlobalOptions({ region: "asia-southeast1" });

// ---- Config / params ----
const SAFE_BROWSING_API_KEY = defineSecret("SAFE_BROWSING_API_KEY");

// Google Gen AI SDK with Vertex AI
// Note: We'll use Vertex AI backend by setting vertexai: true and providing project+location.
// location "asia-southeast1" is supported by Gemini 2.5 Flash on Vertex AI.
const VERTEX_LOCATION = defineString("VERTEX_LOCATION", { default: "asia-southeast1" });
const GEMINI_MODEL = defineString("GEMINI_MODEL", { default: "gemini-2.5-flash" });

// ---- Helper: safe browsing lookup (manual scan use-case) ----
async function safeBrowsingLookup(urls: string[], apiKey: string) {
  // Google Safe Browsing Lookup API v4: threatMatches.find
  const endpoint = `https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${apiKey}`;

  const body = {
    client: { clientId: "safex", clientVersion: "1.0.0" },
    threatInfo: {
      // Keep these values aligned with Safe Browsing v4 docs examples.
      // If you later want to broaden, consult the "Safe Browsing Lists" page.
      threatTypes: ["MALWARE", "SOCIAL_ENGINEERING"],
      platformTypes: ["WINDOWS"],
      threatEntryTypes: ["URL"],
      threatEntries: urls.slice(0, 500).map((u) => ({ url: u })),
    },
  };

  const res = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`SafeBrowsing error ${res.status}: ${text}`);
  }

  return await res.json(); // either {} or { matches: [...] }
}

// ---- Callable: explainAlert ----
// Called from Android only when user opens an alert detail screen.
export const explainAlert = onCall(
  {
    secrets: [SAFE_BROWSING_API_KEY],
    cors: true,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    // Security: require auth (anonymous auth is fine)
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Auth required.");
    }

    const data = request.data as any;

    // Minimal, privacy-first payload
    const alertType = String(data?.alertType ?? "");
    const language = String(data?.language ?? "unknown");
    const category = String(data?.category ?? "unknown");
    const tactics = Array.isArray(data?.tactics) ? data.tactics.map(String) : [];
    const snippet = String(data?.snippet ?? "").slice(0, 500); // already redacted on-device
    const extractedUrl = data?.extractedUrl ? String(data.extractedUrl).slice(0, 500) : null;

    if (!alertType) {
      throw new HttpsError("invalid-argument", "alertType is required.");
    }

    // If this request includes a URL and user explicitly scanned it, we can optionally check Safe Browsing.
    // IMPORTANT: per your product decision, we do NOT auto-check links from notifications.
    let safeBrowsing = null;
    if (extractedUrl && data?.doSafeBrowsingCheck === true) {
      try {
        safeBrowsing = await safeBrowsingLookup([extractedUrl], SAFE_BROWSING_API_KEY.value());
      } catch (e: any) {
        logger.warn("SafeBrowsing failed", e);
        safeBrowsing = { error: String(e?.message ?? e) };
      }
    }

    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
    if (!project) {
      throw new HttpsError("internal", "Missing project id in environment.");
    }

    const ai = new GoogleGenAI({
      vertexai: true,
      project,
      location: VERTEX_LOCATION.value(),
    });

    // System instruction: enforce safe, calm, elder-friendly language and JSON output
    const system = `
You are SafeX, an anti-scam safety assistant.
You must be calm, non-blaming, and actionable.
Return ONLY valid JSON. No markdown.

JSON schema:
{
  "riskLevel": "LOW" | "MEDIUM" | "HIGH",
  "headline": string,
  "whyFlagged": string[],
  "whatToDoNow": string[],
  "whatNotToDo": string[],
  "confidence": number, // 0 to 1
  "notes": string
}

Rules:
- Do not ask the user to click unknown links.
- If the message suggests urgency, impersonation, or money transfer, raise risk.
- Use simple language suitable for elders.
- If safeBrowsing indicates matches, include that in whyFlagged.
`;

    const userPrompt = {
      alertType,
      language,
      category,
      tactics,
      snippet,
      extractedUrl,
      safeBrowsing,
    };

    const response = await ai.models.generateContent({
      model: GEMINI_MODEL.value(),
      // Keep output short-ish for mobile UI.
      contents: [
        {
          role: "user",
          parts: [{ text: `Analyze this alert payload:\n${JSON.stringify(userPrompt)}` }],
        },
      ],
      config: {
        systemInstruction: system,
      },
    });

    const text = response.text ?? "";
    // Best-effort JSON parse
    try {
      const parsed = JSON.parse(text);
      return parsed;
    } catch (e) {
      logger.error("Gemini returned non-JSON", { text });
      // Fallback: return structured but generic
      return {
        riskLevel: "MEDIUM",
        headline: "Suspicious message detected",
        whyFlagged: ["Message matched known scam manipulation patterns."],
        whatToDoNow: ["Do not respond yet.", "Use SafeX Scan to test any links.", "Ask a trusted person if unsure."],
        whatNotToDo: ["Do not share OTP or banking details.", "Do not send money."],
        confidence: 0.5,
        notes: "Fallback response (model output was not valid JSON).",
      };
    }
  }
);

// ---- Callable: reportAlert ----
// Called when user taps Report on alert detail screen.
// Stores only aggregated counters (no raw content).
export const reportAlert = onCall(
  {
    cors: true,
    timeoutSeconds: 15,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Auth required.");
    }

    const data = request.data as any;
    const category = String(data?.category ?? "unknown");
    const tactics = Array.isArray(data?.tactics) ? data.tactics.map(String) : [];
    const domainPattern = data?.domainPattern ? String(data.domainPattern).slice(0, 120) : null;

    // Use a weekly doc ID, e.g. 2026-W05
    const now = new Date();
    const year = now.getUTCFullYear();
    const oneJan = new Date(Date.UTC(year, 0, 1));
    const week = Math.ceil((((now.getTime() - oneJan.getTime()) / 86400000) + oneJan.getUTCDay() + 1) / 7);
    const weekId = `${year}-W${String(week).padStart(2, "0")}`;

    const docRef = admin.firestore().collection("insightsWeekly").doc(weekId);

    const inc = admin.firestore.FieldValue.increment(1);

    const updates: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      totalReports: inc,
      [`categories.${category}`]: inc,
    };

    for (const t of tactics.slice(0, 8)) {
      updates[`tactics.${t}`] = inc;
    }

    if (domainPattern) {
      updates[`domainPatterns.${domainPattern}`] = inc;
    }

    await docRef.set(updates, { merge: true });

    return { ok: true, weekId };
  }
);
