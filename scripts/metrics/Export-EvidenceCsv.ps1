param(
    [string]$EvidenceDir = "docs/evidence",
    [string]$OutDir = "docs/evidence/csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $EvidenceDir)) {
    throw "Evidence directory not found: $EvidenceDir"
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$androidJsonFile = Get-ChildItem $EvidenceDir -Filter 'android_metrics_*.json' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
$feedbackJsonFile = Get-ChildItem $EvidenceDir -Filter 'feedback_metrics_*.json' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $androidJsonFile) { throw "No android metrics json found under $EvidenceDir" }
if (-not $feedbackJsonFile) { throw "No feedback metrics json found under $EvidenceDir" }

$android = Get-Content $androidJsonFile.FullName -Raw | ConvertFrom-Json
$feedback = Get-Content $feedbackJsonFile.FullName -Raw | ConvertFrom-Json

$androidStamp = [regex]::Match($androidJsonFile.BaseName, 'android_metrics_(.+)$').Groups[1].Value
$feedbackStamp = [regex]::Match($feedbackJsonFile.BaseName, 'feedback_metrics_(.+)$').Groups[1].Value

# 1) Per-message loop durations
$loopRows = @()
for ($i = 0; $i -lt $android.perMessageLoopDurationsMs.Count; $i++) {
    $loopRows += [pscustomobject]@{
        sample_index = $i + 1
        loop_duration_ms = [double]$android.perMessageLoopDurationsMs[$i]
    }
}
$loopCsv = Join-Path $OutDir ("android_loop_durations_{0}.csv" -f $androidStamp)
$loopRows | Export-Csv -Path $loopCsv -NoTypeInformation -Encoding UTF8

# 2) Android summary
$androidSummaryRows = @(
    [pscustomobject]@{ metric='message_markers'; value=[double]$android.messageMarkers; unit='count' },
    [pscustomobject]@{ metric='median_loop_duration'; value=[double]$android.medianLoopDurationMs; unit='ms' },
    [pscustomobject]@{ metric='p95_loop_duration'; value=[double]$android.p95LoopDurationMs; unit='ms' },
    [pscustomobject]@{ metric='testcase_duration'; value=[double]$android.testcaseDurationSeconds; unit='s' },
    [pscustomobject]@{ metric='normalized_for_model_count'; value=[double]$android.normalizedForModelCount; unit='count' },
    [pscustomobject]@{ metric='hybrid_calling_gemini_count'; value=[double]$android.hybridCallingGeminiCount; unit='count' },
    [pscustomobject]@{ metric='hybrid_below_threshold_count'; value=[double]$android.hybridBelowThresholdCount; unit='count' }
)
$androidSummaryCsv = Join-Path $OutDir ("android_metrics_summary_{0}.csv" -f $androidStamp)
$androidSummaryRows | Export-Csv -Path $androidSummaryCsv -NoTypeInformation -Encoding UTF8

# 3) Feedback summary
$feedbackSummaryRows = @(
    [pscustomobject]@{ metric='response_count'; value=[double]$feedback.responseCount; unit='count' },
    [pscustomobject]@{ metric='understand_mean'; value=[double]$feedback.means.understand; unit='score_1_to_5' },
    [pscustomobject]@{ metric='understand_median'; value=[double]$feedback.medians.understand; unit='score_1_to_5' },
    [pscustomobject]@{ metric='understand_pct_ge_4'; value=[double]$feedback.pctAtLeast4.understand; unit='percent' },
    [pscustomobject]@{ metric='know_next_mean'; value=[double]$feedback.means.knowWhatToDoNext; unit='score_1_to_5' },
    [pscustomobject]@{ metric='know_next_median'; value=[double]$feedback.medians.knowWhatToDoNext; unit='score_1_to_5' },
    [pscustomobject]@{ metric='know_next_pct_ge_4'; value=[double]$feedback.pctAtLeast4.knowWhatToDoNext; unit='percent' },
    [pscustomobject]@{ metric='speed_mean'; value=[double]$feedback.means.speed; unit='score_1_to_5' },
    [pscustomobject]@{ metric='trust_mean'; value=[double]$feedback.means.trust; unit='score_1_to_5' }
)
$feedbackSummaryCsv = Join-Path $OutDir ("feedback_metrics_summary_{0}.csv" -f $feedbackStamp)
$feedbackSummaryRows | Export-Csv -Path $feedbackSummaryCsv -NoTypeInformation -Encoding UTF8

# 4) Consent + adoption
$consentRows = @(
    [pscustomobject]@{ metric='feedback_use_consent_yes'; yes=[double]$feedback.consent.feedbackUse.yes; total=[double]$feedback.consent.feedbackUse.total },
    [pscustomobject]@{ metric='quote_use_consent_yes'; yes=[double]$feedback.consent.quoteUse.yes; total=[double]$feedback.consent.quoteUse.total },
    [pscustomobject]@{ metric='adoption_intent_yes'; yes=[double]$feedback.adoptionIntent.yes; total=[double]$feedback.adoptionIntent.total }
)
$consentCsv = Join-Path $OutDir ("feedback_consent_adoption_{0}.csv" -f $feedbackStamp)
$consentRows | Export-Csv -Path $consentCsv -NoTypeInformation -Encoding UTF8

# 5) Combined KPI snapshot
$kpiRows = @(
    [pscustomobject]@{ kpi='on_device_latency_median_ms'; value=[double]$android.medianLoopDurationMs; baseline='6'; target='<50'; status='measured' },
    [pscustomobject]@{ kpi='on_device_latency_p95_ms'; value=[double]$android.p95LoopDurationMs; baseline='11.1'; target='<50'; status='measured' },
    [pscustomobject]@{ kpi='guardian_gemini_escalation_rate_pct'; value=''; baseline='~20 (placeholder)'; target='<15'; status='pending' },
    [pscustomobject]@{ kpi='false_positive_rate_pct'; value=''; baseline='~10 (pilot estimate)'; target='<5'; status='pending' },
    [pscustomobject]@{ kpi='user_understand_mean'; value=[double]$feedback.means.understand; baseline='3.182'; target='>=4.0'; status='measured' },
    [pscustomobject]@{ kpi='user_next_action_mean'; value=[double]$feedback.means.knowWhatToDoNext; baseline='3.455'; target='>=4.0'; status='measured' }
)
$kpiCsv = Join-Path $OutDir ("kpi_snapshot_{0}_{1}.csv" -f $androidStamp, $feedbackStamp)
$kpiRows | Export-Csv -Path $kpiCsv -NoTypeInformation -Encoding UTF8

Write-Output "CREATED:$loopCsv"
Write-Output "CREATED:$androidSummaryCsv"
Write-Output "CREATED:$feedbackSummaryCsv"
Write-Output "CREATED:$consentCsv"
Write-Output "CREATED:$kpiCsv"
