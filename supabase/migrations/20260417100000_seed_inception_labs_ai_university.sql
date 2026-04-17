-- Inception Labs (Mercury) 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('inception_labs', 'overview', 'Inception Labs 概要',
$$Inception Labs は **拡散モデル (Diffusion) による LLM** を世界で初めて商用化したスタートアップ。従来の Transformer 自己回帰モデルが左から右へ1トークンずつ生成するのに対し、拡散 LLM (**dLLM**) は**トークンを並列生成**できるため最大10倍の推論速度を実現する。

2025年に発表された **Mercury** は「世界初の商用規模 dLLM」として話題を呼び、2026年2月公開の **Mercury 2** は「史上最速の Reasoning LLM」として速度特化型 LLM の中でもさらに 5倍の性能を達成した。コード生成・構造化出力・ツール使用などの実用機能を完備し、Azure AI Foundry でも提供される。

## 主要サービス
- **Mercury**: 初代 dLLM (一般テキスト生成)
- **Mercury 2**: 2026年2月リリース・推論(Reasoning)特化の dLLM
- **Inception API**: OpenAI 互換 REST API
- **Azure AI Foundry**: 企業向け Microsoft クラウド配布
- **OpenRouter**: サードパーティ経由アクセス

## 強み
- **dLLM アーキテクチャ**: トークン並列生成で速度 10x
- **128K context**: 長ドキュメント対応
- **OpenAI 互換 API**: LangChain / LiteLLM / AISuite 即対応
- **Free tier 10M tokens**: 開発検証に十分な無料枠
- **Function Calling / JSON Schema**: 構造化出力ネイティブサポート$$,
'https://www.inceptionlabs.ai/', '2026-04-17', 1),

('inception_labs', 'models', 'Inception Labs Mercury モデル一覧 (2026)',
$$## Mercury シリーズ

| モデル | タイプ | 特徴 | 速度比較 |
| :--- | :--- | :--- | :--- |
| **Mercury** | 拡散 LLM (通常) | コード・チャット向け | 10x faster vs GPT-4 class |
| **Mercury 2** | 拡散 Reasoning LLM | 推論・数学・コード | 5x faster vs 速度特化LLM |
| **Mercury Coder** | コード特化 dLLM | プログラミング | 推論も高速 |

## アーキテクチャ詳細

**拡散 LLM (dLLM) とは?**
- 従来: 左→右に1トークンずつ生成 (Autoregressive)
- 拡散: ノイズから並列に全トークンを精製 (Diffusion)
- **結果**: GPU を効率的に使い切り、同品質で 5〜10倍高速

## 特徴的な機能
- **128K context**: 長コード・長ドキュメント対応
- **Native tool use**: 関数呼び出しをネイティブサポート
- **Structured Output**: JSON Schema 指定で完璧な構造化出力
- **OpenAI 互換**: ベース URL 差し替えのみで既存コード動作
- **Azure AI Foundry**: エンタープライズ向け SLA 提供$$,
'https://www.inceptionlabs.ai/models', '2026-04-17', 2),

('inception_labs', 'api', 'Inception API 入門',
$$## Inception API の始め方

```python
from openai import OpenAI

# OpenAI 互換 — ベース URL だけ変更
client = OpenAI(
    api_key="YOUR_INCEPTION_API_KEY",
    base_url="https://api.inceptionlabs.ai/v1"
)

response = client.chat.completions.create(
    model="mercury-2",
    messages=[
        {"role": "user", "content": "フィボナッチ数列を計算する Python 関数を書いて。"}
    ]
)
print(response.choices[0].message.content)
```

## Structured Output (JSON Schema)

```python
response = client.chat.completions.create(
    model="mercury-2",
    messages=[{"role": "user", "content": "東京の天気情報をJSONで"}],
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "weather",
            "schema": {
                "type": "object",
                "properties": {
                    "temperature": {"type": "number"},
                    "condition": {"type": "string"}
                }
            }
        }
    }
)
```

## 料金 (2026年4月時点)
- **Free tier**: 10,000,000 tokens / 月 (開発検証用)
- **Developer**: 従量課金 (Mercury $0.25 / 1M input, $1.00 / 1M output)
- **Enterprise**: SLA付き・カスタム料金
- **Azure AI Foundry**: Azure 従量課金統合

## 主要エンドポイント
- `POST /v1/chat/completions` — OpenAI互換チャット
- `POST /v1/completions` — レガシー補完
- `POST /v1/embeddings` — 埋め込み
- Function Calling / Streaming 全対応

## 認証
Inception API Console で API Key 発行。OpenRouter 経由なら `inception/mercury` モデルで即利用可能。$$,
'https://www.inceptionlabs.ai/blog/introducing-inception-api', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
