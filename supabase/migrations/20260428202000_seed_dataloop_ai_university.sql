-- PS#3 S104: AI大学 302→303社化 — Dataloop (データ管理+ラベリング統合/Python SDK/Pipelines)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dataloop', 'overview',
  'Dataloop — データ管理・ラベリング・MLパイプライン統合プラットフォーム (8/9)',
  $$## Dataloop とは

**Dataloop** は **データ管理・アノテーション・MLパイプラインを1つのプラットフォームに統合したAIデータエンジン**。2017年設立のイスラエルスタートアップ (テルアビブ)。Intel Capital / Scale Venture Partners から資金調達。

他のラベリングツールとの最大の差別化点は **Pipelines** 機能 — データ前処理 / アノテーション / モデル学習 / モデル評価をノーコードでパイプライン化し、継続的な Active Learning ループを自動化できる。

## Dataloop の統合アーキテクチャ

```
Dataloop の4層構成:

  Layer 1: データ管理
    ・Dataset (GCS / S3 / Azure Blob 直接接続)
    ・アイテム管理 (画像/動画/テキスト/点群/音声)
    ・メタデータ管理 + 検索 + フィルタリング
    ・データセットのバージョン管理

  Layer 2: アノテーション
    ・バウンディングボックス / ポリゴン / セグメンテーション
    ・動画フレームトラッキング
    ・3D 点群 (LiDAR)
    ・テキスト / 会話 NLP アノテーション

  Layer 3: Pipelines (ノーコード自動化)
    ・Pre-annotation → ヒューマンレビュー → QA → Export
    ・任意のステップに Python 関数を挿入可能
    ・Active Learning ループの自動化

  Layer 4: FaaS (Function as a Service)
    ・Python 関数をサーバーレスで実行
    ・モデル推論 / データ変換 / 品質チェックを自動化
```

## Active Learning 自動化

```
Dataloop Pipeline で Active Learning を実装:

  Pipeline ノード:
    [Dataset] → [Model Inference] → [Uncertainty Filter]
                                          ↓
    [Retrain Trigger] ← [Export to Train] ← [Human Review]

  自動化できること:
    ・信頼度 < 閾値 のサンプルを自動でレビューキューへ
    ・十分な数が集まったら自動で再学習をトリガー
    ・新モデルを自動でデプロイして推論を置き換え
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | Active Learning Pipeline で継続的に精度向上 | 人手ラベリングを最小化しながらモデル改善 |
| **動画トラッキング** | レース動画の馬トラッキングを半自動化 | フレームごとのラベリング不要 |
| **S3 連携** | AWS S3 のレース画像を直接 Dataloop に接続 | データのコピー不要でストレージコスト削減 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dataloop', 'api',
  'Dataloop 実践 — Python SDK/Dataset/Item/Annotation/Pipeline/FaaS/Active Learning自動化',
  $$## インストール & セットアップ

```bash
pip install dtlpy
```

```python
import dtlpy as dl

# 認証
dl.login()  # ブラウザでOAuth認証 (初回のみ)
# または
dl.login_m2m(email="user@example.com", password="password")
```

## Dataset 作成 & データアップロード

```python
import dtlpy as dl

dl.login_m2m(email="user@example.com", password="password")

# プロジェクト取得 or 作成
project = dl.projects.get(project_name="jibun-kaisha-ml")
# project = dl.projects.create(project_name="jibun-kaisha-ml")

# データセット作成
dataset = project.datasets.create(dataset_name="horse-detection-2026")

# ローカルからアップロード
dataset.items.upload(
    local_path="./race_images/",
    local_annotations_path="./annotations/",  # オプション: 既存アノテーション
    overwrite=False,
)

# URL から直接アップロード
url_list = [
    "https://example.com/race_001.jpg",
    "https://example.com/race_002.jpg",
]
for url in url_list:
    dataset.items.upload(local_path=url)

print(f"Dataset: {dataset.id}, Items: {dataset.items.list().items_count}")
```

## アノテーション操作

```python
import dtlpy as dl

project = dl.projects.get(project_name="jibun-kaisha-ml")
dataset = project.datasets.get(dataset_name="horse-detection-2026")

# アイテム取得
item = dataset.items.get(filepath="/race_001.jpg")

# アノテーション追加
builder = item.annotations.builder()

# バウンディングボックス
builder.add(
    annotation_definition=dl.Box(
        top=100, left=200, bottom=300, right=400,
        label="horse"
    ),
    metadata={"horse_number": "3"}
)

# ポリゴン
builder.add(
    annotation_definition=dl.Polygon(
        geo=[[200, 100], [400, 100], [400, 300], [200, 300]],
        label="jockey"
    )
)

# アノテーションをアップロード
item.annotations.upload(builder)
print("Annotations uploaded")
```

## ラベルのエクスポート (COCO / YOLO)

```python
# COCO JSON 形式でエクスポート
import dtlpy as dl

project = dl.projects.get(project_name="jibun-kaisha-ml")
dataset = project.datasets.get(dataset_name="horse-detection-2026")

# エクスポートフィルタ (完了済みのみ)
filters = dl.Filters()
filters.add_join(field="label", values=["horse", "jockey"])

# Zip をダウンロード
dataset.export_dataset(
    local_path="./exports/",
    filters=filters,
    annotation_options=[dl.ViewAnnotationOptions.JSON]  # or MASK, INSTANCE
)

# COCO 変換 (dtlpy Converter)
from dtlpy.utilities import Converter

converter = Converter()
converter.convert_dataset(
    dataset=dataset,
    to_format="coco",
    local_path="./exports/coco/"
)
print("Export complete")
```

## FaaS: Python 関数をサーバーレスで実行

```python
import dtlpy as dl

# FaaS 関数の定義 (ファイル: functions/auto_annotate.py)
"""
# functions/auto_annotate.py
import dtlpy as dl
from ultralytics import YOLO

def auto_annotate_item(item: dl.Item):
    model = YOLO("yolov8n.pt")
    image_stream = item.download(save_locally=False)

    results = model(image_stream)[0]
    builder = item.annotations.builder()

    for box in results.boxes:
        cls = results.names[int(box.cls)]
        if cls in ["horse", "person"]:
            label = "horse" if cls == "horse" else "jockey"
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            builder.add(
                annotation_definition=dl.Box(
                    top=y1, left=x1, bottom=y2, right=x2,
                    label=label
                )
            )

    item.annotations.upload(builder)
    return item
"""

# FaaS としてデプロイ
project = dl.projects.get(project_name="jibun-kaisha-ml")

# サービスとしてデプロイ
package = project.packages.push(
    package_name="auto-annotator",
    src_path="./functions/",
    modules=[dl.PackageModule(
        name="auto_annotate",
        entry_point="auto_annotate.py",
        functions=[
            dl.PackageFunction(
                name="auto_annotate_item",
                inputs=[dl.FunctionIO(type=dl.PackageInputType.ITEM, name="item")]
            )
        ]
    )]
)

service = package.services.deploy(
    service_name="auto-annotate-service",
    runtime=dl.KubernetesRuntime(
        pod_type=dl.INSTANCE_CATALOG_GPU_K80_S,
        concurrency=3
    )
)
print(f"Service deployed: {service.id}")
```

## Pipeline: Active Learning ループの自動化

```python
# Pipeline をコードで定義 (GUI でも設定可能)
import dtlpy as dl

project = dl.projects.get(project_name="jibun-kaisha-ml")

# Pipeline 作成
pipeline = project.pipelines.create(
    name="horse-detection-active-learning",
    nodes=[
        # ノード1: データセット入力
        dl.DatasetNode(
            name="input-dataset",
            dataset_id=dataset.id
        ),
        # ノード2: YOLOv8 自動推論
        dl.FunctionNode(
            name="auto-annotate",
            service=service,
            function_name="auto_annotate_item",
        ),
        # ノード3: 信頼度フィルタリング
        dl.CodeNode(
            name="uncertainty-filter",
            outputs=[
                dl.PipelineNodeIO(name="high-confidence", port_id="high"),
                dl.PipelineNodeIO(name="low-confidence", port_id="low"),
            ]
        ),
        # ノード4: 人間レビュー
        dl.TaskNode(
            name="human-review",
            worker_count=2,
            task_owner="reviewer@example.com",
        ),
    ]
)

pipeline.start()
print(f"Pipeline running: {pipeline.id}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 302→303社化: Dataloop 追加',
  'PS#3 S104。Dataloop (データ管理+ラベリング+MLパイプライン統合/4層アーキテクチャ/Pipeline Active Learning自動化/FaaS Python関数/S3+GCS+Azure直接接続/動画トラッキング/COCO+YOLOエクスポート/Python SDK/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
