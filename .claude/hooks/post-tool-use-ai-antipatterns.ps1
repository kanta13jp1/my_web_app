# Issue #1773: advisory AI-generated code anti-pattern review after Write/Edit.
param()

$toolName = $env:CLAUDE_TOOL_NAME
if ($toolName -notin @('Write', 'Edit')) { exit 0 }

$toolInputJson = $env:CLAUDE_TOOL_INPUT
if (-not $toolInputJson) { exit 0 }

try {
    $inputObject = $toolInputJson | ConvertFrom-Json
    $filePath = $inputObject.file_path
    if (-not $filePath) { exit 0 }

    $repoRoot = (& git rev-parse --show-toplevel 2>$null).Trim()
    if (-not $repoRoot) { exit 0 }
    $absolutePath = if ([System.IO.Path]::IsPathRooted($filePath)) {
        $filePath
    } else {
        Join-Path $repoRoot $filePath
    }
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) { exit 0 }

    $checker = Join-Path $repoRoot 'scripts/check_ai_code_antipatterns.py'
    if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) { exit 0 }
    $review = & python $checker --repo-root $repoRoot $absolutePath 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $review) { exit 0 }

    $context = (($review | Out-String).Trim())
    @{
        hookSpecificOutput = @{
            additionalContext = $context
        }
    } | ConvertTo-Json -Compress -Depth 4
} catch {
    # Hooks must not turn an advisory check failure into a blocked edit.
}

exit 0
