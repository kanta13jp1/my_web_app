-- PS#3 S99: AI大学 293→294社化 — Roboflow (コンピュータービジョンMLプラットフォーム/アノテーション/学習/デプロイ)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'roboflow', 'overview',
  'Roboflow — コンピュータービジョンMLプラットフォーム・アノテーション・学習・推論API (GitHub 3k+ / 8/9)',
  $$## Roboflow とは

**Roboflow** は **コンピュータービジョン (CV) ML の全工程 (データ収集→アノテーション→前処理→学習→デプロイ→推論) を統合するプラットフォーム**。2019年設立の米国スタートアップ。100万社以上が利用。

GitHub 3,000+ スター (roboflow Python SDK)。Free tier あり + Pro/Enterprise プランへの移行可能。YOLOv8 / RT-DETR / SAM (Segment Anything Model) などとネイティブ統合。

## CV ML の複雑さをワンストップで解決

```
コンピュータービジョン ML の現実的な課題:

  従来アプローチ:
    1. 画像収集 → CVAT/LabelImg でアノテーション
    2. データ前処理 → Python スクリプト
    3. YOLOv8 で学習 → ローカル GPU 環境が必要
    4. モデル変換 (ONNX/TensorRT/TFLite)
    5. REST API サービング → Flask/FastAPI で実装
    → 各ステップのツール統合に時間がかかる

  Roboflow のアプローチ:
    1. 画像アップロード → クラウドストレージ
    2. ブラウザ上でアノテーション (自動アノテーション機能付き)
    3. クラウド学習 (GPU 不要)
    4. 自動でモデル変換
    5. Inference API キー 1 本で REST/Python 推論
    → 1日以内にプロトタイプ完成可能
```

## Roboflow Universe: 最大のCVデータセットハブ

```
Roboflow Universe の規模 (2026時点):

  ・50,000+ データセット
  ・データセット検索 + 即座にダウンロード
  ・Fine-tuning のベースライン転移学習に活用
  ・公開モデル + 学習済みウェイトも共有

  例: 「horse detection」で検索
  → 既存の競馬・馬画像データセットを発見
  → そのまま自前データに転移学習
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬実況分析** | レース動画から馬番・位置をリアルタイム検出 | 人手トラッキング不要の自動解析 |
| **書類OCR強化** | 手書きフォーム・レシートの文字認識 | MoneyForward的経費管理の精度向上 |
| **UI自動テスト** | スクリーンショットから UI 要素を検出 | Flutter テスト自動化の補完 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'roboflow', 'api',
  'Roboflow 実践 — Python SDK/アノテーション/YOLOv8学習/Inference API/Universe/Supervision/自動アノテーション',
  $$## インストール & セットアップ

```bash
pip install roboflow
pip install inference          # Roboflow 推論ライブラリ
pip install supervision        # CV 可視化・後処理ライブラリ
```

## データセット管理 & アノテーション

```python
from roboflow import Roboflow

# Roboflow に接続
rf = Roboflow(api_key="YOUR_API_KEY")

# プロジェクト取得 or 作成
project = rf.workspace("jibun-kaisha").project("horse-detection")

# バージョン取得 (学習済みデータセット)
version = project.version(1)

# YOLOv8 形式でダウンロード
dataset = version.download("yolov8")
print(f"Dataset location: {dataset.location}")
# → ./horse-detection-1/ にダウンロード

# データセット情報
print(f"Classes: {version.classes}")
print(f"Images: {version.images}")
```

## YOLOv8 との統合 (学習)

```python
from ultralytics import YOLO
from roboflow import Roboflow

# データセットダウンロード
rf = Roboflow(api_key="YOUR_API_KEY")
project = rf.workspace("jibun-kaisha").project("horse-detection")
dataset = project.version(1).download("yolov8")

# YOLOv8 で学習
model = YOLO("yolov8n.pt")   # ナノモデル (高速・軽量)

results = model.train(
    data=f"{dataset.location}/data.yaml",
    epochs=100,
    imgsz=640,
    batch=16,
    project="jibun-kaisha-cv",
    name="horse_detector_v1",
    device="0",   # GPU
)

print(f"Best model: {results.save_dir}/weights/best.pt")
```

## Roboflow Inference API (クラウド推論)

```python
from roboflow import Roboflow

rf = Roboflow(api_key="YOUR_API_KEY")
project = rf.workspace("jibun-kaisha").project("horse-detection")
model = project.version(1).model

# 画像から推論 (ファイル / URL / numpy array)
result = model.predict("./race_image.jpg", confidence=40, overlap=30).json()

for prediction in result["predictions"]:
    print(
        f"Class: {prediction['class']}, "
        f"Confidence: {prediction['confidence']:.2%}, "
        f"Bbox: ({prediction['x']:.0f}, {prediction['y']:.0f}, "
        f"{prediction['width']:.0f}, {prediction['height']:.0f})"
    )
# → Class: horse, Confidence: 91.23%, Bbox: (245, 180, 120, 200)
```

## ローカル推論 (Inference ライブラリ)

```python
# inference: クラウド不要のローカル推論
from inference import get_model
import cv2
import supervision as sv

# モデルをローカルにダウンロード + 推論
model = get_model(model_id="horse-detection/1", api_key="YOUR_API_KEY")

# 動画ファイルから推論
cap = cv2.VideoCapture("./race_video.mp4")

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # 推論
    results = model.infer(frame)[0]

    # supervision で可視化
    detections = sv.Detections.from_inference(results)

    # バウンディングボックスを描画
    annotator = sv.BoxAnnotator()
    annotated_frame = annotator.annotate(
        scene=frame,
        detections=detections,
    )

    cv2.imshow("Horse Detection", annotated_frame)
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break

cap.release()
```

## Supervision: CV ポスト処理ライブラリ

```python
import supervision as sv
import cv2
from inference import get_model

model = get_model("horse-detection/1", api_key="YOUR_API_KEY")
image = cv2.imread("./race_image.jpg")

# 推論
results = model.infer(image)[0]
detections = sv.Detections.from_inference(results)

# Non-Maximum Suppression
detections = detections.with_nms(threshold=0.5)

# 各検出ボックスに情報を表示
box_annotator = sv.BoxAnnotator()
label_annotator = sv.LabelAnnotator()

labels = [
    f"{class_name} {confidence:.2%}"
    for class_name, confidence in zip(detections["class_name"], detections.confidence)
]

annotated = box_annotator.annotate(image, detections)
annotated = label_annotator.annotate(annotated, detections, labels)

cv2.imwrite("./annotated_race.jpg", annotated)
print(f"Detected {len(detections)} horses")
```

## Roboflow Universe からのデータセット活用

```python
from roboflow import Roboflow

rf = Roboflow(api_key="YOUR_API_KEY")

# Universe から公開データセットを検索・ダウンロード
# → app.roboflow.com/universe で "horse" 検索 → 最も Stars の多いデータセット選択

project = rf.workspace("universe-workspace").project("horse-detection-universe")
dataset = project.version(3).download("yolov8")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 293→294社化: Roboflow 追加',
  'PS#3 S99。Roboflow (コンピュータービジョンMLプラットフォーム/アノテーション/YOLOv8統合/Inference API/Supervision/Universe 50k+データセット/自動アノテーション/GitHub 3k+/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
