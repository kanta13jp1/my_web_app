-- Modular 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('modular', 'overview', 'Modular 概要',
$$Modular は **AI inference stack 統合**を目指す企業。**MAX** (高性能 serving framework) + **Mojo** (Python 互換の systems プログラミング言語) + **BentoML** (2026-02 買収) を 1 つの platform に統合。

「kernel から cloud まで」 (kernel-to-cloud) の inference パイプラインを最適化。GPU / ASIC / CPU など多様 hardware で統一 API を提供。

2026-02 に BentoML 買収で packaging + adaptive batching + Kubernetes orchestration を MAX platform に統合。LLM inference の de facto standard を狙う。

## 主要サービス
- **MAX (Modular Accelerated Xecution)**: 高性能 inference serving framework (vLLM/SGLang 競合)
- **Mojo**: Python 互換 systems language (CUDA カーネル相当を Python で書ける)
- **BentoML 統合**: モデル packaging + serving + autoscale
- **Modular Studio**: 開発・デバッグ環境

## 強み
- **kernel-to-cloud 統合**: 1 つの stack で全レイヤー
- **Mojo**: Python の生産性 + C++ の性能
- **BentoML**: 業界標準の serving 互換
- **multi-hardware**: GPU/ASIC/CPU を統一 API
- **OSS + 商用 hybrid**: MAX core OSS / Enterprise 機能商用$$,
'https://www.modular.com/', '2026-04-19', 1),

('modular', 'models', 'Modular MAX 提供モデル・対応 hardware (2026)',
$$## MAX 対応モデル (vLLM 相当)

| モデル | 用途 |
| :--- | :--- |
| **Llama 3.3 70B** | 汎用推論 |
| **Mistral Large** | 高品質 |
| **Qwen 2.5 72B** | 多言語 |
| **DeepSeek V3** | コスパ |
| **Custom Mojo モデル** | 自前 Mojo 実装 |

## 対応 hardware

| Hardware | 用途 | 特徴 |
| :--- | :--- | :--- |
| **NVIDIA H100/B200** | 標準 LLM | CUDA 互換 + Mojo 最適化 |
| **AMD MI300** | LLM 学習 | ROCm 統合 |
| **AWS Trainium/Inferentia** | エンタープライズ | AWS 連携 |
| **Apple Silicon** | ローカル開発 | M3/M4 対応 |
| **CPU (x86/ARM)** | エッジ推論 | quantize 自動 |

## 特徴的な機能
- **MAX serving**: vLLM 比 30-50% スループット向上
- **Mojo language**: Python syntax + C++ 性能
- **adaptive batching**: 動的 batch サイズ最適化
- **K8s orchestration**: BentoML 統合で deploy 自動化
- **OpenAI 互換 API**: drop-in 可能 (MAX serve 経由)$$,
'https://www.modular.com/open-source/max', '2026-04-19', 2),

('modular', 'api', 'Modular API 入門',
$$## MAX serve で OpenAI 互換 API を起動

```bash
# MAX install
pip install modular

# Llama 3.3 70B を OpenAI 互換 endpoint で起動
max serve --model meta-llama/Meta-Llama-3.3-70B-Instruct --port 8000
```

```python
# OpenAI SDK そのまま (drop-in)
from openai import OpenAI

client = OpenAI(
    api_key="dummy",  # MAX local では認証不要
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

## Mojo で custom kernel

```python
# matrix_mul.mojo
from algorithm import vectorize
from sys.intrinsics import simd_width

fn matmul[type: DType](a: Tensor[type], b: Tensor[type]) -> Tensor[type]:
    var result = Tensor[type](a.shape[0], b.shape[1])
    # SIMD 自動展開
    @parameter
    fn dot_product[width: Int](i: Int):
        # ...
    vectorize[simd_width[type](), dot_product](a.shape[0])
    return result
```

## 料金
- **MAX OSS**: 無料 (Apache 2.0)
- **Modular Enterprise**: 個別問い合わせ
- **Mojo SDK**: 無料 (個人/研究)

## 公式リソース
- [Modular Docs](https://docs.modular.com/)
- [MAX GitHub](https://github.com/modularml/max)
- [Mojo Programming Manual](https://docs.modular.com/mojo/manual/)$$,
'https://docs.modular.com/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
