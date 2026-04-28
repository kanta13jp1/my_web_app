-- PS#3 S103: AI大学 301→302社化 — Kili Technology (エンタープライズラベリング/品質AI/自動化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kili-technology', 'overview',
  'Kili Technology — エンタープライズAIデータラベリング・品質自動化・MLOps統合 (8/9)',
  $$## Kili Technology とは

**Kili Technology** は **エンタープライズ向け AI トレーニングデータ品質プラットフォーム**。2019年設立のフランス・パリのスタートアップ。「AI の品質問題はデータ品質問題」という思想で、**ラベリング品質の自動化と可視化**に特化。

Airbus / Michelin / L'Oréal などのヨーロッパ大企業が採用。GDPR 準拠 (EU データ保護) を前提とした設計が欧州エンタープライズでの採用拡大を支える。GitHub 600+ スター (kili-technology/kili-python-sdk)。

## Kili の特徴: 品質ファーストアプローチ

```
Kili の設計哲学:

  従来のラベリングツールの課題:
    ・アノテーション完了 ≠ 品質確保
    ・間違いに気づくのが学習後 (コスト大)
    ・品質指標が定性的で改善サイクルが回せない

  Kili の解決策:
    1. Quality Review ワークフロー:
       Labeler → Reviewer → QA Manager の3段階
       各段階で品質スコアをリアルタイム計算

    2. Pre-annotations (AI アシスト):
       既存モデルの予測結果を候補として表示
       人間が修正するだけで高速化

    3. Analytics Dashboard:
       ・アノテーター別の精度・スピード・エラー傾向
       ・クラス別のアノテーション難易度ヒートマップ
       ・Inter-Annotator Agreement の時系列変化

    4. API-first 設計:
       全操作が REST API + Python SDK で自動化可能
       MLOps パイプラインへの組み込みが容易
```

## GDPR 対応 (EU エンタープライズ向け)

```
Kili の GDPR 準拠機能:

  ・データ処理契約 (DPA) 自動生成
  ・アノテーター が見るデータを最小化 (必要な属性のみ表示)
  ・忘れられる権利 (データ削除の完全トレーサビリティ)
  ・監査ログ全記録 (誰が / いつ / 何を見て / 何をラベルしたか)
  ・EU データセンターへのデータ保存 (GDPR Article 44)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | Pre-annotations で YOLOv8 候補 → 人間修正 | ラベリング速度 5x 向上 |
| **LLM 品質評価** | 3段階レビューで RLHF データ品質を担保 | 低品質データによるモデル劣化防止 |
| **EU 展開準備** | GDPR 準拠データパイプライン確立 | 将来的な欧州ユーザー獲得に備える |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'kili-technology', 'api',
  'Kili Technology 実践 — Python SDK/プロジェクト/ラベリング/Pre-annotation/品質分析/MLOps統合',
  $$## インストール & セットアップ

```bash
pip install kili
```

```python
from kili.client import Kili

# クライアント初期化
kili = Kili(api_key="YOUR_API_KEY")
```

## プロジェクト作成

```python
from kili.client import Kili

kili = Kili(api_key="YOUR_API_KEY")

# 画像分類プロジェクト作成
project = kili.create_project(
    title="horse-detection",
    description="競馬レース画像の馬検出",
    input_type="IMAGE",  # IMAGE / TEXT / VIDEO / PDF / AUDIO
    json_interface={
        "jobs": {
            "OBJECT_DETECTION_JOB": {
                "content": {
                    "categories": {
                        "HORSE": {
                            "name": "馬",
                            "color": "#FF5733",
                            "children": []
                        },
                        "JOCKEY": {
                            "name": "騎手",
                            "color": "#3498DB",
                            "children": []
                        }
                    },
                    "input": "radio"
                },
                "instruction": "レース内の馬と騎手を全てバウンディングボックスで囲んでください",
                "isChild": False,
                "mlTask": "OBJECT_DETECTION",
                "models": {},
                "required": 1,
                "tools": ["rectangle", "polygon"]
            }
        }
    }
)

project_id = project["id"]
print(f"Project ID: {project_id}")
```

## アセット (画像) アップロード

```python
# URL リストから画像をアップロード
assets = kili.append_many_to_dataset(
    project_id=project_id,
    content_array=[
        "https://example.com/race_001.jpg",
        "https://example.com/race_002.jpg",
        "https://example.com/race_003.jpg",
    ],
    external_id_array=["race_001", "race_002", "race_003"],
    json_metadata_array=[
        {"race_date": "2026-04-28", "race_num": 1},
        {"race_date": "2026-04-28", "race_num": 2},
        {"race_date": "2026-04-28", "race_num": 3},
    ]
)
print(f"Uploaded {len(assets)} assets")
```

## Pre-annotation: AI アシストラベリング

```python
from ultralytics import YOLO
import json

# YOLOv8 でバウンディングボックスを予測
model = YOLO("yolov8n.pt")

def yolo_to_kili_bbox(result, image_width, image_height):
    """YOLOv8 の結果を Kili のフォーマットに変換"""
    annotations = []
    for box in result.boxes:
        x_center, y_center, width, height = box.xywhn[0].tolist()
        cls_id = int(box.cls[0])
        conf = float(box.conf[0])

        # COCO class: 17=horse, 0=person(jockey)
        category = "HORSE" if cls_id == 17 else "JOCKEY"

        annotations.append({
            "type": "rectangle",
            "boundingPoly": [{
                "normalizedVertices": [
                    {"x": x_center - width/2, "y": y_center - height/2},
                    {"x": x_center + width/2, "y": y_center - height/2},
                    {"x": x_center + width/2, "y": y_center + height/2},
                    {"x": x_center - width/2, "y": y_center + height/2},
                ]
            }],
            "categories": [{"name": category, "confidence": conf}],
        })

    return annotations

# Pre-annotation を Kili にアップロード
for external_id, image_url in [
    ("race_001", "https://example.com/race_001.jpg"),
    ("race_002", "https://example.com/race_002.jpg"),
]:
    results = model(image_url)
    annotations = yolo_to_kili_bbox(results[0], 1920, 1080)

    kili.create_predictions(
        project_id=project_id,
        external_id_array=[external_id],
        json_response_array=[{
            "OBJECT_DETECTION_JOB": {
                "annotations": annotations
            }
        }],
        model_name="yolov8n-pretrained"
    )

print("Pre-annotations uploaded successfully")
```

## ラベル取得 & エクスポート

```python
# 完了したラベルを取得
labels = kili.labels(
    project_id=project_id,
    fields=["id", "jsonResponse", "labelType", "createdAt", "author.email"],
    label_type="DEFAULT",  # DEFAULT / REVIEW / PREDICTION
    skip=0,
    first=100
)

for label in labels:
    print(f"Label ID: {label['id']}")
    response = label["jsonResponse"]["OBJECT_DETECTION_JOB"]

    for annotation in response.get("annotations", []):
        category = annotation["categories"][0]["name"]
        bbox = annotation["boundingPoly"][0]["normalizedVertices"]
        print(f"  {category}: {bbox[0]}")

# COCO JSON 形式でエクスポート
# (Kili はエクスポートプラグインを提供)
from kili.plugins import KiliPluginClient

plugin_client = KiliPluginClient(api_key="YOUR_API_KEY")
plugin_client.export(
    project_id=project_id,
    export_format="coco",
    output_file="./exports/horse_detection_coco.json",
    label_types=["DEFAULT"]
)
```

## Analytics: 品質ダッシュボード

```python
# プロジェクト統計取得
stats = kili.count_labels(
    project_id=project_id,
)
print(f"Total labels: {stats}")

# アノテーター別統計
assets = kili.assets(
    project_id=project_id,
    fields=["id", "status", "numberOfValidAssets", "labels.author.email"],
    first=1000
)

from collections import Counter

author_counts = Counter()
for asset in assets:
    for label in asset.get("labels", []):
        author_counts[label["author"]["email"]] += 1

print("\nアノテーター別ラベル数:")
for email, count in author_counts.most_common(10):
    print(f"  {email}: {count} ラベル")
```

## MLOps パイプライン統合

```python
# GHA からラベルを自動取得して YOLOv8 を再学習
# scripts/retrain_with_kili_labels.py

from kili.client import Kili
import yaml
import json
from pathlib import Path

def export_kili_to_yolo(project_id: str, output_dir: str):
    """Kili のラベルを YOLOv8 学習フォーマットに変換"""
    kili = Kili(api_key="YOUR_API_KEY")

    labels = kili.labels(
        project_id=project_id,
        fields=["externalId", "jsonResponse"],
        label_type="DEFAULT",
        first=10000
    )

    output_path = Path(output_dir)
    (output_path / "labels").mkdir(parents=True, exist_ok=True)

    class_map = {"HORSE": 0, "JOCKEY": 1}

    for label in labels:
        ext_id = label["externalId"]
        annotations = label["jsonResponse"]["OBJECT_DETECTION_JOB"]["annotations"]

        yolo_lines = []
        for ann in annotations:
            category = ann["categories"][0]["name"]
            cls_id = class_map.get(category, 0)
            verts = ann["boundingPoly"][0]["normalizedVertices"]

            x_min = min(v["x"] for v in verts)
            x_max = max(v["x"] for v in verts)
            y_min = min(v["y"] for v in verts)
            y_max = max(v["y"] for v in verts)

            x_center = (x_min + x_max) / 2
            y_center = (y_min + y_max) / 2
            width = x_max - x_min
            height = y_max - y_min

            yolo_lines.append(f"{cls_id} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}")

        with open(output_path / "labels" / f"{ext_id}.txt", "w") as f:
            f.write("\n".join(yolo_lines))

    # data.yaml 生成
    data_yaml = {
        "path": str(output_path.absolute()),
        "train": "images/train",
        "val": "images/val",
        "nc": 2,
        "names": ["horse", "jockey"]
    }
    with open(output_path / "data.yaml", "w") as f:
        yaml.dump(data_yaml, f)

    print(f"Exported {len(labels)} labels to YOLO format")

export_kili_to_yolo(project_id="YOUR_PROJECT_ID", output_dir="./data/horse_detection")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 301→302社化: Kili Technology 追加',
  'PS#3 S103。Kili Technology (エンタープライズデータラベリング/3段階品質ワークフロー/Pre-annotation AIアシスト/Analytics Dashboard/GDPR準拠/Python SDK/YOLOv8統合/MLOps統合/GitHub 600+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
