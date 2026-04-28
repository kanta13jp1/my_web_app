-- PS#3 S105: AI大学 304→305社化 — Segments.ai (セマンティックセグメンテーション特化/3Dシーン)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'segments-ai', 'overview',
  'Segments.ai — セマンティックセグメンテーション特化・3Dシーンラベリング・Python SDK (8/9)',
  $$## Segments.ai とは

**Segments.ai** は **セマンティックセグメンテーション・インスタンスセグメンテーション・3Dシーンのラベリングに特化したデータアノテーションプラットフォーム**。ベルギー発のスタートアップ。自動運転 / ロボティクス / 医療画像 AI の開発で採用が多い。

GitHub 300+ スター (segments-ai/segments-python)。**キューブ注釈** (3D バウンディングボックス) と **点群セグメンテーション** のサポートが他ツールより充実しており、自動運転データセット構築での利用実績が高い。

## セグメンテーション特化の強み

```
Segments.ai が得意とするアノテーション:

  2D セグメンテーション:
    ・Semantic Segmentation — ピクセルごとにクラスを割り当て
    ・Instance Segmentation — 同一クラスの個別インスタンスを区別
    ・Panoptic Segmentation — Semantic + Instance を統合
    ・SAM (Segment Anything Model) との統合で自動マスク生成

  3D / LiDAR:
    ・点群セグメンテーション (Velodyne / Livox 形式)
    ・3D バウンディングボックス (自動車 / 歩行者 / 自転車)
    ・カメラ-LiDAR フュージョン (2D + 3D の同期ラベリング)

  動画:
    ・フレーム間のセグメントを自動伝播 (Propagation)
    ・物体追跡 (Tracking) との統合
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV** | 馬・騎手・フェンス・芝生をセマンティックセグメンテーション | バウンディングボックスより高精度な検出モデル構築 |
| **コース解析** | 競馬場のコース画像をゾーン別にセグメンテーション | ゲートからゴールまでの空間分析 |
| **医療 AI** | MRI / CT のセグメンテーション (将来的な医療 × 健康機能) | 高精度な臓器・病変検出モデル |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'segments-ai', 'api',
  'Segments.ai 実践 — Python SDK/データセット/セグメンテーション/SAM統合/3D点群/エクスポート',
  $$## インストール & セットアップ

```bash
pip install segments-python
```

```python
from segments import SegmentsClient

# API キーで接続
client = SegmentsClient("YOUR_API_KEY")
```

## データセット作成 & 画像アップロード

```python
from segments import SegmentsClient
import json

client = SegmentsClient("YOUR_API_KEY")

# データセット作成 (セマンティックセグメンテーション)
dataset = client.add_dataset(
    name="jibun-kaisha/horse-segmentation",
    task_type="segmentation-bitmap",  # or "segmentation-polygon", "pointcloud-cuboid"
    category="image",
    description="競馬レース画像のセマンティックセグメンテーション",
    task_attributes={
        "format_version": "0.1",
        "categories": [
            {"id": 1, "name": "horse", "color": [255, 87, 51]},
            {"id": 2, "name": "jockey", "color": [52, 152, 219]},
            {"id": 3, "name": "track", "color": [46, 204, 113]},
            {"id": 4, "name": "fence", "color": [155, 89, 182]},
            {"id": 5, "name": "crowd", "color": [241, 196, 15]},
        ]
    }
)

print(f"Dataset created: {dataset.full_name}")

# 画像アップロード
import requests
from pathlib import Path

for image_path in Path("./race_images/").glob("*.jpg"):
    with open(image_path, "rb") as f:
        asset = client.upload_asset(dataset.full_name, f, image_path.name)

    sample = client.add_sample(
        dataset=dataset.full_name,
        name=image_path.name,
        attributes={"image": {"url": asset.url}},
        metadata={"source": "local_upload", "race_date": "2026-04-29"}
    )
    print(f"Uploaded: {sample.uuid}")
```

## セグメンテーションアノテーション取得

```python
from segments import SegmentsClient
import numpy as np
from PIL import Image
import io

client = SegmentsClient("YOUR_API_KEY")
dataset_name = "jibun-kaisha/horse-segmentation"

# サンプル一覧
samples = client.get_samples(dataset_name)

for sample in samples:
    if sample.labels.get("ground-truth"):
        label = client.get_label(sample.uuid, labelset="ground-truth")
        annotations = label.attributes.get("annotations", [])

        print(f"\nSample: {sample.name}")
        for ann in annotations:
            print(f"  Category: {ann['category_id']}, "
                  f"Segments: {len(ann.get('segments', []))}")

        # セグメンテーションビットマップを取得
        bitmap_url = label.attributes.get("segmentation_bitmap", {}).get("url")
        if bitmap_url:
            response = requests.get(bitmap_url)
            bitmap = Image.open(io.BytesIO(response.content))
            bitmap_array = np.array(bitmap)
            print(f"  Bitmap shape: {bitmap_array.shape}")
```

## SAM (Segment Anything Model) 統合

```python
# Segments.ai の UI では SAM を使って1クリックでマスク生成
# API でも SAM 推論結果をアップロード可能

from segments import SegmentsClient
from segment_anything import sam_model_registry, SamPredictor
import numpy as np
import torch
import requests
from PIL import Image
import io

client = SegmentsClient("YOUR_API_KEY")

# SAM モデルロード
sam = sam_model_registry["vit_h"](checkpoint="./sam_vit_h_4b8939.pth")
predictor = SamPredictor(sam)

def generate_sam_masks(image_url: str) -> list[dict]:
    """SAM で自動セグメンテーションを生成"""
    response = requests.get(image_url)
    image = Image.open(io.BytesIO(response.content)).convert("RGB")
    image_np = np.array(image)

    predictor.set_image(image_np)

    # 画像全体を自動セグメンテーション
    from segment_anything import SamAutomaticMaskGenerator
    mask_generator = SamAutomaticMaskGenerator(sam)
    masks = mask_generator.generate(image_np)

    return masks

# SAM の結果を Segments.ai にアップロード
sample = client.get_sample("jibun-kaisha/horse-segmentation", "race_001.jpg")
masks = generate_sam_masks(sample.attributes["image"]["url"])

print(f"SAM generated {len(masks)} masks")
# → Segments.ai UI でレビュー & 修正
```

## COCO / Cityscapes 形式エクスポート

```python
from segments import SegmentsClient
from segments.utils import export_dataset

client = SegmentsClient("YOUR_API_KEY")

# COCO Panoptic 形式でエクスポート
export_dataset(
    client=client,
    dataset_identifier="jibun-kaisha/horse-segmentation",
    export_format="coco-panoptic",  # or "coco-instance", "semantic-png", "yolov8"
    export_folder="./exports/coco/",
    labelset="ground-truth",
    release_tag="v1.0"  # バージョンタグ
)

# PNG マスク形式 (Cityscapes 互換)
export_dataset(
    client=client,
    dataset_identifier="jibun-kaisha/horse-segmentation",
    export_format="semantic-png",
    export_folder="./exports/semantic_masks/",
    labelset="ground-truth"
)

print("Export complete")
```

## 3D 点群 (LiDAR) ラベリング

```python
# 3D 点群データのアップロード (自動運転 / ロボティクス用)
import numpy as np

# 点群データ (N x 4: x, y, z, intensity)
point_cloud = np.random.randn(10000, 4).astype(np.float32)

# PCD 形式で保存してアップロード
import open3d as o3d
pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(point_cloud[:, :3])
o3d.io.write_point_cloud("./scene_001.pcd", pcd)

with open("./scene_001.pcd", "rb") as f:
    asset = client.upload_asset(
        "jibun-kaisha/lidar-detection",
        f,
        "scene_001.pcd"
    )

# 3D キューブアノテーションデータセットに追加
sample = client.add_sample(
    dataset="jibun-kaisha/lidar-detection",
    name="scene_001",
    attributes={
        "pointcloud": {"url": asset.url}
    }
)
print(f"3D sample uploaded: {sample.uuid}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 304→305社化: Segments.ai 追加',
  'PS#3 S105。Segments.ai (セマンティックセグメンテーション特化/インスタンス+パノプティック/SAM統合/3D LiDAR点群/動画トラッキング/COCO+Cityscapesエクスポート/Python SDK/GitHub 300+/8/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
