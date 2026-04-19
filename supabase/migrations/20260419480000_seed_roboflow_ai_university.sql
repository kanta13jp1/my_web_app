-- PS版#3 Session 8: Roboflow — コンピュータビジョン AI プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'roboflow',
  'overview',
  'Roboflow — コンピュータビジョン AI の開発・デプロイ統合プラットフォーム',
  E'## Roboflow とは\n\nRoboflow は 2019 年設立のサンフランシスコ発スタートアップ。\n「**誰でも CV (コンピュータビジョン) モデルを構築・デプロイできる**」をビジョンに、\nアノテーション → 学習 → デプロイ までを一気通貫するプラットフォームを提供。\n\n累計調達 $20M+。YOLO / Segment Anything / Grounding DINO など主要 CV モデルと統合。\n Roboflow Universe: 100,000+ 公開 CV データセット。\n\n## 主な特徴\n\n- **Annotate**: 画像・動画への BBox/ポリゴン/キーポイントアノテーション\n- **Augmentation**: データ拡張でモデル汎化性能を自動向上\n- **Train**: YOLOv8 / YOLOv11 をノーコードで学習\n- **Deploy**: API エンドポイントを即生成・エッジデバイスへのエクスポート\n- **Inference**: セルフホスト可能な推論サーバー\n- **Roboflow Universe**: CV モデル・データセットの公開マーケットプレイス\n\n## 対応タスク\n\n| タスク | 説明 | 代表モデル |\n|--------|------|----------|\n| **物体検出** | BBox で物体を特定 | YOLOv8 / YOLOv11 |\n| **インスタンス分割** | ピクセル単位でマスク生成 | SAM 2 / Mask R-CNN |\n| **分類** | 画像をカテゴリに分類 | EfficientNet / ViT |\n| **キーポイント** | 骨格・関節の位置推定 | YOLOv8-pose |\n\n## 活用事例\n\n- **スポーツ分析**: 選手・ボール追跡で戦術データ化\n- **製造品質検査**: 欠陥検出の自動化\n- **農業 AI**: ドローン画像で病害虫を検出\n- **医療画像**: 腫瘍・病変のセグメンテーション\n- **小売 AI**: 棚の欠品検出・顧客動線分析',
  '2026-04-20'
),
(
  'roboflow',
  'models',
  'Roboflow モデル・機能一覧',
  E'## 統合モデル\n\n### YOLO ファミリー\n```python\nfrom ultralytics import YOLO\n\nmodel = YOLO("yolov8n.pt")  # nano (最速) / s / m / l / x (最高精度)\nresults = model("image.jpg")  # 推論\nmodel.train(data="dataset.yaml", epochs=100)  # ファインチューニング\n```\n\n### Segment Anything Model (SAM 2)\n```python\nimport supervision as sv\nfrom roboflow import Roboflow\n\n# ゼロショットセグメンテーション\n# プロンプトなしで任意の物体を分割\n```\n\n### Grounding DINO (テキスト → 物体検出)\n```python\n# テキストで物体を指定して検出\n# 例: "赤いリンゴ" → BBox 自動生成\n```\n\n## Roboflow Supervision\n\n```python\nimport supervision as sv\n\n# 推論結果の可視化・後処理ユーティリティ\nannotator = sv.BoxAnnotator()\nframe = annotator.annotate(scene=image, detections=detections)\n```\n\n## データセット管理\n\n| 機能 | 説明 |\n|------|------|\n| **バージョン管理** | データセットの変更履歴を git 的に管理 |\n| **Augmentation** | 回転/反転/輝度/モザイクで自動拡張 |\n| **フォーマット変換** | COCO/Pascal VOC/YOLO/TFRecord 相互変換 |\n| **アクティブラーニング** | 確信度が低いデータを優先アノテーション |\n\n## デプロイ先\n\n- **Roboflow API**: クラウド推論 API (即使用可)\n- **NVIDIA Jetson**: エッジデバイスへの TensorRT 最適化エクスポート\n- **Raspberry Pi**: Coral TPU 対応\n- **Web ブラウザ**: TensorFlow.js エクスポート\n- **iOS/Android**: Core ML / TFLite エクスポート\n\n## 料金\n\n| プラン | 月額 | 内容 |\n|--------|------|------|\n| Free | $0 | 3プロジェクト・1,000枚/月 |\n| Starter | $249 | 10プロジェクト・10,000枚/月 |\n| Pro | $749 | 無制限プロジェクト |\n| Enterprise | 要相談 | SLA・プライベートクラスタ |',
  '2026-04-20'
),
(
  'roboflow',
  'api',
  'Roboflow 使い方',
  E'## インストール\n\n```bash\npip install roboflow supervision ultralytics\nexport ROBOFLOW_API_KEY="YOUR_API_KEY"\n```\n\n## データセットのダウンロード & 学習\n\n```python\nfrom roboflow import Roboflow\n\n# Roboflow Universe からデータセット取得\nrf = Roboflow(api_key="YOUR_API_KEY")\nproject = rf.workspace("roboflow-universe-projects").project("playing-cards-ow27d")\nversion = project.version(4)\ndataset = version.download("yolov8")  # YOLOv8 形式でダウンロード\n\n# YOLOv8 でファインチューニング\nfrom ultralytics import YOLO\n\nmodel = YOLO("yolov8n.pt")\nresults = model.train(\n    data=f"{dataset.location}/data.yaml",\n    epochs=100,\n    imgsz=640,\n    project="my_cv_project"\n)\n\nprint(f"Best mAP@50: {results.maps[50]:.3f}")\n```\n\n## Roboflow API で推論 (クラウド)\n\n```python\nfrom roboflow import Roboflow\n\nrf = Roboflow(api_key="YOUR_API_KEY")\nproject = rf.workspace("my-workspace").project("my-project")\nmodel = project.version(1).model\n\n# 画像で推論\npredictions = model.predict("test_image.jpg", confidence=40, overlap=30).json()\nfor pred in predictions["predictions"]:\n    print(f"{pred[\'class\']} ({pred[\'confidence\']:.2%}) at ({pred[\'x\']},{pred[\'y\']})")\n```\n\n## セルフホスト推論 (Inference Server)\n\n```bash\n# Docker で推論サーバー起動 (ゼロコスト)\ndocker run -p 9001:9001 roboflow/roboflow-inference-server-cpu:latest\n```\n\n```python\nimport requests\n\nresponse = requests.post(\n    "http://localhost:9001/my-model/1",\n    params={"api_key": "YOUR_API_KEY"},\n    data=open("image.jpg", "rb").read(),\n    headers={"Content-Type": "application/octet-stream"}\n)\nprint(response.json())\n```\n\n## Supervision で推論結果を可視化\n\n```python\nimport cv2\nimport supervision as sv\nfrom ultralytics import YOLO\n\nmodel = YOLO("best.pt")  # 学習済みモデル\nimage = cv2.imread("test.jpg")\n\nresults = model(image)[0]\ndetections = sv.Detections.from_ultralytics(results)\n\nbounding_box_annotator = sv.BoundingBoxAnnotator()\nlabel_annotator = sv.LabelAnnotator()\nannotated = bounding_box_annotator.annotate(scene=image.copy(), detections=detections)\nannotated = label_annotator.annotate(scene=annotated, detections=detections)\n\ncv2.imwrite("annotated.jpg", annotated)\n```\n\n## 活用シーン\n\n- **AI 大学教材**: CV AI の実例デモ (物体検出・セグメンテーション)\n- **競馬 AI 拡張**: レース映像から馬の位置・速度を自動追跡\n- **Flutter アプリ統合**: TFLite エクスポート → Flutter ML Kit で端末推論',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
