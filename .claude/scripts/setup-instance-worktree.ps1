param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('vscode', 'win', 'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6', 'codex1', 'codex2')]
  [string]$Instance
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$MainRepo = 'C:/Users/kanta/GitHub/my_web_app'
if (-not (Test-Path $MainRepo)) {
  $MainRepo = (git rev-parse --show-toplevel 2>$null)
}
if (-not $MainRepo -or -not (Test-Path $MainRepo)) {
  throw 'cannot locate main repo'
}

$WorktreeDir = Join-Path $MainRepo ".claude/worktrees/instance-$Instance"
if ($Instance -like 'codex*') {
  $Branch = "codex/$Instance-wip"
} else {
  $Branch = "claude/$Instance-wip"
}

Write-Output "==> Main repo: $MainRepo"
Write-Output "==> Worktree:  $WorktreeDir"
Write-Output "==> Branch:    $Branch"

Set-Location $MainRepo
git fetch origin main --quiet

if (Test-Path $WorktreeDir) {
  Write-Output '==> Worktree already exists. Updating to latest origin/main...'
  Set-Location $WorktreeDir
  git diff-index --quiet HEAD --
  if ($LASTEXITCODE -ne 0) {
    Write-Output '    [!] uncommitted changes detected. Skipping rebase.'
    Write-Output '    [!] Commit them first, then rerun this script.'
    exit 0
  }
  git rebase origin/main
  Write-Output '==> Worktree updated.'
} else {
  Write-Output '==> Creating new worktree...'
  git show-ref --verify --quiet "refs/heads/$Branch"
  $BranchExists = ($LASTEXITCODE -eq 0)
  if ($BranchExists) {
    git worktree add $WorktreeDir $Branch
  } else {
    git worktree add -b $Branch $WorktreeDir origin/main
  }
  Write-Output '==> Worktree created.'
}

Set-Location $WorktreeDir
git config rebase.autoStash true
Write-Output '==> rebase.autoStash = true'
Write-Output ''
Write-Output 'Setup complete. Use this directory:'
Write-Output "   cd $WorktreeDir"
Write-Output ''
Write-Output "Push branch: git push -u origin $Branch"
Write-Output 'After review/integration only: git push origin HEAD:main'
