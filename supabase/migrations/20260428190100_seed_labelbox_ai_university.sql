-- PS#3 S100: AI大学 294→295社化 — Labelbox (エンタープライズデータラベリング/RLHF/品質管理)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'labelbox', 'overview',
  'Labelbox — エンタープライズデータラベリング・RLHF/RLAIF・品質管理・モデルアシスト (8/9)',
  $$## Labelbox とは

**Labelbox** は **エンタープライズ向けデータラベリング・データキュレーションプラットフォーム**。2018年設立の米国スタートアップ (SF)。Fortune 500 企業を含む1,000社以上が採用。RLHF (人間フィードバックによる強化学習) / RLAIF (AI フィードバック) ワークフローに特化した機能を提供。

機械学習モデルの学習データ品質が最終精度を左右するという思想の下、**ラベリング品質管理** と **アノテーター管理** を軸に設計されている。

## Labelbox が解決する問題

```
データラベリングの現実的な課題:

  品質問題:
    ・アノテーターによる表記ゆれ → Inter-annotator Agreement が低下
    ・難しいエッジケースで判断が割れる
    ・大量データで品質チェックが追いつかない

  Labelbox のアプローチ:
    ・Consensus Labeling (複数人で同一データをラベル → 一致率測定)
    ・Benchmark Labels (正解ラベル埋め込み → アノテーター精度をリアルタイム測定)
    ・AI-assisted labeling (モデル予測 → ヒューマンレビュー → 高速化)
    ・Quality Workflow (2段階レビュー / 品質スコアリング)
```

## RLHF / RLAIF ワークフロー

```
LLM ファインチューニングへの活用:

  1. SFT (教師あり微調整) データ収集:
     → Labelbox で応答品質をラベリング
     → 応答を 1-5 段階評価 + 改善コメント

  2. RLHF Preference Data 収集:
     → 2つのモデル応答を並べて「どちらが良いか」を選択
     → Labelbox がランキングデータを自動構造化

  3. RLAIF (AI フィードバック):
     → Claude / GPT-4 が一次評価 → 人間がエッジケース確認
     → コストを 80% 削減しながら品質維持
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想モデル改善** | 予測結果を専門家がラベリング (的中/外れの根拠) | RLHF でモデル精度向上 |
| **UI/UX フィードバック** | スクリーンショット + ユーザー評価をラベリング | 改善優先度の定量化 |
| **チャーン予測モデル** | 正解ラベルが遅延して届くデータのキュレーション | トレーニングデータ品質向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'labelbox', 'api',
  'Labelbox 実践 — Python SDK/プロジェクト作成/ラベリング/エクスポート/RLHF Preference/品質管理',
  $$## インストール & セットアップ

```bash
pip install labelbox
```

```python
import labelbox as lb

# API キーで接続
client = lb.Client(api_key="YOUR_API_KEY")
```

## プロジェクト作成 & データセット登録

```python
import labelbox as lb
from labelbox.data.annotation_types import (
    LabelList, Label, ClassificationAnnotation, Radio
)

client = lb.Client(api_key="YOUR_API_KEY")

# データセット作成
dataset = client.create_dataset(name="horse-race-images")

# 画像をアップロード
data_rows = dataset.create_data_rows([
    {"row_data": "https://example.com/race1.jpg", "global_key": "race_001"},
    {"row_data": "https://example.com/race2.jpg", "global_key": "race_002"},
])

print(f"Dataset ID: {dataset.uid}")
print(f"Uploaded {len(list(dataset.data_rows()))} rows")
```

## オントロジー (ラベル定義) 設定

```python
# オントロジー = ラベルの定義構造
ontology_builder = lb.OntologyBuilder(
    tools=[
        lb.Tool(
            tool=lb.Tool.Type.BBOX,
            name="horse",
            classifications=[
                lb.Classification(
                    class_type=lb.Classification.Type.RADIO,
                    name="horse_number",
                    options=[lb.Option(value=str(i)) for i in range(1, 19)]
                )
            ]
        ),
        lb.Tool(
            tool=lb.Tool.Type.POINT,
            name="finish_line"
        )
    ],
    classifications=[
        lb.Classification(
            class_type=lb.Classification.Type.RADIO,
            name="race_condition",
            options=[
                lb.Option(value="dry"),
                lb.Option(value="wet"),
                lb.Option(value="muddy"),
            ]
        )
    ]
)

ontology = client.create_ontology(
    name="HorseRaceOntology",
    ontology=ontology_builder.asdict()
)

# プロジェクト作成
project = client.create_project(
    name="Horse Detection Project",
    media_type=lb.MediaType.Image,
)
project.setup_editor(ontology)
```

## ラベルのエクスポート

```python
# ラベリング完了後のエクスポート
export_task = project.export(
    params={
        "performance_details": True,
        "label_details": True,
        "data_row_details": True,
    }
)
export_task.wait_till_done()

# NDJSON 形式でストリーム処理
def process_label(label: dict):
    data_row = label["data_row"]
    annotations = label["projects"][project.uid]["labels"]

    for annotation in annotations:
        for obj in annotation.get("annotations", {}).get("objects", []):
            print(f"Object: {obj['name']}, BBox: {obj.get('bounding_box')}")

export_task.get_buffered_stream(stream_type=lb.StreamType.RESULT).start(
    stream_handler=process_label
)
```

## RLHF Preference Data 収集

```python
# 2つのLLM応答を比較してどちらが良いかをラベリング
# Labelbox でオントロジー定義

ontology_rlhf = lb.OntologyBuilder(
    classifications=[
        lb.Classification(
            class_type=lb.Classification.Type.RADIO,
            name="preferred_response",
            options=[
                lb.Option(value="response_a", label="Response A is better"),
                lb.Option(value="response_b", label="Response B is better"),
                lb.Option(value="tie", label="Both are equal"),
                lb.Option(value="both_bad", label="Neither is good"),
            ]
        ),
        lb.Classification(
            class_type=lb.Classification.Type.CHECKLIST,
            name="quality_criteria",
            options=[
                lb.Option(value="helpful"),
                lb.Option(value="harmless"),
                lb.Option(value="honest"),
                lb.Option(value="concise"),
            ]
        )
    ]
)
```

## 品質管理: Consensus Labeling

```python
# 同一データを複数人でラベリング → 一致率を計測
project = client.create_project(
    name="Quality-Control Project",
    media_type=lb.MediaType.Image,
    quality_modes=[
        lb.QualityMode.Benchmark,   # 正解ラベルを埋め込んでアノテーター精度測定
        lb.QualityMode.Consensus,   # 複数人の一致率を測定
    ]
)

# Consensus 設定: 3人中2人が一致したらラベル確定
project.update(
    queue_mode=lb.QueueMode.Batch,
    auto_audit_percentage=0.1,       # 10% を自動監査
    auto_audit_number_of_labels=2    # 2人のラベルで自動判定
)
```

## Catalog でデータキュレーション

```python
# 類似データ検索 (Embedding ベース)
catalog = client.get_catalog()

# 高信頼度サンプルを検索
search_results = catalog.search_data_rows(
    search_query=[
        lb.SearchQuery(
            field="confidence",
            operator=lb.SearchOperator.GREATER_THAN,
            value=0.9
        )
    ],
    limit=100
)

print(f"Found {len(search_results)} high-confidence samples")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 294→295社化: Labelbox 追加',
  'PS#3 S100。Labelbox (エンタープライズデータラベリング/RLHF Preference Data/RLAIF/Consensus Labeling/Benchmark品質管理/オントロジー/Catalog/Python SDK/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
