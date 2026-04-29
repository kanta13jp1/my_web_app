# Routing — 機能レビュー Scheduled Task Bundle

| Section | Territory | Status | Commit | Notes |
| --- | --- | --- | --- | --- |
| `scripts/feature_review_config.json` | Win | ✅ done | (part 77 / part 78 で更新済) | 対象機能列挙 / 13 機能 round-robin 設定 |
| `docs/SCHEDULE_TASKS.md` 更新 | Win | ✅ done | (part 77 / part 78 で更新済) | 毎時 0 分 cron 説明 |
| `.github/workflows/feature-review.yml` | Codex#2 | ✅ done | `e593a5492` | 毎時 cron / force_full_scan / dry_run / target_features 対応 |
| `scripts/feature_review.py` | Codex#2 | ✅ done | `e593a5492` | 13 機能 rotation / Playwright / Claude / lint / dedupe / Issue 起票 |
| `integration_test/feature_review_dry_run.py` | Codex#2 | ✅ done | `e593a5492` | dry-run smoke test |
| GitHub labels (`auto-review`, `severity:*`, `category:*`, `feature:*`) | Codex#2 | ✅ done | — | 24 件 repo 直接設定済 (= Codex#2 確認済) |
| `docs/handoff-bundles/done/20260429_feature_review_scheduled_task/` 移動 | Win | ✅ done | (part 80) | 全 file main 反映確認 + done/ 移動 (= Win版#132 part 80 / 2026-04-29) |

## Codex#2 の現状 (= 2026-04-29 push 対応時点)

Codex#2 は新 worktree (= 最新 `origin/main` 同期済) で feature-review 関連 file のみを移植し、unrelated 別タスク差分を除外した。

### 次手順

1. Win版 が main で file 存在確認
2. `docs/handoff-bundles/done/20260429_feature_review_scheduled_task/` へ移動
3. 24h soak (= 初回 cron run + 翌日以降の rotation 確認)

### 検証済 (= push 後に再現確認)

- `python -m py_compile scripts/feature_review.py integration_test/feature_review_dry_run.py` → pass
- `python integration_test/feature_review_dry_run.py` → pass
- `python scripts/feature_review.py --config scripts/feature_review_config.json --dry-run --rotation-hour 0 --skip-ai --skip-playwright` → pass

### 本番稼働の前提

- GitHub Secrets `ANTHROPIC_API_KEY` 設定済 (= 既存)
- `SLACK_WEBHOOK_URL` 設定済 (= 既存)
- 24 GitHub labels (auto-review / severity:* / category:* / feature:*) → ✅ Codex#2 設定済

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
