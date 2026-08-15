<#
.SYNOPSIS
  マージ済み PR に対応する worktree を 1 本だけ安全に撤去する (merge+remove = 1 set の後半)。

.DESCRIPTION
  [WORKDIR-ISOLATION] safety = 明示的な /pr-merge / /worktree-sweep からのみ -Apply で呼ぶ。
  hook からは -Apply を付けない (hook が持てる権限は queue への append と報告のみ)。
  scripts\worktree_prune.ps1 は本スクリプトから一切呼ばない (manual-only 契約を維持する)。
  既定は dry-run。-Apply を明示した時だけ削除する。

.PARAMETER Pr
  対象の PR 番号。
.PARAMETER Repo
  gh の --repo に渡す owner/name。マージ側と同じ値を必ず通すこと。
.PARAMETER MergedAtAfter
  この UTC 時刻より後に mergedAt が無いと撤去しない (因果チェック)。
.PARAMETER DrainQueue
  .cache\worktree-removal-queue.jsonl を再検証しながら処理する。

.NOTES
  2026-07-20 新設。C:\tmp に 146 worktree / 14 GB 滞留した事象への恒久対策 (merge+remove=1set)。
  設計は 4 案の判定 + 6 方向レッドチームを経ている。各ガードのコメント末尾の ATTACK n は
  その guard が塞いでいる攻撃シナリオを指す。ガードを外す前に必ずそれを読むこと。
#>
[CmdletBinding()]
param(
  [int]$Pr = 0,
  [string]$Repo = '',
  [datetime]$MergedAtAfter = [datetime]::MinValue,
  [switch]$DrainQueue,
  [switch]$Apply,
  [switch]$NoProcessProbe
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# KILL SWITCH — 環境変数 or sentinel ファイルで即時無効化
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path -Parent $PSScriptRoot
$CacheDir = Join-Path $RepoRoot '.cache'
if ($env:MWA_WORKTREE_RELEASE_DISABLED -eq '1') {
  Write-Host 'WORKTREE RELEASE DISABLED (env MWA_WORKTREE_RELEASE_DISABLED=1) — nothing done.'
  exit 0
}
if (Test-Path (Join-Path $CacheDir 'worktree-release.DISABLED')) {
  Write-Host 'WORKTREE RELEASE DISABLED (.cache\worktree-release.DISABLED present) — nothing done.'
  exit 0
}

# ---------------------------------------------------------------------------
# 定数
# ---------------------------------------------------------------------------

# 生成物 allowlist: これだけの dirty は「作業ではない」とみなす。
# ATTACK 1 / 判定: pubspec.lock は意図的に除外する。手編集が入りうるレビュー対象ファイルであり
# これを noise 扱いすると allowlist が「正確化」ではなく「弱体化」になる。
$GENERATED_PATTERNS = @(
  '*generated_plugin_registrant.cc',
  '*generated_plugin_registrant.h',
  '*GeneratedPluginRegistrant.swift',
  '*generated_plugins.cmake'
)

# ignored ファイルのうち「捨ててよい」ビルド生成物 denylist。
# ATTACK 1 (核心): git status --porcelain は ignored を出さないが
# git worktree remove --force は消す。.env / evidence/ / videos/ / .mcp.json は
# git のどこにも存在しないため attic ですら再構成できない。
# よって「ignored で、かつこの denylist に載っていない」ものが 1 つでもあれば QUARANTINE。
#
# NOTE: git は ignored をディレクトリ単位に畳んで報告するため、エントリは
#       'build/' のような repo ルート相対パスで来る。サブディレクトリに畳まれた
#       ケース ('scripts/__pycache__/') も拾えるよう、名前ベースのものは
#       '*<name>' と '*<name>/*' の両方を置くこと。片方だけだと誤検知して
#       健全な worktree が永久 QUARANTINE になる (2026-07-20 実測で 2 件発生)。
$BUILD_ARTIFACT_PATTERNS = @(
  '.dart_tool/*', '.dart_tool', 'build/*', 'build',
  'node_modules/*', 'node_modules', '*/node_modules', '*/node_modules/*',
  '*ephemeral/*', '*ephemeral',
  '.gradle/*', '.gradle', '*.gradle', '*.gradle/*',
  '__pycache__/*', '__pycache__', '*__pycache__', '*__pycache__/*',
  '.venv/*', '.venv', '.pytest_cache/*', '.pytest_cache',
  '*.pytest_cache', '*.pytest_cache/*',
  '.playwright-mcp/*', '.playwright-mcp',
  'coverage/*', 'coverage',
  'android/local.properties',
  # Flutter が生成する Android プラグイン登録先。android/.gitignore:8 で ignore されており
  # 中身は GeneratedPluginRegistrant.java のみ。flutter pub get で必ず再生成される。
  'android/app/src/main/java', 'android/app/src/main/java/*',
  'ios/Flutter/Generated.xcconfig',
  'ios/Flutter/flutter_export_environment.sh',
  '*GeneratedPluginRegistrant.*',
  '.flutter-plugins*',
  '*.png'
)

$PROTECTED_BRANCHES = @('main', 'master', 'develop', 'staging')

$AtticRoot     = Join-Path $env:USERPROFILE '.claude\state\worktree-attic'
$QueuePath     = Join-Path $CacheDir 'worktree-removal-queue.jsonl'
$QuarPath      = Join-Path $CacheDir 'worktree-quarantine.jsonl'
$HeartbeatPath = Join-Path $CacheDir 'worktree-lastremoval.json'
$LockPath      = Join-Path $CacheDir 'worktree-release.lock'

# ---------------------------------------------------------------------------
# ヘルパ
# ---------------------------------------------------------------------------
function Invoke-Native {
  param([string]$Exe, [string[]]$Arguments)
  $out = & $Exe @Arguments 2>$null
  $code = $LASTEXITCODE
  if ($null -eq $out) { $out = @() }
  return [pscustomobject]@{ Code = $code; Out = @($out); Text = ([string]::Join("`n", @($out))) }
}

function Write-Loud {
  # ATTACK 6: fail-closed が静かだと「今日の問題」に無音で退行する。必ず理由付きで叫ぶ。
  param([string]$Verdict, [string]$Reason)
  Write-Host ("WORKTREE RELEASE {0}: {1}" -f $Verdict, $Reason)
}

function ConvertTo-PosixPath {
  param([string]$WinPath)
  $p = $WinPath -replace '\\', '/'
  if ($p -match '^([A-Za-z]):(.*)$') { return ('/' + $Matches[1].ToLower() + $Matches[2]) }
  return $p
}

function Test-SameOrChild {
  # ATTACK 3: 自分が立っているディレクトリを消さない。cwd 保護。
  param([string]$Parent, [string]$Child)
  if ([string]::IsNullOrWhiteSpace($Parent) -or [string]::IsNullOrWhiteSpace($Child)) { return $false }
  $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\')
  $c = [System.IO.Path]::GetFullPath($Child).TrimEnd('\')
  if ($p -eq $c) { return $true }
  return $c.StartsWith($p + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-MatchesAny {
  param([string]$Value, [string[]]$Patterns)
  foreach ($pat in $Patterns) {
    if ($Value -like $pat) { return $true }
  }
  return $false
}

function Get-GitBash {
  # ATTACK 4: 長いパス。PowerShell 5.1 + LongPathsEnabled=0 では 260 文字の壁に当たるが
  # git-bash (msys2 runtime) の tar は超えられる。attic の書き込みは必ずこちらで行う。
  $g = Get-Command git -ErrorAction SilentlyContinue
  if ($null -eq $g) { return $null }
  $gitHome = Split-Path (Split-Path $g.Source -Parent) -Parent
  foreach ($rel in @('bin\bash.exe', 'usr\bin\bash.exe')) {
    $cand = Join-Path $gitHome $rel
    if (Test-Path $cand) { return $cand }
  }
  return $null
}

function Add-JsonLine {
  # ATTACK 3: 追記は単一 O_APPEND 書き込みで行い、read-modify-write をしない。
  param([string]$Path, [object]$Object)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $line = ($Object | ConvertTo-Json -Compress -Depth 8) + "`n"
  [System.IO.File]::AppendAllText($Path, $line, (New-Object System.Text.UTF8Encoding($false)))
}

function Write-AtomicFile {
  # ATTACK 3: 共有状態は temp + Move で置換する。途中クラッシュで壊れた JSON を残さない。
  param([string]$Path, [string]$Content)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $tmp = "$Path.tmp.$PID"
  [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $tmp -Destination $Path -Force
}

# ---------------------------------------------------------------------------
# single-writer mutex (ATTACK 3: 2 つの cleanup が同じ worktree を消し合う / registry lost update)
# ---------------------------------------------------------------------------
$script:LockStream = $null
function Enter-ReleaseLock {
  if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }
  if (Test-Path $LockPath) {
    $age = (Get-Date) - (Get-Item $LockPath).LastWriteTime
    if ($age.TotalMinutes -gt 10) {
      Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
  }
  try {
    $script:LockStream = [System.IO.File]::Open($LockPath, 'CreateNew', 'Write', 'None')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("pid=$PID ts=$((Get-Date).ToString('o'))")
    $script:LockStream.Write($bytes, 0, $bytes.Length)
    $script:LockStream.Flush()
    return $true
  } catch {
    return $false
  }
}
function Exit-ReleaseLock {
  if ($null -ne $script:LockStream) {
    $script:LockStream.Close()
    $script:LockStream = $null
  }
  Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# worktree 列挙 (registry は使わない)
# ATTACK 5: .cache\worktree-registry.json は 67 日陳腐化しており、
#           branch -> path の解決に使うと存在しないパスや再利用されたパスを指す。
#           唯一の真実は git worktree list --porcelain。
# ---------------------------------------------------------------------------
function Get-WorktreeEntries {
  $r = Invoke-Native -Exe 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'list', '--porcelain')
  if ($r.Code -ne 0) { return @() }
  $entries = @()
  $cur = $null
  foreach ($line in $r.Out) {
    if ($line -like 'worktree *') {
      if ($null -ne $cur) { $entries += $cur }
      $cur = [pscustomobject]@{
        Path = ($line.Substring(9) -replace '/', '\'); Branch = ''; Detached = $false; Locked = $false; Bare = $false
      }
    } elseif ($line -like 'branch *') {
      $cur.Branch = ($line.Substring(7) -replace '^refs/heads/', '')
    } elseif ($line -eq 'detached') { $cur.Detached = $true }
    elseif ($line -like 'locked*')  { $cur.Locked = $true }
    elseif ($line -eq 'bare')       { $cur.Bare = $true }
  }
  if ($null -ne $cur) { $entries += $cur }
  return $entries
}

# ---------------------------------------------------------------------------
# ガード群
# ---------------------------------------------------------------------------

function Get-DirtyVerdict {
  # 可視 dirty: 生成物 allowlist に載っていない行が 1 本でもあれば作業ありとみなす。
  param([string]$Path)
  $r = Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'status', '--porcelain')
  if ($r.Code -ne 0) { return @('<git status failed>') }   # fail-closed
  $real = @()
  foreach ($line in $r.Out) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.Length -le 3) { continue }
    $file = $line.Substring(3).Trim().Trim('"')
    if ($file -like '* -> *') { $file = ($file -split ' -> ')[-1] }
    if (-not (Test-MatchesAny -Value $file -Patterns $GENERATED_PATTERNS)) { $real += $line }
  }
  return $real
}

function Get-PreciousIgnored {
  # ATTACK 1: ignored かつ build 生成物でないもの = git のどこにも無い唯一の写し。
  # --ignored は traditional (ディレクトリ単位に畳む) を使う。build/ 配下を個別列挙しないため速い。
  param([string]$Path)
  $r = Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'status', '--porcelain', '--ignored')
  if ($r.Code -ne 0) { return @('<git status --ignored failed>') }   # fail-closed
  $precious = @()
  foreach ($line in $r.Out) {
    if (-not ($line -like '!!*')) { continue }
    $file = $line.Substring(3).Trim().Trim('"')
    $probe = $file.TrimEnd('/')
    if (-not (Test-MatchesAny -Value $probe -Patterns $BUILD_ARTIFACT_PATTERNS)) { $precious += $file }
  }
  return $precious
}

function Get-OpenPrBranches {
  # ATTACK 6: gh 失敗時に空集合を返すと fail-OPEN になる。
  # ここでは「不明」を $null で表し、-Apply 時は不明なら中断する。
  param([string]$RepoArg)
  if ($null -eq (Get-Command gh -ErrorAction SilentlyContinue)) { return $null }
  # NOTE: $args は PowerShell の自動変数。ここでは絶対に使わない ($ghArgs を使う)。
  $ghArgs = @('pr', 'list', '--state', 'open', '--limit', '200', '--json', 'headRefName')
  if (-not [string]::IsNullOrWhiteSpace($RepoArg)) { $ghArgs += @('--repo', $RepoArg) }
  $r = Invoke-Native -Exe 'gh' -Arguments $ghArgs
  if ($r.Code -ne 0) { return $null }
  try { $payload = $r.Text | ConvertFrom-Json } catch { return $null }
  $set = @{}
  foreach ($item in @($payload)) { if ($item.headRefName) { $set[$item.headRefName] = $true } }
  return $set
}

function Test-FlutterProcessInside {
  # ATTACK 4: dart.exe / flutter_tester.exe が .dart_tool\...\.lock を
  # FILE_SHARE_DELETE 無しで掴んでいると unlink が ERROR_SHARING_VIOLATION になり、
  # git は remove_dir_recurse を break する = 途中まで消えた木が残り、
  # 次回以降 "D " だらけで永久 quarantine 化する。事前に見る。
  param([string]$Path)
  if ($NoProcessProbe) { return @() }
  $names = "Name='dart.exe' OR Name='dartvm.exe' OR Name='dartaotruntime.exe' OR Name='flutter_tester.exe' OR Name='gradle.exe' OR Name='java.exe'"
  try {
    $procs = Get-CimInstance Win32_Process -Filter $names -ErrorAction Stop
  } catch {
    return @()
  }
  $hits = @()
  foreach ($p in $procs) {
    if ($null -ne $p.CommandLine -and $p.CommandLine -like "*$Path*") {
      $hits += ("{0} (pid {1})" -f $p.Name, $p.ProcessId)
    }
  }
  return $hits
}

# ---------------------------------------------------------------------------
# attic (archive-before-remove)
# ---------------------------------------------------------------------------
function Write-Attic {
  # ATTACK 4: attic のパスをブランチ名から作ると 268 文字になり PathTooLongException で
  # 「一番消したい worktree だけが永久に消せない」。ハッシュ固定長にする。
  param([string]$Path, [string]$Branch, [int]$PrNumber, [string]$HeadRefOid, [string[]]$ExtraFiles)

  $sha1 = New-Object System.Security.Cryptography.SHA1Managed
  $sha = [System.BitConverter]::ToString(
    $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Branch))).Replace('-', '').ToLower().Substring(0, 12)
  $stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $dest = Join-Path $AtticRoot ("$sha-$stamp")
  New-Item -ItemType Directory -Force -Path $dest | Out-Null

  $headSha = (Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'rev-parse', 'HEAD')).Text.Trim()
  $originUrl = (Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'remote', 'get-url', 'origin')).Text.Trim()

  $wt = (Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'diff', 'HEAD')).Text
  $idx = (Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'diff', '--cached')).Text
  [System.IO.File]::WriteAllText((Join-Path $dest 'worktree.diff'), $wt, (New-Object System.Text.UTF8Encoding($false)))
  [System.IO.File]::WriteAllText((Join-Path $dest 'index.diff'),    $idx, (New-Object System.Text.UTF8Encoding($false)))

  # untracked (非 ignored) + guard が拾った precious ignored。
  # 前者は git が再構成できないため必ず要る。後者は本来 QUARANTINE で止まるので通常は空だが、
  # 将来 allowlist が緩んだ場合の保険として同じ tar に入れる。
  $others = (Invoke-Native -Exe 'git' -Arguments @('-C', $Path, 'ls-files', '-o', '--exclude-standard')).Out
  $list = @()
  foreach ($f in $others) { if (-not [string]::IsNullOrWhiteSpace($f)) { $list += $f } }
  foreach ($f in @($ExtraFiles)) { if (-not [string]::IsNullOrWhiteSpace($f)) { $list += $f.TrimEnd('/') } }
  $list = @($list | Select-Object -Unique)

  $tarOk = $true
  if ($list.Count -gt 0) {
    $bash = Get-GitBash
    if ($null -eq $bash) {
      $tarOk = $false
    } else {
      $listFile = Join-Path $dest 'untracked.list'
      [System.IO.File]::WriteAllText($listFile, ([string]::Join("`n", $list) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
      $cmd = "cd '$(ConvertTo-PosixPath $Path)' && tar -cf '$(ConvertTo-PosixPath (Join-Path $dest 'untracked.tar'))' -T '$(ConvertTo-PosixPath $listFile)'"
      $t = Invoke-Native -Exe $bash -Arguments @('-lc', $cmd)
      if ($t.Code -ne 0) { $tarOk = $false }
    }
  }

  $meta = [pscustomobject]@{
    ts = (Get-Date).ToUniversalTime().ToString('o')
    pr = $PrNumber; branch = $Branch; path = $Path
    head_sha = $headSha; pr_head_oid = $HeadRefOid; origin = $originUrl
    untracked_count = $list.Count
  }
  Write-AtomicFile -Path (Join-Path $dest 'meta.json') -Content ($meta | ConvertTo-Json -Depth 6)

  if (-not $tarOk) { return $null }
  if (-not (Test-Path (Join-Path $dest 'meta.json'))) { return $null }
  return $dest
}

function Invoke-AtticRetention {
  # ATTACK 6: 30 日保持を手動 Tier 2 に置くと「安全網が次の C:\tmp」になる。書き手側で刈る。
  if (-not (Test-Path $AtticRoot)) { return }
  $cutoff = (Get-Date).AddDays(-30)
  Get-ChildItem -LiteralPath $AtticRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------------------------------------------------------------------------
# 本体: 1 PR を評価して(必要なら)撤去する
# ---------------------------------------------------------------------------
function Invoke-Release {
  param(
    [int]$PrNumber,
    [string]$RepoArg,
    [datetime]$AfterUtc,
    [string]$ExpectedHeadRefOid = ''
  )

  # --- GUARD 1: マージの「証明」。マージ意図 (intent) は結果 (outcome) ではない。必ず gh に問い直す。
  $ghArgs = @('pr', 'view', "$PrNumber", '--json', 'state,mergedAt,headRefName,headRefOid')
  if (-not [string]::IsNullOrWhiteSpace($RepoArg)) { $ghArgs += @('--repo', $RepoArg) }
  $gr = Invoke-Native -Exe 'gh' -Arguments $ghArgs
  if ($gr.Code -ne 0) {
    Write-Loud 'CLEANUP SKIPPED' "gh pr view #$PrNumber failed (exit $($gr.Code)) — merge state unverifiable"
    return 2
  }
  try { $pr = $gr.Text | ConvertFrom-Json } catch {
    Write-Loud 'CLEANUP SKIPPED' "gh pr view #$PrNumber returned unparseable JSON"
    return 2
  }
  if ($pr.state -ne 'MERGED') {
    Write-Loud 'CLEANUP SKIPPED' "PR #$PrNumber state=$($pr.state) (not MERGED)"
    return 0
  }
  if ([string]::IsNullOrWhiteSpace([string]$pr.mergedAt)) {
    Write-Loud 'CLEANUP SKIPPED' "PR #$PrNumber has no mergedAt"
    return 0
  }

  # --- GUARD 2: 因果。ATTACK 5 — 「MERGED」は「今このコマンドがマージした」の証明ではない。
  #     PR 番号を 1 桁打ち間違えると数十日前にマージ済みの PR が MERGED を返し、
  #     無関係な worktree が消える。mergedAt が起動時刻より後であることを要求する。
  $mergedAtUtc = ([datetime]$pr.mergedAt).ToUniversalTime()
  if ($AfterUtc -ne [datetime]::MinValue -and $mergedAtUtc -lt $AfterUtc) {
    Write-Loud 'CLEANUP SKIPPED' "PR #$PrNumber mergedAt=$($pr.mergedAt) predates this invocation — not caused by this merge"
    return 0
  }

  $branch = [string]$pr.headRefName
  $oid    = [string]$pr.headRefOid

  # --- GUARD 3: ATTACK 3 — ブランチ再作成レース。queue から drain する場合は
  #     enqueue 時に保存した headRefOid と一致することを要求する。
  if (-not [string]::IsNullOrWhiteSpace($ExpectedHeadRefOid) -and $ExpectedHeadRefOid -ne $oid) {
    Write-Loud 'CLEANUP SKIPPED' "PR #$PrNumber headRefOid changed since enqueue ($ExpectedHeadRefOid -> $oid)"
    return 0
  }

  if (Test-MatchesAny -Value $branch -Patterns $PROTECTED_BRANCHES) {
    Write-Loud 'CLEANUP SKIPPED' "protected branch $branch"
    return 0
  }

  # --- GUARD 4: パス解決。ATTACK 5 — registry は使わない。porcelain のみ。
  $entries = Get-WorktreeEntries
  $hits = @($entries | Where-Object { $_.Branch -eq $branch })
  if ($hits.Count -eq 0) {
    Write-Loud 'CLEANUP NOT NEEDED' "no worktree registered for branch $branch"
    return 0
  }
  if ($hits.Count -gt 1) {
    Write-Loud 'CLEANUP SKIPPED' "ambiguous: $($hits.Count) worktrees claim branch $branch"
    return 0
  }
  $target = $hits[0]
  $path = $target.Path

  # --- GUARD 5: 解決したパスの自己申告を突き合わせる (resolver を guard 依存にしない)
  $curBranch = (Invoke-Native -Exe 'git' -Arguments @('-C', $path, 'rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()
  if ($curBranch -ne $branch) {
    Write-Loud 'CLEANUP SKIPPED' "path $path is on '$curBranch', not '$branch'"
    return 0
  }

  # --- GUARD 6: 同じリポジトリか (ATTACK 5: --repo を通さない検証は別 repo の PR #n を見てしまう)
  $originUrl = (Invoke-Native -Exe 'git' -Arguments @('-C', $path, 'remote', 'get-url', 'origin')).Text.Trim()
  if (-not [string]::IsNullOrWhiteSpace($RepoArg)) {
    $slug = $RepoArg.Trim()
    if ($originUrl -notlike "*$slug*") {
      Write-Loud 'CLEANUP SKIPPED' "origin '$originUrl' of $path does not match --repo $slug"
      return 0
    }
  }

  # --- GUARD 7: 構造ガード
  if ($target.Bare)     { Write-Loud 'CLEANUP SKIPPED' "bare worktree $path"; return 0 }
  if ($target.Detached) { Write-Loud 'CLEANUP SKIPPED' "detached HEAD $path"; return 0 }
  if ($target.Locked)   { Write-Loud 'CLEANUP SKIPPED' "locked worktree $path (another session holds the lease)"; return 0 }
  if ([System.IO.Path]::GetFullPath($path).TrimEnd('\') -ieq [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')) {
    Write-Loud 'CLEANUP SKIPPED' "refusing to remove the main worktree"
    return 0
  }

  # --- GUARD 8: cwd 保護 (自己マージ)。消さずに queue へ回す。
  if (Test-SameOrChild -Parent $path -Child (Get-Location).Path) {
    if ($Apply) {
      Add-JsonLine -Path $QueuePath -Object ([pscustomobject]@{
        ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; repo = $RepoArg
        branch = $branch; head_ref_oid = $oid; path = $path; reason = 'cwd-inside-target'; verified = $true
      })
    }
    Write-Loud 'CLEANUP QUEUED' "cwd is inside $path — queued; drains on the next /pr-merge or /worktree-sweep"
    return 0
  }

  # --- GUARD 9: 包含証明 (スカッシュ安全)。ATTACK 2 の核心。
  #     is_ancestor(HEAD, origin/main) は 100% squash のこの repo では常に偽 = 0 件。
  #     さらに --delete-branch + fetch --prune で @{u} が消えると
  #     skip("missing upstream") が第二の錠になる。
  #     is_ancestor(HEAD, headRefOid) は pushed-parity を包含するので upstream 依存を丸ごと捨てられる。
  $has = Invoke-Native -Exe 'git' -Arguments @('-C', $path, 'cat-file', '-e', "$oid^{commit}")
  if ($has.Code -ne 0) {
    # --delete-branch 後は refs/heads も origin/<branch> も無い。refs/pull/<n>/head は残る。
    $f = Invoke-Native -Exe 'git' -Arguments @('-C', $path, 'fetch', 'origin', "refs/pull/$PrNumber/head")
    if ($f.Code -ne 0) {
      Write-Loud 'CLEANUP SKIPPED' "cannot fetch refs/pull/$PrNumber/head — containment unprovable"
      return 2
    }
  }
  $anc = Invoke-Native -Exe 'git' -Arguments @('-C', $path, 'merge-base', '--is-ancestor', 'HEAD', $oid)
  if ($anc.Code -ne 0) {
    Write-Loud 'CLEANUP SKIPPED' "local HEAD carries commits absent from the merged PR head (unpushed work) — $path"
    return 0
  }

  # --- GUARD 10: 可視 dirty (生成物 allowlist 適用後)
  $dirty = Get-DirtyVerdict -Path $path
  if ($dirty.Count -gt 0) {
    if ($Apply) {
      Add-JsonLine -Path $QuarPath -Object ([pscustomobject]@{
        ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; branch = $branch
        path = $path; reason = 'uncommitted-non-generated'; sample = @($dirty | Select-Object -First 5)
      })
    }
    Write-Loud 'CLEANUP QUARANTINED' "$($dirty.Count) non-generated uncommitted change(s) in $path — human review required"
    return 0
  }

  # --- GUARD 11: precious ignored (ATTACK 1)
  $precious = Get-PreciousIgnored -Path $path
  if ($precious.Count -gt 0) {
    if ($Apply) {
      Add-JsonLine -Path $QuarPath -Object ([pscustomobject]@{
        ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; branch = $branch
        path = $path; reason = 'ignored-local-only-files'; sample = @($precious | Select-Object -First 5)
      })
    }
    Write-Loud 'CLEANUP QUARANTINED' "$($precious.Count) ignored local-only file(s) (e.g. $($precious[0])) in $path — these exist nowhere in git"
    return 0
  }

  # --- GUARD 12: 別の open PR (fail-CLOSED。ATTACK 6 で指摘された唯一の fail-OPEN を塞ぐ)
  $openPrs = Get-OpenPrBranches -RepoArg $RepoArg
  if ($null -eq $openPrs) {
    Write-Loud 'CLEANUP SKIPPED' 'open-PR state unknown (gh unavailable) — refusing to remove while blind'
    return 2
  }
  if ($openPrs.ContainsKey($branch)) {
    Write-Loud 'CLEANUP SKIPPED' "branch $branch still has an open PR"
    return 0
  }

  # --- GUARD 13: 生きた Flutter/dart プロセス (ATTACK 4)
  $live = Test-FlutterProcessInside -Path $path
  if ($live.Count -gt 0) {
    if ($Apply) {
      Add-JsonLine -Path $QueuePath -Object ([pscustomobject]@{
        ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; repo = $RepoArg
        branch = $branch; head_ref_oid = $oid; path = $path; reason = 'flutter-running'; verified = $true
      })
    }
    Write-Loud 'CLEANUP QUEUED' "live process(es) in $path : $([string]::Join(', ', $live)) — queued, not removed"
    return 0
  }

  $sizeMb = 0
  try {
    $sizeMb = [math]::Round((Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue |
      Measure-Object -Property Length -Sum).Sum / 1MB, 1)
  } catch { $sizeMb = -1 }

  if (-not $Apply) {
    Write-Loud 'DRY-RUN PRUNE' "would remove $path (branch $branch, PR #$PrNumber, $sizeMb MB)"
    return 0
  }

  # --- attic: 失敗したら削除を中止する。この 1 行が --force を生存可能にする。
  $atticDir = Write-Attic -Path $path -Branch $branch -PrNumber $PrNumber -HeadRefOid $oid -ExtraFiles @()
  if ($null -eq $atticDir) {
    Write-Loud 'CLEANUP ABORTED' "attic archive failed for $path — removal cancelled (nothing deleted)"
    return 2
  }

  # --- GUARD 14: TOCTOU 再検査 (ATTACK 3: 評価と削除の間は実測で数十秒開く)。
  #     安いガードだけ、削除直前にもう一度。
  $dirtyNow = Get-DirtyVerdict -Path $path
  $preciousNow = Get-PreciousIgnored -Path $path
  $liveNow = Test-FlutterProcessInside -Path $path
  $entryNow = @(Get-WorktreeEntries | Where-Object { $_.Path -ieq $path })
  if ($dirtyNow.Count -gt 0 -or $preciousNow.Count -gt 0 -or $liveNow.Count -gt 0 -or
      $entryNow.Count -ne 1 -or $entryNow[0].Locked) {
    Write-Loud 'CLEANUP ABORTED' "state changed between evaluation and removal for $path (attic kept at $atticDir)"
    return 0
  }

  # --- 実削除
  $rm = Invoke-Native -Exe 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'remove', '--force', $path)
  if (Test-Path -LiteralPath $path) {
    # ATTACK 4: 部分削除。git は最初の unlink 失敗で break し delete_git_dir を呼ばない。
    # これを「人間の作業あり」と誤読させないため、quarantine ではなく partial として記録する。
    Add-JsonLine -Path $QueuePath -Object ([pscustomobject]@{
      ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; repo = $RepoArg
      branch = $branch; head_ref_oid = $oid; path = $path; reason = 'partial-removal'; partial = $true; verified = $true
    })
    Write-Loud 'CLEANUP PARTIAL' "git worktree remove left $path on disk (exit $($rm.Code)) — re-queued as partial, attic at $atticDir"
    return 2
  }

  Invoke-Native -Exe 'git' -Arguments @('-C', $RepoRoot, 'worktree', 'prune') | Out-Null

  # --- ハートビート (ATTACK 6: 「最後に本当に消せたのはいつか」を誰も記録していない)
  Write-AtomicFile -Path $HeartbeatPath -Content (([pscustomobject]@{
    ts = (Get-Date).ToUniversalTime().ToString('o'); pr = $PrNumber; branch = $branch
    path = $path; size_mb = $sizeMb; attic = $atticDir
  }) | ConvertTo-Json -Depth 6)

  Write-Loud 'CLEANUP OK' "removed $path (branch $branch, PR #$PrNumber, $sizeMb MB) — attic $atticDir"
  return 0
}

# ---------------------------------------------------------------------------
# queue drain
# ---------------------------------------------------------------------------
function Invoke-DrainQueue {
  if (-not (Test-Path $QueuePath)) { return 0 }
  $lines = @(Get-Content -LiteralPath $QueuePath -Encoding UTF8 -ErrorAction SilentlyContinue)
  if ($lines.Count -eq 0) { return 0 }
  $remaining = @()
  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $e = $null
    try { $e = $line | ConvertFrom-Json } catch { continue }
    if (-not (Test-Path -LiteralPath $e.path)) { continue }   # 既に消えている = 成功として捨てる
    # queue エントリは「承認済み削除」ではなく HINT。毎回フル再検証する。
    Invoke-Release -PrNumber ([int]$e.pr) -RepoArg ([string]$e.repo) `
                   -AfterUtc ([datetime]::MinValue) -ExpectedHeadRefOid ([string]$e.head_ref_oid) | Out-Null
    if (Test-Path -LiteralPath $e.path) { $remaining += $line }
  }
  # ATTACK 3: read-filter-rewrite は競合追記を壊すので必ず mutex 内 + atomic replace で行う。
  $body = [string]::Join("`n", $remaining)
  if ($remaining.Count -gt 0) { $body = $body + "`n" }
  Write-AtomicFile -Path $QueuePath -Content $body
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
if (-not (Enter-ReleaseLock)) {
  Write-Loud 'CLEANUP SKIPPED' 'another worktree release holds the lock — nothing done'
  exit 0
}
$exitCode = 0
try {
  Invoke-AtticRetention
  if ($DrainQueue) {
    $exitCode = Invoke-DrainQueue
  }
  if ($Pr -gt 0) {
    $exitCode = Invoke-Release -PrNumber $Pr -RepoArg $Repo -AfterUtc $MergedAtAfter.ToUniversalTime()
  }
} finally {
  Exit-ReleaseLock
}
exit $exitCode
