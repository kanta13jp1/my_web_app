-- PS#3 S100: AI大学 295→296社化 — Scale AI (データラベリング/基盤モデル評価/エンタープライズAI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'scale-ai', 'overview',
  'Scale AI — データラベリング・基盤モデル評価・エンタープライズAI加速プラットフォーム (8/9)',
  $$## Scale AI とは

**Scale AI** は **AIモデルの学習データ生成・評価・RLHF ワークフローを提供するプラットフォーム**。2016年設立、Alexandr Wang CEO。評価額 $13.8B (2024)。OpenAI / Meta / Microsoft / US DoD など主要 AI 企業・政府機関が採用。

Scale の核心は **Nucleus** (データ管理) と **Scale RLHF** (人間フィードバック収集) の2軸。**「AIの最後の1マイル = 高品質な人間の判断」**という考え方でエンタープライズ向けに特化。

## Scale AI の位置づけ

```
AI開発における Scale AI の役割:

  基盤モデル開発フェーズ:
    ┌─────────────────────────────────────────────────┐
    │  事前学習データ収集・品質管理 (Web scraping 精製) │
    │  → Scale Data Engine で管理                     │
    └─────────────────────────────────────────────────┘

  ファインチューニングフェーズ:
    ┌─────────────────────────────────────────────────┐
    │  SFT (教師あり) データ生成                       │
    │  RLHF Preference Data 収集                     │
    │  RLAIF ハイブリッドパイプライン                  │
    └─────────────────────────────────────────────────┘

  評価フェーズ (Eval):
    ┌─────────────────────────────────────────────────┐
    │  Scale HELM (ベンチマーク評価)                   │
    │  Red Teaming (安全性・脆弱性検出)                │
    │  Evaluations API (カスタム評価セット)            │
    └─────────────────────────────────────────────────┘
```

## Scale Spellbook (LLM 評価・比較)

```
Scale Spellbook の特徴:

  ・複数 LLM を同一プロンプトで比較評価 (GPT-4 / Claude / Gemini / Llama など)
  ・A/B テスト + 人間評価 + 自動メトリクスの組み合わせ
  ・プロンプトチェーンのテスト (Multi-turn 評価)
  ・本番環境での性能追跡 (Production Eval)

  活用例:
    - モデル切り替え前の品質保証
    - プロンプトエンジニアリングの効果測定
    - 回帰テスト (モデル更新後の性能劣化検知)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **LLM 選定比較** | Claude / Gemini / GPT-4 を同一タスクで評価 | コスト最適なモデル選択 |
| **RLHF データ生成** | 競馬予想説明文の品質ランキングデータ収集 | 説明モデルの改善 |
| **Red Teaming** | AI アシスタントの安全性テスト | 有害応答パターン事前検出 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'scale-ai', 'api',
  'Scale AI 実践 — Tasks API/ラベリング/Nucleus/Evaluations API/RLHF/Red Teaming/Python',
  $$## インストール & セットアップ

```bash
pip install scaleapi
```

```python
import scaleapi

client = scaleapi.ScaleClient("YOUR_API_KEY")
```

## Tasks API: ラベリングタスク作成

```python
import scaleapi
from scaleapi.tasks import TaskType

client = scaleapi.ScaleClient("YOUR_API_KEY")

# 画像分類タスクの作成
task = client.create_task(
    TaskType.ImageAnnotation,
    project="horse-detection",
    callback_url="https://your-app.com/scale-webhook",
    instruction="競馬レース画像内の馬を全てバウンディングボックスで囲み、馬番号を記入してください。",
    attachment="https://example.com/race_image.jpg",
    geometries={
        "box": {
            "objects_to_annotate": ["horse"],
            "min_height": 10,
            "min_width": 10,
        }
    },
    # オプション: 複数アノテーターで品質確保
    params={
        "number_of_assignments": 3,  # 3人でラベリング
    }
)

print(f"Task ID: {task.task_id}")
print(f"Status: {task.status}")
```

## Nucleus: データ管理・スライシング

```python
import nucleus

# Nucleus に接続
client = nucleus.NucleusClient("YOUR_API_KEY")

# データセット作成
dataset = client.create_dataset("horse-races-2026")

# 画像アップロード
dataset.append(
    items=[
        nucleus.DatasetItem(
            image_location="s3://my-bucket/race_001.jpg",
            reference_id="race_001",
            metadata={"date": "2026-04-28", "course": "tokyo", "distance": 1600}
        ),
        nucleus.DatasetItem(
            image_location="s3://my-bucket/race_002.jpg",
            reference_id="race_002",
            metadata={"date": "2026-04-28", "course": "kyoto", "distance": 2000}
        ),
    ]
)

# スライス作成 (東京コースのみ)
tokyo_slice = dataset.create_slice(
    name="tokyo-races",
    reference_ids=[item.reference_id for item in dataset.items
                   if item.metadata.get("course") == "tokyo"]
)

print(f"Tokyo slice: {len(tokyo_slice)} items")
```

## Evaluations API: LLM 評価

```python
import requests
import json

# Scale Evaluations API でモデル応答を評価
API_KEY = "YOUR_API_KEY"

# 評価タスクの作成 (人間評価)
evaluation_task = {
    "project": "llm-eval-jibun-kaisha",
    "instruction": "以下の競馬予想説明を 1-5 で評価してください。\n基準: 1=根拠なし, 3=普通, 5=詳細で説得力あり",
    "responses": [
        {
            "id": "response_a",
            "model": "claude-sonnet-4-6",
            "text": "1番のシャフリヤールは前走の上がり3ハロン33.2秒が示す通り末脚が鋭く、今回の1600m東京では特に有利な展開が見込めます。"
        },
        {
            "id": "response_b",
            "model": "gpt-4o",
            "text": "1番の馬は強そうです。頑張ってほしいです。"
        }
    ],
    "fields": [
        {"field_id": "quality", "type": "rating", "min": 1, "max": 5},
        {"field_id": "factual", "type": "binary", "label": "事実に基づいているか"}
    ]
}

response = requests.post(
    "https://api.scale.com/v1/evaluation_task",
    headers={"Authorization": f"Basic {API_KEY}"},
    json=evaluation_task
)
task = response.json()
print(f"Evaluation Task ID: {task['task_id']}")
```

## RLHF Preference Ranking

```python
# 2つの応答を比較してどちらが好ましいかランク付け
preference_task = client.create_task(
    TaskType.TextCollection,
    project="rlhf-preference",
    callback_url="https://your-app.com/scale-webhook",
    instruction="以下の2つの競馬予想説明を比較し、より有用な方を選んでください。",
    fields=[
        {
            "type": "comparison",
            "field_id": "preference",
            "label": "どちらの説明が優れていますか？",
            "use_markdown": True,
            "choices": [
                {
                    "label": "説明A",
                    "content": "シャフリヤールは前走の上がりタイムから...(詳細な根拠)"
                },
                {
                    "label": "説明B",
                    "content": "シャフリヤールは強いです。"
                }
            ]
        }
    ]
)

print(f"Preference Task: {preference_task.task_id}")
```

## Red Teaming: 安全性テスト

```python
# Scale の Red Teaming タスクで AI の脆弱性検出
red_team_task = client.create_task(
    TaskType.TextCollection,
    project="red-teaming-ai-assistant",
    callback_url="https://your-app.com/scale-webhook",
    instruction="""
    以下のAIアシスタントの応答に対して、
    有害・不適切・バイアスのある応答を引き出せるプロンプトを作成してください。
    発見した脆弱性カテゴリを選択し、具体的な例を提供してください。
    """,
    fields=[
        {
            "type": "dropdown",
            "field_id": "vulnerability_type",
            "label": "脆弱性カテゴリ",
            "choices": [
                "harmful_content",
                "bias",
                "misinformation",
                "privacy_leak",
                "jailbreak",
                "none_found"
            ]
        },
        {
            "type": "text",
            "field_id": "attack_prompt",
            "label": "攻撃プロンプト例"
        }
    ]
)
```

## Webhook 受信 (Task 完了時)

```python
from flask import Flask, request, jsonify
import scaleapi

app = Flask(__name__)
client = scaleapi.ScaleClient("YOUR_API_KEY")

@app.route("/scale-webhook", methods=["POST"])
def scale_webhook():
    task_data = request.json

    task = client.get_task(task_data["task_id"])

    if task.status == "completed":
        # アノテーション結果を処理
        response = task.response

        # Nucleus に結果をアップロード
        # → 学習データとして活用
        print(f"Task {task.task_id} completed: {response}")

    return jsonify({"status": "ok"})
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 295→296社化: Scale AI 追加',
  'PS#3 S100。Scale AI (データラベリング/RLHF Preference Data/Red Teaming/Nucleus データ管理/Evaluations API/Scale Spellbook LLM比較/Tasks API/Python SDK/$13.8B評価額/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
