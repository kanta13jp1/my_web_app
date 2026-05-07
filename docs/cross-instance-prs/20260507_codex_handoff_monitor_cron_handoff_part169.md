# Cross-Instance PR: Hand-off Auto-Ping Cron 自走化 hand-off

> **作成**: Win版#132 part 169 / 2026-05-07
> **From**: Win Claude (= architect / design)
> **To**: Win Codex (= GHA workflow + Python script 実装)
> **優先度**: medium (= Phase 6 自走化 / Win Claude session 5-10 min/day 削減 / 期限なし)
> **関連**: [docs/CROSS_INSTANCE_HANDOFF_MONITOR_SPEC.md](../CROSS_INSTANCE_HANDOFF_MONITOR_SPEC.md) / part 167 ping trigger schedule / Phase 1→2 自走化分離 dogfood 第 9 例

---

## 概要

Win Claude session の主要 manual triage (= Codex hand-off PR daily query + ping trigger calendar 監視 + 期限残 7 日 ping comment) を GHA cron で自走化。User 要望「できる限り手動の作業をなくしていきたい」直接対応。

## Codex 依頼内容 (= 2 file)

### 1. `.github/workflows/cross-instance-handoff-monitor-cron.yml` 新規

spec §3.1 の YAML をそのまま使用。

- daily 03:00 UTC = 12:00 JST
- workflow_dispatch で dry_run option (= default true)
- `permissions: issues: write, pull-requests: read`

### 2. `scripts/cross_instance_handoff_monitor.py` 新規

spec §3.2 の Python コードをそのまま使用。

- dependency-free (= argparse + gh CLI subprocess + json + datetime + re + pathlib)
- `docs/cross-instance-prs/<date>_codex_*_handoff_part<N>.md` scan
- Issue # + 期限 + keyword 抽出 (= regex)
- `gh pr list --search "<keyword>"` で matching PR 確認
- ping trigger: 起票後 7 日 OR 期限残 7 日
- idempotent: 同 week 内 ping 1 回 cap (= `## Codex hand-off auto-ping (week N` header detection)
- safety cap: `MAX_PINGS_PER_RUN=3`

## 受け入れ条件 (= 7 項目)

spec §4 そのまま転記:

- [ ] `.github/workflows/cross-instance-handoff-monitor-cron.yml` 新規
- [ ] `scripts/cross_instance_handoff_monitor.py` 新規 (dependency-free)
- [ ] `permissions: issues: write, pull-requests: read` 設定
- [ ] dry-run smoke test: 6 active hand-off 全 scan + status 表示
- [ ] apply smoke test: 5/14 を simulate (file mtime back-date) で実 ping
- [ ] idempotent gate test: 同 week 2 度実行 → 2 度目 skip
- [ ] cap test: 4+ trigger でも 3 件で stop

## Win Codex 推奨実装順

1. `scripts/cross_instance_handoff_monitor.py` 作成 (= spec §3.2 コピー)
2. `.github/workflows/cross-instance-handoff-monitor-cron.yml` 作成 (= spec §3.1 コピー)
3. local 動作確認 (= environment 変数 set 後 `python scripts/cross_instance_handoff_monitor.py --apply=false`)
4. PR 作成 (= title `feat(cron): cross-instance hand-off auto-ping monitor (Phase 2 dogfood)`)
5. PR merge 後 dry-run workflow_dispatch 1 回実行 → 結果 issue に comment

## 注意

- **[NO-SCOPE-CREEP]**: 本 cron は hand-off ping のみ。code review / PR auto-merge は別 cron。
- **dry-run default**: 初回数週間は `dry_run=true` 維持推奨。
- **safety cap**: `MAX_PINGS_PER_RUN=3` で 1 cron run 最大 3 ping。
- **idempotent gate**: 同 week 内 2 度 ping 防止。
- **frequency**: daily (= 12:00 JST) で過剰 ping 回避。
- **author auto-detection**: comment author == bot で skip ([AUTO-REPLY] rule respect)。
- **既存 hand-off pattern compatible**: `<YYYYMMDD>_codex_<topic>_handoff_part<N>.md` 命名 + Issue # `Issue [#NNNN](` + 期限 `期限 YYYY-MM-DD` を解析。

## Phase 0 hand-off (= Win Claude territory) 完了 note

本 hand-off 文書は Win Claude triage role の成果物。Codex 振分 5 質問 Q1 YES → Win Claude design / 実装 = Win Codex。

「Phase 1 手動 → Phase 2 自走化分離 dogfood」pattern 第 9 例 (= 累積 ingest / lint / compile / query / scheduled-residuals / feature-review-rotation / ai-tool-changelog / dormant-grace / hand-off-monitor)。

cc @kanta13jp1
