-- PS#3 S93: AI大学 280→281社化 — Snorkel AI (プログラマティック弱教師あり学習 / ラベリング自動化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'snorkel-ai', 'overview',
  'Snorkel AI — プログラマティック弱教師あり学習・ラベリング関数・データ拡張・スタンフォード発 (GitHub 5k+ / 8/9)',
  $$## Snorkel AI とは

**Snorkel** はスタンフォード大学 AI Lab 発のプログラマティック機械学習フレームワーク。**弱教師あり学習 (Weak Supervision)** を使い、**人手ラベリングなしで大量のトレーニングデータを自動生成**する手法を提供。

GitHub 5,000+ スター。Apache 2.0 ライセンス。Snorkel AI 社 (2019年創業) が商用化。Stanford NLP・Google・Intel 等での採用実績。

## 弱教師あり学習の革新

```
従来のアプローチ (コスト大):
  データ 10 万件 → 人間が 10 万件を手動ラベリング
  → 時間: 数週間〜数ヶ月
  → コスト: 数百万円〜

Snorkel のアプローチ:
  データ 10 万件 → Labeling Functions (LF) を数十個書く
  → LF がルールベースで自動ラベリング
  → Label Model が複数 LF の衝突・ノイズを解消
  → 弱ラベル付きデータ 10 万件が完成
  → 時間: 数時間
  → コスト: ほぼゼロ
```

## 核心概念: Labeling Functions (LF)

```python
from snorkel.labeling import labeling_function

# ラベル定数
NEGATIVE = 0
POSITIVE = 1
ABSTAIN = -1   # 判定できない場合

# LF1: キーワードベース
@labeling_function()
def lf_keyword_positive(x):
    positive_words = ["素晴らしい", "最高", "便利", "おすすめ", "使いやすい"]
    return POSITIVE if any(w in x.text for w in positive_words) else ABSTAIN

# LF2: 否定キーワード
@labeling_function()
def lf_keyword_negative(x):
    negative_words = ["最悪", "使えない", "バグ", "遅い", "高い", "不満"]
    return NEGATIVE if any(w in x.text for w in negative_words) else ABSTAIN

# LF3: テキスト長 (短すぎるものは判定困難)
@labeling_function()
def lf_short_text(x):
    return ABSTAIN if len(x.text) < 20 else ABSTAIN

# LF4: 絵文字ベース
@labeling_function()
def lf_emoji_positive(x):
    return POSITIVE if any(e in x.text for e in ["😊", "👍", "✨", "❤"]) else ABSTAIN

# LF5: LLM を使った LF (高精度)
@labeling_function()
def lf_claude_classify(x):
    import anthropic
    client = anthropic.Anthropic()
    response = client.messages.create(
        model="claude-haiku-4-5",
        max_tokens=5,
        messages=[{
            "role": "user",
            "content": f"positive/negative/abstainの1語で答えてください: {x.text[:100]}"
        }]
    )
    result = response.content[0].text.strip().lower()
    if "positive" in result:
        return POSITIVE
    elif "negative" in result:
        return NEGATIVE
    return ABSTAIN
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **感情分析** | ユーザーレビューを LF で自動ラベリング | 手動ラベリング工数 90% 削減 |
| **コンテンツ分類** | 記事カテゴリを LF で自動付与 | 大規模分類データを低コスト作成 |
| **スパム検出** | ルール × モデル × LLM の LF 組み合わせ | 偽陰性・偽陽性を段階的削減 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'snorkel-ai', 'api',
  'Snorkel AI 実践 — LabelingFunction/LabelModel/Applier/スライス/データ拡張/TF統合/Fine-tuning',
  $$## インストール & セットアップ

```bash
pip install snorkel

# GPU 環境 (大規模データ向け)
pip install snorkel[torch]
```

## Label Model: LF の統合と学習

```python
import pandas as pd
from snorkel.labeling import PandasLFApplier, LFAnalysis
from snorkel.labeling.model import LabelModel

# データロード
df = pd.read_parquet("./data/jibun-kaisha-reviews.parquet")

# LF を適用 (各レコードに各 LF の出力を記録)
lfs = [
    lf_keyword_positive,
    lf_keyword_negative,
    lf_short_text,
    lf_emoji_positive,
    lf_claude_classify,
]

applier = PandasLFApplier(lfs=lfs)
L_train = applier.apply(df=df)

# LF の品質分析
analysis = LFAnalysis(L=L_train, lfs=lfs)
print(analysis.lf_summary())
# Coverage  Conflicts  Overlaps  Accuracy
# lf_keyword_positive  0.35   0.12     0.18     —
# lf_keyword_negative  0.28   0.09     0.14     —
# lf_claude_classify   0.87   0.04     0.61     —

# Label Model: 複数 LF の衝突・ノイズを解消して最終ラベルを生成
label_model = LabelModel(cardinality=2, verbose=True)
label_model.fit(L_train=L_train, n_epochs=500, lr=0.001, seed=42)

# 確率付きラベルを生成
probs_train = label_model.predict_proba(L=L_train)
preds_train = label_model.predict(L=L_train, tie_break_policy="abstain")
print(f"Labeled samples: {(preds_train != -1).sum()} / {len(preds_train)}")
```

## Fine-tuning 用データとして出力

```python
from snorkel.utils import probs_to_preds
import numpy as np

# 高信頼度サンプルのみフィルタリング (確率 > 0.8)
max_probs = probs_train.max(axis=1)
high_confidence_mask = max_probs > 0.8

df_filtered = df[high_confidence_mask].copy()
df_filtered["label"] = preds_train[high_confidence_mask]

print(f"High-confidence samples: {len(df_filtered)}")
print(df_filtered["label"].value_counts())

# HuggingFace で Fine-tuning
from datasets import Dataset

dataset = Dataset.from_pandas(df_filtered[["text", "label"]])

from transformers import AutoModelForSequenceClassification, TrainingArguments, Trainer

model = AutoModelForSequenceClassification.from_pretrained(
    "cl-tohoku/bert-base-japanese", num_labels=2
)

training_args = TrainingArguments(
    output_dir="./results",
    num_train_epochs=3,
    per_device_train_batch_size=32,
    evaluation_strategy="epoch",
)

trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
)
trainer.train()
```

## スライス: 重要サブグループの分析

```python
from snorkel.slicing import slicing_function, PandasSFApplier, SliceAwareClassifier

# スライス関数 (重要な部分集合を定義)
@slicing_function()
def sf_short_review(x):
    """短いレビュー (20字以下) は特に難しい"""
    return len(x.text) <= 20

@slicing_function()
def sf_contains_emoji(x):
    """絵文字含みレビュー"""
    return any(e in x.text for e in ["😊", "😡", "👍", "👎"])

sfs = [sf_short_review, sf_contains_emoji]
slice_applier = PandasSFApplier(slicing_functions=sfs)
S_train = slice_applier.apply(df=df_filtered)

# スライス認識モデル (サブグループの精度を重点強化)
slice_model = SliceAwareClassifier(
    base_architecture=model,
    head_weights={"sf_short_review": 2.0, "sf_contains_emoji": 1.5},
)
```

## データ拡張: 学習データを人工的に増やす

```python
from snorkel.augmentation import transformation_function, PandasTFApplier, RandomPolicy

@transformation_function()
def tf_swap_words(x):
    """ランダムに単語をシャッフル (データ拡張)"""
    import random
    words = x.text.split()
    if len(words) < 4:
        return None
    i, j = random.sample(range(len(words)), 2)
    words[i], words[j] = words[j], words[i]
    x.text = " ".join(words)
    return x

@transformation_function()
def tf_abbreviate(x):
    """一部の単語を省略形に変換"""
    x.text = x.text.replace("ありがとうございます", "ありがとう")
    x.text = x.text.replace("よろしくお願いします", "よろしく")
    return x

tfs = [tf_swap_words, tf_abbreviate]
policy = RandomPolicy(len(tfs), sequence_length=2, n_per_original=5, keep_original=True)
tf_applier = PandasTFApplier(tfs, policy)

df_augmented = tf_applier.apply(df=df_filtered)
print(f"Augmented: {len(df_augmented)} samples (original: {len(df_filtered)})")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 280→281社化: Snorkel AI 追加',
  'PS#3 S93。Snorkel AI (弱教師あり学習/Labeling Functions/Label Model/PandasLFApplier/スライス/データ拡張/Fine-tuning統合/スタンフォード発/GitHub 5k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
