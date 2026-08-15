# bc58b50b #1765: PostToolUse self-correction loop for Dart files
# Fires after apply_patch/Write/Edit — auto dart format + flutter analyze + inject errors as additionalContext
# bc58b50b #1834: Plankton Pattern — flutter analyze routing after format

param()

$hookInputJson = [Console]::In.ReadToEnd()
$toolName = $env:CLAUDE_TOOL_NAME
$toolInputJson = $env:CLAUDE_TOOL_INPUT

try {
    if ($hookInputJson) {
        $hookInput = $hookInputJson | ConvertFrom-Json
        $toolName = $hookInput.tool_name
        $inp = $hookInput.tool_input
    } elseif ($toolInputJson) {
        # Backward compatibility when the same hook is invoked by Claude Code.
        $inp = $toolInputJson | ConvertFrom-Json
    } else {
        exit 0
    }

    if ($toolName -notin @('apply_patch', 'Write', 'Edit')) { exit 0 }

    $filePaths = @()
    if ($inp.file_path) { $filePaths += $inp.file_path }
    if ($inp.path) { $filePaths += $inp.path }
    if ($toolName -eq 'apply_patch' -and $inp.command) {
        $patchMatches = [regex]::Matches(
            [string]$inp.command,
            '(?m)^\*\*\* (?:Add|Update) File: (.+\.dart)\s*$'
        )
        $filePaths += @($patchMatches | ForEach-Object { $_.Groups[1].Value.Trim() })
    }

    $filePaths = @($filePaths | Where-Object { $_ -like '*.dart' } | Select-Object -Unique)
    if ($filePaths.Count -eq 0) { exit 0 }

    foreach ($fp in $filePaths) {

        $absPath = if ([System.IO.Path]::IsPathRooted($fp)) { $fp } else {
            Join-Path (Get-Location) $fp
        }
        if (-not (Test-Path $absPath)) { continue }

    $dartExe = 'C:/app/flutter/bin/dart.bat'
    if (-not (Test-Path $dartExe)) { $dartExe = 'dart' }
    $flutterExe = 'C:/app/flutter/bin/flutter.bat'
    if (-not (Test-Path $flutterExe)) { $flutterExe = 'flutter' }

    # Step 1: dart format
    $fmtResult = & $dartExe format $absPath 2>&1
    $fmtExit = $LASTEXITCODE

    if ($fmtExit -ne 0) {
        $errMsg = ($fmtResult | Out-String).Trim() -replace '"', "'"
            $output = @{
                hookSpecificOutput = @{
                    hookEventName = 'PostToolUse'
                    additionalContext = "dart format failed on $fp — $errMsg. Fix formatting then re-run."
                }
            } | ConvertTo-Json -Compress -Depth 4
            Write-Output $output
            continue
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

        $ctx = "flutter analyze on ${fp}: ${errorCount} error(s), ${warnCount} warning(s). Severity: $severity. $hint Details: $summary"
            $output = @{
                hookSpecificOutput = @{
                    hookEventName = 'PostToolUse'
                    additionalContext = $ctx
                }
            } | ConvertTo-Json -Compress -Depth 4
            Write-Output $output
        }
    }
} catch {
    # Never block on hook error
}
exit 0
