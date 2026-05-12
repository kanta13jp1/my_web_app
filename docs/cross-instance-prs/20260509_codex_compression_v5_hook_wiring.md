# Cross-Instance PR — Tier 2.2-2.4 Hook wiring 完成 + 圧縮自動化 100% 化 → Win Codex

> **Author**: Win Claude (Win版#132 part 190 / 2026-05-09 JST)
> **Target**: Win Codex
> **Issue**: [#1983](https://github.com/kanta13jp1/my_web_app/issues/1983) (P1 / dev-env / メモリー/ディスク削減 定期監査)
> **Parent spec**: [`docs/DISK_HYGIENE_RUNBOOK.md`](../DISK_HYGIENE_RUNBOOK.md) §17 (= 本 hand-off 起点)
> **Deadline**: 2026-05-30 (= 21 day buffer)

## 概要

Part 189 §16 で ship した **mid-session compression spec** は **設計のみ完了 / 実装未配線**. Part 190 audit で actual `~/.claude/settings.json` の hook wiring 実測 → **3 critical gap 発見**:

| Gap | 観測 | 影響 |
|-----|------|------|
| A. SessionEnd 非対称 | start 6 ↔ end 4 (= `worktree_cleanup` 欠落) | session 終了時に worktree 累積 14 GB 漸増 |
| B. PostToolUse mid-session 未配線 | `auto-capture.ps1` のみ / `mid_session_compress.py` 起動なし | 90+ min session で SessionStart 効果消失 |
| C. PreCompact 限定配線 | `memory-cleanup.ps1` のみ | compaction 前の重い session で disk pressure 解消されない |

→ **3 hook 追加 + `mid_session_compress.py` 新規実装** で「毎セッション必ず圧縮」guarantee.

## 振分判定 ([INSTANCE-ROLES] 5 質問 score 化)

| Q | 内容 | A | 理由 |
|---|------|---|------|
| Q1 | 設計判断 / 仕様策定が必要? | NO | §17 spec 確定 / 実装のみ |
| Q2 | docs / memory / Roadmap 更新が必要? | NO | 完了 mark のみ (= F task は Win Claude self) |
| Q3 | UI design tokens / 競合分析が必要? | NO | hook 配線 + Python script |
| Q4 | sensitive secrets / 法務 / 個人情報? | NO | local dev env / public hook script |
| Q5 | mobile UAT / AI 大学 contents 必要? | NO | 純 dev infra |

→ **全 NO = Win Codex 担当** ([INSTANCE-ROLES] rule)

## 実装 scope (= Tier 2.2-2.4 / 5 task)

### Task A: `~/.claude/scripts/mid_session_compress.py` 実装

**spec**: [`docs/DISK_HYGIENE_RUNBOOK.md`](../DISK_HYGIENE_RUNBOOK.md) §16.2 + §17.4 + §17.6 / **期限 2026-05-23**

```python
# C:\Users\kanta\.claude\scripts\mid_session_compress.py
"""Mid-session lightweight compression. Runs in <5sec, non-blocking.

Targets (--quick mode):
  1. transcript hot-cache 削除 (= > 30 MB の単一 session log を gzip)
  2. flutter build cache prune (= > 100 MB の build/ ディレクトリ for ages > 2h)
  3. RAM working set trim (= Windows MinWorkingSet adjustment)

Targets (--aggressive mode / threshold fire):
  All --quick + worktree_cleanup --tier1 --apply (= max-runtime-sec=15)

Emits: ~/.claude/logs/mid-compress.csv 1 row per fire.
Lock: ~/.claude/logs/mid-compress.lock for parallel-fire prevention.
Throttle: internal counter via ~/.claude/logs/post_tool_counter.txt
"""
```

CSV format (= §17.8):

```csv
ts,session_id,phase,counter,c_free_gb_before,c_free_gb_after,reclaim_mb,duration_sec
```

### Task B: SessionEnd 5th hook 配線

**期限 2026-05-23**

`~/.claude/settings.json` patch:

```json
"SessionEnd": [
  // 既存 4 entries
  {
    "hooks": [
      {
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\worktree_cleanup.py --tier1 --apply --max-runtime-sec=15\"",
        "timeout": 20
      }
    ]
  }
]
```

### Task C: PostToolUse 2nd hook 配線

**期限 2026-05-25**

```json
"PostToolUse": [
  {
    "matcher": "Bash|Write|Edit",
    "hooks": [
      // 既存 auto-capture
      { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\auto-capture.ps1\"" },
      // 新規 mid_session_compress
      {
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\mid_session_compress.py --quick\"",
        "timeout": 8
      }
    ]
  }
]
```

### Task D: PreCompact hook 完全圧縮

**期限 2026-05-25**

```json
"PreCompact": [
  {
    "hooks": [
      // 既存 memory-cleanup
      { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\memory-cleanup.ps1\"" },
      // 新規 disk-cleanup --pre-compact
      { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File \"C:\\Users\\kanta\\.claude\\hooks\\disk-cleanup.ps1\" -PreCompact" },
      // 新規 worktree_cleanup
      {
        "type": "command",
        "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command \"& python C:\\Users\\kanta\\.claude\\scripts\\worktree_cleanup.py --tier1 --apply --max-runtime-sec=20\"",
        "timeout": 25
      }
    ]
  }
]
```

`disk-cleanup.ps1` の `-PreCompact` parameter 追加 (= aggressive mode toggle / 既存 SessionStart fire との差別化).

### Task E: Threshold-triggered emergency fire

**期限 2026-05-28**

`auto-capture.ps1` 内に C: free GB monitor 追加:

```powershell
# C:\Users\kanta\.claude\hooks\auto-capture.ps1 末尾追加
$freeGB = (Get-PSDrive C).Free / 1GB
if ($freeGB -lt 50) {
  Start-Job -ScriptBlock {
    & python "$env:USERPROFILE\.claude\scripts\mid_session_compress.py" --aggressive
    & python "$env:USERPROFILE\.claude\scripts\worktree_cleanup.py" --tier1 --apply --max-runtime-sec=30
  } | Out-Null
}
```

## 受け入れ条件

- [ ] Task A: `mid_session_compress.py` 実装完了 + smoke test (= --quick / --aggressive 両 mode)
- [ ] Task B: SessionEnd 5th hook 配線 + manual fire test (= worktree_cleanup --tier1 --apply 動作)
- [ ] Task C: PostToolUse 2nd hook 配線 + 50 tool call 後の自動 fire 確認
- [ ] Task D: PreCompact 3 hook 配線 + manual `/compact` 経由 fire test
- [ ] Task E: Threshold trigger emergency fire 動作 (= C: < 50 GB simulated)
- [ ] `~/.claude/logs/mid-compress.csv` 1+ row 蓄積 (= verify run 経由)
- [ ] `~/.claude/settings.json` JSON validate ✅
- [ ] PR description で wiring delta diff visible (= before/after)

## CI / テスト

```bash
# settings.json validate
python -c "import json; json.load(open('C:/Users/kanta/.claude/settings.json'))"

# manual fire test
powershell -NoProfile -ExecutionPolicy Bypass -Command "& python C:\Users\kanta\.claude\scripts\mid_session_compress.py --quick"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& python C:\Users\kanta\.claude\scripts\worktree_cleanup.py --tier1 --apply --max-runtime-sec=15"

# CSV check
Test-Path "$env:USERPROFILE\.claude\logs\mid-compress.csv"
```

## Win Claude side フォロー

- Task A-E 完了後: Win Claude part 197 想定で 1 week observation + DISK_HYGIENE §17 status table backfill (= Task F)
- KPI verify: `mid_compress_fires_per_session` ≥ 3 / `reclaim_mb_per_fire` ≥ 100 MB / `duration_sec` < 5
- Issue #1983 close 推奨: 全 5 task 着地 + KPI 1 week green = close

## 関連

- 親 spec: [`docs/DISK_HYGIENE_RUNBOOK.md`](../DISK_HYGIENE_RUNBOOK.md) §17
- v4 spec (= mid-session compression): 同 RUNBOOK §16
- Issue: [#1983](https://github.com/kanta13jp1/my_web_app/issues/1983)
- 親 Issue (= closed): [#1984](https://github.com/kanta13jp1/my_web_app/issues/1984)
- 既存 5 sprint hand-off (= 5/22-5/24 sprint): #2171 / #2186 / #1124 / #1640 etc.

## Philosophy Alignment ([PHILOSOPHY-22])

- 主要実装: hook wiring gap 3 finding fix で開発環境圧縮 100% guarantee
- 該当原則: #2 (mission) #5 (商品=価値) #6 (時間=資本) #7 (資産負債) #8 (KPI) #9 (IPO)
- 整合性スコア: **7/9 ✅** (gate 通過)

---

> **Hand-off ship**: Win Claude part 190 (2026-05-09 JST). v5 = User 第 5 ask に対する Codex 実装 hand-off.
