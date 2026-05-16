# inject-rules.txt 自動修復 — Tier 1-3 defense in depth

> **Win版#132 part 136 (2026-05-05)**: drift 検出だけでなく **修復まで自動化** する 3 layer mechanism.

## 全体像

```
┌─────────────────────────────────────────────────────────────────┐
│ canonical: .claude/inject-rules.txt (= repo / git tracked)      │
└──────────────┬──────────────────────────────────────────────────┘
               │ git push
               ▼
        ┌─────────────┐
        │ origin/main │
        └──────┬──────┘
               │ git pull (= 各 instance / 各 layer 経由)
               ▼
        ┌────────────────────────────────────────┐
        │ ~/.claude/hooks/inject-rules.txt       │ ← 毎ターン inject 実体
        │ (= local file / per-instance home dir) │
        └────────────────────────────────────────┘
                       ▲
                       │
        ┌──────────────┴───────────────────────┐
        │ 3 Tier auto-sync mechanism            │
        ├───────────────────────────────────────┤
        │ Tier 1: Claude Code SessionStart hook │
        │ Tier 2: Windows Task Scheduler        │
        │ Tier 3: GHA workflow (= notification) │
        └───────────────────────────────────────┘
```

## Tier 1: Claude Code SessionStart hook (= primary / 即時)

**仕組み**: 各 Claude Code session 開始時に `.claude/hooks/session-start-sync-rules.ps1` が自動発火.

**動作**:
1. `python scripts/sync_inject_rules.py --verify --json` で drift 検出
2. drift なし → log 記録のみ (= no action)
3. drift あり → `--apply` で canonical → home 自動修復
4. 全結果を `memory/inject-rules-sync/sync-YYYYMMDD.log` に記録
5. 失敗時は silent (= session 起動を block しない)

**設定**:
- `.claude/settings.json` の `hooks.SessionStart` block (= part 136 で追加済)
- script: `.claude/hooks/session-start-sync-rules.ps1` (= 67 行 / silent failure 設計)

**カバー範囲**:
- ✅ Win Claude Code session 全て
- ❌ Win Codex CLI session (= 別 mechanism / Tier 2 でカバー)

## Tier 2: Windows Task Scheduler (= safety net / 定期)

**仕組み**: Windows Task Scheduler が daily 03:30 JST (= GHA cron 30 分後) に local 実行.

**Task 内容**:
```powershell
cd <repo>
git pull origin main
python scripts/sync_inject_rules.py --apply
```

**Setup** (= 1 度だけ実行):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup_inject_rules_auto_sync.ps1 -Install
```

**確認**:
```powershell
powershell -File scripts/setup_inject_rules_auto_sync.ps1 -Status
```

**Uninstall**:
```powershell
powershell -File scripts/setup_inject_rules_auto_sync.ps1 -Uninstall
```

**カバー範囲**:
- ✅ Codex CLI session 中も動く (= Claude Code 非依存)
- ✅ 長時間 idle instance (= Tier 1 が動かないケース)
- ✅ 複数 user account (= 各 user で 1 度 setup)

**ログ**: `memory/inject-rules-sync/cron-YYYYMMDD.log` (= Tier 1 と別 file で混在せず追跡可)

## Tier 3: GHA workflow (= canonical 更新検出 + 通知)

**仕組み**: weekly cron (= 月曜 03:00 JST) で repo `.claude/inject-rules.txt` integrity 検証 + canonical 更新検出.

**動作**:
1. `scripts/sync_inject_rules.py --verify --json` で integrity check
2. KPI 違反 (= 行数 > 80 / rule 数 ≠ 37 / critical rule 欠落) → Issue 自動作成 (`automation, priority:high`)
3. 直近 commit で canonical 更新検出 → tracking Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) コメント
4. コメント内容: 各 instance の手元 sync 推奨 (= `git pull && --apply`)

**カバー範囲**:
- ✅ 周期 audit (= 行数 / rule 数 / critical rule の整合性)
- ✅ canonical 更新通知 (= 別 instance push を検知)
- ❌ user の手元 file への直接書込は不可 (= GHA runner ↔ user home の隔離)

## 設計 trade-off (= 採用判断の理由)

### 1. SessionStart vs PostToolUse vs UserPromptSubmit
- **SessionStart 採用**: 1 セッション 1 回 / overhead 最小 / 確実に session 開始時 sync
- PostToolUse: 過剰発火 (= 全 tool 後に走る)
- UserPromptSubmit: 同様 / session 中 drift 発生は稀

### 2. Daily 03:30 JST トリガー
- GHA cron (= 03:00 JST) の **30 分後**: GHA が canonical 更新を push しても local pull ↔ apply の余裕
- 深夜帯 (= [SCHEDULE-WAKEUP] rule 02:00-06:00 と若干重複) → 03:30 が user 影響最小

### 3. silent failure 方針
- Python 不在 / repo 未 pull / network 障害 → **session を block しない**
- log 記録だけ残し次回再試行
- block すると Claude Code 起動不能リスク

### 4. Tier 3 が Issue 起票でなく comment の理由
- 全 user に通知すべき = noisy / 既存 Issue (= part 117 #1647 Codex Memory + Thread Automations) は rule infra tracking として既存
- 新 Issue = noise 発生 / dedup 困難

## Troubleshoot

### Tier 1 hook が発火しない

```powershell
# log 確認
Get-Content memory\inject-rules-sync\sync-$(Get-Date -Format 'yyyyMMdd').log

# settings.json に SessionStart 登録されてるか
PYTHONUTF8=1 python -c "import json; d=json.load(open('.claude/settings.json',encoding='utf-8')); print('SessionStart' in d['hooks'])"
```

### Tier 2 Task が動かない

```powershell
# task 状態確認
powershell -File scripts/setup_inject_rules_auto_sync.ps1 -Status

# 手動実行 trigger (= Task Scheduler GUI / Run on demand)
Start-ScheduledTask -TaskName "JibunKK-InjectRulesAutoSync"
```

### Tier 3 GHA workflow

- `gh run list --workflow=inject-rules-drift-cron.yml --limit 5` で直近 run 確認
- workflow_dispatch で手動 trigger 可能

## 関連

- [`docs/RULES_INDEX.md`](RULES_INDEX.md) — 全 37 rule full body (= part 134)
- [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md) — 2 instance fleet (= part 130)
- [`scripts/sync_inject_rules.py`](../scripts/sync_inject_rules.py) — sync engine (= part 135)
- [`scripts/setup_inject_rules_auto_sync.ps1`](../scripts/setup_inject_rules_auto_sync.ps1) — Tier 2 installer (= 本 part)
- [`.claude/hooks/session-start-sync-rules.ps1`](../.claude/hooks/session-start-sync-rules.ps1) — Tier 1 hook (= 本 part)
- [`.github/workflows/inject-rules-drift-cron.yml`](../.github/workflows/inject-rules-drift-cron.yml) — Tier 3 workflow (= part 135 + 本 part 拡張)

(Win版#132 part 136 / 2026-05-05 / 「Tier 1-3 defense in depth」pattern 第 1 例)
