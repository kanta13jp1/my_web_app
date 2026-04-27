-- PS#3 S78: AI大学 251→252社化 — Axolotl

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'axolotl', 'overview',
  'Axolotl — YAML設定でLLMファインチューニングを民主化するOSSフレームワーク (GitHub 9k+ / QLoRA+LoRA+FSDP / 8/9)',
  $## Axolotl とは

**Axolotl** は YAML 設定ファイル 1つで大規模言語モデルのファインチューニングを完結させる OSS フレームワーク。複雑なトレーニングコードを書かずに、設定ファイルを書くだけで QLoRA / LoRA / Full Fine-tuning / FSDP / DeepSpeed を使い分けられる。

## 特徴的な機能

| 機能 | 説明 |
|------|------|
| **YAML 設定** | トレーニング全体をYAMLで記述 / コード不要 |
| **マルチ手法対応** | QLoRA・LoRA・Full FT・FSDP・DeepSpeed |
| **マルチ GPU** | DDP・FSDP・DeepSpeed ZeRO-2/3 |
| **データセット形式** | alpaca / sharegpt / completion / instruct など多数 |
| **Flash Attention 2** | 高速化・VRAM削減 |
| **Hugging Face 統合** | Hub からのモデル/データセット直接読込 |
| **WandB 統合** | トレーニング進捗リアルタイム可視化 |
| **サンプリング戦略** | データセット比率・重み付きサンプリング |

## ポジション

```
設定難易度:   難 ←──────────────── 易
              Transformers > LLaMA-Factory > Unsloth > Axolotl
速度:         遅 ←──────────────── 速
              Transformers < LLaMA-Factory < Axolotl ≈ Unsloth
柔軟性:       低 ←──────────────── 高
              Unsloth < Axolotl < Transformers
```

Axolotl は **「速度と柔軟性のバランス」** で最も評価される。

## 対応モデル

- Llama 2 / 3 / 3.1 / 3.2 / 3.3
- Mistral / Mixtral
- Phi-2 / Phi-3
- Gemma / Gemma 2
- Qwen / Qwen 2.5
- Falcon / MPT / BLOOM
- Code Llama / DeepSeek Coder
- 事実上すべての Hugging Face Transformers 互換モデル

## ライセンス・コミュニティ

- **ライセンス**: Apache 2.0 (商用利用可)
- **GitHub**: 9,000+ Stars / 1,200+ Forks
- **Discord**: アクティブなコミュニティ
- **メンテナ**: Wing Lian (原作者) + コミュニティ

## 自分株式会社での活用シーン

| シーン | 活用方法 |
|--------|----------|
| **カスタム AI キャラ** | 自社ドキュメントで LLM をファインチューニング |
| **日本語特化** | 日本語データで llama-3-8b を QLoRA 調整 |
| **コスト削減** | OpenAI API 依存からローカル推論へ移行 |
| **プライバシー** | 社内データを外部 API に送らず学習可能 |$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'axolotl', 'api',
  'Axolotl 実践 — YAML設定ファイルでQLoRAファインチューニング完全ガイド',
  $## インストール

```bash
# pip インストール (GPU環境必須)
pip install axolotl[flash-attn,deepspeed]

# または Docker (推奨)
docker run --gpus all -it winglian/axolotl:main-latest
```

## 基本的な YAML 設定ファイル

```yaml
# config.yml — Llama-3-8B QLoRA ファインチューニング例
base_model: meta-llama/Meta-Llama-3-8B
model_type: LlamaForCausalLM
tokenizer_type: AutoTokenizer

# データセット設定
datasets:
  - path: tatsu-lab/alpaca  # Hugging Face データセット
    type: alpaca
  # ローカルファイルも可
  # - path: ./data/my_dataset.jsonl
  #   type: sharegpt

# データセット処理
dataset_prepared_path: last_run_prepared
val_set_size: 0.02
sequence_len: 4096
sample_packing: true  # Flash Attention 2 との組み合わせで高速化

# モデル出力
output_dir: ./outputs/my-model

# QLoRA 設定
adapter: qlora
lora_r: 32         # ランク (8/16/32/64)
lora_alpha: 16     # スケーリング係数
lora_dropout: 0.05
lora_target_modules:
  - q_proj
  - k_proj
  - v_proj
  - o_proj
  - gate_proj
  - up_proj
  - down_proj

# 量子化 (QLoRA)
load_in_4bit: true
gptq: false

# トレーニング設定
gradient_accumulation_steps: 4
micro_batch_size: 2
num_epochs: 3
optimizer: paged_adamw_8bit
lr_scheduler: cosine
learning_rate: 0.0002
train_on_inputs: false  # 入力部分を損失計算から除外

# Flash Attention 2
flash_attention: true

# 混合精度
bf16: auto  # bf16 対応 GPU なら自動で bf16
fp16: false

# WandB ログ
wandb_project: my-finetune
wandb_run_id: axolotl-llama3-qlora
```

## トレーニング実行

```bash
# 単一 GPU
accelerate launch -m axolotl.cli.train config.yml

# マルチ GPU (DDP)
accelerate launch --multi_gpu -m axolotl.cli.train config.yml

# FSDP (大規模モデル)
accelerate launch --fsdp "full_shard" -m axolotl.cli.train config.yml

# DeepSpeed ZeRO-3
accelerate launch --deepspeed deepspeed_configs/zero3.json \
  -m axolotl.cli.train config.yml
```

## データセット形式

```python
# Alpaca 形式 (JSON Lines)
{"instruction": "日本語で要約して", "input": "長文テキスト...", "output": "要約テキスト"}

# ShareGPT 形式 (マルチターン会話)
{
  "conversations": [
    {"from": "human", "value": "質問内容"},
    {"from": "gpt", "value": "回答内容"},
    {"from": "human", "value": "フォローアップ"},
    {"from": "gpt", "value": "続きの回答"}
  ]
}

# Completion 形式 (テキスト続き予測)
{"text": "プロンプト + 回答の完全なテキスト"}
```

## 推論テスト

```bash
# トレーニング後の推論テスト
python -m axolotl.cli.inference config.yml \
  --lora_model_dir ./outputs/my-model \
  --gradio  # Gradio UI で対話テスト
```

## GGUF 変換・Ollama デプロイ

```bash
# HuggingFace → GGUF 変換
python llama.cpp/convert_hf_to_gguf.py ./outputs/my-model \
  --outfile my-model-q4_k_m.gguf \
  --outtype q4_K_M

# Ollama でインポート
cat > Modelfile << 'EOF'
FROM ./my-model-q4_k_m.gguf
SYSTEM "あなたは自分株式会社のAIアシスタントです。"
EOF
ollama create my-custom-model -f Modelfile
ollama run my-custom-model
```

## 自分株式会社 実践設定

```yaml
# jibun-kaisha-japanese.yml
base_model: llm-jp/llm-jp-3-3.7b  # 日本語特化モデル
adapter: qlora
lora_r: 64

datasets:
  - path: ./data/jibun_docs.jsonl
    type: alpaca

# A100 40GB 以下で動作
micro_batch_size: 4
gradient_accumulation_steps: 8
bf16: true
flash_attention: true
```$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'axolotl', 'models',
  'Axolotl 技術詳解 — FSDP/DeepSpeed/Flash Attention2統合とファインチューニング手法比較',
  $## サポートするファインチューニング手法

| 手法 | VRAM目安 | 速度 | 品質 | 用途 |
|------|----------|------|------|------|
| **Full Fine-tuning** | 80GB+ | 遅い | 最高 | 大規模計算クラスタ |
| **LoRA** | 24GB+ | 普通 | 高い | RTX 3090/4090 |
| **QLoRA (4bit)** | 8-16GB | 普通 | 高い | RTX 3080/4080 |
| **QLoRA+Flash Attn** | 6-12GB | 速い | 高い | RTX 3070+ (推奨) |
| **QLoRA+Sample Pack** | 6GB | 最速 | 高い | Google Colab A100 |

## FSDP (Fully Sharded Data Parallel)

```yaml
# FSDP 設定例 (70B モデルに有効)
fsdp:
  - full_shard
  - auto_wrap

fsdp_config:
  fsdp_offload_params: true  # CPU オフロード
  fsdp_state_dict_type: FULL_STATE_DICT
  fsdp_transformer_layer_cls_to_wrap: LlamaDecoderLayer
```

FSDP はモデルパラメータを複数 GPU に分散。70B モデルを 4x A100 80GB で学習可能。

## DeepSpeed ZeRO 段階別戦略

```
ZeRO-1: Optimizer State を分散 → VRAM ~30% 削減
ZeRO-2: + Gradient を分散    → VRAM ~50% 削減
ZeRO-3: + Parameter を分散   → VRAM ~70% 削減 (推奨: 大規模モデル)
```

```yaml
# ZeRO-3 設定
deepspeed: deepspeed_configs/zero3.json
# axolotl 付属のテンプレートを使用
```

## Flash Attention 2 の効果

```
通常 Attention:   O(n²) メモリ / O(n²) 時間
Flash Attention 2: O(n) メモリ / O(n) 時間

sequence_len=4096 での比較:
- 標準:         VRAM 22GB
- Flash Attn 2: VRAM 14GB (-36%)
- + sample_packing: スループット 2.5x 向上
```

## Sample Packing の仕組み

```
通常トレーニング:
[短いサンプル___________PAD_PAD_PAD]  ← PAD で無駄
[中程度サンプル_____PAD_PAD_PAD_PAD]
[長いサンプル_______________________]

Sample Packing:
[短い1][短い2][短い3][中程度1][EOF]  ← GPU 効率 100%
```

`sample_packing: true` で有効化。スループット最大 3x 向上。

## LoRA ランク選択ガイド

| タスク | 推奨 rank | 推奨 alpha |
|--------|-----------|------------|
| 一般会話 | r=8 | alpha=16 |
| コード生成 | r=16 | alpha=32 |
| 特定ドメイン | r=32 | alpha=64 |
| スタイル転移 | r=64 | alpha=128 |
| キャラクター | r=128 | alpha=256 |

ルール: `alpha = rank × 2` が出発点。増やすと学習率に相当。

## Axolotl vs Unsloth 使い分け

| 観点 | Axolotl | Unsloth |
|------|---------|---------|
| **設定方法** | YAML ファイル | Python スクリプト |
| **マルチ GPU** | ◎ FSDP/DeepSpeed | △ 基本単一GPU |
| **速度** | ○ Flash Attn 2 | ◎ Triton カーネル |
| **VRAM削減** | ○ QLoRA+Flash Attn | ◎ 独自最適化 |
| **柔軟性** | ◎ 全手法対応 | ○ LoRA/QLoRA 特化 |
| **コード量** | ◎ 不要 | △ Python 必要 |

**結論**: チームでの大規模学習 → Axolotl / 個人Colab高速実験 → Unsloth

## 自分株式会社 推奨パイプライン

```
1. データ収集: 自社ドキュメント/チャット履歴 → ShareGPT 形式変換
2. 実験: Google Colab + Axolotl (QLoRA r=16)
3. 本格学習: RunPod A100 + Axolotl (FSDP)
4. 変換: GGUF Q4_K_M
5. デプロイ: Ollama or LM Studio (ローカル) or vLLM (API)
6. 評価: LM-Eval-Harness で自動評価
```$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 251→252社化: Axolotl 追加',
  'PS#3 S78。Axolotl (YAML設定LLMファインチューニング/QLoRA+LoRA+FSDP+DeepSpeed/Flash Attention2/Sample Packing/GitHub 9k+/Apache 2.0/Hugging Face統合/WandB統合/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
