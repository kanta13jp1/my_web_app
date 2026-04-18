-- Atlas Cloud 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('atlas_cloud', 'overview', 'Atlas Cloud 概要',
$$**Atlas Cloud** は世界初の **フルモーダル inference platform**。チャット・推論・画像・音声・動画のあらゆるモダリティを **OpenAI 互換 API 1 本** で呼び出せる。

300+ モデル (DeepSeek / GPT / Claude / Flux / Qwen / GLM / MiniMax) を統合し、複数 provider の API key を切り替える手間を排除。

Atlas distributed AI infrastructure 上に構築されており、auto scaling・customizable TPM/RPM・SLA 付き低遅延 inference を提供する。

## 主要サービス
- 統一 API: 300+ モデル (LLM / 画像 / 音声 / 動画)
- OpenAI 互換: 既存 SDK そのまま使える
- Serverless / TPM-RPM カスタマイズ
- Free credits (新規登録時)
- Monitoring + Alerts

## 強み
- **唯一のフルモーダル統合** (chat + image + video + audio in 1 API)
- 透過的な per-token 課金
- 300+ モデル / 1 アカウント
- production 向け SLA 低遅延$$,
'https://www.atlascloud.ai/', '2026-04-19', 1),

('atlas_cloud', 'models', 'Atlas Cloud モデル一覧 (2026)',
$$## 主要モデルコレクション

| カテゴリ | モデル例 | 特徴 |
| :--- | :--- | :--- |
| **OpenAI** | gpt-5.4 / gpt-5 / gpt-4o | OpenAI 全シリーズ |
| **DeepSeek** | deepseek-v3 / deepseek-r1 | 推論特化 MoE |
| **Anthropic** | claude-sonnet-4.6 | (利用可能な場合) |
| **GLM** | GLM-4.6 / GLM-4.5-Air | 智譜 AI 中国 LLM |
| **MiniMax** | minimax-m2.1 | 動画/音声統合 |
| **Qwen** | Qwen3-235B / Qwen2.5-72B | 中国フラッグシップ |
| **Flux** | FLUX.1 [dev] / [schnell] | 画像生成 SOTA |

## 特徴的な機能
- 全モダリティ (text/image/audio/video) を統一エンドポイント経由で呼出
- LLM / Chat reference: https://www.atlascloud.ai/docs/en/models/llm
- 300+ モデル一覧: https://www.atlascloud.ai/models/list
- カスタム TPM/RPM 設定$$,
'https://www.atlascloud.ai/models/list', '2026-04-19', 2),

('atlas_cloud', 'api', 'Atlas Cloud API 入門',
$$## Atlas Cloud API の始め方

OpenAI SDK の base URL を変えるだけで動く:

```python
from openai import OpenAI

client = OpenAI(
    api_key="sk-atlas-...",  # Atlas Cloud API key
    base_url="https://api.atlascloud.ai/v1",
)

resp = client.chat.completions.create(
    model="deepseek-v3",
    messages=[{"role": "user", "content": "こんにちは"}],
)
print(resp.choices[0].message.content)
```

## 料金 (2026年4月時点)
- 透過的 per-token 課金 (モデルにより変動)
- 新規登録: 無料クレジット支給
- 詳細料金: https://www.atlascloud.ai/models/list 各モデルページ参照
- 自分株式会社では **Budget Tier** に分類予定 (300+モデル統合価値)$$,
'https://www.atlascloud.ai/docs/en/models/llm', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
