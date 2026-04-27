-- PS#3 S79: AI大学 253→254社化 — PEFT (Hugging Face Parameter-Efficient Fine-Tuning)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'peft', 'overview',
  'PEFT — Hugging Face公式パラメータ効率的ファインチューニングライブラリ (LoRA/QLoRA/Adapter/Prefix Tuning / GitHub 17k+ / 9/9)',
  $$## PEFT とは

**PEFT (Parameter-Efficient Fine-Tuning)** は Hugging Face が開発する、LLM の全パラメータを更新せずに少数のパラメータだけを追加・更新してファインチューニングするライブラリ。

GPT-4 (1.8兆パラメータ) のフルファインチューニングには数十億円の計算コストが必要。PEFT は **学習パラメータを 0.1〜1% に削減** しながら、フルファインチューニングに近い性能を達成する。

## 主要手法

| 手法 | パラメータ比 | VRAM | 特徴 |
|------|------------|------|------|
| **LoRA** | 0.1〜1% | 低 | 行列分解で重みを更新 / 現在の標準 |
| **QLoRA** | 0.1〜1% | 最低 | 4bit量子化+LoRA / RTX 3080以下対応 |
| **AdaLoRA** | 可変 | 低 | LoRA ランクを自動調整 |
| **LoHA** | 0.1〜0.5% | 低 | Hadamard 積による改良 LoRA |
| **IA³** | 0.01% | 最低 | スケーリングのみ / 超高速 |
| **Prefix Tuning** | 0.1% | 低 | プレフィックストークン追加 |
| **Prompt Tuning** | <0.01% | 最低 | Soft Prompt の学習 |
| **Adapter** | 1〜3% | 中 | FFN に小ネット追加 |

## LoRA の原理

```
通常の重み更新: W_new = W_0 + ΔW  (ΔW は W_0 と同サイズ = 膨大)

LoRA の重み更新: W_new = W_0 + B·A
  W_0: 元の重み (凍結 / 更新しない)
  A: [r × d_in] の小行列 (学習対象)
  B: [d_out × r] の小行列 (学習対象)
  r: ランク (8, 16, 32, 64 など)

例: d_in=d_out=4096, r=16 の場合
  通常: 4096 × 4096 = 16,777,216 パラメータ
  LoRA: (16×4096) + (4096×16) = 131,072 パラメータ → 99.2% 削減
```

## GitHub と採用状況

- **GitHub**: 17,000+ Stars / Hugging Face 公式
- **採用**: Llama 3 / Mistral / Stable Diffusion / Whisper ファインチューニングで標準
- **TRL との関係**: TRL の `SFTTrainer` / `DPOTrainer` は PEFT を内部で使用
- **Axolotl との関係**: Axolotl は PEFT を通じて LoRA / QLoRA を提供

## 自分株式会社での活用

| シーン | 手法 | 推奨 |
|--------|------|------|
| **コスト最小ファインチューニング** | QLoRA (r=8) | Colab 無料GPU |
| **高品質ファインチューニング** | LoRA (r=64) | RTX 4090 |
| **マルチタスク対応** | 複数 LoRA アダプタ切り替え | 本番環境 |
| **プロンプト最適化** | Prefix Tuning | GPT-4 APIコスト削減 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'peft', 'api',
  'PEFT 実践 — LoRA/QLoRA実装・複数アダプタ管理・Hugging Face Hub保存・推論最適化',
  $$## インストール

```bash
pip install peft transformers accelerate
# QLoRA (4bit量子化) を使う場合
pip install peft transformers accelerate bitsandbytes
```

## LoRA ファインチューニング

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model, TaskType
import torch

# ベースモデルロード
model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B",
    torch_dtype=torch.bfloat16,
    device_map="auto",
)

# LoRA 設定
lora_config = LoraConfig(
    r=16,                    # ランク
    lora_alpha=32,           # スケーリング (alpha/r が実効的学習率)
    target_modules=[         # どの層に LoRA を追加するか
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    lora_dropout=0.05,
    bias="none",
    task_type=TaskType.CAUSAL_LM,
)

# PEFT モデル作成
model = get_peft_model(model, lora_config)

# 学習可能パラメータ確認
model.print_trainable_parameters()
# 例: trainable params: 20,971,520 || all params: 8,051,372,032 || trainable%: 0.26%
```

## QLoRA (4bit量子化 + LoRA)

```python
from transformers import BitsAndBytesConfig
from peft import prepare_model_for_kbit_training

# 4bit量子化設定
bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",       # NormalFloat4 (推奨)
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,  # double quantization でさらに削減
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B",
    quantization_config=bnb_config,
    device_map="auto",
)

# 4bit モデルを LoRA 学習可能に準備
model = prepare_model_for_kbit_training(model)

lora_config = LoraConfig(r=16, lora_alpha=32, task_type=TaskType.CAUSAL_LM)
model = get_peft_model(model, lora_config)

# VRAM 使用量: 8B モデルが 6-8GB で動作 (通常 16GB+)
```

## アダプタの保存・読み込み

```python
# LoRA アダプタのみ保存 (数MB〜数十MB / ベースモデルは含まない)
model.save_pretrained("./my-lora-adapter")
tokenizer.save_pretrained("./my-lora-adapter")

# Hugging Face Hub にプッシュ
model.push_to_hub("username/my-lora-adapter")

# 後で読み込む
from peft import PeftModel

base_model = AutoModelForCausalLM.from_pretrained("meta-llama/Meta-Llama-3-8B")
model = PeftModel.from_pretrained(base_model, "./my-lora-adapter")

# Hub からも読み込み可
model = PeftModel.from_pretrained(base_model, "username/my-lora-adapter")
```

## 複数アダプタの切り替え

```python
# 複数の LoRA アダプタを1つのモデルで管理
model.load_adapter("./adapter-japanese", adapter_name="japanese")
model.load_adapter("./adapter-coding", adapter_name="coding")
model.load_adapter("./adapter-sales", adapter_name="sales")

# 用途に応じて切り替え
model.set_adapter("japanese")   # 日本語タスク
response = model.generate(...)

model.set_adapter("coding")     # コーディングタスク
response = model.generate(...)

# 複数アダプタの合成 (LoRA merging)
model.add_weighted_adapter(
    adapters=["japanese", "coding"],
    weights=[0.6, 0.4],
    adapter_name="japanese-coder",
)
```

## ベースモデルへのマージ (推論高速化)

```python
# LoRA をベースモデルにマージ → 推論時オーバーヘッドゼロ
merged_model = model.merge_and_unload()
merged_model.save_pretrained("./merged-model")
```

## IA³ (最小パラメータ手法)

```python
from peft import IA3Config

# IA³: 0.01% のパラメータで学習
ia3_config = IA3Config(
    target_modules=["k_proj", "v_proj", "down_proj"],
    feedforward_modules=["down_proj"],
    task_type=TaskType.CAUSAL_LM,
)
model = get_peft_model(model, ia3_config)
# 学習速度: LoRA の 3〜5x 高速
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'peft', 'models',
  'PEFT 技術詳解 — LoRA数学・ランク選択理論・AdaLoRA・マルチモーダル対応・Stable Diffusion応用',
  $$## LoRA の数学的詳細

### 行列分解の理解

```
元の重み行列 W ∈ R^{d×k}
フルファインチューニング: W + ΔW  (ΔW ∈ R^{d×k})

LoRA の仮定:
  ΔW = BA  (B ∈ R^{d×r}, A ∈ R^{r×k}, r << min(d,k))

仮定の根拠: Aghajanyan et al. (2021) による研究
  「LLM の weight 変化は intrinsic rank が低い」
  = 本質的な変化は低次元空間に収まる
```

### スケーリング係数 alpha の役割

```python
# LoRA の出力: h = W_0·x + (alpha/r)·B·A·x
# alpha/r が実効的な学習率スケール

# 例: r=16, alpha=32 → スケール = 2.0
# 例: r=16, alpha=16 → スケール = 1.0 (デフォルト推奨)

# 経験則:
# - alpha = r が最も安定 (スケール=1)
# - alpha = 2r でより積極的な学習
# - r を増やすより alpha を増やすほうが安全
```

## AdaLoRA: ランク自動調整

固定ランクの LoRA では、すべての層に同じランクを割り当てる。AdaLoRA は**重要な層に大きいランク、重要でない層に小さいランク**を自動割り当て:

```python
from peft import AdaLoraConfig

config = AdaLoraConfig(
    init_r=12,           # 初期ランク
    target_r=8,          # 目標平均ランク
    beta1=0.85,
    beta2=0.85,
    deltaT=10,           # ランク調整間隔
    lora_alpha=32,
    target_modules=["q_proj", "v_proj"],
    task_type=TaskType.CAUSAL_LM,
)
```

結果: 同等の品質で LoRA より 10〜20% パラメータ削減。

## LoRA ランク選択の実験的ガイド

```
rank=1〜4:   最小限の調整 / 基本的な口調変更 / IA³ の方が良い場合も
rank=8:      軽量タスク / プロンプトスタイル調整 / Colab T4 で動作
rank=16:     標準的なファインチューニング / 多くのタスクで十分
rank=32:     高品質要求 / 複雑なドメイン適応
rank=64:     論文品質 / RTX 4090 推奨
rank=128+:   フルFT相当 / A100 推奨 / 過学習リスク大
```

**最初は r=16 から始めて損失が収束しなければ上げる戦略が実用的。**

## Stable Diffusion への PEFT 応用

PEFT は LLM だけでなく画像生成モデルにも使える:

```python
# LoRA for Stable Diffusion
from peft import LoraConfig
from diffusers import StableDiffusionPipeline

unet_lora_config = LoraConfig(
    r=4,
    lora_alpha=4,
    init_lora_weights="gaussian",
    target_modules=["to_k", "to_q", "to_v", "to_out.0"],
)

# 特定のキャラクター/スタイルを数百枚の画像で学習
# 学習後: 自社ロゴ/キャラクターを生成可能
```

## マルチモーダル PEFT

```python
# LLaVA / Qwen-VL などビジョンモデルにも適用
from peft import LoraConfig

vision_lora_config = LoraConfig(
    r=8,
    target_modules=["q_proj", "v_proj"],  # ビジョン+テキスト両方
    task_type="FEATURE_EXTRACTION",
)
```

## 自分株式会社 PEFT 運用戦略

```
本番環境でのマルチアダプタ戦略:

1. ベースモデル: Llama-3-8B (ローカル常駐 / 16GB VRAM)
2. アダプタプール (各 50〜200MB):
   - adapter-ja: 日本語品質向上
   - adapter-finance: 家計管理・投資アドバイス
   - adapter-health: 健康・運動アドバイス
   - adapter-code: コード生成支援
3. リクエストに応じてアダプタ切り替え (1ms 以下)
4. コスト: OpenAI API の 1/100 以下

OpenAI API 月 $500 → ローカル PEFT 月 $10 (電気代のみ)
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 253→254社化: PEFT 追加',
  'PS#3 S79。PEFT (Hugging Face Parameter-Efficient Fine-Tuning / LoRA/QLoRA/AdaLoRA/IA³/Prefix Tuning/Adapter / GitHub 17k+ / マルチアダプタ管理 / Stable Diffusion対応 / Apache 2.0 / 9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
