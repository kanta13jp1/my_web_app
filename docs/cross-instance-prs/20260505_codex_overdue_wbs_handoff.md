# [Codex CLI 宛] Overdue WBS task 6 件 hand off + Win Claude 担当 2 件 part 143 deferred

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 142)
**to**: Win Codex CLI
**priority**: high (= 全件 deadline 経過)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix (docs/CODEX_WORKFLOW.md §6) + `[WBS-SYNC]`

## Summary

WBS overdue tasks の deadline 順 top 8 を 5-question 振分で 2 instance 制反映。
Codex territory 6 件をこちらへ hand off、Win Claude territory 2 件 (= 設計系) は
part 143 で深堀。

## Codex CLI 担当 (= 6 件 / 期限近い順)

各 task は overdue 状態。WBS UI: <https://my-web-app-b67f4.web.app/wbs-user-tasks>

| # | issue | rationale | hint |
|---|---|---|---|
| 1 | [#1266](https://github.com/kanta13jp1/my_web_app/issues/1266) VS Code 拡張機能リモートセッション起動 | 実装 (dev-env tooling) | `.vscode/` 拡張 + `code-server` integration |
| 2 | [#1283](https://github.com/kanta13jp1/my_web_app/issues/1283) GHA 未 Push 検知ガード | GHA (workflow_dispatch pre-check) | `.github/workflows/` 新 yml + `gh-checks` action |
| 3 | [#1296](https://github.com/kanta13jp1/my_web_app/issues/1296) Hedra API クレジット残量監視 | EF Deno + monitoring | `supabase/functions/api-credit-monitor/` 新規 + Slack notification |
| 4 | [#1302](https://github.com/kanta13jp1/my_web_app/issues/1302) 記事 draft 品質ガードレール | T-1 dispatch (= blog automation) | `.github/workflows/blog-draft-lint.yml` + textlint or LLM eval |
| 5 | [#1304](https://github.com/kanta13jp1/my_web_app/issues/1304) branch 保護公開 status 自動化 | GHA + branch protection | GitHub API `PATCH /repos/.../branches/main/protection` + status check |
| 6 | [#1308](https://github.com/kanta13jp1/my_web_app/issues/1308) 外部連携 retry/errhandling 強化 | 実装 pattern | EF 内 `withRetry()` helper + DLQ ([AI-DEV-23] #6) |

## Win Claude 担当 (= 2 件 / part 143 deferred)

| # | issue | rationale | next-part deliverable |
|---|---|---|---|
| 7 | [#1305](https://github.com/kanta13jp1/my_web_app/issues/1305) Stripe + フリーミアム | 設計 / business model / 商品=価値 ([PHILOSOPHY-22] #5) | `docs/MONETIZATION_DESIGN.md` (= tier matrix + Stripe schema + EF 設計) |
| 8 | [#1309](https://github.com/kanta13jp1/my_web_app/issues/1309) 計画停止 dashboard | UI design / 設計 doc | `docs/MAINTENANCE_MODE_SPEC.md` (= UI mockup + status schema + auto-toggle logic) |

## 5-question matrix 適用 (= 振分根拠)

質問 (docs/CODEX_WORKFLOW.md §6 抜粋):
1. Q1 設計 / architect 要素を含むか
2. Q2 docs / memory 更新が主か
3. Q3 UI design / mockup を含むか
4. Q4 triage / 競合 / AI 大学 / mobile UAT / 動画 task か
5. Q5 部署横断 / 抽象化レビューが必要か

| # | Q1 | Q2 | Q3 | Q4 | Q5 | judge |
|---|---|---|---|---|---|---|
| 1266 | N | N | N | N | N | Codex |
| 1283 | N | N | N | N | N | Codex |
| 1296 | N | N | N | N | N | Codex |
| 1302 | N | N | N | N | N | Codex |
| 1304 | N | N | N | N | N | Codex |
| 1305 | **Y** | N | N | N | **Y** | Win Claude |
| 1308 | N | N | N | N | N | Codex |
| 1309 | **Y** | N | **Y** | N | N | Win Claude |

## 期限 + SLA

- 全 6 Codex 件: 既に 1-3 日 overdue → 今 session 中の triage 起票推奨
- Win Claude 2 件: part 143 (= 次 session) で 設計 doc 起票

## dogfood

- `[INSTANCE-ROLES]` 5-question matrix 8 件一括適用 (= 第 1 例)
- `[DYNAMIC-CLAIM]` 1 session 2 件 cap 遵守 (= deferred で respect)
- `[WBS-SYNC]` overdue 一括 triage pattern 確立 (= weekly cron 候補)
