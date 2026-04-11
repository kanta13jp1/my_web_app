-- Groq AI コンテンツシード
-- AI大学: Groq プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: LPU新アーキテクチャ / API公開済み / 開発者コミュニティで話題性最高

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('groq', 'overview', 'Groq 概要',
$$Groq は 2016年にシリコンバレーで創業されたAI半導体・推論インフラ企業です。元 Google TPU チームのジョナサン・ロスが設立し、AI の「速度」に特化した独自ハードウェア **LPU (Language Processing Unit)** を開発しました。

Groq の最大の特徴は **圧倒的な推論速度**です。従来のGPUベースの推論と比べて10〜100倍高速なレスポンスを実現し、Llama・Mixtral・Gemma などの人気オープンソースモデルをクラウド経由で提供しています。

## LPU アーキテクチャとは
- **決定論的処理**: GPUと異なりメモリ帯域幅がボトルネックにならない専用設計
- **超低レイテンシ**: トークン生成速度が業界最速クラス（毎秒500〜1000トークン超）
- **省電力**: 同性能のGPUと比べて大幅に消費電力が低い

## 主要サービス
- **GroqCloud** — LPUベースの高速推論 API（無料枠あり）
- **Groq Console** — API キー管理・使用量モニタリング
- **Groq Developer Docs** — SDK・サンプルコード・チュートリアル

## 強み
- 業界最速クラスの推論速度（低レイテンシが必須なリアルタイム用途に最適）
- Llama 4・Mixtral・Gemma・Qwen などの人気 OSS モデルを同一 API で利用可能
- OpenAI 互換 API — 既存コードの最小変更で移行可能
- 無料枠が充実しており、学習・プロトタイプ開発に最適$$,
'https://groq.com/', '2026-04-12', 1),

('groq', 'models', 'Groq で動くモデル一覧 (2026)',
$$## Groq が提供する主要モデル

Groq は独自モデルではなく、人気オープンソースモデルを LPU 上で超高速推論として提供します。

| モデル | コンテキスト | 速度 | 用途 |
| :--- | :--- | :--- | :--- |
| **Llama 4 Scout 17B** | 128K | 超高速 | 汎用・日本語対応 |
| **Llama 4 Maverick 17B** | 128K | 高速 | 高精度汎用タスク |
| **Llama 3.3 70B** | 128K | 高速 | 高精度・複雑タスク |
| **Llama 3.1 8B** | 128K | 最高速 | 低レイテンシ・コスト重視 |
| **Mixtral 8x7B** | 32K | 高速 | MoE・マルチリンガル |
| **Gemma 2 9B** | 8K | 超高速 | 軽量・高品質 |
| **Qwen 2.5 Coder 32B** | 128K | 高速 | コーディング特化 |
| **Llama 3.2 11B Vision** | 128K | 高速 | ビジョン・画像理解 |
| **Whisper Large v3** | — | リアルタイム | 音声認識・文字起こし |

## 推論速度の目安
- **Llama 3.1 8B**: ~1,200 トークン/秒
- **Llama 4 Scout**: ~800 トークン/秒
- **Llama 3.3 70B**: ~300 トークン/秒

これは GPU ベースのサービスと比較して 5〜20倍高速で、チャットボット・リアルタイム翻訳・音声文字起こしなど低レイテンシが求められるユースケースに最適です。

## 特徴的な機能
- **Batch API**: 大量処理を低コストで非同期実行
- **Tool Use / Function Calling**: 全主要モデルで対応
- **Audio API**: Whisper Large v3 によるリアルタイム音声認識$$,
'https://console.groq.com/docs/models', '2026-04-12', 2),

('groq', 'api', 'Groq API 入門',
$$## Groq API の始め方

Groq API は **OpenAI SDK と完全互換**のため、ベースURLを変更するだけで移行できます。

```python
from groq import Groq

client = Groq(api_key="your-groq-api-key")

response = client.chat.completions.create(
    model="llama-3.3-70b-versatile",
    messages=[
        {"role": "user", "content": "Groq の LPU アーキテクチャを説明してください。"}
    ]
)

print(response.choices[0].message.content)
```

## OpenAI SDK からの移行（最小変更）

```python
# 変更前 (OpenAI)
from openai import OpenAI
client = OpenAI(api_key="...")

# 変更後 (Groq: ベースURLのみ変更)
from openai import OpenAI
client = OpenAI(
    api_key="your-groq-api-key",
    base_url="https://api.groq.com/openai/v1"
)
```

## 音声認識 (Whisper)

```python
with open("audio.mp3", "rb") as f:
    transcription = client.audio.transcriptions.create(
        file=f,
        model="whisper-large-v3",
        response_format="text",
        language="ja"
    )
print(transcription)
```

## 料金 (2026年4月時点)

| モデル | 入力 (100万トークン) | 出力 (100万トークン) |
| :--- | :--- | :--- |
| **Llama 3.1 8B** | $0.05 | $0.08 |
| **Llama 3.3 70B** | $0.59 | $0.79 |
| **Llama 4 Scout** | $0.11 | $0.34 |
| **Mixtral 8x7B** | $0.24 | $0.24 |

- **無料枠あり**: 毎分リクエスト制限付きで無料利用可能
- API キーは [Groq Console](https://console.groq.com/) で発行（Googleアカウントで即登録可能）
- SDK: `pip install groq` / npm: `npm install groq`$$,
'https://console.groq.com/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Groq 追加 (10社目)',
  'Groq (LPU超高速推論) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、LPUアーキテクチャの解説・速度比較・OpenAI互換API情報を収録。AI大学プロバイダー数 9社→10社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
