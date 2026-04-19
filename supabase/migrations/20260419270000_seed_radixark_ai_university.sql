-- RadixArk (SGLang) 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('radixark', 'overview', 'RadixArk (SGLang) 概要',
$$RadixArk は **SGLang** (LLM 推論エンジン) のメンテナンス会社。2026-01 に Accel リードで Series A を実施し $400M valuation で spin-out。CEO Ying Sheng は xAI の元 research scientist。

SGLang は **vLLM 競合**の高性能 LLM serving framework。RadixAttention (KV cache 最適化) でマルチターン会話が業界最速。Berkeley Sky Computing Lab 発の OSS。

主要顧客は xAI / DeepSeek / Tencent / Cursor / 0G / NVIDIA / Pony.ai 等の Tier 1 AI 企業。GitHub 16k+ stars。

## 主要サービス
- **SGLang OSS**: GitHub OSS (Apache 2.0) - vLLM 競合
- **RadixArk Cloud**: managed SGLang inference (商用)
- **Enterprise Support**: SLA + custom optimization
- **RadixAttention**: KV cache 共有 (チャット履歴最大化)

## 強み
- **業界最速 multi-turn**: RadixAttention で 5-10x スループット
- **xAI 等大手採用**: Grok 4 等の本番推論で実績
- **OSS + 商用**: hybrid モデル
- **Berkeley 発**: 学術品質のコード base$$,
'https://github.com/sgl-project/sglang', '2026-04-19', 1),

('radixark', 'models', 'RadixArk SGLang 対応モデル一覧 (2026)',
$$## SGLang 対応モデル

| モデル | 用途 | RadixAttention 効果 |
| :--- | :--- | :--- |
| **Llama 3.3 70B** | 汎用推論 | 5x スループット |
| **Mistral Large** | 高品質 | 4x |
| **Qwen 2.5 72B** | 多言語 | 5x |
| **DeepSeek V3** | コスパ | 6x |
| **Grok 2** | xAI 公式 | 8x (multi-turn) |

## 対応 hardware

| Hardware | 用途 |
| :--- | :--- |
| **NVIDIA H100/B200** | 標準 |
| **NVIDIA L40S** | コスパ |
| **AMD MI300** | ROCm |
| **CPU** | dev/quantize |

## 特徴的な機能
- **RadixAttention**: 同一 prefix の KV cache を共有 (multi-turn 最適化)
- **Tensor Parallelism**: 大規模モデルの分散推論
- **Speculative decoding**: smaller model + verifier で 2-3x 高速化
- **OpenAI 互換 API**: drop-in 可能
- **Function calling**: tool use 統合
- **vLLM 比 30-50% 高速**: 公式ベンチマークで証明$$,
'https://docs.sglang.ai/', '2026-04-19', 2),

('radixark', 'api', 'RadixArk SGLang API 入門',
$$## SGLang OSS で OpenAI 互換 API を起動

```bash
# SGLang install
pip install "sglang[all]"

# Llama 3.3 70B を OpenAI 互換 endpoint で起動
python -m sglang.launch_server \
  --model-path meta-llama/Meta-Llama-3.3-70B-Instruct \
  --port 8000
```

```python
# OpenAI SDK そのまま (drop-in)
from openai import OpenAI

client = OpenAI(
    api_key="dummy",
    base_url="http://localhost:8000/v1",
)

response = client.chat.completions.create(
    model="meta-llama/Meta-Llama-3.3-70B-Instruct",
    messages=[
        {"role": "user", "content": "こんにちは!"}
    ],
)
print(response.choices[0].message.content)
```

## RadixArk Cloud (managed)

```python
# RadixArk Cloud の managed endpoint (β)
client = OpenAI(
    api_key="<RADIXARK_API_KEY>",
    base_url="https://api.radixark.ai/v1",
)
```

## RadixAttention の効果

```
シナリオ: 100 ユーザーが同じシステムプロンプトでチャット
  vLLM: 各リクエスト独立処理 → KV cache 重複
  SGLang: 共通 prefix 検出 → KV cache 共有 → 5x スループット
```

## 料金
- **SGLang OSS**: 無料 (Apache 2.0)
- **RadixArk Cloud**: β価格 (個別問い合わせ)
- **Enterprise Support**: SLA + 24/7 サポート (商用)

## 公式リソース
- [SGLang GitHub](https://github.com/sgl-project/sglang) (16k+ stars)
- [SGLang Docs](https://docs.sglang.ai/)
- [RadixArk](https://radixark.ai/)
- [Speculative Decoding 解説](https://lmsys.org/blog/2025-01-15-sglang-speculative/)$$,
'https://docs.sglang.ai/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
