# PreCompact / SessionStart / StatusLine / Setup — 通常設計 spec (#1564 / part 152)

> **Codex #1 implementation note (2026-05-13 JST)**: the repo-managed slice now ships
> `.claude/hooks/pre-compact-backup.ps1` redaction/frontmatter, `.claude/hooks/session-start-state-check.ps1`,
> `.claude/hooks/statusline.ps1`, `.claude/settings.json` wiring, `docs/CLAUDE_CODE_SETUP_RUNBOOK.md`,
> `memory/transcripts/.gitkeep`, and `scripts/check_session_state_hooks.py` with CI coverage.
> User-home `~/.claude/settings.json` remains a manual per-instance action.

> **status**: 設計 spec / Win版#132 part 152 / 2026-05-05
> **issue**: [#1564](https://github.com/kanta13jp1/my_web_app/issues/1564) [追加要望][P1] Claude Code PreCompact/StatusLine/SessionStart/Setup による記憶保全
> **scope**: 設計のみ (Win Claude territory) / 実装は Win Codex (= hook 配備 + script 拡張) ハンドオフ
> **NotebookLM source**: `Claude Code Masterclass` / `Codex vs Claude Code`
> **template**: `docs/DESIGN_SPEC_TEMPLATE.md` 通常 5 section 適用 (= sensitive ではないため §2 倫理 review section 不要)
> **適用原則**: PHILOSOPHY-22 + AI-DEV-23 + BRAIN-32 + INDIE-29 + SYNERGY-30
> **2 instance 制反映**: Issue body は「10 インスタンス並行」前提だが [INSTANCE] (part 130 / 2 instance 制) で現状 = Win Claude + Win Codex のみ. 仕様は 2 instance を base にしつつ N instance scalable 設計.

## 1. 思想

`my_web_app` の AI fleet は context compact / session 切替 / quota 超過 fallback / worktree 切替で
**「セッション間状態継承の断絶」** が起きやすい. 1 incident で再現に 30+ min 失う risk.

**「記憶 = 資本」** (= PHILOSOPHY-22 #7 資産負債) を前提に、**4 hook + 1 script + 2 SOP** で
セッション間連続性を担保する.

- **PreCompact hook** = compact 直前に自動 backup (= 既存 `.claude/hooks/pre-compact-backup.ps1`)
- **SessionStart hook** = drift 自動修復 + 復元 trigger (= 既存 `.claude/hooks/session-start-sync-rules.ps1` 拡張)
- **StatusLine** = 担当 / branch / dirty / 次品質ゲート 常時可視化 (= 新規)
- **Setup hook** (= `--init` / `--maintenance`) = 新規参画 + 定期保守 SOP 分離 (= 新規 SOP doc)

## 2. 既存基盤確認

| 必要 infra | 既存 status | 対応 |
|---|---|---|
| PreCompact hook | **整備済** (= `.claude/hooks/pre-compact-backup.ps1` / part 122 bc58b50b #1848) | §3.1 で復元 path 拡張 + 秘匿情報除外を強化 |
| SessionStart hook (drift sync) | **整備済** (= `.claude/hooks/session-start-sync-rules.ps1` / part 136) | §3.2 で behind/ahead/dirty/未 push/品質ゲート検出を追加 |
| 担当 instance 確認 | 部分 (= `[INSTANCE]` rule で session 冒頭発話で確認) | §3.3 StatusLine で常時表示化 |
| `scripts/codex_session_check.py` | **整備済** | §3.2 SessionStart hook で連動 |
| `scripts/session_residuals_to_issue.py` | **整備済** (= part 118 / Issue #1647) | §3.2 で前回未完了 surface 連動 |
| StatusLine 設定 | **未整備** | §3.3 で `~/.claude/settings.json` `statusLine` 新規 |
| `--init` / `--maintenance` SOP | **未整備** | §3.4 で `docs/CLAUDE_CODE_SETUP_RUNBOOK.md` 新設 |
| transcripts dir (`memory/transcripts/`) | 未整備 (= hook 起動時に自動作成) | §3.1 で `.gitkeep` 配置 + secret-scan gate |
| 秘匿情報除外規約 | **未整備** | §4 で明文化 (= `compactSummary` 内 GitHub PAT / API keys を redact) |

## 3. 設計 (= 4 hook + 1 script + 2 SOP)

### 3.1 PreCompact hook 拡張 (= 既存 + 復元 path 強化)

**現状** (= `.claude/hooks/pre-compact-backup.ps1` / part 122):
- compact 直前に `$env:CLAUDE_COMPACT_TRIGGER_SUMMARY` を `memory/transcripts/compact-<ts>.md` へ保存
- log = `memory/compact-log.txt`
- silent failure (= hook error は session block しない)

**追加要件**:
- backup ファイル冒頭に **復元 trigger info** を payload として記録:
  ```yaml
  ---
  saved_at: 2026-05-05 19:55:23 JST
  instance: Win Claude (= win-claude)
  worktree: .claude/worktrees/crazy-jennings-93b113
  branch: claude/crazy-jennings-93b113
  head_sha: f523149f0
  in_progress_issue: 1577
  active_pr: 2022
  next_quality_gates:
    - dart format --set-exit-if-changed
    - flutter analyze (0 issues)
    - gh pr checks
  uncommitted_files: []
  unpushed_commits: 0
  ---
  ```
- **秘匿情報 redact**: `$compactSummary` 内の以下 pattern を `[REDACTED]` 置換:
  - GitHub PAT (= `gh[ops]_[A-Za-z0-9]{36,}`)
  - Bearer token (= `Bearer [A-Za-z0-9._-]{20,}`)
  - WorkOS / Supabase / Anthropic API keys (= `sk-[A-Za-z0-9]{20,}` / `sb_[A-Za-z0-9]{20,}`)
  - `.env` 行 (= `[A-Z_]+=.*` で key 名 +「password」「secret」「token」「key」含む行)

**復元手順** (= 受入 #1 / 1 分以内):
- 新 session 開始 → `~/.claude/hooks/session-resume.ps1` が `memory/transcripts/` の最新 compact-*.md を読み取り
- 冒頭 YAML payload + summary を session 冒頭で AI に inject
- 30 秒以内に「担当・branch・WBS・次品質ゲート」復元

### 3.2 SessionStart hook 拡張 (= 既存 + 5 検出機能追加)

**現状** (= `.claude/hooks/session-start-sync-rules.ps1` / part 136):
- `scripts/sync_inject_rules.py --verify --json` で drift 検知
- drift 時に `--apply` で canonical → home 自動修復

**追加要件** (= 受入 #3):
- 以下 **5 検出** を session 冒頭で並列実行 + warning surface:

```powershell
# .claude/hooks/session-start-state-check.ps1 (= 新規)

$projectDir = $env:CLAUDE_PROJECT_DIR
$logFile = Join-Path $projectDir "memory\session-start-check\$(Get-Date -Format 'yyyyMMdd').log"

# 1. branch 取り違え検知 (= 受入 #2)
$currentBranch = git -C $projectDir rev-parse --abbrev-ref HEAD
$expectedPrefix = if ($env:CLAUDE_INSTANCE -eq 'win-codex') { 'codex/' } else { 'claude/' }
if (-not $currentBranch.StartsWith($expectedPrefix)) {
    "WARN: branch=$currentBranch / expected prefix=$expectedPrefix" | Out-File $logFile -Append
}

# 2. behind/ahead 検出
git -C $projectDir fetch origin --quiet
$ahead  = (git -C $projectDir rev-list HEAD..origin/main --count) -as [int]
$behind = (git -C $projectDir rev-list origin/main..HEAD --count) -as [int]

# 3. dirty path 検出
$dirty = git -C $projectDir status --short
if ($dirty) { "WARN: dirty paths: $($dirty -join '; ')" | Out-File $logFile -Append }

# 4. 未 push commit 検出
$unpushed = git -C $projectDir log "@{push}..HEAD" --oneline 2>$null
if ($unpushed) { "WARN: unpushed: $($unpushed -join '; ')" | Out-File $logFile -Append }

# 5. 品質ゲート未完 surface
# = 既存 scripts/codex_session_check.py / session_residuals_to_issue.py 連動
& python "$projectDir\scripts\codex_session_check.py" --json | Out-File $logFile -Append
```

**Output** (= 受入 #1 + #3 復元):
- `memory/session-start-check/<date>.log` = warning list
- session 冒頭 inject 経由で AI に表示 (= `~/.claude/hooks/session-resume.ps1` 経由)

### 3.3 StatusLine 設定 (= 新規 / 受入 #1 常時可視化)

**目的**: Claude Code CLI prompt に **担当 / Issue / branch / dirty / 次品質ゲート** を常時表示.

**設計**:
```json
// ~/.claude/settings.json (= 追加)
{
  "statusLine": {
    "type": "command",
    "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\statusline.ps1\""
  }
}
```

```powershell
# ~/.claude/hooks/statusline.ps1 (= 新規)

$projectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }

# instance 識別 (= 環境変数 or worktree path から推定)
$instance = if ($env:CLAUDE_INSTANCE) {
    $env:CLAUDE_INSTANCE
} elseif ((Get-Location).Path -match 'instance-codex') {
    'win-codex'
} else {
    'win-claude'
}

# branch / dirty
$branch = git -C $projectDir rev-parse --abbrev-ref HEAD 2>$null
$dirtyCount = (git -C $projectDir status --short 2>$null | Measure-Object).Count
$dirtyMark = if ($dirtyCount -gt 0) { "*$dirtyCount" } else { '' }

# 在 progress Issue (= memory/active-issue.txt 1 行 / hook が更新)
$activeIssue = ''
$activeFile = Join-Path $projectDir 'memory\active-issue.txt'
if (Test-Path $activeFile) { $activeIssue = (Get-Content $activeFile -First 1).Trim() }

# 次品質ゲート (= memory/next-quality-gate.txt 1 行)
$nextGate = ''
$gateFile = Join-Path $projectDir 'memory\next-quality-gate.txt'
if (Test-Path $gateFile) { $nextGate = (Get-Content $gateFile -First 1).Trim() }

# StatusLine format (= max ~80 char)
# 例: [win-claude] #1577 | claude/crazy-jennings*3 | gate=dart-format
$line = "[$instance]"
if ($activeIssue) { $line += " #$activeIssue" }
$line += " | $branch$dirtyMark"
if ($nextGate) { $line += " | gate=$nextGate" }

Write-Output $line
```

**運用**: hook が `memory/active-issue.txt` / `memory/next-quality-gate.txt` を更新 (= 起票時 / 着手時 / 完了時).

### 3.4 Setup hook SOP (= `--init` / `--maintenance` 分離 / 新規 docs)

**新規 doc**: `docs/CLAUDE_CODE_SETUP_RUNBOOK.md`.

**構成**:

```markdown
# Claude Code Setup Runbook (= --init / --maintenance 分離)

## --init (= 新規参画 / 1 回のみ)

決定論的 commands:
1. `git clone https://github.com/kanta13jp1/my_web_app.git` (= 既存)
2. `cd my_web_app && flutter pub get`
3. `git worktree add .claude/worktrees/<part-name> -b claude/<part-name>` (= [WORKDIR-ISOLATION])
4. `python scripts/sync_inject_rules.py --apply` (= rule home 同期)
5. `cp ~/.claude/settings.example.json ~/.claude/settings.json` + statusLine 編集 (= §3.3)
6. `cp .env.example .env` + 秘匿 key 設定
7. `flutter analyze` で 0 issues 確認

## --maintenance (= 定期 / 月 1 回)

決定論的 commands:
1. `flutter pub upgrade --major-versions` (= dependency audit)
2. `python scripts/notebooklm_issue_crosscheck.py --apply` (= [ISSUE-PRECHECK] / part 120)
3. `python scripts/wiki_compile.py` + `wiki_lint.py` (= Karpathy Compile/Lint cycle)
4. `python scripts/consolidate_memory.py` (= [MEMORY-DECAY] / 30+ 日 reference 0 cleanup)
5. `gh pr list --state stale --search 'updated:<2026-04-01'` (= stale PR triage)
6. `git remote prune origin` + `git worktree prune`
7. `flutter analyze` で 0 issues 維持

## 秘匿情報取扱 (= 受入 #5)

保存先:
- `~/.claude/settings.json` = GitHub PAT / NotebookLM cookie (= file mode 600 推奨)
- `.env` = Supabase URL / Anthropic API key / WorkOS key (= `.gitignore` 必須 / repo 直 commit 禁止)
- `memory/transcripts/` = compact summary (= `[REDACTED]` filter 経由 / §3.1)

禁止:
- `.env` を repo に commit
- compact backup に raw API key を残す (= §3.1 redact filter で除外)
- StatusLine に PAT prefix 表示 (= `[gho_]` 等は出力しない)

CI gate:
- `.github/workflows/secret-scan.yml` で `memory/transcripts/*.md` 内 secret pattern 検出 → block merge
```

## 4. 受入条件 mapping

| 受入条件 | 対応 section |
|---|---|
| #1 context compact 後 1 分以内に復元 | §3.1 (= YAML payload + redact filter) + §3.2 (= 5 検出) + §3.3 (= StatusLine 即可視化) |
| #2 N instance 並行で branch/worktree 取り違え検知 | §3.2 step 1 (= prefix check) + §3.3 (= 担当 instance 常時表示) |
| #3 SessionStart で behind/ahead/dirty/未 push/品質ゲート検出 | §3.2 step 2-5 |
| #4 新規セットアップ vs 定期メンテ commands 分離 | §3.4 (= `CLAUDE_CODE_SETUP_RUNBOOK.md` の `--init` / `--maintenance` 章分離) |
| #5 保存先 + 秘匿情報取扱 明文化 | §3.4 「秘匿情報取扱」section + §3.1 redact filter |

## 5. Win Codex hand off scope

- [ ] `.claude/hooks/pre-compact-backup.ps1` 拡張 (= §3.1 / YAML payload + redact filter / **既存ファイル拡張**)
- [ ] `.claude/hooks/session-start-state-check.ps1` 新規 (= §3.2 / 5 検出)
- [ ] `~/.claude/hooks/statusline.ps1` 新規 (= §3.3 / instance / branch / dirty / next gate)
- [ ] `~/.claude/settings.json` `statusLine` 設定追加 (= §3.3 / **手動 / 各 instance 個別**)
- [ ] `docs/CLAUDE_CODE_SETUP_RUNBOOK.md` 新規 (= §3.4 / `--init` / `--maintenance` 章 + 秘匿情報取扱)
- [ ] `memory/transcripts/.gitkeep` 配置 (= §2)
- [ ] `.github/workflows/secret-scan.yml` 拡張 (= §3.4 / `memory/transcripts/*.md` 対象追加)
- [ ] 復元 hook = `~/.claude/hooks/session-resume.ps1` 拡張 (= §3.1 / 最新 compact-*.md 読込)
- [ ] memory/active-issue.txt / memory/next-quality-gate.txt 配置 + hook 更新 logic
- [ ] `scripts/codex_session_check.py` `--json` mode 既存確認 (= §3.2 / 既整備済)

EF 数 +0 (= EF 関与なし / [EF-CAP-50] 完全遵守).
推定工数: 8h (= PreCompact 拡張 1.5h + SessionStart hook 1.5h + StatusLine 1h + Setup runbook 2h + secret-scan 拡張 1h + 復元 hook 拡張 1h).

## 6. 9 原則 alignment

### PHILOSOPHY-22 (= 8/9 評価 / 7+/9 ✅ ゲート達成)

- ✅ #1 CEO 感 — StatusLine で「自分が CEO として今どこに居るか」常時可視化
- ✅ #2 ミッション — 記憶 = 資本 / 失わない
- ✅ #4 6 部署 — Win Claude (= architect / docs) territory 直撃 / Win Codex (= 実装) hand off scope §5 で 10 件
- ✅ #5 商品=価値 — 1 incident で 30+ min 失う = 価値毀損
- ✅ #6 時間最適化 — compact 復元 30 秒以内 = 時間最適化最大化
- ✅ #7 資産負債 — memory/transcripts/ + active-issue.txt = 永続資産
- ✅ #8 KPI — 復元時間 (= < 1 min) / branch 取り違え件数 (= 0) / 秘匿情報漏洩件数 (= 0) を計測可
- ✅ #9 IPO — secret-scan gate + 秘匿情報明文化 = SOC2 必要要件

= **8/9 ✅** (= 7+/9 ゲート達成 / #3 mentor は scope 外).

### AI-DEV-23 (= 7/7 推奨)

- ✅ #1 Auth — file mode 600 / `.env` gitignore
- ✅ #2 deny-by-default — secret-scan で `.env` commit 即 block
- ✅ #3 trace_id — log file に timestamp + instance + ts 付与
- ✅ #4 circuit-breaker — hook silent failure (= session block しない / `exit 0`)
- ✅ #5 memory — `memory/transcripts/` retention (= 30 日 cleanup 推奨 / consolidate-memory skill)
- ✅ #6 DLQ — hook 失敗時 log file に記録 (= `compact-log.txt` / `session-start-check/<date>.log`)
- ✅ #7 quality-gate — secret-scan workflow + flutter analyze 0 issues

= **7/7 ✅**.

### BRAIN-32 (= 7/7 推奨)

- ✅ #1 Atomic Note — 各 compact-*.md = 独立 Atomic Note
- ✅ #2 Cross-link — YAML payload に `active_pr` / `in_progress_issue` で link
- ✅ #3 横断検索 — `mem-search` skill / `notebooklm` CLI で transcripts 検索可
- ✅ #4 メタデータ — YAML frontmatter で saved_at / instance / branch
- ✅ #5 メンテナンス — §3.4 `--maintenance` で `consolidate_memory.py` 月 1
- ✅ #6 自走化 — hook で人手介入ゼロ
- ✅ #7 PKM 永続化 — `memory/transcripts/` `.gitkeep` で trackable

= **7/7 ✅**.

### INDIE-29 (= 7/7 推奨)

- ✅ #1 shipping 速度 — 既存 hook 拡張 + 1 SOP / 工数 8h
- ✅ #2 dogfood — 本 spec を本 session で先行適用 (= part 152 で復元 manual 検証)
- ✅ #3 lo-fi tooling — PowerShell hook + Python script / 既存 stack 流用
- ✅ #5 simplicity — 4 hook + 1 script + 2 SOP / 過剰抽象なし
- ✅ #6 measurable — 復元時間 / branch 取り違え 0 / secret 漏洩 0
- ✅ #7 reproducibility — `--init` 決定論的 commands

### SYNERGY-30 (= 4+/7 ✅)

- ✅ #1 cross-instance-pr — Win Codex hand off §5 で 10 件
- ✅ #3 5 正本同期 — Issues + WBS + memory + worktree + PR
- ✅ #4 5-question matrix — Q1 + Q2 + Q5 YES = Win Claude
- ✅ #5 fleet hygiene — 2 instance prefix 検知 (= claude/ vs codex/)

## 7. 受け入れ条件 mapping (= 受入条件 self-check)

| 受入条件 | section | 検証方法 |
|---|---|---|
| #1 1 分以内復元 | §3.1 + §3.2 + §3.3 | manual: compact 直後の new session で StatusLine 表示まで stopwatch |
| #2 branch 取り違え検知 | §3.2 step 1 | manual: codex/ branch で win-claude 起動 → log warn 確認 |
| #3 SessionStart 5 検出 | §3.2 step 2-5 | manual: dirty + ahead/behind 状態で起動 → log warn 確認 |
| #4 init/maintenance 分離 | §3.4 | manual: runbook 章分離 + 各 commands 決定論的 (= side effect 同一) |
| #5 秘匿情報明文化 | §3.4 「秘匿情報取扱」 | secret-scan workflow 実行 → memory/transcripts/ 内 PAT pattern 検出 → block |

## 8. NotebookLM 蓄積予定

- 本 spec を `docs/notebooklm-intake/jibun-master-brain-spec-template-seed.md` の蓄積 list に追加
- `notebooklm source add docs/PRECOMPACT_MEMORY_BACKUP_SPEC.md` 実行は part 152 後で
- Source: `Claude Code Masterclass` / `Codex vs Claude Code` 由来 NotebookLM list 反映済 (= Issue #1564 body)

## 9. 通常 spec template 第 7 例

本 spec は通常 5 section 適用 (= sensitive ではない / §2 倫理 review section 不要).

| 通常 spec | part | 工数 |
|---|---|---|
| SIX_DEPT_KPI | 143 | 12h |
| ONE_IN_TWO_OUT | 143 | 11.5h |
| MAINTENANCE_SOP | 144 | 6h |
| TERM_TOOLTIP | 144 | 8h |
| NARRATIVE_UI_ACTION | 145 | 9h |
| DEV_ENV_SETUP | 145 | 5h |
| **PRECOMPACT_MEMORY_BACKUP** | **152** | **8h** |

= 通常 7 例平均 8.5h (= sensitive 12.0h より -29%).
= 通常 spec template の **既存 hook 拡張** pattern 第 1 例 (= ゼロから新規ではなく既存 base + 増分設計).
