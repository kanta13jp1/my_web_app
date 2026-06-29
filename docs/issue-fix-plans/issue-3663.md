# Issue Fix Plan #3663

- Issue: [[追加要望] 🌱 ユーザー獲得+free→paid転換 統括（成長エピック）](https://github.com/kanta13jp1/my_web_app/issues/3663)
- Labels: 追加要望,priority:critical,monetization,growth
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28343035978

## Goal

[追加要望] 🌱 ユーザー獲得+free→paid転換 統括（成長エピック）

## Current Context

```text
## 🌱 ユーザー獲得 + free→paid 転換 統括（成長エピック）

収益化の課金基盤は完成・テスト実証済（統括 #3639）。本Issueは**実ユーザーを増やし有料転換させる**ための成長タスクを統括する。

### 監査の核心（既存インフラは厚い・壊れているのは"つなぎ目"）
- SEO土台/robots/sitemap/OGP/構造化データ・**Qiita+dev.to日次自動投稿**・週次X投稿・**紹介プログラム(growth-hub)**・チャネルアトリビューションは**既にlive**。
- 🔴 ファネルが**最高intentの2点で破綻**: (1) ai-hub の `402 free_limit_reached`(upgrade_url:/billing付き)を**クライアントが一切解釈していない**(ai_service が `message` でなく `error` キーを読む)→ 上限到達時に汎用エラー。(2) landing が logged-out に「完全無料/課金の概念が存在しない」と繰り返し料金非提示→壁で信頼破壊。
- 🔴 **operator が収益を見られない**: admin_analytics に billing_subscriptions/MRR クエリ皆無→初課金が来ても判別不能。

### 最初の実¥への最短路
**operator が Stripe **live** で自己購読(¥980)** が最速の実MRR（KYC後・本日可）。外部の実課金ユーザーはトラフィック+時間が必要→以下のP0で正直で観測可能なファネルを組む。

### 子タスク（P0優先）
- P0 #C1 402→アプリ内アップグレード導線 / #C2 landing「完全無料」修正+料金提示 / #C3 経営ダッシュボードに有料転換(MRR)セクション
- P1 #C4 課金ファネル計測 / #C5 常設アップグレード導線+使用量ナッジ / #C6 紹介報酬→実Stripe特典 / #C8 Product Huntローンチ
- P2 #C7 紹介→有料アトリビューション / #C9 sitemap自動生成 / #C10 静的per-route meta / #C11 daily-metricsに収益 / #C12 死にメトリクス修正

親: 収益化統括 #3639


```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
