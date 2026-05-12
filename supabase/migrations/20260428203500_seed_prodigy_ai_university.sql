-- PS#3 S104: AI大学 303→304社化 — Prodigy (spaCy/NLP特化ラベリング/アクティブラーニング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'prodigy', 'overview',
  'Prodigy — spaCy/NLP特化ラベリングツール・Active Learning・ローカル実行 (Explosion AI / 9/9)',
  $$## Prodigy とは

**Prodigy** は **spaCy を開発した Explosion AI が作ったNLP特化のデータアノテーションツール**。ローカルで動作する Python パッケージ (サーバー不要)。年間ライセンス制 ($490/年)。スクリプトで完全自動化できる点が最大の特徴。

spaCy との深い統合により、**モデルのトレーニング → 推論結果の確認 → 人間のフィードバック → 再トレーニング** のサイクルを1つのワークフローで回せる。

## Prodigy の設計哲学: 「少ないデータで最高精度を」

```
Prodigy の核心: Active Learning + Binary Choice

  従来のアノテーション:
    全データを網羅的にラベリング → 時間・コスト大

  Prodigy のアプローチ:
    1. モデルが「不確か」なサンプルだけを人間に提示
    2. 人間は「Accept (正しい)」or「Reject (間違い)」の2択
    3. 少ないクリックで最大の精度向上を実現

  → Binary Choice UI: キーボード 1打でラベリング
  → Accept = A キー / Reject = X キー
  → 1時間で 500〜1000 サンプルのラベリングが可能
```

## 多様なアノテーションタイプ

```
Prodigy のビルトインレシピ:

  NLP:
    ・ner.manual / ner.correct — 固有表現認識
    ・textcat.manual / textcat.teach — テキスト分類
    ・rel.manual — 関係抽出
    ・dep.correct — 依存構造

  画像:
    ・image.manual — 画像分類 + バウンディングボックス
    ・image.caption — 画像キャプション生成評価

  音声:
    ・audio.transcribe — 音声書き起こし
    ・audio.manual — 音声分類

  LLM:
    ・openai.ner — GPT で NER 候補生成 → 人間確認
    ・openai.textcat — GPT で分類候補 → 人間確認
    ・choice — 複数選択形式 (RLHF Preference 収集に最適)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 NLP** | レース実況テキストから固有表現を抽出 (馬名/騎手名/コース) | spaCy カスタムモデルの高速構築 |
| **感情分析** | SNS の競馬投稿から感情・意図を分類 | ユーザーセンチメント分析 |
| **LLM 応答評価** | `choice` レシピで RLHF Preference データ収集 | Fine-tuning 用高品質データを少人数で収集 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'prodigy', 'api',
  'Prodigy 実践 — インストール/NERラベリング/テキスト分類/LLM統合/spaCy学習/カスタムレシピ/RLHF',
  $$## インストール & セットアップ

```bash
# ライセンス購入後、pip でインストール
pip install prodigy --extra-index-url https://YOUR_LICENSE_KEY@download.prodi.gy

# 動作確認
python -m prodigy stats
```

## NER (固有表現認識) ラベリング

```bash
# テキストから固有表現を手動でラベリング
python -m prodigy ner.manual horse-racing-ner \
  blank:ja \
  ./data/race_texts.jsonl \
  --label HORSE_NAME,JOCKEY_NAME,RACE_COURSE,DISTANCE

# → http://localhost:8080 でアノテーション UI が開く
# A/X/スペースキーでラベリング
```

```python
# 入力データ形式 (JSONL)
# data/race_texts.jsonl
import json

texts = [
    "シャフリヤールがデムーロ騎手を背に東京競馬場1600mを制した。",
    "タイトルホルダーが横山和生騎手とともに大阪杯2000mで快勝。",
    "イクイノックスが川田将雅騎手で天皇賞秋3200mを圧勝。",
]

with open("./data/race_texts.jsonl", "w", encoding="utf-8") as f:
    for text in texts:
        f.write(json.dumps({"text": text}, ensure_ascii=False) + "\n")
```

## Active Learning: モデルアシストNER

```bash
# 既存 spaCy モデルを使ってアクティブラーニング
python -m prodigy ner.teach horse-racing-ner \
  ja_core_news_lg \
  ./data/race_texts.jsonl \
  --label HORSE_NAME,JOCKEY_NAME

# モデルが不確かなサンプルだけを提示
# → 確信度の低いエンティティ候補を優先的に人間に見せる
```

## テキスト分類ラベリング

```bash
# テキスト分類 (レース結果の感情分析)
python -m prodigy textcat.manual race-sentiment \
  ./data/race_comments.jsonl \
  --label 喜び,失望,中立,怒り
```

```python
# race_comments.jsonl の形式
comments = [
    "1番人気のシャフリヤールが来た！期待通り！",  # 喜び
    "本命が飛んだ...今日も外れた",               # 失望
    "3連複は当たったけど配当が低かった",           # 中立
    "なんで最後の直線で失速するんだ",              # 怒り
]

with open("./data/race_comments.jsonl", "w", encoding="utf-8") as f:
    for text in comments:
        f.write(json.dumps({"text": text}, ensure_ascii=False) + "\n")
```

## LLM 統合: GPT/Claude で候補生成 → 人間確認

```bash
# OpenAI GPT でNER候補を生成 → 人間がAccept/Reject
python -m prodigy openai.ner horse-racing-ner-llm \
  ./data/race_texts.jsonl \
  --lang ja \
  --label HORSE_NAME,JOCKEY_NAME,RACE_COURSE \
  --model gpt-4o
```

```python
# カスタムレシピ: Claude API で候補生成
import prodigy
from prodigy.components.stream import get_stream
import anthropic

@prodigy.recipe(
    "custom.ner.claude",
    dataset=("データセット名", "positional", None, str),
    source=("入力ファイル", "positional", None, str),
)
def custom_ner_claude(dataset, source):
    client = anthropic.Anthropic()
    stream = get_stream(source)

    def add_suggestions(stream):
        for example in stream:
            text = example["text"]

            # Claude で NER 候補を生成
            response = client.messages.create(
                model="claude-haiku-4-5",
                max_tokens=500,
                messages=[{
                    "role": "user",
                    "content": f"""
                    以下のテキストから競馬関連の固有表現を抽出してください。
                    JSON形式で返答: {{"spans": [{{"start": 0, "end": 5, "label": "HORSE_NAME"}}]}}

                    テキスト: {text}
                    """
                }]
            )

            try:
                import json
                spans = json.loads(response.content[0].text)["spans"]
                example["spans"] = spans
            except Exception:
                example["spans"] = []

            yield example

    return {
        "dataset": dataset,
        "stream": add_suggestions(stream),
        "view_id": "ner",
    }
```

## RLHF Preference データ収集

```python
# choice レシピで2つの応答を比較評価
# data/horse_predictions.jsonl

predictions = [
    {
        "text": "どちらの競馬予想説明が優れていますか？",
        "options": [
            {
                "id": "A",
                "text": "シャフリヤールは前走の上がり3ハロン33.2秒という数字が示す通り、末脚の破壊力は出走馬中トップクラス。東京競馬場の直線1000mは末脚型に有利で、本命◎"
            },
            {
                "id": "B",
                "text": "シャフリヤールは強い馬です。今回も期待できます。"
            }
        ]
    }
]

with open("./data/horse_predictions.jsonl", "w", encoding="utf-8") as f:
    for item in predictions:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")
```

```bash
# Preference ラベリング実行
python -m prodigy choice horse-prediction-rlhf \
  ./data/horse_predictions.jsonl \
  --multiple  # 複数選択を許可 (タイも選べる)
```

## spaCy モデルへの学習データエクスポート & 再学習

```python
import prodigy
from prodigy.components.db import connect
import spacy
from spacy.tokens import DocBin

# Prodigy DB からラベルをエクスポート
db = connect()
dataset = db.get_dataset("horse-racing-ner")

print(f"Total annotations: {len(dataset)}")
print(f"Accepted: {sum(1 for d in dataset if d.get('answer') == 'accept')}")

# spaCy 学習用に変換
# spacy convert でフォーマット変換
import subprocess

subprocess.run([
    "python", "-m", "prodigy", "data-to-spacy",
    "./data/spacy_data/",
    "--ner", "horse-racing-ner",
    "--lang", "ja",
    "--eval-split", "0.2"
])

# spaCy で再学習
subprocess.run([
    "python", "-m", "spacy", "train",
    "./config.cfg",
    "--output", "./models/horse_ner_v2/",
    "--paths.train", "./data/spacy_data/train.spacy",
    "--paths.dev", "./data/spacy_data/dev.spacy",
])
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 303→304社化: Prodigy 追加',
  'PS#3 S104。Prodigy (spaCy/NLP特化ラベリング/Active Learning Binary Choice/NER+テキスト分類/LLM統合GPT+Claude/RLHF Preference/音声/画像/カスタムレシピ/年間$490ライセンス/Explosion AI/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
