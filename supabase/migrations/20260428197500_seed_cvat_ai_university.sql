-- PS#3 S102: AI大学 299→300社化 — CVAT (OSSアノテーションツール/Intel製/自動アノテーション)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cvat', 'overview',
  'CVAT — OSS コンピュータービジョンアノテーションツール・Intel製・セルフホスト可能 (GitHub 11k+ / 9/9)',
  $$## CVAT とは

**CVAT (Computer Vision Annotation Tool)** は **Intel が開発したオープンソースのコンピュータービジョンアノテーションツール**。GitHub 11,000+ スター。Apache 2.0 ライセンスで完全無料 + セルフホスト可能。Docker Compose でローカル環境に構築でき、データをクラウドに送らずプライバシーを守ったままラベリングが可能。

**CVAT.ai** (マネージドクラウド) + **CVAT OSS** (セルフホスト) の2形態。Waymo / Apple / Samsung など大企業でも採用実績あり。

## CVAT の特徴

```
他ツールとの差別化:

  無料 & セルフホスト:
    ・Docker Compose 1コマンドで構築
    ・データが外部に出ない (医療/金融/機密データに最適)
    ・ユーザー数無制限 (SaaS は per-seat 料金がかかる)

  豊富なアノテーション形式:
    ・バウンディングボックス / ポリゴン / ポリライン / 点群
    ・セグメンテーションマスク (インスタンス / パノプティック)
    ・3D ポイントクラウド (自動運転向け)
    ・動画トラッキング (フレーム間の物体追跡)

  自動アノテーション:
    ・nuclio (サーバーレス) で DL モデルをアタッチ
    ・Mask R-CNN / YOLOv8 / SAM を API として登録
    ・1クリックでモデル推論 → アノテーション候補生成
```

## CVAT API: プログラマティック操作

```
CVAT REST API でできること:

  ・タスク / プロジェクト作成
  ・画像 / 動画のアップロード
  ・アノテーションのエクスポート (COCO / YOLO / Pascal VOC / CVAT XML)
  ・ユーザー管理 / ロール割り当て
  ・自動アノテーションモデルの登録 (nuclio 経由)

  → CI/CD パイプラインへの組み込みも可能
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | セルフホスト CVAT で馬画像をラベリング | データプライバシー確保 + 無料運用 |
| **動画トラッキング** | レース動画で馬の位置をフレーム追跡 | 手動トラッキング不要の自動化 |
| **CI/CD 統合** | GHA から CVAT API でアノテーションを自動エクスポート | 学習パイプラインの完全自動化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cvat', 'api',
  'CVAT 実践 — Docker構築/REST API/cvat-sdk/タスク/アノテーション/自動アノテーション/エクスポート/GHA統合',
  $$## セットアップ (Docker Compose)

```bash
# CVAT をローカルにセットアップ
git clone https://github.com/opencv/cvat
cd cvat

# デフォルト設定で起動 (http://localhost:8080)
docker compose up -d

# スーパーユーザー作成
docker exec -it cvat_server bash
python manage.py createsuperuser

# → ブラウザで http://localhost:8080 にアクセス
```

## Python SDK (cvat-sdk) セットアップ

```bash
pip install cvat-sdk
```

```python
from cvat_sdk import make_client
from cvat_sdk.models import TaskWriteRequest, DataMetaWrite

# クライアント作成
client = make_client(
    host="http://localhost:8080",
    credentials=("admin", "password")
)
```

## タスク作成 & 画像アップロード

```python
from cvat_sdk import make_client
from cvat_sdk.models import TaskWriteRequest, LabelRequest
from pathlib import Path

client = make_client(host="http://localhost:8080", credentials=("admin", "password"))

# タスク作成 (ラベル定義込み)
task_spec = TaskWriteRequest(
    name="horse-detection-batch-01",
    labels=[
        LabelRequest(name="horse", color="#FF5733"),
        LabelRequest(name="jockey", color="#3498DB"),
        LabelRequest(
            name="horse_number",
            color="#2ECC71",
            attributes=[
                {"name": "value", "mutable": False, "input_type": "number",
                 "default_value": "1", "values": [str(i) for i in range(1, 19)]}
            ]
        )
    ]
)

task = client.tasks.create(spec=task_spec)
print(f"Task ID: {task.id}")

# 画像アップロード
image_files = list(Path("./race_images/").glob("*.jpg"))
task.upload_data(
    resources=image_files,
    data_params={"image_quality": 95}
)
print(f"Uploaded {len(image_files)} images")
```

## アノテーションのエクスポート

```python
# COCO 形式でエクスポート
task_id = 1

# エクスポートジョブを開始
client.tasks.export_dataset(
    id=task_id,
    format="COCO 1.0",  # or "YOLO 1.1", "Pascal VOC 1.1", "CVAT for images 1.1"
    filename="./exports/horse_detection_coco.zip",
    include_images=True
)
print("エクスポート完了: ./exports/horse_detection_coco.zip")

# ZIP を解凍して COCO JSON を読み込み
import zipfile
import json

with zipfile.ZipFile("./exports/horse_detection_coco.zip") as z:
    z.extractall("./exports/coco/")

with open("./exports/coco/annotations/instances_default.json") as f:
    coco = json.load(f)

print(f"Images: {len(coco['images'])}")
print(f"Annotations: {len(coco['annotations'])}")
print(f"Categories: {[c['name'] for c in coco['categories']]}")
```

## REST API 直接利用 (GHA CI/CD 統合)

```python
import requests

BASE_URL = "http://localhost:8080/api"
AUTH = ("admin", "password")

# タスク一覧取得
tasks = requests.get(f"{BASE_URL}/tasks/", auth=AUTH).json()
print(f"Total tasks: {tasks['count']}")

# 完了済みアノテーションをエクスポート (GHA から実行可能)
def export_annotations(task_id: int, format_name: str = "COCO 1.0") -> bytes:
    """GHA CI から呼び出してアノテーションを自動エクスポート"""
    # エクスポートリクエスト
    export_url = f"{BASE_URL}/tasks/{task_id}/dataset/"
    params = {"format": format_name, "action": "download"}

    response = requests.get(export_url, params=params, auth=AUTH)

    if response.status_code == 202:
        # 非同期処理中 → ポーリング
        import time
        while response.status_code == 202:
            time.sleep(2)
            response = requests.get(export_url, params=params, auth=AUTH)

    return response.content

# 使用例
annotations_zip = export_annotations(task_id=1)
with open("./annotations.zip", "wb") as f:
    f.write(annotations_zip)
```

## 自動アノテーション (nuclio + YOLOv8 統合)

```bash
# nuclio でサーバーレス自動アノテーション関数をデプロイ
# YOLOv8 を CVAT の自動アノテーション機能として登録

cd cvat/serverless/pytorch/ultralytics/yolov8/nuclio

# function.yaml を編集してモデルパスを設定
# デプロイ
nuctl deploy --project-name cvat \
  --path . \
  --platform local

# → CVAT UI から "Run Auto Annotation" でワンクリック推論
```

```python
# Python から自動アノテーションを実行
auto_annotation_job = requests.post(
    f"{BASE_URL}/tasks/{task_id}/auto_annotation/",
    auth=AUTH,
    json={
        "function": {
            "id": "pth-ultralytics-yolov8-det",
        },
        "mapping": {
            "horse": [{"value": "horse", "attribute_values": {}}],
            "person": [{"value": "jockey", "attribute_values": {}}],
        },
        "cleanup": False,  # 既存のアノテーションを保持
    }
)
print(f"Auto-annotation job: {auto_annotation_job.json()}")
```

## GHA ワークフローへの組み込み

```yaml
# .github/workflows/retrain-with-new-labels.yml
name: CVAT Export & Retrain

on:
  schedule:
    - cron: '0 2 * * 1'   # 毎週月曜 AM2:00

jobs:
  export-and-retrain:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Export CVAT Annotations
        run: |
          python scripts/export_cvat_annotations.py \
            --task-id ${{ vars.CVAT_TASK_ID }} \
            --format "COCO 1.0" \
            --output ./data/annotations.zip

      - name: Train YOLOv8
        run: |
          pip install ultralytics
          yolo train \
            data=./data/horse_detection.yaml \
            model=yolov8n.pt \
            epochs=50 \
            imgsz=640

      - name: Upload Model to S3
        run: |
          aws s3 cp ./runs/detect/train/weights/best.pt \
            s3://my-bucket/models/horse_detector_latest.pt
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 299→300社化: CVAT 追加 (記念300社達成)',
  'PS#3 S102。CVAT (Intel OSS/セルフホスト Docker/REST API/cvat-sdk/COCO+YOLO+Pascal VOCエクスポート/nuclio自動アノテーション/YOLOv8統合/動画トラッキング/GHA CI統合/GitHub 11k+/Apache 2.0/9/9) を ai_university_content に追加。AI大学300社達成マイルストーン。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
