-- PS#3 S78: AI大学 250→251社化 — Unsloth 追加
-- Unsloth: 高速LLMファインチューニング / VRAM 80%削減 / 2-5倍高速 / GitHub 25k+ / QLoRA/LoRA / Daniel Han作

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'unsloth',
  'overview',
  'Unsloth — 高速LLMファインチューニング (VRAM 80%削減 / 2-5倍高速 / GitHub 25k+ / QLoRA/LoRA / 無料)',
  $$## Unsloth — Ultra-Fast LLM Fine-tuning

**カテゴリ**: LLM Fine-tuning / MLOps / Open Source / GPU Optimization
**開発者**: Daniel Han + Michael Han (兄弟 / オーストラリア)
**設立**: 2023年末
**ライセンス**: Apache 2.0 (Community版) / 商用ライセンス (Pro版)
**GitHub**: github.com/unslothai/unsloth (25,000+ スター)
**対応モデル**: Llama 3 / Mistral / Gemma / Phi / Qwen / Falcon / その他多数
**対応手法**: QLoRA / LoRA / フル ファインチューニング
**評価**: 9/9

### 概要
Unsloth は **「LLMのファインチューニングを2〜5倍高速化し、VRAMを最大80%削減する」** Python ライブラリ。2024年に登場して以来、コスト効率の高いLLMカスタマイズツールとして爆発的に普及。Google Colab の無料GPUでも 7B〜13B モデルのファインチューニングが可能になった。

**なぜ速いか**: PyTorch の自動微分を回避し、**Triton カーネルによるカスタム CUDA 実装** でバックワードパス (勾配計算) を最適化。さらに QLoRA (4bit量子化 + LoRA) と組み合わせることでVRAM消費を劇的に削減。

**日本での普及**: Zenn・Qiita での解説記事が急増中。「ChatGPT を自社データで学習させたい」という需要に応える最もコスト効率の高い手段として注目。

### 通常のファインチューニングとの比較

```
[VRAM 使用量比較 (Llama 3 8B QLoRA ファインチューニング)]

方法                    VRAM    速度        コスト
---------------------------------------------------
フル (FP16)            80GB+   基準        A100×4 必要
PyTorch + QLoRA        24GB    基準        A100×1 必要
Unsloth + QLoRA        8GB     2.2倍速     RTX 4080 で可能
Unsloth (Colab)        6GB     2.2倍速     Google Colab 無料で可能

→ Unsloth を使えば「月数万円のGPUクラウド代」が
  「無料の Google Colab」で代替可能
```

### 対応モデル (2025年時点)

| モデルファミリー | 対応バージョン |
|------------|------------|
| Llama (Meta) | Llama 3.1 / 3.2 / 3.3 |
| Mistral / Mixtral | v0.1〜最新 |
| Gemma (Google) | Gemma 2 (2B/9B/27B) |
| Phi (Microsoft) | Phi-3 Mini/Medium/Small |
| Qwen (Alibaba) | Qwen 2.5 全サイズ |
| DeepSeek | DeepSeek-R1 / V3 |
| CodeLlama | 7B/13B/34B |
| TinyLlama | 1.1B |

### LoRA vs QLoRA vs Unsloth QLoRA

```
[ファインチューニング手法の比較]

フル ファインチューニング:
  全パラメータを更新 → 最高精度 / 最大VRAM / 最高コスト
  7Bモデル → FP16 で 60〜80GB VRAM

LoRA (Low-Rank Adaptation):
  重み行列に低ランク行列を追加学習
  → 全パラメータの1〜5% のみ更新
  → VRAM 削減 (でも普通のLoRAはまだ大きい)

QLoRA (Quantized LoRA, Tim Dettmers 2023):
  ベースモデルを4bit量子化 → VRAMをさらに削減
  → 6〜8GB で 7Bモデルをファインチューニング可能

Unsloth QLoRA:
  QLoRAの手法 + Tritonカーネル最適化
  → QLoRAより さらに 2〜5倍高速
  → VRAMは同等かやや少ない
  → 精度損失なし (同じQLoRAの結果と同等)
```

### Unsloth の最適化技術

```
[技術的な高速化の仕組み]

1. Triton カーネル (カスタムCUDA)
   通常: PyTorch の自動微分 → 汎用的だが非効率
   Unsloth: 各演算のバックワードパスをカスタム実装
   → 不要なメモリコピーを削減 / 演算を fusion

2. Flash Attention 2 統合
   通常の Attention: O(N²) メモリ
   Flash Attention: O(N) メモリ / 高速
   → Unsloth は Flash Attention 2 をデフォルトで統合

3. RoPE (Rotary Position Embedding) 最適化
   ロングコンテキスト (8K〜128K) でのメモリ効率を改善
   → 長い会話履歴でのファインチューニングが現実的に

4. Gradient Checkpointing の最適化
   通常: 中間活性化を全部保存 → メモリ大
   Unsloth: 必要な部分のみ再計算 → VRAM大幅削減
```

### 代表的なユースケース

```
1. 日本語特化モデルの作成
   ベース: Llama 3.1 8B or Qwen 2.5 7B
   データ: 日本語コーパス / 社内文書
   → 日本語応答精度を大幅向上

2. 業務特化チャットボット
   データ: 自社FAQ / 製品マニュアル / 過去の問い合わせ
   → Instruction Tuning で業務知識を持つLLMを構築

3. コード生成モデル
   データ: 社内コードベース / APIリファレンス
   → 自社固有のコーディングスタイルを学習

4. 医療・法律特化モデル (ローカル実行前提)
   機密データをクラウドLLMに送らずにカスタマイズ
```

### 自分株式会社での活用可能性
```
現在: OpenAI API を使用 → 汎用モデル
将来: Unsloth で自社データをファインチューニング
  → 自分株式会社のライフマネジメントコンテキストを理解するLLM
  → 「どんなユーザーがどんな悩みを持ちやすいか」を学習
  → CS自動返信の精度を大幅向上 / コスト削減

AI大学コンテンツとしての価値:
  「Google ColabでLLMをファインチューニングする入門ガイド」
  「Unslothで自社データを学習させたAIアシスタントを作る方法」
  日本でも「自社LLMを作りたい」ニーズは高まっており、
  低コストで実現できる Unsloth の解説記事は高い検索需要$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'unsloth',
  'api',
  'Unsloth API — Python実装 / QLoRA学習コード / Alpaca形式データ準備 / Supabase EF統合',
  $$## Unsloth 実装ガイド

### インストール
```bash
pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
pip install --no-deps trl peft accelerate bitsandbytes

# CUDA環境によって異なる場合
pip install unsloth
```

### QLoRA ファインチューニング 完全コード
```python
from unsloth import FastLanguageModel
from trl import SFTTrainer
from transformers import TrainingArguments
from datasets import load_dataset
import torch

# ==================== 1. モデルロード ====================
MAX_SEQ_LENGTH = 2048
DTYPE = None           # None = 自動検出 (Float16 or BFloat16)
LOAD_IN_4BIT = True    # QLoRA: 4bit量子化

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/llama-3-8b-Instruct",
    max_seq_length=MAX_SEQ_LENGTH,
    dtype=DTYPE,
    load_in_4bit=LOAD_IN_4BIT,
)

# ==================== 2. LoRA アダプター追加 ====================
model = FastLanguageModel.get_peft_model(
    model,
    r=16,                   # LoRAランク (8〜64、高いほど高精度/VRAM大)
    target_modules=[        # LoRAを適用するレイヤー
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",  # Unsloth最適化版
    random_state=3407,
)

# ==================== 3. データ準備 (Alpaca形式) ====================
ALPACA_TEMPLATE = """以下は指示とオプションの入力です。適切な応答を生成してください。

### 指示:
{}

### 入力:
{}

### 応答:
{}"""

def format_prompts(examples):
    instructions = examples["instruction"]
    inputs = examples.get("input", [""] * len(instructions))
    outputs = examples["output"]

    texts = []
    for inst, inp, out in zip(instructions, inputs, outputs):
        text = ALPACA_TEMPLATE.format(inst, inp, out) + tokenizer.eos_token
        texts.append(text)
    return {"text": texts}

# Supabase からファインチューニングデータを取得する例
import requests
import json

def load_finetuning_data_from_supabase(
    supabase_url: str,
    supabase_key: str,
    table: str = "finetuning_examples",
) -> list[dict]:
    """Supabase からファインチューニング用データを取得"""
    resp = requests.get(
        f"{supabase_url}/rest/v1/{table}",
        headers={
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
        },
        params={"select": "instruction,input,output", "limit": 10000},
    )
    return resp.json()

# HuggingFace データセットを使う場合
dataset = load_dataset("json", data_files="training_data.jsonl", split="train")
dataset = dataset.map(format_prompts, batched=True)

# ==================== 4. トレーナー設定 ====================
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=MAX_SEQ_LENGTH,
    dataset_num_proc=2,
    packing=False,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        num_train_epochs=3,
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=10,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir="outputs",
    ),
)

# ==================== 5. 学習実行 ====================
trainer_stats = trainer.train()
print(f"学習時間: {trainer_stats.metrics['train_runtime']:.2f}秒")
print(f"Peak VRAM: {torch.cuda.max_memory_reserved() / 1e9:.2f}GB")

# ==================== 6. 推論テスト ====================
FastLanguageModel.for_inference(model)  # 推論モードに切り替え (2倍速)

inputs = tokenizer(
    [ALPACA_TEMPLATE.format("自分株式会社のAI大学について説明して", "", "")],
    return_tensors="pt",
).to("cuda")

outputs = model.generate(**inputs, max_new_tokens=256, temperature=0.7)
print(tokenizer.decode(outputs[0], skip_special_tokens=True))

# ==================== 7. モデル保存 ====================
# LoRAアダプターのみ保存 (小さい)
model.save_pretrained("lora_model")
tokenizer.save_pretrained("lora_model")

# GGUF形式で保存 (Ollama/LM Studio で使える)
model.save_pretrained_gguf("gguf_model", tokenizer, quantization_method="q4_k_m")
```

### Google Colab での実行 (無料GPU)
```python
# Colab ノートブックの先頭セル
# ランタイム → T4 GPU を選択

!pip install "unsloth[colab-new] @ git+https://github.com/unslothai/unsloth.git"
!pip install --no-deps trl peft accelerate bitsandbytes

# VRAM 確認
import torch
print(f"GPU: {torch.cuda.get_device_name(0)}")
print(f"VRAM: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB")
# → GPU: Tesla T4 / VRAM: 15.8GB
# → Llama 3 8B QLoRA なら十分!
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'unsloth',
  'models',
  'Unsloth 技術詳細 — Tritonカーネル最適化 / QLoRAの数学 / GGUF変換 / LoRA vs フルFT判断基準',
  $$## Unsloth 技術詳細

### Triton カーネル最適化の仕組み

```
[なぜ標準 PyTorch より速いか]

標準 PyTorch の自動微分:
  順伝播: Linear(x) = W × x
  逆伝播: 自動微分 → dL/dW を計算
  → 各演算でメモリを確保・解放 → オーバーヘッド大

Unsloth の Triton カーネル:
  1. 複数演算を融合 (kernel fusion)
     例: LayerNorm + 活性化関数 → 1つのカーネルで実行
     → CUDA カーネル起動回数を削減 → レイテンシ削減

  2. カスタム逆伝播
     ReLU / SiLU / SwiGLU の逆伝播を手動実装
     → 不要な中間テンソルを保存しない
     → VRAM 使用量を削減

  3. RoPE の最適化
     通常: sin/cos テーブルをFP32で計算 → キャスト
     Unsloth: BF16で直接計算 → VRAM削減 + 速度向上
```

### QLoRA の数学

```
[QLoRA = Quantization + LoRA]

ステップ1: ベースモデルの量子化 (NF4 形式)
  FP16 (16bit) → NF4 (4bit)
  FP16: 65,536通りの値
  NF4: 「正規分布に最適化された16通りの値」
  → 正規分布に従うニューラルネットの重みに最適

ステップ2: Double Quantization
  量子化定数 (scale factor) も量子化
  → さらに約0.5bit/パラメータを削減

ステップ3: LoRA アダプター学習 (FP16)
  固定: 量子化済みベースモデル (4bit)
  学習: LoRAアダプター W = W0 + α/r × BA (FP16)
  → バックワードパスは高精度のまま

ステップ4: Paged Optimizers
  Adam Optimizer の状態をCPU RAMに退避
  → VRAM 不足時に自動でCPUとやりとり
  → GPUメモリ上限を超えた学習が可能
```

### ファインチューニング種類別の選択指針

```
[タスク別推奨設定]

1. チャットボット / 指示追従 (Instruction Tuning)
   手法: QLoRA / LoRA
   データ形式: Alpaca (instruction, input, output)
   r=16, lora_alpha=16, epochs=3
   → 最も一般的なユースケース

2. 継続事前学習 (Domain Adaptation)
   手法: フル ファインチューニング or LoRA r=64
   データ形式: 生テキスト (pretraining形式)
   → 専門分野の語彙・知識を大量に学習

3. DPO (Direct Preference Optimization)
   手法: Unsloth + TRL DPOTrainer
   データ形式: (prompt, chosen, rejected)
   → RLHF代替 / 人間の好みに合わせる

4. コード特化
   手法: QLoRA
   データ形式: (instruction, code)
   → 社内コーディング規約を学習

適切なLoRAランク (r) の選択:
  r=4:  最小限のパラメータ / 高速 / 精度低
  r=8:  バランス良好 (推奨出発点)
  r=16: 多くのタスクに最適
  r=32: 複雑なタスク / 多様なドメイン
  r=64: フルファインチューニングに近い精度
```

### GGUF 変換とデプロイ

```python
# LoRA学習後 → GGUF変換 → Ollama/LM Studio で実行

# Q4_K_M 量子化 (推奨バランス)
model.save_pretrained_gguf(
    "my_custom_model",
    tokenizer,
    quantization_method="q4_k_m",
)
# → my_custom_model/model-Q4_K_M.gguf が生成

# Ollama でカスタムモデルとして登録
# Modelfile を作成:
with open("Modelfile", "w") as f:
    f.write("FROM ./my_custom_model/model-Q4_K_M.gguf\n")
    f.write('SYSTEM "あなたは自分株式会社のAIアシスタントです。"\n')

# ollama create my-custom-model -f Modelfile
# ollama run my-custom-model
```

### 自分株式会社との関連性

```
具体的な活用ロードマップ:

Phase 1 (現在): OpenAI API (汎用GPT-4o-mini)
  コスト: $0.00015/1K tokens
  品質: 汎用的 / 自分株式会社コンテキスト理解は弱い

Phase 2 (近中期): Unsloth でカスタマイズ
  対象: Llama 3.1 8B or Qwen 2.5 7B (日本語強)
  データ: Supabase の CSチケット・FAQ・ユーザー行動ログ
  結果: 自分株式会社特化の高精度応答 + ローカル実行でコストゼロ

Phase 3 (長期 / IPO後): 大規模カスタムモデル
  MosaicAI / Databricks でフル学習
  自分株式会社の全ユーザーデータから最適なLLMを作成

AI大学コンテンツとしての価値:
  「ゼロからLLMをファインチューニングする完全ガイド (Unsloth + Colab)」
  「GPT-4の代わりに自社データで学習したLLMを使う方法」
  → 実用的・コスト削減直結 → 高い検索需要
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 250→251社化: Unsloth 追加',
  'PS#3 S78。Unsloth (高速LLMファインチューニング/VRAM 80%削減/2-5倍高速/Tritonカーネル/QLoRA/LoRA/GitHub 25k+/Google Colab無料GPU対応/GGUF変換/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
