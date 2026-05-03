# bc58b50b #1791: PreToolUse guard — GitHub MCP commit前にローカルlint強制実行
# Fires before mcp__github__create_or_update_file / push_files
# Prevents git hook bypass via GitHub API / WEB版 / Codex MCP commits
# Exit 2 = block the tool call; exit 0 = allow

param()

$toolInputJson = $env:CLAUDE_TOOL_INPUT
if (-not $toolInputJson) { exit 0 }

try {
    $inp = $toolInputJson | ConvertFrom-Json

    # Extract file path from GitHub MCP input (content field or path field)
    $fp = $inp.path
    if (-not $fp) { exit 0 }

    $dartExe    = 'C:/app/flutter/bin/dart.bat'
    $flutterExe = 'C:/app/flutter/bin/flutter.bat'
    if (-not (Test-Path $dartExe))    { $dartExe    = 'dart' }
    if (-not (Test-Path $flutterExe)) { $flutterExe = 'flutter' }

    # Dart files: dart format check + flutter analyze
    if ($fp -like '*.dart') {
        # Write content to temp file for analysis
        $tmpFile = [System.IO.Path]::GetTempFileName() + '.dart'
        try {
            if ($inp.content) {
                # Content is base64 encoded per GitHub API
                try {
                    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($inp.content))
                    [System.IO.File]::WriteAllText($tmpFile, $decoded)
                } catch {
                    # Not base64 or already text
                    [System.IO.File]::WriteAllText($tmpFile, $inp.content)
                }

                $fmtResult = & $dartExe format --output=none $tmpFile 2>&1
                $fmtExit = $LASTEXITCODE
                if ($fmtExit -ne 0) {
                    $errMsg = ($fmtResult | Out-String).Trim() -replace '"', "'"
                    $output = "{`"decision`":`"block`",`"reason`":`"dart format check failed for $fp — $errMsg. Run dart format before committing via GitHub MCP.`"}"
                    Write-Output $output
                    exit 2
                }

                $analyzeResult = & $flutterExe analyze $tmpFile 2>&1
                $analyzeExit = $LASTEXITCODE
                if ($analyzeExit -ne 0) {
                    $errLines = ($analyzeResult | Out-String).Trim() -replace '"', "'"
                    $output = "{`"decision`":`"block`",`"reason`":`"flutter analyze found errors in $fp — $errLines. Fix errors before committing via GitHub MCP.`"}"
                    Write-Output $output
                    exit 2
                }
            }
        } finally {
            if (Test-Path $tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
        }
    }

    # TypeScript/Deno files: deno lint check
    if ($fp -like '*.ts' -and $fp -like '*/functions/*') {
        $denoExe = 'deno'
        $tmpFile = [System.IO.Path]::GetTempFileName() + '.ts'
        try {
            if ($inp.content) {
                try {
                    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($inp.content))
                    [System.IO.File]::WriteAllText($tmpFile, $decoded)
                } catch {
                    [System.IO.File]::WriteAllText($tmpFile, $inp.content)
                }
                $lintResult = & $denoExe lint $tmpFile 2>&1
                $lintExit = $LASTEXITCODE
                if ($lintExit -ne 0) {
                    $errMsg = ($lintResult | Out-String).Trim() -replace '"', "'"
                    $output = "{`"decision`":`"block`",`"reason`":`"deno lint failed for $fp — $errMsg. Fix lint errors before committing via GitHub MCP.`"}"
                    Write-Output $output
                    exit 2
                }
            }
        } finally {
            if (Test-Path $tmpFile) { Remove-Item $tmpFile -ErrorAction SilentlyContinue }
        }
    }

} catch {
    # Never block on hook error — log and allow
    $logFile = Join-Path (Split-Path $PSScriptRoot -Parent) "hooks\pre-commit-guard-log.txt"
    Add-Content -Path $logFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ERROR: $_" -ErrorAction SilentlyContinue
}
exit 0
