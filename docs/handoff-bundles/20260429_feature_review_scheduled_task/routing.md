# Routing — 機能レビュー Scheduled Task Bundle

| Section | Territory | Status | Commit | Notes |
| --- | --- | --- | --- | --- |
| `scripts/feature_review_config.json` | Win | ✅ done | (本 bundle commit) | 対象機能列挙 / レビュー対象 page + EF action |
| `docs/SCHEDULE_TASKS.md` 更新 | Win | ✅ done | (本 bundle commit) | 新 task 説明セクション追加 |
| `.github/workflows/feature-review.yml` | Codex#2 | ⏳ pending | — | 週次 cron 火曜 JST 03:00 (= UTC 月 18:00) |
| `scripts/feature_review.py` | Codex#2 | ⏳ pending | — | Playwright + Claude API + GitHub Issue 起票 ロジック |
| `integration_test/feature_review_dry_run.py` | Codex#2 | ⏳ pending | — | --dry-run mode で smoke test |
| GitHub labels (`auto-review`, `severity:*`, `feature:*`) | Codex#2 | ⏳ pending | — | リポジトリ設定で追加 |
| `docs/handoff-bundles/done/20260429_feature_review_scheduled_task/` 移動 | Codex#2 | ⏳ pending | — | 全 section ✅ 後の最終 commit |

## Codex#2 受領手順

1. 本 README + routing 確認
2. workflow yml + Python script を **本 bundle 内に追加** (= `scripts/feature_review.py` を bundle 内に skeleton 配置済 → 実装で書き換え)
3. integration test 追加
4. PR は既存 main 直 push で OK (= bundle 完成 = 全 section ✅ で `done/` 移動)
5. 本 routing.md の status 列を ✅ に更新 + commit hash 記載

## 完成判定

全 section ✅ + 24h soak (= 初回 cron run + 翌週 cron run 2 回) で完成. `done/` 移動.

---

*Win版#132 part 77 / 2026-04-29*
