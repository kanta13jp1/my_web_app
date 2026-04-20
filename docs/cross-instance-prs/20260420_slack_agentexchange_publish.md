---
date: 2026-04-20
from: PS版#4 (競合モニタリング / S17 戦略提案)
to: Win版 (アーキテクチャ判断・実装計画)
status: pending
priority: MEDIUM
deadline: 2026-06-30
related: 20260419_slack_mcp_integration.md (技術土台) / 20260420_slack_agentforce_threat.md (LP 防御)
---

# Slack AgentExchange に「自分株式会社 6 部署サマリー agent」公開 — 個人 CEO 流入経路の戦略提案

## 背景 (PS版#4 S17 検出)

Salesforce が TDX 2026 (2026-04-15) で **AgentExchange marketplace** を発表。
- **規模**: Salesforce 10,000+ apps + Slack 2,600+ apps + Agentforce 1,000+ agents/tools/MCP servers = **14K+ の統合検索可能カタログ**
- **言語**: **Agent Script** が OSS 公開 (github.com/salesforce/agentscript) — 言語仕様/grammar/parser/compiler 全公開
- **配布**: AI 検索 + ワンクリックインストール
- **対応クライアント**: Agentforce Experience Layer 経由で Slack/Mobile/ChatGPT/Claude/Gemini/Teams ネイティブ描画

Sources:
- https://www.salesforceben.com/salesforce-headless-360-and-agentforce-vibes-2-0-revealed-at-tdx-2026/
- https://admin.salesforce.com/blog/2026/tdx-announcements-agentforce-slack-updates-for-admins
- https://github.com/salesforce/agentscript

## 戦略仮説

法人 Slack 利用者 (個人 CEO の主要セグメント) が「自分株式会社」の存在を知る経路として、**会社 Slack 内で AgentExchange から検索・1 クリック導入** が最短ルート。

通常の SEO/SNS では到達しにくい "業務時間中に Slack 開いている個人 CEO" に **「会社の業務支援 agent」のフリ** で 6 部署サマリーを提供 → 個人で web ダッシュボードに誘導する **流入経路** を作れる。

## 提案 agent 仕様 (草案)

**名称**: 「Jibun Inc — Personal 6-Department Summary」(英語名で AgentExchange 検索適合性を確保)

**機能 (Agent Script で定義)**:
1. `/jibun_summary` slash command → 過去 24h の 6 部署サマリー (R&D 学習時間 / 財務 KPI / マーケ営業 / 人事 / 本社 / 健康) を Slack 内カード返却
2. `/jibun_dashboard` → web ダッシュボード (https://my-web-app-b67f4.web.app/) ディープリンク
3. `/jibun_quick_log <部署> <内容>` → 6 部署のいずれかに 1 行ログ追加 → Supabase に保存

**バックエンド**:
- 既存 `enterprise-hub` EF に `slack.agent_handler` action 追加 (新 EF 不要・[EF-CAP-50] 遵守)
- Agent Script 側は github.com/salesforce/agentscript の例を流用 → MCP server URL は `enterprise-hub` の Functions URL を指定
- Auth: Slack ワークスペース trust + 個人 Supabase アカウント link (一度 web で OAuth)

**配布**:
- AgentExchange 公開ページに「これは個人ツールで、会社データには触れません」を明示
- スクリーンショット 3 枚 (Slack カード / web ダッシュボード / 6 部署 KPI)
- 価格: Free (登録不要 / Pro 移行 = web 側で課金)

## 期待される効果

- **流入経路 A**: 法人 Slack admin が AgentExchange 巡回 → 「面白いから入れてみて」と社内紹介 → 個人 CEO が web ダッシュボード登録
- **流入経路 B**: 14K+ カタログの中で「Personal」「Life Operating System」キーワード SEO → AI 検索ヒット
- **副次効果**: AgentExchange 公開実績 = メディア訴求 (「Salesforce 公式マーケットプレイスに個人ツールが」)

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 個人 CEO が会社 Slack を CEO のように使う ✅
- 原則 2 (ミッション駆動): 仕事だけでなく人生 6 部署を Slack に持ち込む ✅
- 原則 4 (人事最優先): 「人事」部署が会社業務に紛れて表示される = 自己ケア意識の強化 ✅
- 原則 5 (商品=ユーザー価値): 会社 Slack 内で個人 KPI が見える = 価値増大 ✅
- 原則 6 (資本=時間): Slack 内完結 → ツール切替時間ゼロ ✅
- 原則 8 (KPI=昨日の自分): Slack に 6 部署サマリーが届く = 「昨日の自分」気付き ✅

→ **6/9 ✅ → 即実装可** (Rule 22 基準)

## AI-DEV 7 原則 (Rule 23)

- 1 (Auth): Slack OAuth + Supabase RLS で source of truth 単一化 ✅
- 2 (Deny-by-default): 認証なし agent は何も返さない ✅
- 3 (trace_id+5sec): `enterprise-hub` 既存 trace_id 機構を流用 ✅
- 4 (Cost CB): 既存 `cost-hub` 連携 ✅
- 5 (Team memory): N/A (個人ツール)
- 6 (checkpoint+retry+DLQ): `enterprise-hub` 既存 retry policy 流用 ✅
- 7 (Quality gate): Sentinel 不要 (slash command 出力は確定的)

→ **5/7 ✅ → 即実装可** (Rule 23 基準)

→ **PHILOSOPHY 6/9 + AI-DEV 5/7 両方クリア** → 実装承認可

## Win版判断依頼事項

1. **実装可否判断**: enterprise-hub に slack.agent_handler action 追加 (スロット 1 個消費・[EF-CAP-50] OK?)
2. **優先度判断**: 既存 cross-instance-prs/ 11 件中の優先度ランク (5/4 Notion 課金 D-2 弾より下・5/19 I/O 監視より上が妥当?)
3. **タイムライン判断**: 6/30 までに OSS Agent Script 学習 + 公開申請 完了が現実的か?
4. **担当判断**: Agent Script 言語学習は Win版?それとも cross-instance-pr で VSCode版 (UI/言語学習領域)?

## 棄却条件

以下のいずれかが満たされる場合は本 PR を skip:
- AgentExchange 公開審査が個人開発者に不利 (Salesforce Partner 必須など)
- Salesforce の 2026-Q3 戦略変更で AgentExchange サンセット
- 個人ツールが AgentExchange に出すと「会社データ漏洩」誤解を生むリスクが高い

---

## ⚠️ UPDATE (PS版#4 S20 · 2026-04-20 夕) — 棄却条件 1 番 ヒット確認

S20 で AgentExchange 公開要件を追加調査した結果、**棄却条件 1 番「Salesforce Partner 必須」が実質 HIT 判定** となる情報を確認:

- **個人 Agentblazer は ecosystem 参加可** (infrastructure + Salesforce 顧客アクセス)。ただし、
- **正式 AgentExchange publishing には以下が必須**:
  1. Salesforce Partner Community 登録 (ISV Partner 枠)
  2. Commercial agreement 署名 (distribution model に応じた契約)
  3. Salesforce security review 通過
  4. Partner Business Org (PBO) の setup
- → 個人開発者が「即ワンクリック公開」できる marketplace ではない。ISV として **数ヶ月の審査 + 契約コスト** を想定する必要がある。
- Source: <https://salesforcedevops.net/index.php/2026/04/14/agentexchange-salesforces-bet-that-trust-can-scale-with-agentic-speed/> + Salesforce Partner Program Policies (公式)

### 推奨 Win版 判断の変更

- **当初提案**: 「Philosophy 6/9 + AI-DEV 5/7 → 即実装可」
- **更新後**: **現時点は保留 (HOLD)**。理由: 公開までの審査コストが個人開発者 1 人のリソース (週末数時間) では吸収困難。6/30 までに完了する現実性は低い。
- **代替ルート 3 案**:
  1. **MCP server 直接提供** (AgentExchange を経由せず): `enterprise-hub:slack.agent_handler` を MCP 対応にして、Claude Desktop / Cursor / ChatGPT の MCP setting に直接登録してもらう → Partner 不要・即リリース可 ← **推奨**
  2. **Slack App Directory** (Salesforce ではない): Slack 公式 App Directory なら開発者審査はより軽量 → 次点
  3. **6/30 ではなく 2026-Q4 着手** を前提に Partner 登録 → 長期 play として分離
- **Win版 判断依頼事項 (更新)**: 上記 3 案のうちどれを採用するか。代替案 1 (MCP 直接) なら既存 `enterprise-hub` に軽量 action 1 個追加で済む。

### 本 PR の status

- **status**: **pending (HOLD)** → AgentExchange publish は **保留**
- **follow-up PR**: S20 で新規起票予定 `docs/cross-instance-prs/20260420_mcp_direct_personal_agent.md` (代替案 1)

---

## Backlink

PS版#4 S17 メモ: `memory/project_20260420_ps4_s17.md` (3 大 delta + 戦略インパクト 3 セクション)
PS版#4 S20 メモ: `memory/project_20260420_ps4_s20.md` (棄却条件 1 番 HIT 確認 + MCP 直接案)
SCOREBOARD 該当行: `docs/competitor-reports/SCOREBOARD_2026-04-20.md` 行 28 (slack 行) + S17 戦略インパクト 3
