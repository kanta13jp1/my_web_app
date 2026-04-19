-- Inworld AI 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('inworld', 'overview', 'Inworld AI 概要',
$$Inworld AI は、AI エージェント・キャラクター・音声システムを構築するための包括的なプラットフォーム。
2024〜2025 年に **Inworld Router** (LLM ルーティング) + **Agent Runtime** (C++ オーケストレーション) + **Inworld TTS** を発表。

ゲーム NPC からエンタープライズ AI エージェントまで幅広い用途に対応。OpenAI / Anthropic / Google など主要プロバイダーのモデルを 1 つの API で統合し、コスト・遅延・品質ベースの動的ルーティングを実現する。

## 主要サービス
- **Inworld Router**: hundreds of models を OpenAI 互換 API で統合・自動フォールバック・KPI 計測
- **Agent Runtime**: C++ ベース orchestration core (LLM + TTS + STT + tools・無料・モデル消費課金のみ)
- **Inworld TTS**: 高品質低遅延 voice synthesis (per-character pricing)
- **Realtime API**: speech-to-speech (OpenAI Realtime protocol 互換)

## 強み
- **gateway 統合**: OpenAI/Anthropic/Google etc を単一 API でアクセス
- **OpenAI Realtime 互換**: 既存 client minimal change で乗換可能
- **observability + experiments**: live KPI 計測・モデル比較自動化
- **ゲーム業界実績**: NPC dialogue / character AI で老舗$$,
'https://inworld.ai/', '2026-04-19', 1),

('inworld', 'models', 'Inworld AI モデル一覧 (2026)',
$$## Inworld Router 経由で利用可能な主要モデル

| モデル | プロバイダー | 入力 ($/M) | 出力 ($/M) | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| **GPT 5 Mini** | OpenAI | $0.25 | $2.00 | 軽量推論 |
| **GPT 4o Mini** | OpenAI | $0.15 | $0.60 | 高速/安価 |
| **GPT 4.1** | OpenAI | $2.00 | $8.00 | 高品質 |
| **GPT 5.4** | OpenAI | (provider rate) | (provider rate) | 最新 reasoning |
| **Grok 4.20** | xAI | (provider rate) | (provider rate) | reasoning |
| **Claude Sonnet 4.6** | Anthropic | (provider rate) | (provider rate) | 設計判断 |
| **Gemini 3.1 Pro** | Google | (provider rate) | (provider rate) | マルチモーダル |

## 特徴的な機能
- **動的ルーティング**: cost / latency / quality でモデル自動選択
- **fallback chain**: 1 モデル失敗時に次を自動試行
- **A/B testing**: live experiment で複数モデルの KPI 比較
- **TTS統合**: speech-to-speech pipeline 内蔵
- **エージェントランタイム**: tool use + memory + state machine 標準装備$$,
'https://inworld.ai/models', '2026-04-19', 2),

('inworld', 'api', 'Inworld AI API 入門',
$$## Inworld Router の始め方

```python
# OpenAI SDK そのまま使える (drop-in replacement)
from openai import OpenAI

client = OpenAI(
    api_key="<INWORLD_API_KEY>",
    base_url="https://api.inworld.ai/v1",
)

response = client.chat.completions.create(
    model="gpt-4o-mini",  # Router 経由でルーティング
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## 動的ルーティング (cost-based)

```python
# 最安モデルを自動選択
response = client.chat.completions.create(
    model="auto",  # Router が cost 軸で選択
    messages=[...],
    extra_body={"routing_strategy": "cheapest"},
)
```

## 料金 (2026年4月時点)
- **Router 利用料**: 無料 (モデル消費料のみ)
- **GPT 4o Mini**: $0.15 / 100万入力 token, $0.60 / 100万出力 token
- **GPT 5 Mini**: $0.25 / 100万入力 token, $2.00 / 100万出力 token
- **Agent Runtime**: 無料 (C++ orchestration core)
- **TTS**: 文字数ベース課金 (詳細は公式)$$,
'https://docs.inworld.ai/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
