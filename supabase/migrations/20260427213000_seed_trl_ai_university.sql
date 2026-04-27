-- PS#3 S79: AI大学 252→253社化 — TRL (Hugging Face RLHF)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trl', 'overview',
  'TRL (Transformer Reinforcement Learning) — Hugging Face公式RLHF/DPOライブラリ (GitHub 10k+ / SFT→RLHF→DPO / 9/9)',
  $## TRL とは

**TRL (Transformer Reinforcement Learning)** は Hugging Face が開発・メンテナンスする LLM の強化学習ファインチューニング専用ライブラリ。ChatGPT・Claude・Gemini の中核技術である **RLHF (Reinforcement Learning from Human Feedback)** と **DPO (Direct Preference Optimization)** を数十行のコードで実装できる。

## 主要アルゴリズム

| アルゴリズム | 概要 | 用途 |
|-------------|------|------|
| **SFT (Supervised Fine-Tuning)** | 教師あり学習の基盤 | Step 1: 基本能力習得 |
| **Reward Modeling** | 人間の好みを学習するスコアラー | Step 2: 評価基準構築 |
| **PPO (Proximal Policy Opt.)** | RLHFの標準的RL手法 | Step 3: 古典的RLHF |
| **DPO (Direct Preference Opt.)** | RL不要の選好学習 | Step 3: 現代的代替手法 |
| **ORPO** | SFT+DPOを1ステップで | 効率化・最新手法 |
| **KTO** | 単一出力の好み/嫌いで学習 | 省アノテーション |
| **GRPO** | Group Relative Policy Opt. (DeepSeek-R1採用) | 推論モデル学習 |

## なぜ TRL が重要か

```
ChatGPT = GPT-4 (SFT) + Reward Model + PPO (RLHF)
Claude   = Constitutional AI (SFT) + RLAIF
Gemini   = SFT + RLHF (人間フィードバック)
         ↑ これらを再現できるのが TRL
```

## RLHF vs DPO

```
RLHF (古典):
  人間フィードバック → Reward Model 学習 → PPO で LLM 更新
  利点: 最も実績あり / 欠点: 複雑・不安定・計算コスト大

DPO (現代):
  (chosen, rejected) ペアデータ → 直接 LLM 更新
  利点: シンプル・安定・高速 / 欠点: ペアデータ必要
```

現在の主流は **DPO** → TRL の `DPOTrainer` が最もよく使われる。

## エコシステム

- **対応モデル**: Llama / Mistral / Gemma / Qwen / Phi → すべての Transformers 互換
- **PEFT 統合**: LoRA / QLoRA と組み合わせてVRAM削減
- **Accelerate 統合**: マルチ GPU / FSDP / DeepSpeed 対応
- **WandB 統合**: トレーニングログ自動記録
- **GitHub**: 10,000+ Stars / Hugging Face 公式リポジトリ

## 自分株式会社での活用シーン

| シーン | 手法 | 期待効果 |
|--------|------|---------|
| **AI アシスタント品質向上** | DPO | ユーザー好みの回答スタイルに調整 |
| **有害コンテンツ除去** | RLHF / Constitutional AI | 安全な出力の確保 |
| **業務特化チューニング** | SFT → DPO | 社内用語・業務フロー対応 |
| **競合差別化** | ORPO | 少ないデータで高品質化 |$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trl', 'api',
  'TRL 実践 — SFTTrainer・DPOTrainer・GRPOTrainerの完全実装ガイド',
  $## インストール

```bash
pip install trl
# PEFT (LoRA) と組み合わせる場合
pip install trl peft accelerate bitsandbytes
```

## Step 1: SFT (Supervised Fine-Tuning)

```python
from datasets import load_dataset
from trl import SFTConfig, SFTTrainer
from peft import LoraConfig
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Meta-Llama-3-8B",
    torch_dtype=torch.bfloat16,
    device_map="auto",
)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Meta-Llama-3-8B")
tokenizer.pad_token = tokenizer.eos_token

# LoRA 設定
peft_config = LoraConfig(
    r=16,
    lora_alpha=32,
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj"],
    task_type="CAUSAL_LM",
)

dataset = load_dataset("trl-lib/tldr", split="train")

trainer = SFTTrainer(
    model=model,
    args=SFTConfig(
        output_dir="./sft-output",
        num_train_epochs=3,
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        learning_rate=2e-4,
        bf16=True,
        logging_steps=10,
    ),
    train_dataset=dataset,
    tokenizer=tokenizer,
    peft_config=peft_config,
)
trainer.train()
trainer.save_model()
```

## Step 2: DPO (Direct Preference Optimization)

```python
from trl import DPOConfig, DPOTrainer
from peft import PeftModel

# SFT済みモデルをロード
model = AutoModelForCausalLM.from_pretrained(
    "./sft-output",
    torch_dtype=torch.bfloat16,
    device_map="auto",
)
# reference model (更新しない)
ref_model = AutoModelForCausalLM.from_pretrained(
    "./sft-output",
    torch_dtype=torch.bfloat16,
    device_map="auto",
)

# DPO データセット形式: {prompt, chosen, rejected}
dpo_dataset = load_dataset("trl-lib/ultrafeedback_binarized", split="train")

trainer = DPOTrainer(
    model=model,
    ref_model=ref_model,
    args=DPOConfig(
        output_dir="./dpo-output",
        num_train_epochs=1,
        per_device_train_batch_size=2,
        gradient_accumulation_steps=8,
        learning_rate=5e-7,
        beta=0.1,        # KL 制約の強さ (0.1〜0.5 が一般的)
        bf16=True,
    ),
    train_dataset=dpo_dataset,
    tokenizer=tokenizer,
)
trainer.train()
```

## Step 3: GRPO (DeepSeek-R1 方式・推論強化)

```python
from trl import GRPOConfig, GRPOTrainer

# 報酬関数を自分で定義 (ルールベース or モデルベース)
def reward_fn(completions, prompts, **kwargs):
    """正解率ベースの報酬関数例"""
    rewards = []
    for completion, prompt in zip(completions, prompts):
        # 数学問題なら正解を確認
        if "answer:" in completion.lower():
            rewards.append(1.0)
        else:
            rewards.append(0.0)
    return rewards

trainer = GRPOTrainer(
    model=model,
    args=GRPOConfig(
        output_dir="./grpo-output",
        num_train_epochs=1,
        per_device_train_batch_size=1,
        gradient_accumulation_steps=16,
        learning_rate=1e-6,
        num_generations=8,   # 1プロンプトあたり生成数
        bf16=True,
    ),
    reward_funcs=reward_fn,
    train_dataset=math_dataset,
    tokenizer=tokenizer,
)
trainer.train()
```

## カスタム DPO データセット作成

```python
# 自社データから DPO データセットを作成
import json

dpo_data = []
for item in company_qa_data:
    dpo_data.append({
        "prompt": item["question"],
        "chosen": item["good_answer"],    # 品質が高い回答
        "rejected": item["bad_answer"],   # 品質が低い回答
    })

with open("company_dpo.jsonl", "w") as f:
    for d in dpo_data:
        f.write(json.dumps(d, ensure_ascii=False) + "\n")
```$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'trl', 'models',
  'TRL 技術詳解 — RLHF/DPO数学・GRPO推論強化・PPO vs DPO比較・最新アルゴリズム動向',
  $## DPO の数学的原理

**DPO の損失関数**:

```
L_DPO(π_θ) = -E[(x,y_w,y_l)~D] [
    log σ(β · log(π_θ(y_w|x) / π_ref(y_w|x))
           - β · log(π_θ(y_l|x) / π_ref(y_l|x)))
]
```

- `y_w`: chosen (好ましい回答)
- `y_l`: rejected (好ましくない回答)
- `β`: KL 制約の強さ (大きいほど ref_model から離れにくい)
- `π_ref`: 参照モデル (SFT 済みの固定モデル)

**直感的理解**:
```
chosen の確率 ↑ → rejected の確率 ↓
ただし ref_model から極端に離れないよう β で制御
```

## PPO vs DPO vs GRPO 比較

| 観点 | PPO | DPO | GRPO |
|------|-----|-----|------|
| **必要モデル数** | 4 (policy/ref/reward/critic) | 2 (policy/ref) | 1 (policy+報酬関数) |
| **安定性** | 不安定 | 安定 | 比較的安定 |
| **計算コスト** | 高 | 中 | 中 |
| **必要データ** | prompt + reward | (chosen,rejected) ペア | prompt + 報酬関数 |
| **推論能力** | 普通 | 普通 | 高い (DeepSeek-R1) |
| **採用例** | 初代ChatGPT | Llama-3-Instruct | DeepSeek-R1 |

## ORPO (Odds Ratio Preference Optimization)

SFT と DPO を 1 ステップに統合:

```
通常パイプライン: SFT (24h) → DPO (12h) = 36h
ORPO パイプライン: ORPO (20h) = 20h (-44% 時間)
```

```python
from trl import ORPOConfig, ORPOTrainer

trainer = ORPOTrainer(
    model=model,
    args=ORPOConfig(
        output_dir="./orpo-output",
        lambda=0.1,  # SFT と DPO のバランス
        beta=0.1,
    ),
    train_dataset=dpo_dataset,
    tokenizer=tokenizer,
)
```

## KTO (Kahneman-Tversky Optimization)

DPO はペアデータ必須。KTO は**単一出力に好き/嫌いラベルだけ**:

```python
# DPO データ: prompt → (chosen, rejected) ペア必要
# KTO データ: prompt + completion + label (True/False) で OK

kto_dataset = [
    {"prompt": "...", "completion": "いい回答", "label": True},
    {"prompt": "...", "completion": "悪い回答", "label": False},
]
```

ペアデータ収集コスト半減。アノテーション効率重視の場合に有効。

## RLHF 実装の完全パイプライン

```
Phase 1: SFT (1〜3 epochs)
  └─ 高品質な instruction-following データで基本能力を習得

Phase 2: Reward Model 学習 (DPO なら不要)
  └─ 人間のフィードバック (chosen/rejected) で好みを学習

Phase 3: PPO または DPO
  └─ Policy を reward に基づいて最適化

Phase 4: 評価
  └─ MT-Bench / AlpacaEval / Arena-Hard でスコア確認
```

## 自分株式会社 推奨 RLHF 戦略

```
予算・時間が限られる場合 → ORPO (1ステップ・低コスト)
品質最優先の場合        → SFT → DPO (実績ある2段階)
推論能力を強化したい場合 → SFT → GRPO (DeepSeek-R1方式)
アノテーションコスト削減 → SFT → KTO (単一ラベルでOK)
```

データ量目安:
- SFT: 5,000〜50,000 件
- DPO/KTO: 1,000〜20,000 ペア/件
- GRPO: 500〜5,000 件 (報酬関数で自動生成可)$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 252→253社化: TRL 追加',
  'PS#3 S79。TRL (Transformer Reinforcement Learning / Hugging Face公式RLHF・DPO・GRPOライブラリ/SFTTrainer/DPOTrainer/GRPOTrainer/PPO/ORPO/KTO/GitHub 10k+/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
