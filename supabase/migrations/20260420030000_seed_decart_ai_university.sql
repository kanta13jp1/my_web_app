-- PS版#3 Session 11: Decart — リアルタイム生成動画 AI ($3.1B valuation)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'decart',
  'overview',
  'Decart — 世界初のリアルタイム動画生成 AI ($3.1B 評価額)',
  $md$## Decart とは

Decart は 2023 年設立のイスラエル発 AI スタートアップ。
**世界初のリアルタイム動画生成モデル「Oasis」と「Mirage」** を開発・提供している。

2024 年 11 月に発表した **Oasis** (AI Minecraft) は公開 3 日で 100 万ユーザーを突破。
続く **MirageLSD** (Live-Stream Diffusion) は **40ms 以下のレイテンシ** で
ライブ動画を別の世界観に変換できる初のモデルとして話題に。

2025 年 8 月に Series B で **$100M 調達 (累計 $153M+ / 評価額 $3.1B)**。
Sequoia Capital・Benchmark・Zeev Ventures が継続出資、Aleph VC が新規参画。

## 既存の動画生成 AI との違い

| 観点 | Decart (Mirage/Oasis) | Runway / Luma / Kling 等 |
|------|----------------------|---------------------------|
| **生成方式** | リアルタイム連続生成 | 5〜10 秒バッチ生成 |
| **レイテンシ** | <40ms (体感ゼロ) | 10 秒〜数分 |
| **入力** | ライブ動画ストリーム | テキスト・1枚画像 |
| **長さ制限** | 無制限 (連続変換) | 5〜10 秒/クリップ |
| **対話性** | プレイ可能 (ゲーム化) | 単方向生成 |
| **インフラ** | 自社 GPU 最適化スタック | 外部クラウド GPU |

## 主要プロダクト

### Oasis (2024-11) — AI Minecraft

- **世界初の playable な AI 生成ゲーム** (Minecraft 風オープンワールド)
- キーボード/マウス操作で世界が AI により逐次生成される
- 公開 3 日で 100 万プレイヤー突破
- バックエンドは独自学習の World Model + GPU 最適化

### MirageLSD (2025-夏) — リアルタイム動画変換

- **Live-Stream Diffusion**: ライブ動画を別の絵柄/世界観に変換
- レイテンシ <40ms (人間の知覚閾値以下)
- 入力: Webcam・OBS・録画動画
- 出力: アニメ調・サイバーパンク・写実油絵 など任意のスタイル
- 用途: ライブ配信エフェクト・バーチャル背景・XR コンテンツ

## ビジネスモデル

- **Mirage API** (近日公開予定): 動画変換を SaaS として提供
- **GPU アクセラレーションスタック**: 自社最適化技術を他社にライセンス
- **エンタープライズ契約**: ゲームスタジオ・配信プラットフォーム向け

## 創業・組織

- 設立: 2023 年 (テルアビブ + サンフランシスコ)
- 共同創業者: Dean Leitersdorf (CEO)、Moshe Shalev (CPO)
- 強み: GPU カーネル最適化 + 世界モデル研究の融合$md$,
  '2026-04-20'
),
(
  'decart',
  'models',
  'Decart モデル一覧 (Oasis / MirageLSD)',
  $md$## モデル比較

| モデル | リリース | 入力 | 出力 | レイテンシ | ステータス |
|--------|---------|------|------|-----------|-----------|
| **Oasis** | 2024-11 | キー入力 | ゲーム映像 | リアルタイム | 公開 (Web デモ) |
| **MirageLSD** | 2025-夏 | ライブ動画 | スタイル変換動画 | <40ms | 公開 (API 準備中) |
| **次期 Foundation Model** | 2026 予定 | マルチモーダル | 任意 | リアルタイム | 開発中 |

## Oasis 詳細

```text
概要:
  - 世界初の playable AI 生成 Minecraft 風ゲーム
  - 学習: 数千時間の Minecraft プレイ動画 + キー入力ペア

技術:
  - World Model (DiT 系) + Action Encoder
  - フレーム毎に次フレームを 1.5B param モデルで予測
  - 独自 GPU 最適化 (1 H100 で 20fps 達成)

プレイ:
  - https://oasis.decart.ai/welcome (無料・登録不要)
  - WASD 移動・マウスで視点変更・ブロック設置
```

## MirageLSD 詳細

```text
概要:
  - ライブ動画を任意のスタイルに連続変換
  - 例: Webcam → アニメキャラ・実写 → ピクサー風

技術:
  - Latent Stream Diffusion (LSD) アーキテクチャ
  - フレーム間の整合性を保ちながら逐次変換
  - <40ms = OBS の 30fps ライブ配信に組込可

対応プロンプト例:
  - "Studio Ghibli style anime"
  - "Cyberpunk neon city overlay"
  - "Oil painting in Van Gogh style"
  - "Underwater scene with bioluminescent fish"

デモ:
  - https://mirage.decart.ai/ (Web ブラウザで Webcam 接続)
```

## 自分株式会社からの活用イメージ

| 機能 | Decart 適用 |
|------|-----------|
| **AI 大学** | プレイ可能な「AI モデル体験」コンテンツとして埋め込み |
| **ホーム画面** | ユーザーアバター動画にスタイルエフェクト |
| **動画編集スキル** | NotebookLM 動画 → スタイル変換 → YouTube 投稿パイプライン |
| **ゲーミフィケーション** | 学習達成バッジを Oasis 風 3D 世界で可視化 |

## 競合・近接プロバイダー

- **Runway / Luma / Kling**: 短尺バッチ生成 → Decart は連続リアルタイム
- **Pika / Hailuo**: 同上 (バッチ)
- **NVIDIA Omniverse**: リアルタイム 3D だが AI 生成ではない$md$,
  '2026-04-20'
),
(
  'decart',
  'api',
  'Decart 使い方 (Web デモ + 今後の API)',
  $md$## 現状の利用方法 (2026-04 時点)

Mirage API は 2026 年内公開予定。現時点では Web デモ経由で体験可能。

### Oasis (AI Minecraft) を試す

```text
1. https://oasis.decart.ai/welcome を開く
2. 「Play Now」をクリック (登録不要)
3. WASD 移動・マウス視点変更・左クリックでブロック設置
4. 数十秒でセッションタイムアウト (無料デモのため)
```

### MirageLSD (動画スタイル変換) を試す

```text
1. https://mirage.decart.ai/ を開く
2. Webcam アクセスを許可
3. プロンプト入力 (例: "anime style")
4. リアルタイムで変換された動画が表示される
5. OBS の仮想カメラと組合せてライブ配信に組込可
```

## 想定 API スキーマ (公式公開時に確認)

```typescript
// supabase/functions/decart-stylize/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req) => {
  const { videoUrl, prompt, style } = await req.json();

  // Decart Mirage API (β想定)
  const response = await fetch("https://api.decart.ai/v1/mirage/transform", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("DECART_API_KEY")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      input_url: videoUrl,
      prompt: prompt,           // 例: "Studio Ghibli style"
      style: style,             // anime / oil_painting / cyberpunk
      output_format: "mp4",
      max_duration_seconds: 60,
    }),
  });

  const result = await response.json();
  return new Response(JSON.stringify({ outputUrl: result.url }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

## Flutter Web からの呼出 (公開後想定)

```dart
// lib/services/decart_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class DecartService {
  static Future<String?> stylizeVideo({
    required String videoUrl,
    required String prompt,
    String style = 'anime',
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'decart-stylize',
      body: {
        'videoUrl': videoUrl,
        'prompt': prompt,
        'style': style,
      },
    );
    return (response.data as Map?)?['outputUrl'] as String?;
  }
}
```

## 料金 (推定 — API 公開時に確認)

- **Web デモ**: 完全無料 (セッション制限あり)
- **Mirage API β**: 招待制 (waitlist 受付中)
- **想定価格帯**: $0.05〜0.20/秒 (リアルタイム GPU 占有のため高単価予測)

## 注意事項・制約

- **生成コンテンツの著作権**: モデル学習データに既存ゲーム/動画が含まれる可能性
- **長尺保証なし**: <40ms レイテンシだが連続稼働時間は GPU 課金次第
- **モバイル対応**: Webcam ベース → スマホブラウザでも動作 (iOS Safari は要検証)

## 公式リソース

- Web: https://decart.ai/
- Mirage デモ: https://mirage.decart.ai/
- Oasis デモ: https://oasis.decart.ai/welcome
- Research: https://decart.ai/research
- Mirage 解説: https://decart.ai/publications/mirage$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
