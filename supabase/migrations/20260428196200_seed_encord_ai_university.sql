-- PS#3 S102: AI大学 298→299社化 — Encord (医療+CV特化ラベリング/Active Learning/品質管理)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'encord', 'overview',
  'Encord — 医療画像+CV特化データラベリング・Active Learning・品質管理・LLMデータ (8/9)',
  $$## Encord とは

**Encord** は **医療画像 (MRI/CT/病理) とコンピュータービジョンに特化したデータラベリング・アクティブラーニングプラットフォーム**。2021年設立の英国スタートアップ。元 Palantir エンジニアが創業。医療 AI 領域での採用率が高く、FDA 規制対応 (21 CFR Part 11 / HIPAA) を意識した品質管理機能が強み。

**Encord Active** (OSS) と **Encord Annotate** (SaaS) の2層構成。Encord Active は GitHub 2k+ スター。DICOM / NIfTI 形式の医療画像にネイティブ対応。

## 医療AI向け特化機能

```
医療画像ラベリングの課題と Encord の解決策:

  課題:
    ・DICOM/NIfTI/WSI (全スライド病理画像) の特殊フォーマット
    ・放射線科医・病理医など専門家のみが正確にラベリング可能
    ・FDA 規制対応 (監査証跡 / 電子署名 / バージョン管理)
    ・3D ボリュームデータのセグメンテーション

  Encord の解決:
    ・DICOM ビューア内蔵 (Hounsfield Unit / ウィンドウレベル調整)
    ・3D ポリゴンセグメンテーション (CT ボリュームを断面ごとにラベル)
    ・監査ログ自動記録 (誰が / いつ / 何を変更したか)
    ・専門家 vs ジュニアアノテーターの二層レビュー
```

## Encord Active: OSS データキュレーション

```
Encord Active の特徴:

  データ品質の自動評価:
    ・Blur Score — ピンぼけ画像を自動検出
    ・Brightness / Contrast Score — 過露出・露出不足
    ・Object Area — アノテーション漏れの検出
    ・Label Consistency — 複数ラベラー間の不一致を可視化

  Active Learning サイクル:
    1. モデルを学習
    2. Encord Active で予測不確実性を計算
    3. 不確実性の高いサンプルを優先ラベリング
    4. モデルを再学習 → 精度向上
    → 少ないラベルデータで最大精度を実現
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | Active Learning で最重要サンプルを優先ラベリング | 少ないデータで高精度モデル構築 |
| **UI 品質監査** | スクリーンショットの Blur/コントラスト自動チェック | 低品質なテストデータを排除 |
| **LLM データ収集** | アノテーション品質スコアで高品質データのみ選別 | Fine-tuning データの精度向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'encord', 'api',
  'Encord 実践 — Python SDK/プロジェクト/アノテーション/Encord Active/Active Learning/品質スコア',
  $$## インストール & セットアップ

```bash
pip install encord
pip install encord-active   # OSS データキュレーション
```

```python
from encord import EncordUserClient

# API キーで接続
client = EncordUserClient.create_with_token(
    resource_id="YOUR_RESOURCE_ID",
    private_key="YOUR_PRIVATE_KEY"
)
```

## プロジェクト作成 & データアップロード

```python
from encord import EncordUserClient
from encord.objects import OntologyStructure

client = EncordUserClient.create_with_token(
    resource_id="YOUR_RESOURCE_ID",
    private_key="YOUR_PRIVATE_KEY"
)

# データセット作成
dataset = client.create_dataset(
    dataset_name="horse-detection-dataset",
    storage_location=StorageLocation.CORD_STORAGE
)

# 画像アップロード
upload_job = dataset.upload_images(
    path="./race_images/",
    transform_bounding_boxes_to_polygons=False
)
upload_job.wait_for_completion()

print(f"Dataset UID: {dataset.dataset_hash}")
```

## オントロジー (アノテーション構造) 定義

```python
from encord.objects import (
    OntologyBuilder, ClassificationBuilder, RadioAttribute
)
from encord.objects.ontologies import BoundingBoxCoordinates

# オントロジー作成
ontology_builder = OntologyBuilder()

# 物体クラス追加
horse_class = ontology_builder.add_object(
    name="horse",
    shape="bounding_box"  # or "polygon", "keypoint", "polyline"
)

# ネスト属性 (馬番号)
horse_class.add_attribute(
    RadioAttribute,
    name="horse_number",
    required=True,
    options=[str(i) for i in range(1, 19)]
)

jockey_class = ontology_builder.add_object(
    name="jockey",
    shape="polygon"
)

# プロジェクト作成
project = client.create_project(
    project_name="horse-detection",
    ontology_hash=ontology.ontology_hash,
    dataset_hashes=[dataset.dataset_hash],
)

print(f"Project UID: {project.project_hash}")
```

## ラベルのエクスポート & 変換

```python
# ラベルをエクスポート (COCO / YOLO 形式)
project = client.get_project("YOUR_PROJECT_HASH")

# すべての完了ラベルを取得
labels = project.list_labels_for_export(
    initialisations=None  # None = 全ラベル
)

for label in labels:
    data_unit = label.data_units[0]
    print(f"Image: {data_unit.title}")

    for obj in label.object_actions:
        print(f"  Class: {obj.object.name}, BBox: {obj.coordinates}")

# COCO JSON エクスポート
from encord.utilities.coco.exporter import CordToCOCOExporter

exporter = CordToCOCOExporter()
coco_json = exporter.export(labels=list(labels))

import json
with open("./exports/annotations.json", "w") as f:
    json.dump(coco_json, f)
```

## Encord Active: データ品質分析 (OSS)

```bash
# Encord Active を起動
encord-active init ./horse-detection-project
encord-active visualise

# → ブラウザで http://localhost:8501 が開く
# データ品質スコア (Blur/輝度/コントラスト/アノテーション一貫性) を可視化
```

```python
# Python API でも品質スコアを取得
from encord_active.lib.project import Project

project = Project("./horse-detection-project")

# 品質の低いサンプルを抽出
quality_metrics = project.get_data_quality_metrics()

low_quality = [
    sample for sample in quality_metrics
    if sample["blur_score"] < 0.3 or sample["brightness"] > 0.9
]

print(f"低品質サンプル数: {len(low_quality)}")
for sample in low_quality[:5]:
    print(f"  {sample['data_row_id']}: blur={sample['blur_score']:.2f}")
```

## Active Learning: 不確実性サンプリング

```python
import numpy as np
from encord import EncordUserClient

def compute_entropy(probabilities: list[float]) -> float:
    """予測確率のエントロピー = 不確実性"""
    probs = np.array(probabilities)
    probs = probs[probs > 0]  # log(0) 回避
    return -np.sum(probs * np.log2(probs))

# モデルの予測結果から不確実性を計算
inference_results = [
    {
        "data_row_id": "race_001",
        "probabilities": [0.95, 0.03, 0.02],  # 確信高い
        "predicted_class": "horse"
    },
    {
        "data_row_id": "race_002",
        "probabilities": [0.45, 0.40, 0.15],  # 不確実
        "predicted_class": "horse"
    },
    {
        "data_row_id": "race_003",
        "probabilities": [0.33, 0.34, 0.33],  # 最も不確実
        "predicted_class": "jockey"
    },
]

# エントロピーでソート (高い = より不確実 = 優先ラベリング)
for result in inference_results:
    result["entropy"] = compute_entropy(result["probabilities"])

priority_queue = sorted(
    inference_results,
    key=lambda x: x["entropy"],
    reverse=True
)

print("Active Learning 優先ラベリングキュー:")
for i, item in enumerate(priority_queue, 1):
    print(f"  {i}. {item['data_row_id']}: entropy={item['entropy']:.3f}")
```

## LLM データ収集 (テキストアノテーション)

```python
# Encord でテキストラベリングプロジェクト作成
# (LLM SFT / RLHF データ用)
text_project = client.create_project(
    project_name="llm-quality-evaluation",
    project_type="text",
    description="競馬予想説明の品質評価 (RLHF データ)"
)

# テキストデータを登録
dataset = client.create_dataset("llm-responses")
dataset.upload_text_files(
    texts={
        "response_001.txt": "シャフリヤールは前走の上がり3ハロン33.2秒から末脚の鋭さが証明されており...",
        "response_002.txt": "この馬は強いと思います。頑張ってください。",
    }
)
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 298→299社化: Encord 追加',
  'PS#3 S102。Encord (医療画像+CV特化ラベリング/DICOM+NIfTI対応/3Dセグメンテーション/FDA規制対応/Encord Active OSS データキュレーション/Active Learning/品質スコア/Python SDK/GitHub 2k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
