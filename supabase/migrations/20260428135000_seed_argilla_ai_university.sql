-- PS#3 S92: AI大学 278→279社化 — Argilla (OSS LLM/NLP アノテーション・RLHF データ収集)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'argilla', 'overview',
  'Argilla — OSS LLM/NLPアノテーション・RLHF・Fine-Tuningデータ収集・HuggingFace統合 (GitHub 4k+ / 8/9)',
  $$## Argilla とは

**Argilla** は LLM・NLP モデルの**Fine-Tuning と RLHF 向けデータ収集・アノテーションプラットフォーム**。スペイン発スタートアップ (2021年創業)。Label Studio より LLM 特化、Hugging Face エコシステムとの深い統合が特徴。

GitHub 4,000+ スター。Apache 2.0 ライセンス。2024年 Hugging Face コミュニティと密接に連携し、大規模 OSS データセット作成で広く採用。

## Label Studio との違い

```
Label Studio vs Argilla:

  Label Studio:
    ✓ 汎用ラベリング (画像/音声/動画/テキスト全対応)
    ✓ 幅広い産業ユースケース
    → 「何でもラベリング」ツール

  Argilla:
    ✓ LLM / NLP 特化 (テキスト専門)
    ✓ HuggingFace Hub との直接統合
    ✓ RLHF / DPO / Fine-tuning データ収集に最適化
    ✓ データセット作成→HuggingFace Hub 公開→モデル訓練 のシームレスな流れ
    → 「LLM を育てる」ツール
```

## 主要ユースケース

```
Argilla の 4 大ユースケース:

  1. テキスト分類 (Fine-tuning 用ラベリング)
     → 感情分析/トピック分類/意図分類

  2. LLM 応答評価 (RLHF/DPO データ収集)
     → ランキング (A/B どちらが良い?)
     → レーティング (1〜5 点評価)
     → 批評 (何が悪いか自由記述)

  3. 指示チューニングデータ作成 (SFT)
     → 質問 + 理想的な回答ペアを人間が作成
     → データ品質レビュー・フィルタリング

  4. RAG パイプライン評価
     → 検索結果の関連性評価
     → 回答の事実性チェック
```

## HuggingFace Hub との統合

```python
# Argilla データセットを HuggingFace Hub に直接公開
import argilla as rg

rg.init(api_url="http://localhost:6900", api_key="admin.apikey")

# データセットを HuggingFace Hub からロード
from datasets import load_dataset
hf_dataset = load_dataset("imdb", split="train[:1000]")

# Argilla データセットに変換
rg_dataset = rg.DatasetForTextClassification.from_datasets(
    hf_dataset,
    inputs="text",
    annotation="label",
)
rg.log(rg_dataset, name="imdb-review-labeling")

# アノテーション完了後 HuggingFace Hub に公開
rg_dataset_annotated = rg.load("imdb-review-labeling")
hf_dataset = rg_dataset_annotated.to_datasets()
hf_dataset.push_to_hub("kanta13jp1/jibun-kaisha-sentiment-v3")
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **LLM Fine-tuning** | Claude 応答の品質ラベリング | 日本語特化モデル改善 |
| **RLHF/DPO** | 応答ランキングデータ収集 | 有害・不正確回答を削減 |
| **RAG 評価** | 検索結果の関連性を人手評価 | RAGパイプライン最適化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'argilla', 'api',
  'Argilla 実践 — インストール/FeedbackDataset/RLHF収集/DPO/Fine-tuning/HuggingFace Hub連携/Spaces',
  $$## インストール & 起動

```bash
pip install argilla

# Docker で Argilla Server を起動
docker run -d --name argilla \
  -p 6900:6900 \
  argilla/argilla-quickstart:latest

# Argilla Spaces (HuggingFace 上で無料ホスト)
# → huggingface.co/new-space で Argilla テンプレートを選択
```

## FeedbackDataset: LLM 評価データ収集

```python
import argilla as rg

rg.init(
    api_url="http://localhost:6900",
    api_key="admin.apikey",
)

# LLM 応答評価データセット定義
dataset = rg.FeedbackDataset(
    fields=[
        rg.TextField(name="instruction", title="ユーザーの指示"),
        rg.TextField(name="response", title="AI の応答", use_markdown=True),
        rg.TextField(name="context", title="コンテキスト情報", required=False),
    ],
    questions=[
        # レーティング (1〜5)
        rg.RatingQuestion(
            name="quality",
            title="応答の品質を評価してください",
            values=[1, 2, 3, 4, 5],
            required=True,
        ),
        # ラベル選択 (複数選択可)
        rg.MultiLabelQuestion(
            name="issues",
            title="問題がある場合、該当するものを選んでください",
            labels=[
                "事実誤り",
                "日本語が不自然",
                "有害・不適切な内容",
                "指示に従っていない",
                "冗長すぎる",
                "情報不足",
            ],
            required=False,
        ),
        # 自由記述
        rg.TextQuestion(
            name="correction",
            title="改善した回答を記入してください (任意)",
            required=False,
            use_markdown=True,
        ),
    ],
    guidelines="AIの応答を評価し、問題がある場合は指摘・修正してください。",
)

# データセットを Argilla に追加
dataset.push_to_argilla(name="jibun-kaisha-llm-eval-v1", workspace="default")
```

## レコードの追加 (LLM 出力を評価対象として登録)

```python
import argilla as rg
import anthropic

client = anthropic.Anthropic()

# 評価対象の指示リスト
instructions = [
    "自分株式会社の特徴を200字で説明してください",
    "競合他社と比べた優位性は何ですか？",
    "月額料金を教えてください",
]

records = []
for instruction in instructions:
    # Claude に応答させる
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=300,
        messages=[{"role": "user", "content": instruction}]
    )
    ai_response = response.content[0].text

    # Argilla レコードとして追加
    records.append(
        rg.FeedbackRecord(
            fields={
                "instruction": instruction,
                "response": ai_response,
            },
            metadata={"model": "claude-sonnet-4-6", "date": "2026-04-28"},
        )
    )

# Argilla に一括登録
dataset = rg.FeedbackDataset.from_argilla("jibun-kaisha-llm-eval-v1")
dataset.add_records(records)
print(f"Added {len(records)} records for evaluation")
```

## RLHF/DPO データ収集 (A/B ランキング)

```python
# A/B 応答ランキングデータセット (DPO 用)
dataset = rg.FeedbackDataset(
    fields=[
        rg.TextField(name="instruction", title="指示"),
        rg.TextField(name="response_a", title="応答 A"),
        rg.TextField(name="response_b", title="応答 B"),
    ],
    questions=[
        rg.RankingQuestion(
            name="preference",
            title="より良い応答を選んでください",
            values=["response_a", "response_b"],
            required=True,
        ),
    ],
)
dataset.push_to_argilla(name="jibun-kaisha-dpo-v1")
```

## アノテーション完了後: Fine-tuning データとして出力

```python
# アノテーション済みデータを取得
dataset = rg.FeedbackDataset.from_argilla("jibun-kaisha-llm-eval-v1")

# 高品質なデータ (評価 4-5 点) のみ抽出
hf_dataset = dataset.format_as("datasets")
high_quality = hf_dataset.filter(
    lambda x: x["quality"][0]["value"] >= 4
)

# HuggingFace Hub に公開 → Fine-tuning に使用
high_quality.push_to_hub("kanta13jp1/jibun-kaisha-sft-data-v3")
print(f"Published {len(high_quality)} high-quality samples")

# TRL / PEFT で Fine-tuning
# from trl import SFTTrainer
# trainer = SFTTrainer(model=model, train_dataset=high_quality, ...)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 278→279社化: Argilla 追加',
  'PS#3 S92。Argilla (OSS LLM/NLPアノテーション/FeedbackDataset/RLHF Rating/DPO A-Bランキング/HuggingFace Hub統合/Fine-tuning SFT/Spaces対応/GitHub 4k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
