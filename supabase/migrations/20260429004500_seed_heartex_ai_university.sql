-- PS#3 S105: AI大学 305→306社化 — Heartex/Label Studio Enterprise (OSS最大手ラベリングツール)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'label-studio', 'overview',
  'Label Studio (Heartex) — OSS最大手ラベリングツール・マルチモーダル・ML Backend統合 (GitHub 16k+ / 9/9)',
  $$## Label Studio とは

**Label Studio** は **GitHub 16,000+ スターを持つ最も広く使われているオープンソースデータラベリングプラットフォーム**。Heartex 社が開発・維持。Apache 2.0 ライセンスで完全無料。**Label Studio Enterprise** (商用版) もあり。

**あらゆるデータタイプに対応** するのが最大の強み — テキスト / 画像 / 音声 / 動画 / 時系列 / HTML / PDF を1つの UI で処理できる。ML Backend 統合により、モデルのアクティブラーニングも簡単に実現。

## Label Studio の特徴

```
他ツールとの差別化:

  完全 OSS & セルフホスト:
    ・Docker 1コマンドで起動
    ・全データが自社サーバーに保持 (GDPR / HIPAA 対応)
    ・GitHub 16k+ スター / コミュニティ活発

  マルチモーダル対応:
    ・テキスト: NER / 分類 / 関係抽出 / 会話
    ・画像: 分類 / バウンディングボックス / ポリゴン / セグメンテーション / キーポイント
    ・音声: 書き起こし / 分類 / 音声イベント検出
    ・動画: フレームトラッキング / 時系列イベント
    ・時系列: 異常検出 / イベントタグ付け

  ML Backend 統合:
    ・任意の ML モデルをバックエンドとして接続
    ・Pre-annotation (モデル推論結果を初期値として表示)
    ・Active Learning (不確実なサンプルを優先提示)
    ・インタラクティブ学習 (アノテーターのクリックでリアルタイムにモデルが更新)
```

## Label Studio XML テンプレートシステム

```xml
<!-- カスタムアノテーション UI を XML で定義 -->
<!-- 画像 + バウンディングボックス + 分類の複合タスク -->
<View>
  <Image name="image" value="$image"/>
  <RectangleLabels name="label" toName="image">
    <Label value="horse" background="#FF5733"/>
    <Label value="jockey" background="#3498DB"/>
    <Label value="fence" background="#2ECC71"/>
  </RectangleLabels>
  <Choices name="race_condition" toName="image" choice="single">
    <Choice value="dry"/>
    <Choice value="wet"/>
    <Choice value="muddy"/>
  </Choices>
</View>
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV** | 競馬画像を Docker セルフホストで安全にラベリング | クラウドにデータを送らず無料で大規模処理 |
| **音声 AI** | 競馬実況音声の書き起こし + 感情タグ付け | 音声認識 + 感情分析モデルの学習データ |
| **LLM RLHF** | テキスト分類で AI 応答品質をランキング | Fine-tuning 用データをチームで効率収集 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'label-studio', 'api',
  'Label Studio 実践 — Docker構築/Python SDK/プロジェクト/タスク/アノテーション/ML Backend/Active Learning',
  $$## セットアップ (Docker)

```bash
# Docker で起動 (ポート 8080)
docker run -it -p 8080:8080 \
  -v $(pwd)/mydata:/label-studio/data \
  heartexlabs/label-studio:latest

# Docker Compose (永続化設定)
# docker-compose.yml
version: "3"
services:
  label-studio:
    image: heartexlabs/label-studio:latest
    ports: ["8080:8080"]
    volumes:
      - ./data:/label-studio/data
    environment:
      - DJANGO_DB=sqlite
      - STORAGE_PERSISTENCE=1
```

## Python SDK

```bash
pip install label-studio-sdk
```

```python
from label_studio_sdk import Client

# 接続
ls = Client(url="http://localhost:8080", api_key="YOUR_API_KEY")
ls.check_connection()
print("Connected to Label Studio")
```

## プロジェクト作成 & タスクアップロード

```python
from label_studio_sdk import Client
from label_studio_sdk.label_interface import LabelInterface

ls = Client(url="http://localhost:8080", api_key="YOUR_API_KEY")

# プロジェクト作成 (XML テンプレートでUIを定義)
project = ls.start_project(
    title="horse-detection",
    label_config="""
    <View>
      <Image name="image" value="$image_url"/>
      <RectangleLabels name="bbox" toName="image">
        <Label value="horse" background="#FF5733"/>
        <Label value="jockey" background="#3498DB"/>
      </RectangleLabels>
      <Choices name="quality" toName="image" choice="single">
        <Choice value="clear"/>
        <Choice value="blurry"/>
        <Choice value="occluded"/>
      </Choices>
    </View>
    """
)

print(f"Project ID: {project.id}")

# タスク (画像) を一括追加
tasks = [
    {"data": {"image_url": "https://example.com/race_001.jpg", "race_date": "2026-04-29"}},
    {"data": {"image_url": "https://example.com/race_002.jpg", "race_date": "2026-04-29"}},
    {"data": {"image_url": "https://example.com/race_003.jpg", "race_date": "2026-04-29"}},
]
project.import_tasks(tasks)
print(f"Imported {len(tasks)} tasks")
```

## アノテーション取得 & エクスポート

```python
from label_studio_sdk import Client

ls = Client(url="http://localhost:8080", api_key="YOUR_API_KEY")
project = ls.get_project(1)

# 完了したアノテーションを取得
tasks = project.get_labeled_tasks()
print(f"Labeled tasks: {len(tasks)}")

for task in tasks[:3]:
    annotations = task["annotations"]
    for ann in annotations:
        results = ann["result"]
        for r in results:
            if r["type"] == "rectanglelabels":
                bbox = r["value"]
                print(f"  BBox: x={bbox['x']:.1f}%, y={bbox['y']:.1f}%, "
                      f"w={bbox['width']:.1f}%, h={bbox['height']:.1f}%, "
                      f"label={bbox['rectanglelabels'][0]}")

# COCO 形式でエクスポート
export_data = project.export_tasks(
    export_type="COCO",  # or "YOLO", "VOC", "CSV", "JSON"
)
with open("./exports/horse_detection_coco.json", "w") as f:
    import json
    json.dump(export_data, f, indent=2)
```

## ML Backend 統合 (Active Learning)

```python
# label_studio_ml ライブラリで ML Backend を実装
# pip install label-studio-ml

from label_studio_ml import LabelStudioMLBase
from ultralytics import YOLO
import numpy as np

class YOLOv8Backend(LabelStudioMLBase):
    """YOLOv8 を Label Studio の ML Backend として使用"""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.model = YOLO("yolov8n.pt")

    def predict(self, tasks, **kwargs):
        """タスクに対して予測を実行 (Pre-annotation)"""
        predictions = []

        for task in tasks:
            image_url = task["data"]["image_url"]
            results = self.model(image_url)[0]

            # Label Studio 形式に変換
            ls_results = []
            for box in results.boxes:
                cls_name = results.names[int(box.cls)]
                if cls_name not in ["horse", "person"]:
                    continue

                label = "horse" if cls_name == "horse" else "jockey"
                x1, y1, x2, y2 = box.xyxy[0].tolist()
                img_w, img_h = results.orig_shape[1], results.orig_shape[0]

                ls_results.append({
                    "from_name": "bbox",
                    "to_name": "image",
                    "type": "rectanglelabels",
                    "value": {
                        "x": x1 / img_w * 100,
                        "y": y1 / img_h * 100,
                        "width": (x2 - x1) / img_w * 100,
                        "height": (y2 - y1) / img_h * 100,
                        "rectanglelabels": [label],
                    },
                    "score": float(box.conf),
                })

            predictions.append({
                "result": ls_results,
                "score": float(np.mean([r["score"] for r in ls_results])) if ls_results else 0.0,
            })

        return predictions

    def fit(self, completions, workdir=None, **kwargs):
        """新しいアノテーションでモデルを再学習"""
        # completions = 新しいラベルデータ
        # → YOLO 形式に変換して再学習
        print(f"Retraining with {len(completions)} new annotations")
        return {"model_version": "retrained"}


# ML Backend サーバーとして起動
# label-studio-ml start yolov8_backend --port 9090
```

```python
# Label Studio にML Backend を登録
from label_studio_sdk import Client

ls = Client(url="http://localhost:8080", api_key="YOUR_API_KEY")
project = ls.get_project(1)

# ML Backend を接続
project.connect_ml_backend(
    url="http://localhost:9090",
    title="YOLOv8 Auto-Annotator",
    is_interactive=True,  # インタラクティブ学習を有効化
)
print("ML Backend connected")
```

## GHA 統合: 定期的な自動エクスポート

```yaml
# .github/workflows/export-label-studio.yml
name: Export Label Studio Annotations

on:
  schedule:
    - cron: '0 3 * * 1'   # 毎週月曜 AM3:00

jobs:
  export:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Export Annotations
        run: |
          pip install label-studio-sdk

          python -c "
          from label_studio_sdk import Client
          import json

          ls = Client(
            url='${{ secrets.LABEL_STUDIO_URL }}',
            api_key='${{ secrets.LABEL_STUDIO_API_KEY }}'
          )
          project = ls.get_project(${{ vars.PROJECT_ID }})
          data = project.export_tasks('YOLO')

          with open('./data/annotations_latest.json', 'w') as f:
              json.dump(data, f)
          print(f'Exported')
          "

      - name: Commit annotations
        run: |
          git config user.email 'github-actions@github.com'
          git config user.name 'GitHub Actions'
          git add ./data/annotations_latest.json
          git commit -m 'chore: weekly annotation export' || exit 0
          git push
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 305→306社化: Label Studio (Heartex) 追加',
  'PS#3 S105。Label Studio (Heartex/OSS最大手/GitHub 16k+/マルチモーダル対応/ML Backend Active Learning/XML UIテンプレート/Docker セルフホスト/YOLOv8統合/GHA自動エクスポート/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
