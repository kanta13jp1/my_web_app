# bc58b50b #1765: PostToolUse self-correction loop for Dart files
# Fires after Write/Edit — auto dart format + flutter analyze + inject errors as additionalContext
# bc58b50b #1834: Plankton Pattern — flutter analyze routing after format

param()

$toolName = $env:CLAUDE_TOOL_NAME
if ($toolName -notin @('Write', 'Edit')) { exit 0 }

$toolInputJson = $env:CLAUDE_TOOL_INPUT
if (-not $toolInputJson) { exit 0 }

try {
    $inp = $toolInputJson | ConvertFrom-Json
    $fp = $inp.file_path
    if (-not $fp) { exit 0 }
    if (-not ($fp -like '*.dart')) { exit 0 }

    $absPath = if ([System.IO.Path]::IsPathRooted($fp)) { $fp } else {
        Join-Path (Get-Location) $fp
    }
    if (-not (Test-Path $absPath)) { exit 0 }

    $dartExe = 'C:/app/flutter/bin/dart.bat'
    if (-not (Test-Path $dartExe)) { $dartExe = 'dart' }
    $flutterExe = 'C:/app/flutter/bin/flutter.bat'
    if (-not (Test-Path $flutterExe)) { $flutterExe = 'flutter' }

    # Step 1: dart format
    $fmtResult = & $dartExe format $absPath 2>&1
    $fmtExit = $LASTEXITCODE

    if ($fmtExit -ne 0) {
        $errMsg = ($fmtResult | Out-String).Trim() -replace '"', "'"
        $output = "{`"hookSpecificOutput`":{`"additionalContext`":`"dart format failed on $fp — $errMsg. Fix formatting then re-run.`"}}"
        Write-Output $output
        exit 0
    }

    # Step 2: flutter analyze (Plankton Pattern — bc58b50b #1834)
    $analyzeResult = & $flutterExe analyze $absPath 2>&1
    $analyzeExit = $LASTEXITCODE

    if ($analyzeExit -ne 0) {
        $analyzeText = ($analyzeResult | Out-String).Trim()

        # Count errors vs warnings
        $errorLines = ($analyzeText -split "`n") | Where-Object { $_ -match '^\s*(error|Error)' }
        $warnLines  = ($analyzeText -split "`n") | Where-Object { $_ -match '^\s*(warning|Warning|info|Info)' }
        $errorCount = @($errorLines).Count
        $warnCount  = @($warnLines).Count

        # Severity classification for routing hint
        $severity = if ($errorCount -ge 3) { "COMPLEX" } elseif ($errorCount -ge 1) { "SIMPLE" } else { "WARN_ONLY" }

        $summary = ($analyzeText -split "`n" | Where-Object { $_ -match 'error|warning|info' } | Select-Object -First 8 | Out-String).Trim() -replace '"', "'"

        $hint = switch ($severity) {
            "COMPLEX"   { "3+ errors detected — consider breaking fix into smaller edits." }
            "SIMPLE"    { "1-2 errors — fix directly." }
            "WARN_ONLY" { "Warnings only — format OK, warnings can be addressed separately." }
        }

        $ctx = "flutter analyze on $fp: ${errorCount} error(s), ${warnCount} warning(s). Severity: $severity. $hint Details: $summary"
        $output = "{`"hookSpecificOutput`":{`"additionalContext`":`"$ctx`"}}"
        Write-Output $output
    }
} catch {
    # Never block on hook error
}
exit 0
