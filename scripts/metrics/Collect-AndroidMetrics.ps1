param(
    [string]$RepoRoot = ".",
    [switch]$RunTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Push-Location $RepoRoot
try {
    $sdk = "C:\Users\JON\AppData\Local\Android\Sdk"
    $env:ANDROID_HOME = $sdk
    $env:ANDROID_SDK_ROOT = $sdk

    if ($RunTest) {
        & .\gradlew.bat :app:connectedDebugAndroidTest "-Pandroid.testInstrumentationRunnerArguments.class=com.safex.app.ModelThresholdTest" --no-daemon | Out-Null
    }

    $outDir = Join-Path $PWD "app/build/outputs/androidTest-results/connected/debug"
    if (-not (Test-Path $outDir)) {
        throw "Connected test output not found: $outDir"
    }

    $logFile = Get-ChildItem $outDir -Recurse -Filter "logcat-com.safex.app.ModelThresholdTest-testMessages.txt" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $logFile) {
        throw "Logcat file for ModelThresholdTest not found."
    }

    $xmlFile = Get-ChildItem $outDir -Filter "TEST-*.xml" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $lines = Get-Content $logFile.FullName

    $msgTimes = @()
    $reMessage = [regex]'^(?<ts>\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}).*=== MESSAGE'
    foreach ($line in $lines) {
        $m = $reMessage.Match($line)
        if ($m.Success) {
            $ts = $m.Groups["ts"].Value
            $dt = [datetime]::ParseExact(
                ("{0}-{1}" -f (Get-Date).Year, $ts),
                "yyyy-MM-dd HH:mm:ss.fff",
                [System.Globalization.CultureInfo]::InvariantCulture
            )
            $msgTimes += $dt
        }
    }

    $loopDurMs = @()
    for ($i = 1; $i -lt $msgTimes.Count; $i++) {
        $loopDurMs += [math]::Round(($msgTimes[$i] - $msgTimes[$i - 1]).TotalMilliseconds, 3)
    }

    function Get-Percentile([double[]]$arr, [double]$p) {
        if (-not $arr -or $arr.Count -eq 0) { return $null }
        $sorted = $arr | Sort-Object
        if ($sorted.Count -eq 1) { return [double]$sorted[0] }
        $rank = ($p / 100.0) * ($sorted.Count - 1)
        $lo = [math]::Floor($rank)
        $hi = [math]::Ceiling($rank)
        if ($lo -eq $hi) { return [double]$sorted[$lo] }
        $w = $rank - $lo
        return [double]($sorted[$lo] * (1 - $w) + $sorted[$hi] * $w)
    }

    $median = Get-Percentile $loopDurMs 50
    $p95 = Get-Percentile $loopDurMs 95

    $hybridCalls = @($lines | Select-String -Pattern "calling Gemini for explanation").Count
    $hybridBelow = @($lines | Select-String -Pattern "Combined score below threshold").Count
    $normalizedCount = @($lines | Select-String -Pattern "Normalized for model:").Count

    $testCaseSeconds = $null
    if ($xmlFile) {
        [xml]$x = Get-Content $xmlFile.FullName
        $tc = $x.testsuite.testcase | Select-Object -First 1
        if ($tc -and $tc.time) { $testCaseSeconds = [double]$tc.time }
    }

    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $evidenceDir = Join-Path $PWD "docs/evidence"
    if (-not (Test-Path $evidenceDir)) {
        New-Item -ItemType Directory -Path $evidenceDir | Out-Null
    }

    $result = [ordered]@{
        generatedAt = (Get-Date).ToString("s")
        logFile = $logFile.FullName
        junitFile = if ($xmlFile) { $xmlFile.FullName } else { $null }
        messageMarkers = $msgTimes.Count
        perMessageLoopDurationsMs = $loopDurMs
        medianLoopDurationMs = if ($median) { [math]::Round($median, 3) } else { $null }
        p95LoopDurationMs = if ($p95) { [math]::Round($p95, 3) } else { $null }
        testcaseDurationSeconds = $testCaseSeconds
        normalizedForModelCount = $normalizedCount
        hybridCallingGeminiCount = $hybridCalls
        hybridBelowThresholdCount = $hybridBelow
        notes = @(
            "ModelThresholdTest currently prints escaped placeholders for score values.",
            "This evidence captures timing and execution volume without app code changes.",
            "Hybrid escalation counts are expected to be zero in this test because HybridTriageEngine is not executed."
        )
    }

    $jsonPath = Join-Path $evidenceDir ("android_metrics_{0}.json" -f $stamp)
    $mdPath = Join-Path $evidenceDir ("android_metrics_{0}.md" -f $stamp)

    $result | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $jsonPath

    @"
# Android Metrics Evidence ($stamp)

- Log file: $($result.logFile)
- JUnit file: $($result.junitFile)
- Message markers observed: $($result.messageMarkers)
- Median per-message loop duration (ms): $($result.medianLoopDurationMs)
- P95 per-message loop duration (ms): $($result.p95LoopDurationMs)
- JUnit test duration (s): $($result.testcaseDurationSeconds)
- "Normalized for model" count: $($result.normalizedForModelCount)
- Hybrid "calling Gemini" count: $($result.hybridCallingGeminiCount)
- Hybrid "below threshold" count: $($result.hybridBelowThresholdCount)

## Notes
- ModelThresholdTest currently prints escaped placeholders for score values.
- This artifact measures timing/volume only, with no app logic changes.
- For Guardian escalation-rate evidence, collect logs from real Guardian triage (Hybrid engine path).
"@ | Set-Content -Encoding UTF8 $mdPath

    Write-Output "WROTE_JSON=$jsonPath"
    Write-Output "WROTE_MD=$mdPath"
}
finally {
    Pop-Location
}
