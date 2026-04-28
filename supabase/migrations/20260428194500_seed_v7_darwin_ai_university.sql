-- PS#3 S101: AI大学 297→298社化 — V7 Darwin (モデルアシストアノテーション/Auto-Annotate/LLM評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'v7-darwin', 'overview',
  'V7 Darwin — モデルアシストアノテーション・Auto-Label・LLM評価・データエンジン (8/9)',
  $$## V7 Darwin とは

**V7 Darwin** は **AI モデルを使って自動でアノテーションを生成し、人間のレビューで精度を高めるデータエンジン**。英国 V7 Labs 社が開発 (2018年設立)。コンピュータービジョン特化で始まり、現在は LLM データ収集・評価にも拡張。

GitHub Stars 3k+ (v7-labs/darwin-py)。「**Auto-Label**」機能が最大の特徴で、Segment Anything Model (SAM) / Grounding DINO / CLIP などの基盤モデルをワンクリックで呼び出して候補アノテーションを生成する。

## Auto-Label: ワンクリックで基盤モデルを呼び出し

```
V7 Darwin の Auto-Label フロー:

  1. 画像をアップロード
  2. Auto-Label ボタン → 複数基盤モデルを並列実行:
     ・SAM (Segment Anything Model) → セグメンテーションマスク生成
     ・Grounding DINO → テキストプロンプトで物体検出
       ("horse running" → 馬を自動検出)
     ・CLIP → 画像-テキスト類似度で分類候補提示
  3. 生成された候補を人間がレビュー → 承認 / 修正 / 却下
  4. 修正データでモデルを継続改善 (Active Learning ループ)
```

## Workflow Builder: ノーコードパイプライン

```
V7 Darwin の Workflow 機能:

  ノードを繋ぐだけでラベリングパイプラインを構築:

  Dataset → [Auto-Label (AI)] → [Review] → [QA] → Export

  各ノードのカスタマイズ:
    ・Auto-Label: どのモデルを使うか / 信頼度閾値
    ・Review: 担当者割り当て / SLA 設定
    ・QA: サンプリング率 / 不一致時のルーティング
    ・Export: COCO / YOLO / Pascal VOC / CSV
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | SAM で馬の輪郭を自動セグメント → 人間がレビュー | ラベリング時間 70% 削減 |
| **LLM 応答評価** | 競馬予想テキストの品質を複数観点でタグ付け | Fine-tuning 用高品質データ収集 |
| **Active Learning** | 低信頼度サンプルを自動抽出 → 優先ラベリング | 少ないデータで最大精度向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'v7-darwin', 'api',
  'V7 Darwin 実践 — darwin-py SDK/データセット/アノテーション/Auto-Label/エクスポート/LLMデータ収集',
  $$## インストール & セットアップ

```bash
pip install darwin-py
```

```python
import darwin

# クライアント初期化
client = darwin.Client.local()   # ~/.darwin/config.yaml を読み込む
# または
client = darwin.Client(api_key="YOUR_API_KEY")
```

## データセット作成 & 画像アップロード

```python
import darwin
from pathlib import Path

client = darwin.Client(api_key="YOUR_API_KEY")

# データセット作成
dataset = client.create_dataset("horse-detection")
print(f"Dataset: {dataset.slug}")

# ローカル画像をアップロード
dataset.push(
    files=[Path("./race_images/race_001.jpg"), Path("./race_images/race_002.jpg")],
    path="/"  # データセット内のフォルダ
)

# フォルダごと一括アップロード
import glob
image_files = [Path(p) for p in glob.glob("./race_images/*.jpg")]
dataset.push(files=image_files, path="/batch_001")
```

## アノテーションクラス定義

```python
# JSON 形式でクラスを定義
annotation_classes = [
    {
        "name": "horse",
        "annotation_types": ["bounding_box", "polygon", "keypoint"],
        "metadata": {"color": "#FF5733"},
        "annotation_group": "objects",
    },
    {
        "name": "jockey",
        "annotation_types": ["bounding_box"],
        "metadata": {"color": "#3498DB"},
        "annotation_group": "objects",
    },
    {
        "name": "horse_number",
        "annotation_types": ["tag"],
        "metadata": {"color": "#2ECC71"},
        "annotation_group": "tags",
    }
]

# API 経由でクラス作成 (darwin-py v2 では REST API 直接呼び出し)
import requests

headers = {"Authorization": f"ApiKey YOUR_API_KEY", "Content-Type": "application/json"}

for cls in annotation_classes:
    response = requests.post(
        f"https://darwin.v7labs.com/api/v2/teams/YOUR_TEAM/annotation_classes",
        headers=headers,
        json=cls
    )
    print(f"Created class: {cls['name']} → {response.status_code}")
```

## darwin-py でアノテーション読み込み & 処理

```python
import darwin.datatypes as dt
from darwin.dataset.utils import get_annotations

# データセット取得
client = darwin.Client(api_key="YOUR_API_KEY")
dataset = client.get_remote_dataset("YOUR_TEAM/horse-detection")

# ローカルにダウンロード (darwin JSON 形式)
dataset.pull(filters={"statuses": ["complete"]})

# アノテーションを解析
for annotation_file in dataset.local_annotations:
    for annotation in annotation_file.annotations:
        if isinstance(annotation, dt.BoundingBox):
            print(
                f"Image: {annotation_file.filename}, "
                f"Class: {annotation.name}, "
                f"BBox: x={annotation.bounding_box.x:.0f}, y={annotation.bounding_box.y:.0f}, "
                f"w={annotation.bounding_box.w:.0f}, h={annotation.bounding_box.h:.0f}"
            )
        elif isinstance(annotation, dt.Polygon):
            print(f"Image: {annotation_file.filename}, Polygon with {len(annotation.paths[0])} points")
```

## エクスポート (YOLO / COCO 形式)

```python
# YOLOv8 形式でエクスポート
dataset.export(
    annotation_format="yolo_darknet",  # or "coco", "pascal_voc", "csv"
    include_url=True,
    outdir="./exports/yolo/"
)

# COCO JSON 形式
dataset.export(
    annotation_format="coco",
    outdir="./exports/coco/"
)

print("エクスポート完了 — YOLOv8 学習に使用可能")
```

## LLM 評価データ収集 (Text プロジェクト)

```python
# V7 Darwin の Text アノテーション機能
# テキスト → カテゴリ分類 / エンティティ認識

text_annotations = [
    {
        "filename": "response_001.txt",
        "text": "シャフリヤールは前走の上がり3ハロン33.2秒が示す通り末脚が鋭く...",
        "annotations": [
            {
                "name": "quality",
                "ranges": [],  # テキスト全体にタグ
                "tag_value": "high_quality"
            },
            {
                "name": "factual_accuracy",
                "ranges": [[0, 30]],  # テキストの範囲指定でエンティティ
                "tag_value": "verified"
            }
        ]
    }
]

# REST API でアノテーションをアップロード
for item in text_annotations:
    response = requests.put(
        f"https://darwin.v7labs.com/api/v2/teams/YOUR_TEAM/items/{item['filename']}/annotations",
        headers=headers,
        json={"annotations": item["annotations"]}
    )
    print(f"Uploaded annotation for {item['filename']}: {response.status_code}")
```

## Active Learning: 低信頼度サンプルの自動抽出

```python
# モデル推論結果の信頼度でサンプルを優先順位付け
# (V7 Darwin の Workflows で GUI 設定も可能)

import numpy as np

def prioritize_for_labeling(inference_results: list[dict]) -> list[dict]:
    """信頼度が低いサンプルを優先的にラベリングキューに追加"""
    # 信頼度でソート (低い順 = 不確かなものを優先)
    sorted_results = sorted(
        inference_results,
        key=lambda x: x.get("confidence", 1.0)
    )

    # 信頼度 0.7 未満のサンプルを抽出
    uncertain_samples = [
        r for r in sorted_results
        if r.get("confidence", 1.0) < 0.7
    ]

    print(f"優先ラベリング対象: {len(uncertain_samples)} / {len(inference_results)} サンプル")
    return uncertain_samples

# 使用例
inference_results = [
    {"image": "race_001.jpg", "confidence": 0.95, "class": "horse"},
    {"image": "race_002.jpg", "confidence": 0.42, "class": "horse"},  # 不確か
    {"image": "race_003.jpg", "confidence": 0.61, "class": "jockey"}, # 不確か
]

priority_queue = prioritize_for_labeling(inference_results)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 297→298社化: V7 Darwin 追加',
  'PS#3 S101。V7 Darwin (モデルアシストアノテーション/Auto-Label SAM+Grounding DINO/Workflow Builder/darwin-py SDK/YOLO+COCO エクスポート/LLM評価データ/Active Learning/GitHub 3k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
