package com.safex.app.data.models

data class CheckLinkResponse(
    val safe: Boolean,
    val riskLevel: String,
    val headline: String,
    val reasons: List<String>
) {
    companion object {
        fun fromMap(data: Map<String, Any?>): CheckLinkResponse {
            return CheckLinkResponse(
                safe = data["safe"] as? Boolean ?: false,
                riskLevel = data["riskLevel"] as? String ?: "UNKNOWN",
                headline = data["headline"] as? String ?: "",
                reasons = (data["reasons"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList()
            )
        }
    }
}
