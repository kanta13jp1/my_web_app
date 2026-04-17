-- Windowsアプリ版#69: HeyGen AI 大学コンテンツ seed
-- ビジネス向けAIアバター動画 — 100K+企業採用・175言語・G2 #1急成長

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('heygen', 'overview',
'HeyGen: ビジネス向けAIアバター動画の世界標準',
$$# HeyGen

HeyGenは**100,000社以上のビジネスが採用するAIアバター動画プラットフォーム**。
「15秒の録画からスタジオ品質の動画を生成」する技術で、企業コミュニケーションを革新。
175言語対応・G2 2025年最速成長製品賞1位・MCP経由でAIエージェントと統合可能。

## 概要

- **ユーザー**: 100,000社以上 (Fortune 500から中小企業まで)
- **言語**: 175言語でリップシンク動画生成
- **API**: $5から利用可能 (Pay-as-you-go)
- **受賞**: G2 Best Software Awards 2025 #1 Fastest Growing Product
- **用途**: マーケティング動画・企業研修・製品説明・SNSコンテンツ

## HeyGenが解決する問題

```
従来の企業動画制作:
  撮影スタジオ確保 → タレント手配 → 収録 → 編集 → 多言語翻訳
  = 1本あたり数日〜数週間 / 数十万円

HeyGen:
  テキスト入力 → AIアバターが自動生成 → 175言語に即翻訳
  = 1本あたり数分 / 数百円
```

## 主要機能

| 機能 | 詳細 |
|------|------|
| **Avatar V** | 15秒録画からスタジオ品質アバター生成。業界最高のリアリズム |
| **Video Translation** | 既存動画を175言語にリップシンク翻訳 |
| **AI Script** | テキスト入力で台本・動画を自動生成 |
| **Instant Avatar** | カメラ不要・テキストのみで即動画生成 |
| **Team Collaboration** | 複数メンバーでアバター・テンプレートを共有 |

## 採用業界

- **企業研修**: スクリプト更新 → 同じアバターで新バージョン即再生成
- **マーケティング**: 多言語SNS動画を1本の素材から量産
- **eラーニング**: 講師のアバターで自動コース動画生成
- **カスタマーサービス**: よくある質問をアバターが動画で回答
$$,
'https://www.heygen.com/',
'2026-04-17', 1),

('heygen', 'models',
'HeyGen Avatar V: 最先端AIアバターモデル',
$$# HeyGen モデル体系

## Avatar V (最新フラッグシップ)

```
入力: 15秒の自撮り動画 (スマホでOK)
    ↓
[Avatar V モデル]
    ↓
出力: スタジオ品質のリアルタイムレンダリングアバター
  - マルチアングル安定性 (カメラ角度が変わっても同一人物に見える)
  - ロングフォームパフォーマンス (長い動画でも一貫性維持)
  - ライフライクモーション (自然な体の動き)
```

## アバタータイプ比較

| タイプ | 作成方法 | リアリズム | 速度 |
|--------|---------|---------|------|
| **Avatar V** | 15秒録画 | 🏆 最高 | 中 |
| **Instant Avatar** | テキストのみ | 高 | 速 |
| **Photo Avatar** | 静止画1枚 | 中 | 高速 |
| **Studio Avatar** | 専用撮影 | 完璧 | 要撮影 |

## 動画翻訳技術

HeyGenの最大の独自技術は**175言語へのリップシンク翻訳**:

```
元動画 (日本語) → [HeyGen翻訳エンジン] → 英語・スペイン語・フランス語...
                                       → 口の動きも各言語に合わせて自動調整
```

- 音声のみの翻訳ではなく、**口唇の動きも翻訳先言語に合わせて変換**
- 声のクローニングで元の話者の声質を維持したまま翻訳

## MCP統合 (2026年新機能)

```
Claude / OpenAI / Manus → HeyGen MCP → 動画生成
「この商品説明を日本語と英語の動画にして」
  → AIが自動でHeyGen APIを呼び出し → 2本の動画を生成
```
$$,
'https://www.heygen.com/',
'2026-04-17', 2),

('heygen', 'api',
'HeyGen API: プログラムで動画生成を自動化',
$$# HeyGen Developer API

## 概要

HeyGen APIで**動画生成・翻訳・アバター作成をプログラムから自動化**。
Pay-as-you-goで$5から始められる。Supabase Edge Functionとの統合も簡単。

## クイックスタート

```typescript
// supabase/functions/video-generator/index.ts
const HEYGEN_API_KEY = Deno.env.get('HEYGEN_API_KEY');

// 動画生成リクエスト
const response = await fetch('https://api.heygen.com/v2/video/generate', {
  method: 'POST',
  headers: {
    'X-Api-Key': HEYGEN_API_KEY!,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    video_inputs: [{
      character: {
        type: 'avatar',
        avatar_id: 'your-avatar-id',
        avatar_style: 'normal',
      },
      voice: {
        type: 'text',
        input_text: 'こんにちは！自分株式会社のAIアシスタントです。',
        voice_id: 'ja-JP-female-01',
      },
      background: {
        type: 'color',
        value: '#0A0A0A', // DESIGN.md の background色
      },
    }],
    dimension: { width: 1280, height: 720 },
  }),
});

const { data } = await response.json();
const videoId = data.video_id;

// 生成完了を待機
const videoUrl = await pollVideoStatus(videoId);
```

## 動画翻訳API

```typescript
// 既存動画を175言語に翻訳
const translateResponse = await fetch('https://api.heygen.com/v2/video_translate', {
  method: 'POST',
  headers: { 'X-Api-Key': HEYGEN_API_KEY! },
  body: JSON.stringify({
    video_url: 'https://example.com/japanese-video.mp4',
    output_language: 'en',  // 英語に翻訳
    title: 'Product Explanation - English',
  }),
});
```

## 自分株式会社との統合可能性

| ユースケース | 実装案 | 期待価値 |
|------------|-------|---------|
| **AI大学 解説動画** | 各プロバイダーの概要をHeyGenアバターが説明 | 学習体験を動画化・差別化 |
| **ブログ → 動画変換** | blog記事をHeyGenで動画化してSNSに投稿 | コンテンツ再利用・拡散 |
| **多言語対応** | 日本語コンテンツを英語動画に自動変換 | 海外ユーザー獲得 |

## APIプラン

| プラン | 月額 | 動画数/月 |
|--------|------|---------|
| **Pay-as-you-go** | $5〜 | 従量 |
| **Creator** | $29 | 60本 |
| **Business** | $149 | 無制限+SSO |
| **Enterprise** | 要問い合わせ | カスタム |
$$,
'https://docs.heygen.com/docs/quick-start',
'2026-04-17', 3),

('heygen', 'news',
'HeyGen AI 最新ニュース (2026-04-17)',
$$# HeyGen 最新動向 (2026-04-17)

## 主要アップデート

### G2 2025年最速成長製品賞 #1受賞
B2B SaaSの最高権威G2のBest Software Awards 2025で「Fastest Growing Product」1位を受賞。
100,000社以上への急速な普及が評価された。

### MCP統合リリース
Claude・OpenAI・Manusなど主要AIエージェントとのMCP統合を提供開始。
「AIエージェントに頼むと動画が生成される」新ワークフローを実現。

### Avatar V: 15秒録画→スタジオ品質
新モデル「Avatar V」は15秒の自撮り動画からスタジオ品質のデジタルアバターを作成。
マルチアングル安定性と長尺動画対応が業界水準を大幅に上回ると評価。

### 175言語リップシンク翻訳の精度向上
既存動画を175言語に変換する際の口唇同期精度が大幅向上。
「録り直し不要で世界中に届ける」エンタープライズ需要を取り込む。

## 競合比較: ビジネス動画AI 2026

| プラットフォーム | 強み | 採用規模 |
|---------------|------|---------|
| **HeyGen** | 175言語翻訳・Avatar V・API | 100K+企業 |
| **Synthesia** | エンタープライズ特化・125言語 | 大企業中心 |
| **Hedra** | リアルタイム対話・$0.05/分 | 3M+個人 |
| **D-ID** | 静止画→動画 | 中規模 |

## このプロジェクトへの示唆

- **ブログコンテンツの動画化**: `blog-auto-publisher` EFにHeyGen統合 → テキスト記事→説明動画の自動生成
- **AI大学 v3**: 各AIプロバイダーの概要をアバターが説明する動画コンテンツ追加
- **多言語SNS展開**: 日本語コンテンツをHeyGen翻訳→英語SNS動画→海外ユーザー獲得
$$,
'https://www.heygen.com/',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
