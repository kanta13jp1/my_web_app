# Cross-Instance PR: Dormant Instance 30 日 Grace 自走化 hand-off

> **作成**: Win版#132 part 165 / 2026-05-07
> **From**: Win Claude (= architect / design)
> **To**: Win Codex (= GHA workflow + Python script 実装)
> **優先度**: medium (= Phase 6 自走化 / 期限なし / monthly cleanup ROI 計算で正当化)
> **関連**: [docs/DORMANT_INSTANCE_GRACE_AUTOMATION_SPEC.md](../DORMANT_INSTANCE_GRACE_AUTOMATION_SPEC.md) / Issue [#1962](https://github.com/kanta13jp1/my_web_app/issues/1962) (= 第 1 ケーススタディ)

---

## 概要

part 163 で確立した「dormant 30 日 grace pattern」を Phase 1 (= 手動) から Phase 2 (= 自走化) に分離。Win Claude territory「dormant 整理」を構造的自走化。

## Codex 依頼内容 (= 3 file)

### 1. `.github/workflows/dormant-instance-grace-cron.yml` 新規

spec §3.1 の YAML をそのまま使用。

- weekly Mon 02:00 UTC = 11:00 JST
- workflow_dispatch で dry_run option
- `permissions: issues: write` (= comment + close 必要)

### 2. `scripts/dormant_instance_grace.py` 新規

spec §3.2 の Python コードをそのまま使用。

- dependency-free (= argparse + gh CLI subprocess + json + datetime)
- 11 dormant label 全網羅
- WARN_DAYS=14 で grace comment / GRACE_DAYS=30 で auto-CLOSE
- `workflow-failure` label + 再現 comment detection で safety gate

### 3. dry-run smoke test → apply smoke test

a. `gh workflow run dormant-instance-grace-cron.yml -f dry_run=true` で初回実行 → 該当件数確認
b. dry-run 出力で WARN/CLOSE candidate を visual review
c. 問題なければ `dry_run=false` で actual run
d. Issue #1962 (= 第 1 ケース) で grace comment 自動投稿確認

## 受け入れ条件 (= 8 項目)

spec §4 そのまま転記:

- [ ] `.github/workflows/dormant-instance-grace-cron.yml` 新規
- [ ] `scripts/dormant_instance_grace.py` 新規 (dependency-free)
- [ ] `permissions: issues: write` 設定
- [ ] dry-run smoke test 1 回成功
- [ ] apply smoke test 1 回成功
- [ ] `workflow-failure` label 付与 issue skip 確認
- [ ] 再現 comment 含む issue skip 確認
- [ ] PR description に spec link + 受け入れ条件 checklist

## Win Codex 推奨実装順

1. `scripts/dormant_instance_grace.py` 作成 (= spec §3.2 コピー)
2. `.github/workflows/dormant-instance-grace-cron.yml` 作成 (= spec §3.1 コピー)
3. local 動作確認 (= `python scripts/dormant_instance_grace.py --apply=false` を environment 変数 set 後実行)
4. PR 作成 (title: `feat(cron): dormant instance 30-day grace automation (#1962 follow-up)`)
5. PR merge 後 dry-run workflow 1 回実行 → 結果 comment

## 注意

- **[NO-SCOPE-CREEP]**: 本 cron は dormant label issue のみ対象。
- **dry-run default**: 初回数週間は `dry_run=true` 維持推奨。
- **safety**: `workflow-failure` label + 再現 comment detection で **bug-as-dormant** 誤 close 回避。
- **frequency**: weekly cap (= Mon 11:00 JST) で comment spam 回避。
- **idempotent**: 既 grace comment 投稿済 issue には 2 度投稿しない (= `has_grace_comment()` check)。

## Phase 0 hand-off (= Win Claude territory) 完了 note

本 hand-off 文書は Win Claude triage role の成果物 (= [INSTANCE-ROLES] 遵守 / Codex 振分 5 質問 Q1 YES → Win Claude design / 実装 = Win Codex)。

Phase 1 (= 手動 / part 163 / Issue #1962 適用) → Phase 2 (= 自走化 / 本 hand-off / Codex 実装) → Phase 3 (= 月次 KPI report / 削減 graveyard 件数集計 / 別 cron 候補) の 3 段階で graveyard 防止 infra 完成想定。

cc @kanta13jp1
