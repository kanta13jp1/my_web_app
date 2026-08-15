<#
.SYNOPSIS
  PR をマージし、成功が証明できた場合だけ対応する worktree を撤去する (merge+remove = 1 set)。

.DESCRIPTION
  ハウススタイルに合わせ --squash / --delete-branch を既定にし、--admin を通す。
  撤去の判断とガードはすべて scripts\worktree_release.ps1 側にある。本スクリプトは
  「マージが実際に成功したか」だけを見て、失敗していれば撤去に進まない。

.PARAMETER Pr
  マージする PR 番号。
.PARAMETER Repo
  owner/name。撤去側にも同じ値を渡す (別 repo の同番号 PR を見に行かせないため)。
.PARAMETER Admin
  gh pr merge に --admin を通す。
.PARAMETER DryRun
  マージせず、撤去側の判定だけを表示する。

.NOTES
  2026-07-20 新設。使い方は /pr-merge スラッシュコマンド経由を推奨。
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][int]$Pr,
  [string]$Repo = 'kanta13jp1/my_web_app',
  [switch]$Admin,
  [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Release = Join-Path $PSScriptRoot 'worktree_release.ps1'

if ($env:MWA_WORKTREE_RELEASE_DISABLED -eq '1') {
  Write-Host 'ONE-SET DISABLED (env MWA_WORKTREE_RELEASE_DISABLED=1) — run gh pr merge manually.'
  exit 0
}

# 起動時刻。ATTACK 5: 「MERGED」が今回の結果であることを後段で確かめるための基準。
# 5 分のクロックスキュー許容。
$startUtc = (Get-Date).ToUniversalTime().AddMinutes(-5)

# --- step 0: 前回までに溜まったキューを先に drain する (自己マージ / プロセスロック分)
& powershell -NoProfile -ExecutionPolicy Bypass -File $Release -DrainQueue -Apply

if ($DryRun) {
  Write-Host "DRY-RUN: would run gh pr merge $Pr --repo $Repo --squash --delete-branch"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $Release -Pr $Pr -Repo $Repo
  exit 0
}

# --- step 1: マージ
$mergeArgs = @('pr', 'merge', "$Pr", '--repo', $Repo, '--squash', '--delete-branch')
if ($Admin) { $mergeArgs += '--admin' }
& gh @mergeArgs
$mergeExit = $LASTEXITCODE

# --- step 2: 因果ゲート。ATTACK 5:
#     「already merged」でも exit 1 を返しつつ gh pr view は MERGED を返す。
#     マージが成功していないなら撤去には進まない。
if ($mergeExit -ne 0) {
  Write-Host "MERGE FAILED (exit $mergeExit) — CLEANUP SKIPPED. Nothing was removed."
  exit $mergeExit
}

# --- step 3: 撤去 (すべてのガードは worktree_release.ps1 側)
& powershell -NoProfile -ExecutionPolicy Bypass -File $Release `
    -Pr $Pr -Repo $Repo -MergedAtAfter $startUtc -Apply
exit $LASTEXITCODE
