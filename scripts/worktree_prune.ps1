<#
.SYNOPSIS
    Stale worktree prune for .claude/worktrees/.

.DESCRIPTION
    Detects stale worktrees that are safe to remove and reports / prunes them.
    Safe = 0 uncommitted + branch tracked or merged + no open PR + not current dir.
    Risky = uncommitted / detached HEAD / open PR / current dir → SKIP.

    Default mode = --dry-run (= report only). Use --Apply to actually prune.

.PARAMETER Apply
    Apply the prune (= delete worktree dir + git worktree remove).
    Without this flag, runs in dry-run mode (= report only).

.PARAMETER Force
    Skip uncommitted-changes guard (= dangerous / use only when sure).

.NOTES
    Win版#132 part 160-b 2026-05-07. Win Claude territory (= hygiene infra / docs).
    [WORKDIR-ISOLATION] safety = manual slash command only / NOT auto-hook.
    Reference: docs/DISK_HYGIENE_RUNBOOK.md §4.
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error 'Not in a git repo'
    exit 1
}

# Locate canonical worktree dir (= main repo's .claude/worktrees/)
# Always operate from the main checkout to avoid recursion when invoked from a worktree.
$mainWorktreeRoot = git worktree list 2>$null |
    Select-Object -First 1 |
    ForEach-Object { ($_ -split '\s+')[0] }
if (-not $mainWorktreeRoot) { $mainWorktreeRoot = $repoRoot }

$worktreesDir = Join-Path $mainWorktreeRoot '.claude/worktrees'
if (-not (Test-Path $worktreesDir)) {
    Write-Host "No worktrees dir at $worktreesDir"
    exit 0
}

$selfPath = (Get-Location).Path -replace '\\', '/'

# Collect open PR head branches (= keep these worktrees)
$openPrBranches = @()
try {
    $prJson = gh pr list --state open --json headRefName 2>$null
    if ($prJson) {
        $openPrBranches = ($prJson | ConvertFrom-Json) | ForEach-Object { $_.headRefName }
    }
} catch {
    Write-Warning "gh pr list failed; falling back to repo state only"
}

$reportRows = @()
$totalReclaimMB = 0

Get-ChildItem -Directory $worktreesDir | ForEach-Object {
    $wt = $_.FullName
    $wtName = $_.Name
    $wtPathFwd = $wt -replace '\\', '/'

    # 1. Self check
    if ($selfPath -like "$wtPathFwd*") {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason='self (current dir)'; size_mb=0; branch=''; uncommitted=0 }
        return
    }

    # 2. Branch
    $branch = git -C $wt rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason='git inaccessible'; size_mb=0; branch=''; uncommitted=0 }
        return
    }

    # 3. Detached HEAD = SKIP (codex worktrees frequently use this)
    if ($branch -eq 'HEAD') {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason='detached HEAD (active codex/manual?)'; size_mb=0; branch='HEAD'; uncommitted=0 }
        return
    }

    # 4. Uncommitted changes = SKIP unless --Force
    $uncommittedLines = @(git -C $wt status -s 2>$null)
    $uncommitted = $uncommittedLines.Count
    if ($uncommitted -gt 0 -and -not $Force) {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason="uncommitted=$uncommitted (use -Force to override)"; size_mb=0; branch=$branch; uncommitted=$uncommitted }
        return
    }

    # 5. Open PR = SKIP
    if ($openPrBranches -contains $branch) {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason='open PR'; size_mb=0; branch=$branch; uncommitted=$uncommitted }
        return
    }

    # 6. main branch worktree = SKIP (= jolly-nash type)
    if ($branch -eq 'main' -or $branch -eq 'master') {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason='main branch worktree'; size_mb=0; branch=$branch; uncommitted=$uncommitted }
        return
    }

    # 6.5. Unmerged commits = SKIP (= branch has commits not on main → would lose work)
    $aheadCount = 0
    try {
        $aheadCount = [int](git -C $wt rev-list main..$branch --count 2>$null)
    } catch { $aheadCount = -1 }
    if ($aheadCount -gt 0 -and -not $Force) {
        $reportRows += [pscustomobject]@{ name=$wtName; decision='SKIP'; reason="ahead of main by $aheadCount commits (use -Force to override)"; size_mb=0; branch=$branch; uncommitted=$uncommitted }
        return
    }

    # 7. Size
    $sizeMb = 0
    try {
        $sizeMb = [math]::Round((Get-ChildItem -Recurse -File -Force $wt -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum / 1MB, 1)
    } catch { $sizeMb = -1 }

    # 8. PRUNE
    $reportRows += [pscustomobject]@{ name=$wtName; decision='PRUNE'; reason='safe: no PR + no uncommitted + non-main'; size_mb=$sizeMb; branch=$branch; uncommitted=$uncommitted }
    $totalReclaimMB += $sizeMb
}

Write-Host ''
Write-Host '=== Worktree Prune Report ===' -ForegroundColor Cyan
$reportRows | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ''
$pruneCount = ($reportRows | Where-Object { $_.decision -eq 'PRUNE' }).Count
Write-Host "Candidates to prune: $pruneCount"
Write-Host ("Estimated reclaim:   {0:N1} MB" -f $totalReclaimMB)

if (-not $Apply) {
    Write-Host ''
    Write-Host 'DRY-RUN mode. Re-run with -Apply to actually prune.' -ForegroundColor Yellow
    exit 0
}

# APPLY
Write-Host ''
Write-Host '=== Applying prune ===' -ForegroundColor Yellow
$pruneList = $reportRows | Where-Object { $_.decision -eq 'PRUNE' }
foreach ($row in $pruneList) {
    $wt = Join-Path $worktreesDir $row.name
    Write-Host "  removing $($row.name) (= $($row.branch) / $($row.size_mb) MB)"
    try {
        # Use git worktree remove to keep .git/worktrees/ metadata clean
        git -C $mainWorktreeRoot worktree remove --force $wt 2>&1 | Out-Null
    } catch {
        Write-Warning "git worktree remove failed for $($row.name); falling back to dir delete"
        Remove-Item -Recurse -Force $wt -ErrorAction SilentlyContinue
    }
}

# Final cleanup
git -C $mainWorktreeRoot worktree prune 2>&1 | Out-Null

Write-Host ''
Write-Host ("Prune complete. Reclaimed ~{0:N1} MB across {1} worktrees." -f $totalReclaimMB, $pruneCount) -ForegroundColor Green
