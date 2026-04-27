-- PS#3 S83: AI大学 260→261社化 — Weights & Biases (ML実験管理 / MLOps / wandb)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wandb', 'overview',
  'Weights & Biases (wandb) — ML実験管理・モデルレジストリ・LLMオブザーバビリティの業界標準 (GitHub 9k+ / 8/9)',
  $$## Weights & Biases (wandb) とは

**Weights & Biases** (通称 **wandb**) は ML モデルの**実験管理・可視化・コラボレーション**を提供するプラットフォーム。2017年創業、2024年時点で $250M 調達・評価額 $1.25B のユニコーン。

OpenAI・Google DeepMind・NVIDIA・Microsoft など世界トップの AI 組織が採用する業界標準ツール。

## 4大中核機能

| 機能 | 説明 |
|------|------|
| **Experiments** | loss/accuracy/hyperparameter をリアルタイム可視化 |
| **Artifacts** | データセット・モデル・コードのバージョン管理 |
| **Sweeps** | Bayesian / グリッド / ランダム hyperparameter 最適化 |
| **Reports** | 実験結果をチームで共有できるインタラクティブレポート |

## 2024年の新機能: LLM オブザーバビリティ

```
wandb の進化:
  従来 → ML実験管理 (loss curve / accuracy / hyperparameter)
  現在 → LLM Tracing (プロンプト / レスポンス / トークン消費 / レイテンシ)

Weave (LLMオブザーバビリティ):
  ・LLM アプリのトレースとデバッグ
  ・RAG パイプラインの評価
  ・プロンプトバージョン管理
  ・コスト追跡 (OpenAI / Anthropic / etc.)
```

## モデルレジストリ

```
Artifacts + Registry = エンタープライズ MLOps:

  Training → Log Model → Registry → Staging → Production
                 ↓
            Lineage Tracking
            (どのデータで訓練したか / どの実験か)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **LLM コスト追跡** | Weave で API コスト監視 | 月次 AI コスト 20%削減 |
| **ファインチューニング** | 実験比較でベストモデル特定 | 精度改善サイクル短縮 |
| **チームコラボ** | Reports 共有 | 技術的意思決定の可視化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wandb', 'api',
  'wandb 実践 — init/log/Sweeps/Artifacts/Weave LLMトレース・PyTorch/HuggingFace/LangChain統合',
  $$## インストール

```bash
pip install wandb

# 認証 (APIキー入力)
wandb login

# または環境変数
export WANDB_API_KEY="your-api-key"
```

## 基本: 実験ログ

```python
import wandb
import torch
import torch.nn as nn

# 実験開始 (プロジェクト / 設定 / タグを指定)
run = wandb.init(
    project="jibun-kaisha-nlp",
    config={
        "learning_rate": 1e-4,
        "batch_size": 32,
        "epochs": 10,
        "model": "bert-base-japanese",
    },
    tags=["fine-tuning", "japanese"],
    notes="日本語感情分析モデルの実験",
)

# 訓練ループ
for epoch in range(run.config.epochs):
    train_loss = train_one_epoch(model, optimizer)
    val_loss, val_acc = evaluate(model, val_loader)

    # メトリクスをリアルタイムログ
    wandb.log({
        "epoch": epoch,
        "train/loss": train_loss,
        "val/loss": val_loss,
        "val/accuracy": val_acc,
        "lr": optimizer.param_groups[0]["lr"],
    })

# 実験終了
wandb.finish()
```

## HuggingFace Transformers との統合

```python
from transformers import TrainingArguments, Trainer
import wandb

wandb.init(project="jibun-kaisha-llm", name="llama3-finetune-v1")

training_args = TrainingArguments(
    output_dir="./output",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    learning_rate=2e-5,
    report_to="wandb",          # ← これだけで自動連携
    run_name="llama3-finetune-v1",
    logging_steps=10,
    eval_steps=100,
    save_strategy="epoch",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=train_dataset,
    eval_dataset=eval_dataset,
)

trainer.train()
```

## Hyperparameter Sweep (Bayesian最適化)

```python
import wandb

# Sweep 設定
sweep_config = {
    "method": "bayes",          # bayes / grid / random
    "metric": {"name": "val/loss", "goal": "minimize"},
    "parameters": {
        "learning_rate": {"min": 1e-5, "max": 1e-3, "distribution": "log_uniform_values"},
        "batch_size": {"values": [16, 32, 64]},
        "dropout": {"min": 0.1, "max": 0.5},
        "num_layers": {"values": [2, 4, 6]},
    },
    "early_terminate": {        # パフォーマンス悪い実験を早期打ち切り
        "type": "hyperband",
        "min_iter": 3,
    },
}

# Sweep 作成
sweep_id = wandb.sweep(sweep_config, project="jibun-kaisha-nlp")

def train(config=None):
    with wandb.init(config=config):
        config = wandb.config
        model = build_model(
            num_layers=config.num_layers,
            dropout=config.dropout,
        )
        optimizer = torch.optim.AdamW(model.parameters(), lr=config.learning_rate)
        # ... 訓練 ...
        wandb.log({"val/loss": val_loss})

# Sweep 実行 (10回試行)
wandb.agent(sweep_id, function=train, count=10)
```

## Artifacts: データ・モデルのバージョン管理

```python
# データセットを Artifact として保存
with wandb.init(project="jibun-kaisha-data") as run:
    artifact = wandb.Artifact(
        name="japanese-sentiment-dataset",
        type="dataset",
        description="日本語感情分析データセット v2",
        metadata={"size": 50000, "source": "twitter"},
    )
    artifact.add_dir("./data/")
    run.log_artifact(artifact)

# モデルを Artifact として保存
with wandb.init(project="jibun-kaisha-models") as run:
    model_artifact = wandb.Artifact("bert-japanese-v1", type="model")
    model_artifact.add_file("./output/model.pt")
    run.log_artifact(model_artifact)

# 別の実験で Artifact を再利用
with wandb.init(project="jibun-kaisha-nlp") as run:
    artifact = run.use_artifact("japanese-sentiment-dataset:latest")
    data_dir = artifact.download()
    # → lineage tracking が自動記録される
```

## Weave: LLM トレース (2024年新機能)

```python
import weave
from openai import OpenAI

# Weave 初期化
weave.init("jibun-kaisha-llm-app")

# OpenAI コールを自動トレース
client = OpenAI()

@weave.op()   # ← デコレータで自動ログ
def chat_with_gpt(user_message: str) -> str:
    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": user_message}],
    )
    return response.choices[0].message.content

# 呼び出すだけで自動記録
answer = chat_with_gpt("自分株式会社の競合は？")
# → プロンプト / レスポンス / トークン数 / コスト / レイテンシが wandb に自動保存

# LangChain との統合
from langchain_openai import ChatOpenAI
import weave

weave.init("jibun-kaisha-rag")
llm = ChatOpenAI(model="gpt-4o")

@weave.op()
def rag_pipeline(query: str) -> str:
    contexts = vector_db.search(query)
    return llm.invoke(f"Context: {contexts}\n\nQ: {query}").content
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wandb', 'models',
  'wandb 技術詳解 — MLOps成熟度モデル・Weave評価フレームワーク・エンタープライズ統合・ROI計算',
  $$## MLOps 成熟度モデル (wandb 観点)

```
Level 0 — 手動実験:
  → Excel/Notion でパラメータ記録
  → 再現不可能、スケールしない

Level 1 — wandb 導入:
  → 全実験が自動記録・比較可能
  → チームで共有・再現性確保

Level 2 — Artifacts 活用:
  → データ・モデルのリネージ追跡
  → 「どのデータで何のモデルを作ったか」が一目瞭然

Level 3 — Sweeps 自動化:
  → Bayesian 最適化でベストハイパーパラメータ自動探索
  → 人間の直感より効率的な実験設計

Level 4 — 本番監視:
  → Weave で LLM アプリの品質・コスト・レイテンシ監視
  → 異常検出 → アラート → 対処
```

## wandb vs 競合比較

| ツール | 強み | 弱み |
|--------|------|------|
| **wandb** | UI 優秀 / コミュニティ最大 / LLM Weave | 有料プランが高い |
| **MLflow** | OSS / 完全自己ホスト可 / Databricks 統合 | UI が古い |
| **Comet ML** | 実験再現性 / コスト予測 | シェア小 |
| **Neptune.ai** | 大規模実験管理 | LLM 機能弱い |
| **TensorBoard** | 無料 / TF/PyTorch 標準 | コラボ機能なし |

**選択基準**: チーム開発 + LLM アプリ → wandb / 完全 OSS 要件 → MLflow

## Weave 評価フレームワーク (LLM品質計測)

```python
import weave
from weave import Evaluation

weave.init("jibun-kaisha-eval")

# 評価データセット
questions = [
    {"input": "自分株式会社とは?", "expected": "AIライフマネジメントアプリ"},
    {"input": "競合は何社?", "expected": "21社"},
]

# 評価スコアリング関数
@weave.op()
def answer_quality(model_output: str, expected: str) -> dict:
    from anthropic import Anthropic
    client = Anthropic()

    judge = client.messages.create(
        model="claude-3-5-haiku-latest",
        max_tokens=10,
        messages=[{
            "role": "user",
            "content": f"Expected: {expected}\nActual: {model_output}\nScore (0-1):",
        }]
    )
    score = float(judge.content[0].text.strip())
    return {"quality": score, "correct": score > 0.7}

# 評価実行
evaluation = Evaluation(
    dataset=questions,
    scorers=[answer_quality],
)
results = evaluation.evaluate(my_rag_app)
# → wandb ダッシュボードで結果確認
```

## ROI 計算

```
wandb 投資対効果の試算:

エンジニア 1名が実験管理に費やす時間:
  Before (手動): 2h/週 × 50週 = 100h/年
  After (wandb): 0.2h/週 × 50週 = 10h/年
  削減: 90h/年 × エンジニア単価 ¥5,000/h = ¥450,000/年/人

実験サイクル加速:
  Before: 1実験/週 (設定・実行・記録・比較を手動)
  After:  5実験/週 (Sweeps 自動化 + 比較 UI)
  5倍速化 → 年間実験数 52本 → 260本

モデル性能向上 (Sweeps):
  Bayesian 最適化 → 手動チューニング比 15〜30%精度改善
```

## 自分株式会社 統合計画

```
Phase 1: wandb 導入 (1週間)
  - 既存 training スクリプトに wandb.init + wandb.log 追加
  - チームプロジェクト作成・メンバー招待

Phase 2: Artifacts 活用 (2週間)
  - データセット・モデルを Artifact 管理に移行
  - CI/CD と連携して自動 artifact 登録

Phase 3: LLM 監視 (1ヶ月)
  - Weave で AI 機能全体のトレース
  - コスト・品質ダッシュボード構築
  - 異常検出アラート設定
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 260→261社化: Weights & Biases (wandb) 追加',
  'PS#3 S83。Weights & Biases (ML実験管理/Sweeps Bayesian最適化/Artifacts バージョン管理/Weave LLMトレース/OpenAI+HuggingFace+LangChain統合/評価額$1.25B/GitHub 9k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
