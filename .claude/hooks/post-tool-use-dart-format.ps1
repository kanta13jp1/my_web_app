# bc58b50b #1765: PostToolUse self-correction loop for Dart files
# Fires after Write/Edit — auto dart format + inject error as additionalContext

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

    $result = & $dartExe format $absPath 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $errMsg = ($result | Out-String).Trim() -replace '"', "'"
        $output = "{`"hookSpecificOutput`":{`"additionalContext`":`"dart format failed on $fp — $errMsg. Fix formatting then re-run.`"}}"
        Write-Output $output
    }
} catch {
    # Never block on hook error
}
exit 0
