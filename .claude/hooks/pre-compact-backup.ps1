# bc58b50b #1848: PreCompact hook - transcript backup before context compaction
# AI_FLEET_SYNERGY Principle #5: Memory & State Continuity Hooks
# Issue #1564: add resumable metadata and secret redaction.

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

function ConvertTo-YamlScalar {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "''"
    }

    return "'" + ($Value -replace "'", "''") + "'"
}

function Redact-SessionText {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $redacted = $Text
    $patterns = @(
        @{ Pattern = 'gh[opsu]_[A-Za-z0-9_]{20,}'; Replacement = '[REDACTED_GITHUB_TOKEN]' },
        @{ Pattern = 'Bearer\s+[A-Za-z0-9._-]{20,}'; Replacement = 'Bearer [REDACTED]' },
        @{ Pattern = 'sk-[A-Za-z0-9_-]{20,}'; Replacement = 'sk-[REDACTED]' },
        @{ Pattern = 'sb_[A-Za-z0-9_]{20,}'; Replacement = 'sb_[REDACTED]' },
        @{ Pattern = '(?i)\b([A-Z0-9_]*(PASSWORD|SECRET|TOKEN|KEY)[A-Z0-9_]*\s*=\s*)[^\s,;]+'; Replacement = '$1[REDACTED]' }
    )

    foreach ($item in $patterns) {
        $redacted = [regex]::Replace(
            $redacted,
            [string]$item.Pattern,
            [string]$item.Replacement
        )
    }

    return $redacted
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

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$datestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { $projectDir = (Get-Location).Path }

$transcriptDir = Join-Path $projectDir "memory\transcripts"
if (-not (Test-Path $transcriptDir)) {
    New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
}

$compactSummary = Redact-SessionText $env:CLAUDE_COMPACT_TRIGGER_SUMMARY
$branch = Invoke-GitText $projectDir @("branch", "--show-current")
$headSha = Invoke-GitText $projectDir @("rev-parse", "--short", "HEAD")
$dirtyText = Invoke-GitText $projectDir @("status", "--short")
$dirty = @($dirtyText -split "`n" | Where-Object { $_.Trim() })
$upstream = Invoke-GitText $projectDir @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
$unpushedCommits = "0"
if ($upstream) {
    $unpushedCommits = Invoke-GitText $projectDir @("rev-list", "${upstream}..HEAD", "--count")
    if (-not $unpushedCommits) { $unpushedCommits = "0" }
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

$activeIssue = $env:ACTIVE_ISSUE
if (-not $activeIssue) {
    $activeIssue = Get-FirstNonEmptyLine (Join-Path $projectDir "memory\active-issue.txt")
}

$activePr = $env:ACTIVE_PR
if (-not $activePr) {
    $activePr = $env:PR_NUMBER
}

$gatePath = Join-Path $projectDir "memory\next-quality-gate.txt"
$qualityGates = @()
if (Test-Path $gatePath) {
    $qualityGates = @(Get-Content -Path $gatePath -ErrorAction SilentlyContinue |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 5)
}
if ($qualityGates.Count -eq 0) {
    $qualityGates = @(
        "python scripts/codex_session_check.py --json",
        "git diff --check",
        "gh pr checks"
    )
}

$dirtyYaml = @()
if ($dirty.Count -eq 0) {
    $dirtyYaml += "uncommitted_files: []"
} else {
    $dirtyYaml += "uncommitted_files:"
    foreach ($line in $dirty) {
        $dirtyYaml += "  - $(ConvertTo-YamlScalar $line)"
    }
}

$gateYaml = @("next_quality_gates:")
foreach ($gate in $qualityGates) {
    $gateYaml += "  - $(ConvertTo-YamlScalar $gate)"
}

$frontmatter = @(
    "---",
    "saved_at: $(ConvertTo-YamlScalar ($datestamp + ' local'))",
    "instance: $(ConvertTo-YamlScalar $instance)",
    "two_instance_policy: $(ConvertTo-YamlScalar 'Win Claude + Win Codex only')",
    "worktree: $(ConvertTo-YamlScalar $projectDir)",
    "branch: $(ConvertTo-YamlScalar $branch)",
    "head_sha: $(ConvertTo-YamlScalar $headSha)",
    "in_progress_issue: $(ConvertTo-YamlScalar $activeIssue)",
    "active_pr: $(ConvertTo-YamlScalar $activePr)"
) + $gateYaml + $dirtyYaml + @(
    "unpushed_commits: $unpushedCommits",
    "---"
)

$outFile = Join-Path $transcriptDir "compact-$timestamp.md"

try {
    $content = @"
$($frontmatter -join "`n")

# Compact Backup - $datestamp

## Summary (AI-generated before compact)
$compactSummary

## Recovery Notes
- Read the YAML frontmatter first for branch, issue, dirty paths, and quality gates.
- Run `python scripts/codex_session_check.py --json` from the worktree before edits.
- Keep the active fleet to Win Claude + Win Codex only; do not revive old Codex #2/#3 lanes.
- Treat this file as redacted session memory, not a credential store.

## Key Reference Files
- `.claude/settings.json` - managed hooks and statusline command.
- `memory/active-issue.txt` - current issue marker when present.
- `memory/next-quality-gate.txt` - next local or CI gate marker when present.
- `docs/CLAUDE_CODE_SETUP_RUNBOOK.md` - init and maintenance separation.
"@
    [System.IO.File]::WriteAllText($outFile, $content, [System.Text.Encoding]::UTF8)

    $logFile = Join-Path $transcriptDir "compact-log.txt"
    Add-Content -Path $logFile -Value "[$datestamp] PreCompact backup: $outFile" -ErrorAction SilentlyContinue
} catch {
    # Hooks must never block the host session.
}

exit 0
