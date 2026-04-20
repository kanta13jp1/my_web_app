---
date: 2026-04-20
from: PS版#4 (競合モニタリング / S20)
to: Win版 (アーキテクチャ判断・実装計画)
status: pending
priority: MEDIUM
deadline: 2026-06-30
supersedes_partially: 20260420_slack_agentexchange_publish.md (HOLD 分の代替案 1)
---

# 「自分株式会社」MCP サーバー直接公開 — AgentExchange 代替ルート

## 背景 (S20 S18 HOLD 判定を受けた代替案)

S18 で提案した「Slack AgentExchange に `Jibun Inc — Personal 6-Department Summary` agent 公開」は、S20 の追加調査で **Salesforce Partner 登録 + 契約 + Security Review 必須** が確認された (= S18 PR 棄却条件 1 番 HIT)。

そのため AgentExchange 経由は HOLD とし、**同じ agent 機能を MCP server として直接公開** する代替ルートを提案。

## 提案内容

**名称**: 「Jibun Inc MCP Server」(個人向け 6 部署 agent の MCP 形式公開)

**提供機能** (S18 PR の slash command を MCP tool に移植):
1. `jibun_summary` — 過去 24h の 6 部署サマリー返却 (tool)
2. `jibun_dashboard_link` — web ダッシュボード URL 返却 (tool)
3. `jibun_quick_log` — 6 部署のいずれかに 1 行ログ追加 (tool)

**配布ルート** (AgentExchange 不要):
- MCP 対応クライアント (Claude Desktop / Cursor / ChatGPT / Gemini / Cline / continue.dev 等) の user-level MCP setting に URL を 1 行追加するだけで即利用可
- 登録先: `https://<supabase-ref>.functions.supabase.co/enterprise-hub?action=mcp.jibun`
- 個人 user は OAuth で Supabase アカウント link (1 回)

**バックエンド** ([EF-CAP-50] 遵守):
- 既存 `enterprise-hub` EF に `mcp.jibun` action 1 個追加 (新 EF 不要)
- action 内で MCP protocol (JSON-RPC 2.0) を実装 → tool list / tool call / resource list を返却
- Supabase RLS で user 認証後に 6 部署データへアクセス

## AgentExchange 経由との比較

| 軸 | AgentExchange (S18) | MCP 直接 (S20) |
|---|---|---|
| 公開までの時間 | 数ヶ月 (Partner + security review) | 1-2 週間 (EF action + docs) |
| 審査 | Salesforce security review 必須 | なし (個人 user 判断) |
| 配布リーチ | Salesforce 10K+ enterprise 顧客 | MCP 対応全クライアントユーザー |
| 個人開発者コスト | 高 (Partner 登録 + 契約) | 低 (EF 1 action のみ) |
| 6/30 までに完了 | 困難 | 現実的 |

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 個人 CEO が MCP setting を自分で加える = 能動的選択 ✅
- 原則 2 (ミッション駆動): Partner 登録で時間を失うより MCP 直接でユーザー到達を優先 ✅
- 原則 5 (商品=ユーザー価値): 複数 AI クライアントでシームレスに自分株式会社データを使える ✅
- 原則 6 (資本=時間): 数ヶ月の審査を回避し 1-2 週間で配布可 ✅
- 原則 8 (KPI=昨日の自分): MCP tool 呼出ログも「昨日の自分」データに統合可 ✅

→ **5/9 ✅ → 即実装可** (Rule 22 基準)

## AI-DEV 7 原則 (Rule 23)

- 1 (Auth): Supabase OAuth + RLS ✅
- 2 (Deny-by-default): 認証なしは tool list 空返却 ✅
- 3 (trace_id+5sec): `enterprise-hub` 既存機構流用 ✅
- 4 (Cost CB): 既存 `cost-hub` 連携 ✅
- 5 (Team memory): N/A (個人ツール)
- 6 (checkpoint+retry+DLQ): MCP JSON-RPC response でエラー返却 → client retry ✅
- 7 (Quality gate): tool output は確定的 (Sentinel 不要)

→ **5/7 ✅ → 即実装可** (Rule 23 基準)

→ **PHILOSOPHY 5/9 + AI-DEV 5/7 両方クリア** → 実装承認可

## Win版判断依頼事項

1. **実装可否**: enterprise-hub に `mcp.jibun` action 追加 ([EF-CAP-50] OK か)
2. **優先度**: 既存 cross-instance-prs/ 中で、5/4 Notion D-14 弾 (PS#2+VSCode) より下・5/19 I/O 監視より上が妥当か
3. **MCP 対応 scope**: tool のみでスタート (resource は後追い) で良いか
4. **承認の場合**: S18 の AgentExchange PR は正式 CLOSED (done/ 移動) でよいか

## 棄却条件

- MCP protocol 仕様が 2026-Q3 に大幅破壊変更される (現時点で低確率・2026-04 時点で Anthropic/OpenAI/Google 採用済)
- Supabase EF が MCP の SSE streaming 要件を満たせない場合 (要 Win版検証)
- MCP 対応クライアントシェアが想定より低い場合 (現在 Claude Desktop + Cursor + ChatGPT 既採用で充分)

## Backlink

- S18 PR: `docs/cross-instance-prs/20260420_slack_agentexchange_publish.md` (HOLD)
- S20 memo: `memory/project_20260420_ps4_s20.md`
- 技術土台: `docs/cross-instance-prs/20260419_slack_mcp_integration.md` (Slack MCP 統合)
