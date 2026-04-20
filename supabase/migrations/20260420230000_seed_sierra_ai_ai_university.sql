-- Session PS#3-S25: AI大学 143 社化 — Sierra 追加
-- Bret Taylor (OpenAI 会長・元 Salesforce 共同 CEO) + Clay Bavor (元 Google Labs) 創業の
-- agentic customer experience プラットフォーム。
-- 2024-02 launch → 2026-01 ARR $150M / 2025-09 $350M round @ $10B valuation。
-- 既存 142 社に空白だった「エンタープライズ CX 専業 agent」軸を埋める。
-- 顧客: ADT / SiriusXM / Sonos / WeightWatchers / Fortune 50 の 40%
-- Step 0: 8/9 (closed SaaS のため OSS=0.5 減点 / API=顧客契約ベース限定で 0.5 減点)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'sierra',
    'overview',
    'Sierra — Bret Taylor が率いる agentic customer experience プラットフォーム',
    $md$
# Sierra — Bret Taylor が率いる agentic customer experience プラットフォーム

2023 年 stealth 創業、2024-02 launch。CEO **Bret Taylor** (OpenAI 取締役会長・
元 Salesforce 共同 CEO・元 Facebook CTO・Google Maps 共同開発) と CTO
**Clay Bavor** (元 Google Labs VP / Google VR Project Starline リード) が率いる
「エンタープライズ向け agentic customer experience (CX) プラットフォーム」。
コールセンター・サポートチャネル・voice agent を全て自律 AI で運用し、
**解決ベース課金 (outcome-based pricing)** を世界初で定着させた。

## 既存 142 社との差別化
| 観点 | Sierra | Salesforce Agentforce | Decagon (既存未登録) |
|------|--------|------------------------|----------------------|
| レイヤー | 🎧 **agentic CX (voice + chat) SaaS** | CRM 統合 agent | CX agent (early stage) |
| 導入形態 | 非公開 SaaS / 顧客個別構築 | Salesforce 内製 add-on | マルチテナント SaaS |
| 課金モデル | **outcome-based** (解決単価 / upsell 成功単価) | seat + credit | conversation-based |
| 主要顧客 | Fortune 50 の 40% (ADT / SiriusXM / Sonos 等) | Salesforce 既存顧客 | Notion / Duolingo 等 |
| Voice 比率 | text 超えて voice が primary (2025-10) | voice は限定 | text 中心 |
| 哲学 | 「ヒトを代替する autonomous agent 工場」 | CRM 業務フロー自動化 | 会話 resolution 最適化 |

## 主要プロダクト — Agent OS 2.0 (2025-11 改訂)
8 プロダクトで構成された CX 向け agentic 基盤。
- **Agent Studio 2.0** — 業務プロセス記述 + plybook 化で agent 構成 (低コード)
- **Agent Data Platform** — 顧客単位の persistent memory + context graph
- **Live Assist** — 人間エスカレーション UI (agent が難題を引き継ぐ前に人間 handoff)
- **Voice Agent** — call-center 代替 (2024-10 GA → 2025-10 で text 超え primary channel)
- **Chat Agent** — 従来型 web widget + in-app chat
- **Agent SDK** — 顧客内部ツール接続 (CRM / billing / ERP 連携)
- **Trust & Safety** — PII 検出 + guardrail + escalation rule
- **Analytics** — resolution rate / containment / CSAT / cost-per-resolve 監視

## 業績 (Sacra 推計 / 2026-01 時点)
- **ARR $150M** (2026-01) ← $130M (2025-12) ← $100M (2025-11) ← $26M (2024-12)
- 7 四半期で $0→$100M ARR (SaaS 史上最速クラス)
- 初 $50M 単四半期を 2025-Q4 に達成
- 粗利率非公開だが outcome-based で mid-70s% 前後推定

## 資金調達
- 2024-10 Series B: **$175M @ $4.5B valuation** (Sequoia 主導・Benchmark・Thrive 他)
- 2025-09 Series C: **$350M @ $10B valuation** (Greenoaks Capital 主導)
- 累計 **$635M / 3 ラウンド / 5 投資家**
- 2024-10 → 2025-09 の 11 ヶ月で valuation 2.2 倍

## 提携・パートナー
- **ADT** (home security): contract cancellation / billing 自動化
- **SiriusXM** (satellite radio): 音声 AI "Harmony" = 電話サポート完全自律化 /
  2025-12 Agent Data Platform 深化発表
- **Sonos**: speaker trouble-shooting (技術マニュアル RAG → reset / firmware / WiFi 誘導)
- **WeightWatchers**: 習慣 coaching (B2C エンドユーザー direct)
- Fortune 50 の **40%** に浸透

## 自分株式会社での活用
- daily-judgment: Sierra の outcome-based pricing 思想を参考に、1 機能 1 成功単位で
  KPI 設計 (docs/PHILOSOPHY.md 原則 8「KPI = 昨日の自分」)
- growth-hub: CS 返信自動化 (cs-check.yml) に Sierra 方式の「解決率 + CSAT + cost」
  3 指標ダッシュボードを Mirror
- AI大学: CX 軸 = 第 13 カテゴリ候補 (既存 agent 軸は Cognition / Harvey / Manus に
  分散・単一 vertical に集約された例として Sierra が首位)
$md$,
    NOW()
  ),
  (
    'sierra',
    'models',
    'Agent OS 2.0 — CX 特化 8 プロダクト統合 + multi-LLM routing',
    $md$
# Agent OS 2.0 — CX 特化 8 プロダクト統合 + multi-LLM routing

## アーキテクチャ概要
Sierra は自社 foundation model を訓練せず、**OpenAI GPT-4o / Claude Sonnet /
Anthropic Haiku / open-weight** を task-complexity 別に routing する layered
agent runtime。内部の付加価値は以下 3 層:

1. **Agent Data Platform (ADP)** — 顧客ごとの long-term memory + 行動 graph
2. **Agent Studio** — 業務プロセス記述 DSL (playbook) + guardrail
3. **Voice runtime** — latency 400ms 以下の full-duplex 音声 stack

## Voice Agent (2024-10 GA)
- latency: 400ms target (人間会話の quasi-realtime)
- ASR: Deepgram / Rev / OpenAI Whisper を契約別 routing
- TTS: ElevenLabs + Cartesia の 2 社併用 (voice 多様性確保)
- 2025-10 時点で **text 超えて voice が primary channel** (顧客 mix 依存)
- SiriusXM "Harmony" が代表 deploy 例 — 電話応答完全自律

## Agent Data Platform (ADP / 2025-12 GA)
- 顧客 1 人あたり **persistent memory graph** 保持
- 過去の interaction / 解決履歴 / preference を graph DB (非公開) に蓄積
- 新規 conversation 時に関連 context を自動引き込み (RAG 超えた semantic memory)
- SiriusXM が初期 deep integration 顧客 (2025-12 発表)

## Agent Studio 2.0
- playbook DSL で業務フロー記述 (低コード / YAML + 自然言語混在)
- guardrail: PII masking / upsell 許可条件 / escalation trigger
- A/B test 内蔵 (新 playbook vs 旧 playbook を trafic split で比較)
- 顧客 AD / SSO 統合 (SAML / OIDC)

## multi-LLM routing
- 難易度別 routing: FAQ → Haiku / 複雑交渉 → Sonnet / extreme edge case → GPT-4o
- cost-per-resolve を最小化する dispatcher が自動 routing 決定
- ゼロ retention 契約 (OpenAI / Anthropic 両社) で顧客 data は学習利用されない

## Trust & Safety
- PII detection → mask → log
- prompt injection resist (OWASP LLM Top 10 対応)
- guardrail: 「返金上限」「約款超え回答禁止」等 domain rule を playbook で encode
- human-in-loop: 信頼度低い回答は Live Assist で人間 review

## ライセンス / 公開度
- **closed SaaS** — weights / code / model 非公開
- API は **顧客契約ベース限定** (一般 developer 公開なし)
- open-source 寄与ゼロ (競合 Decagon / Ada と同じ position)
- 論文発表なし — 技術 blog のみ (sierra.ai/blog)
$md$,
    NOW()
  ),
  (
    'sierra',
    'api',
    'Sierra — 契約プロセス + outcome-based pricing の自分株式会社適用',
    $md$
# Sierra — 契約プロセス + outcome-based pricing の自分株式会社適用

## アクセス方法
Sierra は **一般 developer 向け self-serve API を公開していない**。
顧客獲得は以下の enterprise sales process:

1. https://sierra.ai/contact から企業情報提出
2. Sierra の solutions team が POC spec を合議 (2-4 週間)
3. 初期 playbook + integration spec を Sierra 側が実装 (6-12 週間)
4. 多年契約 + outcome-based 課金で本番稼働

自分株式会社 (個人単位 SaaS) は **Sierra の target 顧客外** のため、
直接利用は想定不可。参考にするのは**思想・ダッシュボード設計**。

## outcome-based pricing の構造
公式 blog (https://sierra.ai/blog/outcome-based-pricing-for-ai-agents) より:

- **課金単位 = 成功 resolution**
  - chat/voice 会話が user の期待 outcome に到達したら課金
  - 到達失敗 (escalation / drop-off) は原則**無料**
- **upsell/retention 成功**: ADT の cancellation save 等は成功単価に上乗せ
- **multi-year enterprise contract**: 最低契約期間 12-36 ヶ月
- **implementation fee**: 初期 $100K-$500K 相当を別途 (顧客規模依存)

## 自分株式会社 growth-hub への応用 (参考実装)
```typescript
// supabase/functions/growth-hub/index.ts に追加
// ※ Sierra 方式の outcome-based KPI tracking を internal で実装
case 'cs.resolution_tracking':
  // 1. CS 返信 → user 返信なし 48h → resolved 判定
  // 2. resolved rate / CSAT / cost-per-resolve を 3 指標で dashboard 化
  // 3. escalation rate 閾値超過で alert (Sierra Live Assist 相当)
  return await trackResolutionOutcome(body);
```

## 比較 table (CX agent 領域の 2026 時点 market leader)
| 会社 | 初 ARR $100M 到達 | Valuation | 課金モデル | 顧客規模 |
|------|--------------------|-----------|-------------|-----------|
| **Sierra** | 7 四半期 (2025-11) | $10B | outcome-based | Fortune 50 の 40% |
| Decagon | 未達成 (推計 ~$60M) | ~$1.5B | conversation-based | mid-market SaaS |
| Ada | 未公表 | ~$1B | seat-based | SMB 〜 mid |
| Salesforce Agentforce | 統合商品のため ARR 単独不明 | - | seat + credit | Salesforce 既存顧客 |

## 試す (参考 resources)
- 公式: https://sierra.ai/
- 顧客事例: https://sierra.ai/customers
- SiriusXM 発表: https://sierra.ai/blog/siriusxm-adp-announcement
- outcome-based pricing thesis: https://sierra.ai/blog/outcome-based-pricing-for-ai-agents
- Bret Taylor interview: https://cheekypint.substack.com/p/bret-taylor-of-sierra-on-ai-agents

## 想定コラボ
- Thinking Machines Lab (S18) との対比: 「foundation model を作る」側 vs
  「foundation model を顧客 outcome に変換する application 層」の 2 象限
- Cognition (既存) との補完: 内部開発 agent (Devin) と CX 外部 agent (Sierra) で
  「社内 vs 社外」の agent 活用 spectrum を埋める
- Harvey (既存) / Manus (既存) と合わせて「vertical agentic SaaS 3 強」
  (Harvey=法務 / Sierra=CX / Manus=汎用 task) を AI大学 categorization に提案
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
