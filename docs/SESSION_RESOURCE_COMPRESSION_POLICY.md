# Session Resource Compression Policy

> **status**: per-session checklist / 2026-05-16 Win版#132 part 220 / single-page reference
> **scope**: 2 instance fleet (Win Claude + Win Codex) per-session resource discipline
> **詳細 ops runbook**: [`DISK_HYGIENE_RUNBOOK.md`](DISK_HYGIENE_RUNBOOK.md) (= 2016 行 / Tier 1+2 implementation)

## 目的

毎セッション開発フローで**ローカル環境メモリ / ハードディスク容量枯渇を構造的に防止**. SNS 煽り (= 新モデル発表) や user direct ask 多重発火に翻弄されず、サステナブルに開発継続できる per-session guardrail.

## Per-session 圧縮 checklist (= MUST / 全 instance)

### Open phase (= SessionStart)

1. **PRE KPI snapshot**: `Get-Date` + RAM / C: free 取得
2. **v24 SS hard exit gate** (= 部 215 ship): RAM > 90% で即 wrap-up MUST
3. **v26 YY hard exit gate** (= 部 216 ship): C: free < 10 GB で即 cleanup MUST
4. **fatigue:FATIGUE flag**: last_fire > 30min 経過確認 (= 未経過なら skip session)
5. **同日 4-part cap** (= 部 220 立証): 5th 起動禁止 / 翌 06:00 JST+ qualify

### Working phase (= 30 min cadence)

6. **30min KPI snapshot** (= hook 自動): RAM/C: delta 観測 + DEGRADED 判定
7. **uncommitted 変更 10 min 超え禁止**: 都度 commit + push (= STASH-SAFETY rule)
8. **lefthook hang 抑制**: 2nd try + foreground monitor (= 部 219u 教訓)
9. **git log origin/main..HEAD 確認**: orphan commit 検出 (= 部 219u 第 1 例教訓)
10. **session_hygiene_check.py --apply --force 1 回実行 MUST** (= 部 219u-2 ship)

### Close phase (= wrap-up)

11. **POST KPI snapshot**: PRE → POST delta 記録
12. **memory file 作成**: `memory/project_<YYYYMMDD>_<instance>_part<N>.md` + MEMORY.md index 追記
13. **ROADMAP 1 entry 追記**: instance + session# + サマリ + commit hash + Philosophy Alignment
14. **次 session prompt 標準出力** (= 部 218-b 確立)
15. **wrap-up commit + PR ship**: 1 PR で完結 (= rebase 必須 / push 衝突回避)

## 緊急 trigger (= 即 exit MUST)

| 条件 | 動作 | 根拠 |
|------|------|------|
| RAM > 90% | v24 SS hard exit | 部 215-220 連続 12 例発火 |
| C: < 10 GB | v26 YY hard cleanup | 部 216 ship |
| fatigue:FATIGUE | 即 wrap-up | 部 215+ ship |
| 同日 5th part start | reject + 翌 06:00 reschedule | 部 220 立証 |
| compaction 後 90 min 超え | wrap-up + exit | COMPACTION-RESUME rule |
| 02:00-06:00 JST wakeup | reject + reschedule | SCHEDULE-WAKEUP rule |
| 7h+ idle | 暴走 detection / 緊急停止 | SCHEDULE-WAKEUP rule |
| user input なし 2 回連続 | 停止サイン | SCHEDULE-WAKEUP rule |

## 関連 issue

- [#2508](https://github.com/kanta13jp1/my_web_app/issues/2508) P1 — memory/disk hygiene KPI dashboard (= /project-gantt view)
- [#2523](https://github.com/kanta13jp1/my_web_app/issues/2523) P1 — /goal ベース WBS 実行・wrap-up 標準化
- [#1983](https://github.com/kanta13jp1/my_web_app/issues/1983) P1 — メモリ/ディスク使用量削減の定期監査
- [#1564](https://github.com/kanta13jp1/my_web_app/issues/1564) P1 — Claude Code PreCompact/StatusLine/SessionStart/Setup による記憶保全

## 関連 rule (= `~/.claude/hooks/inject-rules.txt`)

- `[CAVEMAN]` — communication 圧縮 (= ~75% token 削減)
- `[STASH-SAFETY]` — uncommitted 変更 10 min 超え禁止
- `[SCHEDULE-WAKEUP]` — 深夜 wakeup 禁止 + idle limit
- `[COMPACTION-RESUME]` — compaction 後 90 min 以内 wrap-up
- `[MEMORY-DECAY]` — memory file 30+ days reference 0 で consolidate / 200+ entries で split
- `[WORKDIR-ISOLATION]` — main repo 直接編集禁止 / worktree 必須

## SNS 煽り対策 intake (= 新モデル発表時)

新 AI モデル発表 SNS 投稿に翻弄されず、評価 task として正式取り込み:

1. **scripts/check_versions.py --web** で公式 source 検証 (= `[AI-TOOL-VERIFY]` rule)
2. [#2520](https://github.com/kanta13jp1/my_web_app/issues/2520) P1 比較ベンチ基盤に evaluation candidate として追加
3. [#2522](https://github.com/kanta13jp1/my_web_app/issues/2522) P2 月次レビューに反映
4. SNS 投稿のまま「最強モデル」固定採用は禁止 (= プロンプト/tool/価格/レイテンシで逆転前提)

## 部 220 contribution

部 220 (= 2026-05-16 同日 5th part / RAM hard exit 第 12 例) で本 policy doc を ship. 既存 ops runbook (DISK_HYGIENE_RUNBOOK.md / 2016 行) は深度実装 ref, 本 doc は per-session quick checklist として位置付け. 同日 4-part cap rationale 立証 = 自然 GC は overnight 必要 / intra-day 累積追いつかず.
