-- Windowsアプリ版#69: Hedra AI 大学コンテンツ seed
-- リアルタイム会話型アバター動画 — Character-3 オムニモーダルモデル / a16z $44M

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('hedra', 'overview',
'Hedra AI: リアルタイム会話型アバター動画の最前線',
$$# Hedra AI

Hedraは**画像・テキスト・音声を同時処理するオムニモーダルAI**によって
「話す・歌う・動くアバター動画」をリアルタイムで生成するプラットフォーム。
Andreessen Horowitz (a16z) から$44M調達、3M+ユーザー、1000万本以上の動画生成実績。

## 設立背景

- **拠点**: サンフランシスコ
- **資金調達**: $44M (Andreessen Horowitz リード / 2024年Series A)
- **ユーザー数**: 3M+
- **動画生成数**: 1,000万本+
- **価格**: $0.05/分 — 競合比15倍安い

## Character-3: 業界初のオムニモーダルキャラクターモデル

```
従来のアバターAI:
  テキスト → TTS → 音声 → 口唇同期
  (3ステップのパイプライン = 遅延・不自然さ)

Character-3 (Hedra):
  [画像 + テキスト + 音声] → 同時処理 → 自然なアバター動画
  (1つのモデルで全処理 = 低遅延・高精度)
```

## 主要機能

| 機能 | 詳細 |
|------|------|
| **Character-3** | 業界最高精度の口唇同期 (独立テスト9/10) |
| **リアルタイムアバター** | sub-100ms遅延でLiveKit経由のライブ会話 |
| **フルボディ動作** | 顔だけでなく全身の自然な動き |
| **マイクロ表情** | 感情に応じた微細な表情変化 |
| **多言語対応** | 任意の言語で口唇同期 |

## 競合との差別化

| ツール | 強み | Hedraとの違い |
|--------|------|--------------|
| **Luma AI** | 高品質動画生成 | キャラクター固定なし・会話非対応 |
| **Kling AI** | リアルな動画生成 | アバター対話機能なし |
| **D-ID** | ビジネスアバター | Hedraより遅延・精度劣る |
| **HeyGen** | ビジネス動画 | リアルタイム対話非対応 |
| **Hedra** | 🏆 リアルタイム対話型 | Character-3の圧倒的口唇同期精度 |
$$,
'https://www.hedra.com/',
'2026-04-17', 1),

('hedra', 'models',
'Character-3: Hedraのオムニモーダルキャラクターモデル',
$$# Character-3 技術詳細

## アーキテクチャの革新

Character-3は「オムニモーダル」という新概念を実装:

```python
# 従来の3ステップパイプライン（各社の方式）
text → TTS_model → audio
audio + image → lip_sync_model → video
video + audio → render_pipeline → final_video

# Character-3（Hedra独自）
[image, text, audio] → character3_model → talking_video
# 1モデルで全入力を同時処理 → 自然で高精度
```

## 性能指標

| 指標 | Character-3 | 業界平均 |
|------|------------|--------|
| 口唇同期精度 | 9/10 | 6/10 |
| 30秒動画生成時間 | ~60秒 | 3-5分 |
| リアルタイム遅延 | <100ms | 500ms+ |
| コスト | $0.05/分 | $0.75/分 |

## リアルタイムモード (LiveKit統合)

```typescript
// LiveKit + Hedra でライブ会話アバターを実装
import { HedraClient } from '@hedra/sdk';
import LiveKit from 'livekit-client';

const hedra = new HedraClient({ apiKey: process.env.HEDRA_API_KEY });

// リアルタイムアバターセッション開始
const session = await hedra.realtime.createSession({
  avatar_image_url: 'https://example.com/avatar.jpg',
  voice_id: 'en-US-neural-01',
  livekit_room: roomName,
});
// → ユーザーが話すとアバターがリアルタイムで応答
```

## Hedra Omnia (最新リリース)

Hedra Omniaはキャラクター動画を超えた「ビジュアル・クリエイティブ・インテリジェンス」基盤:
- 複雑なキャラクター駆動のシーン生成
- 高効率な統合基盤モデル
- 「トーキングヘッド以上」の表現力
$$,
'https://www.hedra.com/',
'2026-04-17', 2),

('hedra', 'api',
'Hedra API: アバター動画をアプリに組み込む',
$$# Hedra Developer API

## 概要

HedraはREST API・Node.js SDK・LiveKit plugin・Make.com統合を提供。
Supabase Edge Functionから呼び出し、自分株式会社にAIアバター機能を追加可能。

## Node.js SDK 基本例

```typescript
// supabase/functions/avatar-video/index.ts
import { Hedra } from '@hedra/sdk';

const hedra = new Hedra({ apiKey: Deno.env.get('HEDRA_API_KEY') });

// 動画生成リクエスト
const video = await hedra.characters.generate({
  avatar_image: 'https://example.com/presenter.jpg',
  audio_source: {
    type: 'text',
    text: 'こんにちは！自分株式会社のAIアシスタントです。',
    voice: 'ja-JP-neural',
  },
  output_format: 'mp4',
});

// 生成完了まで待機
const result = await hedra.videos.wait(video.id);
console.log('動画URL:', result.url); // 30秒動画 → 約60秒で完成
```

## REST API 直接利用

```bash
# 動画生成リクエスト
curl -X POST https://mercury.dev.dream-ai.com/api/v1/characters \
  -H "X-API-KEY: $HEDRA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "AIアシスタントからのメッセージ",
    "voice": "ja-JP",
    "avatarImage": "BASE64_OR_URL"
  }'
```

## 自分株式会社との統合可能性

| ユースケース | 実装方法 | 効果 |
|------------|---------|------|
| **AIアシスタント動画** | `ai-assistant` EFにHedra統合 | テキスト回答 → 動画回答に昇格 |
| **AI大学の解説動画** | 各プロバイダー説明をアバターが話す | 学習体験の大幅向上 |
| **ギター評価フィードバック** | 演奏評価をアバターが解説 | guitar-recording-studio強化 |

## プラン・コスト

| プラン | 月額 | 上限 |
|--------|------|------|
| **Free** | $0 | 3分/月 |
| **Creator** | $8 | 60分/月 |
| **Pro** | $29 | 240分/月 |
| **API** | $0.05/分 | 従量課金 |
$$,
'https://www.hedra.com/api-profile',
'2026-04-17', 3),

('hedra', 'news',
'Hedra AI 最新ニュース (2026-04-17)',
$$# Hedra AI 最新動向 (2026-04-17)

## 主要アップデート

### Hedra Omnia リリース
「トーキングヘッドを超えた」統合基盤モデル。
単純な口唇同期から、複雑なキャラクター主導の動画シーン生成へ進化。
「ビジュアル・クリエイティブ・インテリジェンス」プラットフォームとして再定義。

### a16z $44M調達完了
Andreessen Horowitzをリードに$44Mを調達。
「AI動画の競争は始まったばかり」として積極的な製品開発を継続。

### 3M+ユーザー・1000万本突破
短期間でのスケール。コスト ($0.05/分) が普及を加速。
$0.75/分の競合と比べ15倍安い価格戦略が功を奏す。

### LiveKit統合でリアルタイム対話アバターを実用化
sub-100ms遅延でのリアルタイム会話アバターを商用提供。
カスタマーサービスBot・AIインフルエンサー・教育用アバターに展開。

## 業界への影響

| 従来の問題 | Hedraによる解決 |
|-----------|---------------|
| アバター動画 = 高コスト・低精度 | $0.05/分・業界最高精度 |
| リアルタイム対話は不可能 | sub-100ms遅延で実用化 |
| 3ステップパイプラインの遅延・不自然さ | Character-3で1ステップ処理 |

## このプロジェクトへの示唆

- **AI大学のコンテンツ形式革新**: テキストだけでなく「アバターが解説する動画」コンテンツを追加
- **バイラル動画パイプライン強化**: `viral-video-ad-generator` EFにHedra統合でプレゼンター付き動画生成
- **ギター評価の進化**: 演奏評価結果をAIコーチ (Hedraアバター) が口頭で解説
$$,
'https://www.hedra.com/',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
