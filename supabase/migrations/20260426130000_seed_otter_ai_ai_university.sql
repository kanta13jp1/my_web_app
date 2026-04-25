-- PS#3 S54 fix (PS#1 S46): 20260426130000 — Otter.ai AI大学 seed (provider/category/content schema)
-- Otter.ai: AI ミーティングアシスタント / SpeechX / $50M / 月間 1M+

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'otter_ai',
  'overview',
  'Otter.ai — AI ミーティングアシスタント (SpeechX / OtterPilot 自動参加 / 1M+ ユーザー)',
  $$## Otter.ai — AI ミーティングアシスタント

**カテゴリ**: AI Meeting Intelligence / Speech-to-Text
**設立**: 2016年 / 本社: マウンテンビュー (カリフォルニア)
**調達**: 50M USD (Founders Fund / GGV Capital)
**ユーザー数**: 月間 1M+ (2024年)
**評価**: 8/9

### 概要
Otter.ai は独自の SpeechX AI モデルを使ったリアルタイム文字起こし + ミーティングアシスタントサービス。Zoom・Teams・Google Meet に自動参加して会話をリアルタイムでテキスト化し、終了後すぐに要約・アクションアイテム・重要発言のハイライトを自動生成する。

### 主な特長
- **リアルタイム文字起こし**: 会議中にリアルタイムでテキストが流れる (複数話者識別付き)
- **AI 要約**: 会議終了直後に要約・アクションアイテムを自動生成・メール送信
- **Otter AI Chat**: 文字起こし内容について質問できる Conversational AI
- **自動参加 (OtterPilot)**: カレンダー連携で会議に自動入室・録音・文字起こし
- **チーム共有**: 文字起こしをリアルタイムでチームメンバーと共有・コメント付け
- **統合**: Zoom / Microsoft Teams / Google Meet / Salesforce / HubSpot

### 競合との差別化
Krisp: ノイズキャンセリング特化 (文字起こしはサブ機能) / Fireflies.ai: CRM統合強い・エンタープライズ向け / Notion AI: ノート管理統合 / Microsoft Copilot: Teams専用の深い統合

Otter の強みは **SpeechX モデルの高精度な話者識別 × OtterPilot 自動参加 × Otter AI Chat** の組み合わせ。

### 導入コスト
- **Free**: 300 分/月・単一話者識別
- **Pro**: 月 10 USD (1200 分/月・OtterPilot 3 ミーティング/月)
- **Business**: 月 20 USD/席 (無制限・管理コンソール・Salesforce 統合)
- **Enterprise**: 問い合わせ (SOC2 / SSO / カスタム統合)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'otter_ai',
  'api',
  'Otter.ai — API・OtterPilot統合 (REST API / OAuth 2.0 / Zapier / Make)',
  $$## Otter.ai API / 統合

### Otter.ai API (Developer)
REST API で文字起こしデータをプログラムから取得可能。

主なエンドポイント: GET /v1/speeches (一覧) / GET /v1/speeches/{id} (詳細) / GET /v1/speeches/{id}/transcripts (テキスト取得)

認証: OAuth 2.0 (Bearer Token)

### Zapier / Make 連携
- 新しい文字起こし完成 → Slack/Notion/Salesforce に自動転送
- アクションアイテム → Asana/Trello タスク自動作成

### OtterPilot API (Enterprise)
- カレンダー連携で会議に自動参加
- カスタム語彙 (専門用語・社名) の登録で精度向上

### 制限事項
- API は Business / Enterprise プランのみ
- リアルタイム文字起こし WebSocket は未公開 (UI のみ)$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'otter_ai',
  'models',
  'Otter.ai — AIモデル (SpeechX 話者識別 / GPT-4 要約 / Otter AI Chat / 多言語β)',
  $$## Otter.ai の AI モデル

音声認識・文字起こし: SpeechX (独自) / 話者識別: 独自ダイアリゼーションモデル / 要約・アクションアイテム抽出: GPT-4 ベース (独自 fine-tune) / Otter AI Chat: LLM (詳細非公開)

### SpeechX モデルの特徴
- **話者識別**: 最大 20+ 人の話者を自動識別・ラベル付け
- **専門用語対応**: カスタム語彙登録で業界固有用語の精度向上
- **多言語**: 英語中心。日本語は β (2024 年時点で精度向上中)
- **ノイズ耐性**: 在宅・カフェ環境でも高精度

### 自分株式会社での活用可能性
- 投資家ミーティング・顧客ヒアリングの文字起こし自動化
- アクションアイテムを自動 WBS タスク化 (tools-hub 連携)
- チームミーティングの議事録自動生成 → Notion 連携$$,
  NULL,
  NULL,
  201
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 200→201社化: Otter.ai 追加',
  'PS#3 S54 (PS#1 S46 fix)。Otter.ai (AI ミーティングアシスタント / SpeechX モデル / リアルタイム文字起こし + 要約 + アクションアイテム / OtterPilot 自動参加 / 50M USD / 月間 1M+ / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
