-- PS#3 S101: AI大学 296→297社化 — SuperAnnotate (CV+NLPデータラベリング/AutoAnnotate/品質管理)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'superannotate', 'overview',
  'SuperAnnotate — CV+NLPデータラベリング・AutoAnnotate・品質ワークフロー・LLM Fine-tuning (8/9)',
  $$## SuperAnnotate とは

**SuperAnnotate** は **コンピュータービジョン (CV) と NLP の両方に対応したデータラベリング・データキュレーションプラットフォーム**。2018年設立、アルメニア起源のスタートアップ。コンピュータービジョン出身のチームによる高精度アノテーションツールが強み。

**AutoAnnotate** (モデルアシストアノテーション) と **品質ワークフロー** の組み合わせで、人手ラベリングのコストを最大80%削減。LLM の SFT (教師あり微調整) および RLHF データパイプラインにも対応。

## SuperAnnotate の強み

```
他ツールとの差別化:

  Labelbox / Scale AI との比較:
    ・ピクセル精度アノテーション (インスタンスセグメンテーション)
    ・SuperAnnotate Neural Network — 半自動ラベリングに特化した内製モデル
    ・ベクター / ポリゴン / キーポイント / 3D LiDAR をネイティブ対応
    ・NLP (テキスト分類 / エンティティ認識 / 関係抽出) も同一 UI で処理

  特徴:
    ・チーム管理 (QA ロール / レビュアーロール の分離)
    ・カスタム属性 (Nested attributes) でアノテーション構造を細かく定義
    ・Issue Tracking — アノテーターとレビュアーが対話でき品質管理を効率化
```

## LLM Fine-tuning データパイプライン

```
SuperAnnotate を使った LLM データ収集フロー:

  1. 指示データ生成 (Instruction Tuning):
     → テキストエディタで質問・応答ペアを作成
     → 複数アノテーターが独立にラベル → Consensus で確定

  2. RLHF Preference データ:
     → 複数の LLM 応答を並べてランク付け
     → 1-5 評価スケール + 自由記述コメント

  3. RLAIF ハイブリッド:
     → GPT-4 / Claude が一次評価 → 人間がレビュー
     → コスト効率と品質のバランス調整

  4. Safety / Red Team データ:
     → 有害応答パターンをタグ付け
     → カテゴリ別 (violence / bias / misinformation) に分類
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬 CV モデル** | セグメンテーションで馬番認識精度向上 | バウンディングボックスより細粒度な位置特定 |
| **AI アシスタント改善** | 応答品質ランキングデータ収集 | RLHF による説明品質向上 |
| **UI 自動テスト** | スクリーンショットの UI 要素を多クラス分類 | Flutter テスト用の高精度訓練データ生成 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'superannotate', 'api',
  'SuperAnnotate 実践 — Python SDK/プロジェクト/アノテーション/AutoAnnotate/エクスポート/LLMデータ収集',
  $$## インストール & セットアップ

```bash
pip install superannotate
```

```python
import superannotate as sa

# 認証 (API キー or config.json)
sa.init(token="YOUR_API_KEY")
```

## プロジェクト作成 & 画像アップロード

```python
import superannotate as sa

sa.init(token="YOUR_API_KEY")

# プロジェクト作成 (Vector タイプ = バウンディングボックス / ポリゴン)
project = sa.create_project(
    project_name="horse-detection",
    project_description="競馬レース画像の馬検出",
    project_type="Vector"  # Vector / Pixel / Video / Document / Tiled
)

print(f"Project created: {project}")

# 画像アップロード (ローカルフォルダから一括)
sa.upload_images_from_folder_to_project(
    project="horse-detection",
    folder_path="./race_images/",
    extensions=["jpg", "jpeg", "png"]
)
```

## クラス定義 (アノテーション構造)

```python
# アノテーションクラスを定義
classes = [
    {
        "name": "horse",
        "color": "#FF5733",
        "attribute_groups": [
            {
                "name": "horse_number",
                "is_multiselect": False,
                "attributes": [
                    {"name": str(i)} for i in range(1, 19)
                ]
            },
            {
                "name": "position",
                "is_multiselect": False,
                "attributes": [
                    {"name": "leading"},
                    {"name": "mid_field"},
                    {"name": "trailing"}
                ]
            }
        ]
    },
    {
        "name": "jockey",
        "color": "#3498DB",
        "attribute_groups": []
    }
]

sa.create_annotation_classes(
    project="horse-detection",
    classes=classes
)
```

## AutoAnnotate (AI アシストラベリング)

```python
# SuperAnnotate の AI モデルで自動アノテーション
# 事前学習モデル (COCO / ImageNet) を使って候補を生成 → 人間がレビュー

# モデル一覧確認
models = sa.get_models(project="horse-detection")
print(models)

# AutoAnnotate 実行 (全画像に対してモデル推論)
sa.run_prediction(
    project="horse-detection",
    images_list=None,  # None = 全画像
    model_name="Instance Segmentation"  # or "Object Detection"
)
print("AutoAnnotate 完了。レビュー待ちキューに追加されました。")
```

## アノテーションのエクスポート

```python
# SuperAnnotate JSON 形式でエクスポート
sa.export_annotation(
    project="horse-detection",
    folder_path="./exports/sa_format/",
    annotation_statuses=["Completed"],  # 完了済みのみ
)

# COCO 形式に変換 (YOLOv8 学習用)
sa.export_annotation(
    project="horse-detection",
    folder_path="./exports/coco/",
    format="COCO JSON"
)

# エクスポートしたアノテーションを読み込み
import json

with open("./exports/sa_format/horse_001.json") as f:
    annotation = json.load(f)

for instance in annotation.get("instances", []):
    print(
        f"Class: {instance['className']}, "
        f"Type: {instance['type']}, "
        f"Attributes: {instance.get('attributes', [])}"
    )
```

## LLM データ収集 (Document プロジェクト)

```python
# テキストデータのラベリング (LLM SFT / RLHF)
text_project = sa.create_project(
    project_name="llm-preference-data",
    project_description="競馬予想説明の品質ランキング",
    project_type="Document"
)

# テキストサンプルをアップロード
texts = [
    {
        "name": "sample_001.txt",
        "content": "シャフリヤールは前走の上がり3ハロン33.2秒から...",
        "metadata": {"model": "claude-sonnet-4-6", "task": "horse_prediction"}
    },
    {
        "name": "sample_002.txt",
        "content": "この馬は強いと思います。",
        "metadata": {"model": "gpt-4o", "task": "horse_prediction"}
    }
]

sa.upload_texts_to_project(
    project="llm-preference-data",
    texts=texts
)

# クラス定義 (評価カテゴリ)
quality_classes = [
    {
        "name": "quality_score",
        "color": "#2ECC71",
        "attribute_groups": [
            {
                "name": "score",
                "is_multiselect": False,
                "attributes": [
                    {"name": "1_poor"},
                    {"name": "2_below_average"},
                    {"name": "3_average"},
                    {"name": "4_good"},
                    {"name": "5_excellent"},
                ]
            }
        ]
    }
]

sa.create_annotation_classes(
    project="llm-preference-data",
    classes=quality_classes
)
```

## チーム管理 & 品質ワークフロー

```python
# プロジェクトにアノテーターを招待
sa.invite_contributors(
    project="horse-detection",
    contributors=[
        {"email": "annotator1@example.com", "role": "Annotator"},
        {"email": "reviewer@example.com", "role": "QA"},
    ]
)

# アノテーション品質統計を取得
stats = sa.get_project_workflow_attribute(
    project="horse-detection",
    attribute="annotationStatuses"
)
print(f"完了: {stats.get('Completed', 0)}")
print(f"レビュー待ち: {stats.get('InReview', 0)}")
print(f"差し戻し: {stats.get('Returned', 0)}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 296→297社化: SuperAnnotate 追加',
  'PS#3 S101。SuperAnnotate (CV+NLPデータラベリング/AutoAnnotate/Nested属性/品質ワークフロー/LLM SFT+RLHF データ収集/Document プロジェクト/Python SDK/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
