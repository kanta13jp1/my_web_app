-- GMI Cloud 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('gmi_cloud', 'overview', 'GMI Cloud 概要',
$$**GMI Cloud** は **NVIDIA TensorRT-LLM** をバックエンドに採用した低遅延 inference platform。100+ オープンモデルを OpenAI 互換 API で提供する。

H100/H200 GPU を時間貸しまたはトークン課金で利用でき、自社モデル運用とサーバーレス inference の両方に対応。`vLLM` + `FP8` 最適化により業界トップクラスの latency を実現。

## 主要サービス
- Inference Engine: 100+ モデル (DeepSeek/GLM/Llama/Qwen/Mistral 等)
- Free Tier: 限定トークン無料
- Pay-per-token: $0.000001 - $0.50/request
- GPU 時間貸し: H100 約 $2.10/GPU-hour

## 強み
- **TensorRT-LLM 採用** — NVIDIA 公式最適化 stack
- **2026 最低レイテンシ級** (vLLM+FP8)
- 100+ モデルを 1 アカウント
- console.gmicloud.ai で smart inference hub 提供$$,
'https://www.gmicloud.ai/', '2026-04-19', 1),

('gmi_cloud', 'models', 'GMI Cloud モデル一覧 (2026)',
$$## 主要モデル

| モデル | 入力 / 出力 ($/M tokens) | 特徴 |
| :--- | :--- | :--- |
| **GLM-5** (Zhipu AI) | $1.00 / $3.20 | 中国フラッグシップ |
| **DeepSeek-V3.2** | $0.28 / $0.40 | 推論コスパ最強 |
| **DeepSeek R1 Distill Qwen 1.5B** | Free Tier | 蒸留 R1 |
| **Llama-3.1-8B-Instruct** | Free Tier | OSS 標準 |
| **Llama-3.1-70B / 405B** | (要確認) | 大型 OSS |

## 特徴的な機能
- TensorRT-LLM + vLLM 統合 stack
- FP8 量子化で latency 半減
- H100 GPU 即時プロビジョン
- console.gmicloud.ai で全モデル一覧$$,
'https://docs.gmicloud.ai/inference-engine/billing/price', '2026-04-19', 2),

('gmi_cloud', 'api', 'GMI Cloud API 入門',
$$## GMI Cloud API の始め方

OpenAI SDK 互換のため base URL 切替で動く:

```python
from openai import OpenAI

client = OpenAI(
    api_key="gmi-...",  # GMI Cloud API key
    base_url="https://api.gmicloud.ai/v1",
)

resp = client.chat.completions.create(
    model="deepseek-v3.2",
    messages=[{"role": "user", "content": "こんにちは"}],
)
print(resp.choices[0].message.content)
```

## 料金 (2026年4月時点)
- Free Tier: 限定トークン無料
- Pay-per-token: モデル別変動
- GPU 時間貸し: H100 $2.10/GPU-hour
- 詳細: https://docs.gmicloud.ai/inference-engine/billing/price
- 自分株式会社では **Budget Tier** に分類 (DeepSeek 系なら $0.30 前後)$$,
'https://console.gmicloud.ai/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
