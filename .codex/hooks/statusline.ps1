# Issue #1564: repo-managed Claude Code statusline command.
# Shows instance, active issue, branch/dirty marker, and next quality gate.

param()

$ErrorActionPreference = "SilentlyContinue"

function Invoke-GitText {
    param(
        [string]$ProjectDir,
        [string[]]$Arguments
    )

    $output = & git -C $ProjectDir @Arguments 2>$null
    if ($LASTEXITCODE -ne 0 -or $null -eq $output) {
        return ""
    }

    return ($output -join "`n").Trim()
}

function Get-FirstNonEmptyLine {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return ""
    }

    $line = Get-Content -Path $Path -ErrorAction SilentlyContinue |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1
    if ($null -eq $line) {
        return ""
    }
    return $line.Trim()
}

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$branch = Invoke-GitText $projectDir @("branch", "--show-current")
if (-not $branch) { $branch = "no-git" }

$dirtyCount = 0
$dirty = Invoke-GitText $projectDir @("status", "--short")
if ($dirty) {
    $dirtyCount = @($dirty -split "`n" | Where-Object { $_.Trim() }).Count
}

$instance = $env:CLAUDE_INSTANCE
if (-not $instance) {
    if ($branch -match '^(codex|codex1)/') {
        $instance = "win-codex"
    } elseif ($branch -match '^claude/') {
        $instance = "win-claude"
    } else {
        $instance = "unknown"
    }
}

$activeIssue = Get-FirstNonEmptyLine (Join-Path $projectDir "memory\active-issue.txt")
$nextGate = Get-FirstNonEmptyLine (Join-Path $projectDir "memory\next-quality-gate.txt")

$dirtyMark = ""
if ($dirtyCount -gt 0) {
    $dirtyMark = "*$dirtyCount"
}

$line = "[$instance]"
if ($activeIssue) {
    $line += " #$activeIssue"
}
$line += " | $branch$dirtyMark"
if ($nextGate) {
    $line += " | gate=$nextGate"
}

if ($line.Length -gt 120) {
    $line = $line.Substring(0, 117) + "..."
}

Write-Output $line
exit 0
