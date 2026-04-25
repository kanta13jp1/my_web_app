-- PS#3 S52: AI大学 198→200社化 — Tome 追加
-- Tome: AI プレゼンテーション・ドキュメント生成 / GPT-4 統合 / $75M / 5M+ ユーザー

INSERT INTO ai_university_content (provider, category, title, content, sort_order)
VALUES
(
  'tome_app',
  'overview',
  'Tome — AI プレゼンテーション・ドキュメント生成 (GPT-4 統合 / $75M / 5M+ ユーザー)',
  $md$## Tome — AI プレゼンテーション・ドキュメント生成

**カテゴリ**: AI Presentation Builder / Document Creation
**設立**: 2020年 / 本社: サンフランシスコ
**調達**: $75M (Series B 2022、Coatue 主導 / Greylock・Lightspeed 参加)
**ユーザー数**: 5M+ (2023年時点)
**評価**: ★8/9

### 概要
Tome は GPT-4 を基盤とした AI プレゼンテーション・ドキュメントビルダー。テキストのプロンプトから完成度の高いスライドやページを秒速で自動生成する。Notion のブロック構造と Canva のビジュアルリッチさを融合させ、AI narration 機能でプレゼン音声も自動生成できる。

### 主な特長
- **テキスト→スライド自動生成**: プロンプト一行で 10 ページ以上のプレゼン資料を即時生成
- **AI narration**: スライドの内容に合わせた音声ナレーションを自動作成
- **GPT-4 統合**: コンテンツ要約・リライト・箇条書き展開を内部から直接呼び出し
- **ライブ埋め込み**: Figma / Loom / Airtable などをスライド内にライブ埋め込み
- **Web 公開**: ワンクリックで Web URL として共有、閲覧・コメント権限を細かく設定可
- **モバイル対応**: スマートフォンで閲覧・編集が最適化されたレスポンシブ表示

### 競合との差別化
| ツール | 特徴 |
|--------|------|
| **Gamma** | テキスト→スライド生成 (類似。月間 4M+ ユーザー) |
| **Canva AI** | テンプレート豊富・デザイン特化 |
| **Beautiful.AI** | デザインルール自動適用 |
| **PowerPoint Copilot** | 既存 Office ユーザーへの深い統合 |

Tome の強みは **Notion-like なブロックベース編集 × AI narration × Web 公開**の組み合わせ。

### 導入コスト
- **Free**: 無制限ページ (AI クレジット月 50)
- **Pro**: $8/月 (AI クレジット無制限・カスタムドメイン)
- **Enterprise**: SSO・監査ログ・専用サポート
$md$,
  1
),
(
  'tome_app',
  'api',
  $md$## Tome API / 統合

### パートナー統合 (公式)
- **Figma**: デザインファイルをスライドに直接埋め込み (ライブ同期)
- **Loom**: 録画動画をページ内に埋め込み
- **Airtable / Google Sheets**: データテーブルをライブ接続
- **Giphy / Unsplash**: 画像・GIF をワンクリック挿入

### GPT-4 プロンプト API (内部)
Tome 内部の AI 機能は OpenAI GPT-4 API を使用。ユーザー向けに直接 API は公開していないが、Zapier / Make 経由で以下が可能:
- 新規 Tome 作成トリガー
- テンプレートからページ自動生成

### 制限事項
- パブリック REST API は未公開 (2024 年時点)
- Enterprise プランでは Salesforce / HubSpot との CRM 統合ロードマップあり
$md$,
  2
),
(
  'tome_app',
  'models',
  $md$## Tome が使用する AI モデル

| 用途 | モデル |
|------|--------|
| コンテンツ生成 | OpenAI GPT-4 |
| 画像生成 | DALL·E 3 (オプション) |
| AI narration (音声) | ElevenLabs / OpenAI TTS |
| 画像検索 | Unsplash API / Google Images |

### AI 生成フロー
1. ユーザーがトピック / アウトライン / URL をプロンプト入力
2. GPT-4 がページ構成・コンテンツを生成
3. DALL·E 3 または Unsplash が画像を補完
4. AI narration が各スライドの音声スクリプトを作成

### 自分株式会社での活用可能性
- プレゼン資料の自動生成 (投資家向け / 社内報告)
- AI 大学コンテンツの視覚化 (インフォグラフィック → Tome ページ)
- 競合比較資料の自動更新 (Airtable データ連携)
$md$,
  197
)
ON CONFLICT DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 198→199社化: Tome 追加',
  'PS#3 S52。Tome (AI プレゼンテーション・ドキュメントビルダー / GPT-4 統合 / $75M Series B / Coatue 主導 / 5M+ ユーザー / ★8/9) を ai_university_content に追加。',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
