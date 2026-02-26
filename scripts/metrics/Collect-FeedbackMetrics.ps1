param(
    [string]$XlsxPath = "",
    [string]$RepoRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Push-Location $RepoRoot
try {
    if ([string]::IsNullOrWhiteSpace($XlsxPath)) {
        $auto = Get-ChildItem "docs/user_feedback" -Filter "*.xlsx" -File | Select-Object -First 1
        if (-not $auto) {
            throw "No XLSX found under docs/user_feedback."
        }
        $XlsxPath = $auto.FullName
    }

    if (-not (Test-Path $XlsxPath)) {
        throw "Feedback XLSX not found: $XlsxPath"
    }

    $excel = $null
    $wb = $null
    $ws = $null
    $used = $null
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Open((Resolve-Path $XlsxPath))
        $ws = $wb.Worksheets.Item(1)
        $used = $ws.UsedRange

        $rows = [int]$used.Rows.Count
        $cols = [int]$used.Columns.Count
        if ($rows -lt 2) {
            throw "Feedback sheet has no data rows."
        }

        $headers = @()
        for ($c = 1; $c -le $cols; $c++) {
            $headers += [string]$ws.Cells.Item(1, $c).Text
        }

        function Find-Col([string[]]$h, [string]$pattern) {
            for ($i = 0; $i -lt $h.Count; $i++) {
                if ($h[$i] -match $pattern) { return ($i + 1) }
            }
            return $null
        }

        $colUnderstand = Find-Col $headers "Task success:.*understand what SafeX detected"
        $colNext = Find-Col $headers "Task success:.*knew what to do next"
        $colSpeed = Find-Col $headers "^Speed:"
        $colTrust = Find-Col $headers "^Trust:"
        $colUse = Find-Col $headers "Would you use SafeX"
        $colConsent = Find-Col $headers "feedback may be used"
        $colQuoteConsent = Find-Col $headers "anonymized quote"

        if (-not $colUnderstand -or -not $colNext) {
            throw "Could not find required task-success columns in feedback sheet."
        }

        function Collect-NumericCol([object]$sheet, [int]$rStart, [int]$rEnd, [int]$c) {
            $vals = @()
            for ($r = $rStart; $r -le $rEnd; $r++) {
                $raw = [string]$sheet.Cells.Item($r, $c).Text
                if ($raw -match "\d+") {
                    $vals += [int]$matches[0]
                }
            }
            return $vals
        }

        function Mean([int[]]$arr) {
            if (-not $arr -or $arr.Count -eq 0) { return $null }
            return [double](($arr | Measure-Object -Average).Average)
        }

        function Median([int[]]$arr) {
            if (-not $arr -or $arr.Count -eq 0) { return $null }
            $s = $arr | Sort-Object
            $n = $s.Count
            if ($n % 2 -eq 1) { return [double]$s[[int]($n / 2)] }
            return [double](($s[$n/2 - 1] + $s[$n/2]) / 2.0)
        }

        function PctAtLeast([int[]]$arr, [int]$minVal) {
            if (-not $arr -or $arr.Count -eq 0) { return $null }
            $count = ($arr | Where-Object { $_ -ge $minVal }).Count
            return [double](100.0 * $count / $arr.Count)
        }

        function Count-Yes([object]$sheet, [int]$rStart, [int]$rEnd, [int]$c) {
            if (-not $c) { return $null }
            $yes = 0
            $total = 0
            for ($r = $rStart; $r -le $rEnd; $r++) {
                $raw = [string]$sheet.Cells.Item($r, $c).Text
                if ([string]::IsNullOrWhiteSpace($raw)) { continue }
                $total++
                if ($raw -match "^(Yes|Agree|I agree)") { $yes++ }
            }
            return @{ yes = $yes; total = $total }
        }

        $rStart = 2
        $rEnd = $rows

        $understand = Collect-NumericCol $ws $rStart $rEnd $colUnderstand
        $next = Collect-NumericCol $ws $rStart $rEnd $colNext
        $speed = if ($colSpeed) { Collect-NumericCol $ws $rStart $rEnd $colSpeed } else { @() }
        $trust = if ($colTrust) { Collect-NumericCol $ws $rStart $rEnd $colTrust } else { @() }

        $adoption = Count-Yes $ws $rStart $rEnd $colUse
        $consent = Count-Yes $ws $rStart $rEnd $colConsent
        $quoteConsent = Count-Yes $ws $rStart $rEnd $colQuoteConsent

        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $evidenceDir = Join-Path $PWD "docs/evidence"
        if (-not (Test-Path $evidenceDir)) {
            New-Item -ItemType Directory -Path $evidenceDir | Out-Null
        }

        $result = [ordered]@{
            generatedAt = (Get-Date).ToString("s")
            xlsxPath = (Resolve-Path $XlsxPath).Path
            responseCount = $rows - 1
            means = [ordered]@{
                understand = if ($understand.Count) { [math]::Round((Mean $understand), 3) } else { $null }
                knowWhatToDoNext = if ($next.Count) { [math]::Round((Mean $next), 3) } else { $null }
                speed = if ($speed.Count) { [math]::Round((Mean $speed), 3) } else { $null }
                trust = if ($trust.Count) { [math]::Round((Mean $trust), 3) } else { $null }
            }
            medians = [ordered]@{
                understand = if ($understand.Count) { [math]::Round((Median $understand), 3) } else { $null }
                knowWhatToDoNext = if ($next.Count) { [math]::Round((Median $next), 3) } else { $null }
                speed = if ($speed.Count) { [math]::Round((Median $speed), 3) } else { $null }
                trust = if ($trust.Count) { [math]::Round((Median $trust), 3) } else { $null }
            }
            pctAtLeast4 = [ordered]@{
                understand = if ($understand.Count) { [math]::Round((PctAtLeast $understand 4), 2) } else { $null }
                knowWhatToDoNext = if ($next.Count) { [math]::Round((PctAtLeast $next 4), 2) } else { $null }
            }
            consent = @{
                feedbackUse = $consent
                quoteUse = $quoteConsent
            }
            adoptionIntent = $adoption
        }

        $jsonPath = Join-Path $evidenceDir ("feedback_metrics_{0}.json" -f $stamp)
        $mdPath = Join-Path $evidenceDir ("feedback_metrics_{0}.md" -f $stamp)
        $result | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $jsonPath

        @"
# Feedback Metrics Evidence ($stamp)

- Source XLSX: $($result.xlsxPath)
- Responses: $($result.responseCount)

## Means (1-5)
- Understand what SafeX detected: $($result.means.understand)
- Knew what to do next: $($result.means.knowWhatToDoNext)
- Speed felt fast enough: $($result.means.speed)
- Trust privacy posture: $($result.means.trust)

## Median (1-5)
- Understand what SafeX detected: $($result.medians.understand)
- Knew what to do next: $($result.medians.knowWhatToDoNext)

## Percent scoring >= 4
- Understand what SafeX detected: $($result.pctAtLeast4.understand)%
- Knew what to do next: $($result.pctAtLeast4.knowWhatToDoNext)%

## Consent and adoption
- Feedback use consent: $($result.consent.feedbackUse.yes)/$($result.consent.feedbackUse.total)
- Quote consent: $($result.consent.quoteUse.yes)/$($result.consent.quoteUse.total)
- Would use SafeX today (Yes-like): $($result.adoptionIntent.yes)/$($result.adoptionIntent.total)
"@ | Set-Content -Encoding UTF8 $mdPath

        Write-Output "WROTE_JSON=$jsonPath"
        Write-Output "WROTE_MD=$mdPath"
    }
    finally {
        if ($wb) { $wb.Close($false) | Out-Null }
        if ($excel) { $excel.Quit() }
        if ($used) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($used) }
        if ($ws) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($ws) }
        if ($wb) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
        if ($excel) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}
finally {
    Pop-Location
}
