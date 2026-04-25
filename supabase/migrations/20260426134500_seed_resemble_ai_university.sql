-- PS#3 S55: AI大学 203→204社化 — Resemble AI 追加
-- Resemble AI: リアルタイム音声クローン / <50ms レイテンシ / $8M / ゲーム・会話AI向け

INSERT INTO ai_university_content (provider_id, section, content_md, display_order)
VALUES
(
  'resemble_ai',
  'overview',
  $md$## Resemble AI — リアルタイム音声クローン & 合成

**カテゴリ**: Real-Time Voice Cloning / Text-to-Speech / Deepfake Detection
**設立**: 2019年 / 本社: サンフランシスコ (カリフォルニア)
**調達**: $8M (シード / Y Combinator S20)
**特許技術**: リアルタイム声クローン (<50ms レイテンシ)
**評価**: ★8/9

### 概要
Resemble AI は**リアルタイム音声クローン**を最大の特徴とする SaaS プラットフォーム。テキスト入力から <50ms で合成音声を返す低遅延 API が強みで、ゲームのプレイヤー音声生成・会話 AI アシスタント・カスタマーサービスボットなど、応答速度が命のユースケースに特化している。また、自社技術で **Deepfake 音声検出** サービスも提供し、音声セキュリティ側面も網羅する。

### 主な特長
- **<50ms レイテンシ**: WebSocket ストリーミング API でリアルタイム合成
- **感情・スタイル制御**: API で感情強度・話速・ピッチをリアルタイム変更
- **声クローン**: 5 分のサンプルで高品質な声クローン生成
- **Deepfake Detection**: 合成音声か本物かを判定する逆方向 API
- **多言語**: 英語・日本語・スペイン語など対応
- **エンタープライズ**: オンプレミス展開 / 音声データの自社所有保証

### 競合との差別化
| ツール | 特徴 |
|--------|------|
| **ElevenLabs** | 最高品質・感情豊か / 非リアルタイム中心 |
| **Murf** | コンテンツ制作向け / Canva 統合 |
| **Coqui** | OSS・ローカル実行 / リアルタイム非対応 |
| **Cartesia** | Sonic モデル 80ms / スタートアップ競合 |

Resemble の強みは **50ms リアルタイム × Deepfake 検出 × 音声データ所有保証**。ゲーム・会話 AI・音声セキュリティの 3 領域をカバーする唯一のプラットフォーム。

### 導入コスト
- **Pay-as-you-go**: $0.006/秒 (6,000 文字 ≈ $1)
- **Professional**: $99/月 (200 万文字・Deepfake Detection 付き)
- **Enterprise**: 問い合わせ (オンプレミス / SLA / 音声データ完全所有)
$md$,
  1
),
(
  'resemble_ai',
  'api',
  $md$## Resemble AI API / 統合

### Python SDK

```python
from resemble import Resemble

Resemble.api_key("YOUR_API_KEY")

# 同期生成 (標準)
response = Resemble.v2.clips.create_sync(
    project_uuid="<project_uuid>",
    voice_uuid="<voice_uuid>",
    body="自分株式会社のAI大学へようこそ。リアルタイム音声合成のデモです。",
    is_public=False,
    is_archived=False,
    sample_rate=44100,
    output_format="mp3",
    precision="PCM_16"
)
print(response["item"]["audio_src"])
```

### WebSocket ストリーミング (リアルタイム <50ms)

```python
import websockets
import asyncio
import json

async def stream_tts():
    uri = "wss://app.resemble.ai/ws/api/v1/stream"
    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps({
            "token": "YOUR_API_KEY",
            "voice_uuid": "<voice_uuid>",
            "data": "Hello, this is a real-time synthesis test.",
            "sample_rate": 22050
        }))
        while True:
            chunk = await ws.recv()
            if chunk == b"END":
                break
            # 音声チャンクをリアルタイム再生
            audio_buffer.write(chunk)

asyncio.run(stream_tts())
```

### 声クローン作成

```python
# 5分のサンプル音声から声クローン
voice = Resemble.v2.voices.create(
    name="My Custom Voice JP",
    dataset_url="https://storage.example.com/voice_samples.zip"
)
voice_uuid = voice["item"]["uuid"]
```

### Deepfake Detection API

```python
# 音声が本物か合成か判定
result = Resemble.v2.detect.create(
    audio_url="https://storage.example.com/audio.mp3"
)
print(result["is_deepfake"])  # True / False
print(result["confidence"])    # 0.0 - 1.0
```

### 制限事項
- 声クローンは 5 分以上の高品質サンプルが必要
- ストリーミング API は Professional プラン以上
- 日本語のサンプルは英語より多め (10 分推奨)
$md$,
  2
),
(
  'resemble_ai',
  'models',
  $md$## Resemble AI の技術

| 機能 | 技術 |
|------|------|
| Text-to-Speech | 独自 Neural TTS (Chroma モデル) |
| Voice Cloning | 独自ゼロショット / フューショット クローニング |
| Real-time Streaming | WebSocket + チャンク分割合成 |
| Deepfake Detection | 独自バイナリ分類モデル |
| 感情制御 | SSML 拡張 + API パラメータ |

### パフォーマンス指標
- **レイテンシ**: <50ms (WebSocket ストリーミング初回チャンク)
- **品質**: MOS スコア 4.2/5.0 (English)
- **声クローン精度**: EER 3.2% (話者識別誤り率)
- **Deepfake 検出精度**: 97.8% (自社ベンチマーク)

### 自分株式会社での活用可能性
- 会話 AI アシスタントへの低遅延音声合成統合 (<50ms でネイティブ体験)
- ゲーミフィケーション機能でのプレイヤー固有音声生成
- 音声コンテンツの Deepfake 検出・認証 (セキュリティ強化)
- 自社キャラクターの声クローン → LP 音声案内

### 日本語対応状況
- 日本語対応: ★7/9 (英語 ★9/9 に対して改善余地あり)
- 日本語声クローン: サンプル 10 分以上推奨
$md$,
  3
)
ON CONFLICT (provider_id, section) DO UPDATE
  SET content_md = EXCLUDED.content_md,
      display_order = EXCLUDED.display_order,
      updated_at = NOW();

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 203→204社化: Resemble AI 追加',
  'PS#3 S55。Resemble AI (リアルタイム音声クローン / <50ms WebSocket ストリーミング / Deepfake 検出 / 5分サンプルで声クローン / $8M YC S20 / ★8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
