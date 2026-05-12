-- PS#3 S91: AI大学 277→278社化 — Label Studio (OSS データラベリング / アノテーションプラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'label-studio', 'overview',
  'Label Studio — OSS データラベリング・マルチモーダルアノテーション・ML支援ラベリング (GitHub 16k+ / 9/9)',
  $$## Label Studio とは

**Label Studio** は画像・テキスト・音声・動画・時系列データに対応した**オープンソースのデータラベリングプラットフォーム**。2019年創業の Heartex (米国) が開発。2023年 Databricks が買収。

GitHub 16,000+ スター。Apache 2.0 ライセンス。Label Studio Enterprise (SaaS/オンプレ商用版) も提供。ML エンジニアが「自分でラベリング環境を構築する」際のデファクトスタンダード。

## 対応データタイプとタスク

```
Label Studio が対応するデータ:

  テキスト:
    ✓ テキスト分類 (感情/カテゴリ)
    ✓ 固有表現認識 (NER)
    ✓ 質問応答 (Q&A ペア作成)
    ✓ テキスト要約 (参照要約)
    ✓ LLM 出力評価 (Good/Bad/RLHF)

  画像:
    ✓ 画像分類
    ✓ バウンディングボックス (物体検出)
    ✓ セグメンテーション (ポリゴン/ブラシ)
    ✓ キーポイント

  音声:
    ✓ 音声分類
    ✓ 文字起こし (Transcription)
    ✓ スピーカー識別

  動画:
    ✓ 動画分類
    ✓ オブジェクトトラッキング

  マルチモーダル:
    ✓ 画像+テキスト (キャプション生成)
    ✓ 音声+テキスト (対話評価)
```

## ML アシスタントラベリング

```
Label Studio の最大強み:

  通常ラベリング:
    データ → 人間がラベル付け → 完成

  ML アシスタント:
    データ → MLモデルが予測 → 人間が修正・確認 → 完成

  効果:
    → ラベリング工数を最大 80% 削減
    → モデルの弱点を集中的に修正
    → アクティブラーニングで精度が上がるにつれ工数減少
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **感情分析 Fine-Tuning** | ユーザーレビューにラベル付け | 日本語特化モデルを改善 |
| **LLM 評価** | Claude の応答品質を人間が評価 | RLHF データ収集 |
| **音声認識** | サービス内音声データを転写 | 音声機能の精度向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'label-studio', 'api',
  'Label Studio 実践 — インストール/プロジェクト/ラベリングUI/Python SDK/ML Backend/LLM評価/GHA連携',
  $$## インストール & 起動

```bash
# pip でインストール
pip install label-studio

# 起動 (http://localhost:8080)
label-studio start

# Docker で起動 (本番推奨)
docker run -it -p 8080:8080 \
  -v $(pwd)/mydata:/label-studio/data \
  heartexlabs/label-studio:latest

# または Docker Compose
```

```yaml
# docker-compose.yml
version: "3"
services:
  label-studio:
    image: heartexlabs/label-studio:latest
    ports:
      - "8080:8080"
    volumes:
      - ./data:/label-studio/data
    environment:
      - DJANGO_DB=sqlite
      - LABEL_STUDIO_LOCAL_FILES_SERVING_ENABLED=true
```

## ラベリング設定 (XML テンプレート)

```xml
<!-- テキスト感情分析タスク -->
<View>
  <Text name="text" value="$text" />
  <Choices name="sentiment" toName="text" choice="single">
    <Choice value="ポジティブ" />
    <Choice value="ネガティブ" />
    <Choice value="ニュートラル" />
  </Choices>
</View>
```

```xml
<!-- LLM 応答評価タスク (RLHF) -->
<View>
  <Text name="prompt" value="$prompt" />
  <Header value="AI の応答:" />
  <Text name="response" value="$response" />
  <Rating name="quality" toName="response" maxRating="5" icon="star" />
  <TextArea name="comment" toName="response"
            placeholder="改善点を記入してください" rows="3"/>
  <Choices name="issues" toName="response" choice="multiple">
    <Choice value="事実誤り" />
    <Choice value="日本語不自然" />
    <Choice value="有害な内容" />
    <Choice value="指示に従っていない" />
  </Choices>
</View>
```

```xml
<!-- 固有表現認識 (NER) -->
<View>
  <Labels name="label" toName="text">
    <Label value="人名" background="#FF0000"/>
    <Label value="組織名" background="#0000FF"/>
    <Label value="地名" background="#00FF00"/>
    <Label value="製品名" background="#FFFF00"/>
  </Labels>
  <Text name="text" value="$text"/>
</View>
```

## Python SDK: データのインポート・エクスポート

```python
from label_studio_sdk import Client

# Label Studio に接続
ls = Client(url="http://localhost:8080", api_key="your-api-key")

# プロジェクト作成
project = ls.start_project(
    title="jibun-kaisha-sentiment-v3",
    label_config="""
    <View>
      <Text name="text" value="$text" />
      <Choices name="label" toName="text">
        <Choice value="positive" />
        <Choice value="negative" />
        <Choice value="neutral" />
      </Choices>
    </View>
    """,
)

# ラベリング対象データをインポート
import pandas as pd

df = pd.read_parquet("./data/unlabeled.parquet")
tasks = [{"text": row["text"]} for _, row in df.iterrows()]
project.import_tasks(tasks)

print(f"Project ID: {project.id}, Tasks: {len(tasks)}")
```

```python
# ラベリング完了後にエクスポート
from label_studio_sdk import Client

ls = Client(url="http://localhost:8080", api_key="your-api-key")
project = ls.get_project(id=1)

# アノテーション済みデータを取得
annotations = project.export_tasks(export_type="JSON")

# HuggingFace Dataset 形式に変換
labeled_data = []
for task in annotations:
    if task["annotations"]:
        ann = task["annotations"][0]
        label = ann["result"][0]["value"]["choices"][0]
        labeled_data.append({
            "text": task["data"]["text"],
            "label": label,
        })

import pandas as pd
labeled_df = pd.DataFrame(labeled_data)
labeled_df.to_parquet("./data/labeled_v3.parquet")
print(f"Labeled samples: {len(labeled_df)}")
```

## ML Backend: 自動予測でラベリングを高速化

```python
# ml_backend.py (Label Studio ML Backend)
from label_studio_ml import LabelStudioMLBase
import anthropic

class ClaudeAnnotator(LabelStudioMLBase):
    def predict(self, tasks, **kwargs):
        """Claude で自動ラベリング (人間が確認・修正)"""
        client = anthropic.Anthropic()
        predictions = []

        for task in tasks:
            text = task["data"]["text"]
            response = client.messages.create(
                model="claude-haiku-4-5",
                max_tokens=10,
                messages=[{
                    "role": "user",
                    "content": f"テキストの感情を positive/negative/neutral の1単語で回答:\n{text}"
                }]
            )
            label = response.content[0].text.strip().lower()

            predictions.append({
                "result": [{
                    "type": "choices",
                    "value": {"choices": [label]},
                    "from_name": "label",
                    "to_name": "text",
                }],
                "score": 0.8,  # 自動ラベルの信頼度
            })

        return predictions
```

```bash
# ML Backend を起動
pip install label-studio-ml
label-studio-ml start ml_backend.py --port 9090

# Label Studio の設定で ML Backend URL を登録:
# Settings → Machine Learning → Add Model → http://localhost:9090
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 277→278社化: Label Studio 追加',
  'PS#3 S91。Label Studio (OSS データラベリング/テキスト+画像+音声+動画対応/NER/LLM評価RLHF/ML Backend自動予測/Python SDK/Docker/Databricks買収/GitHub 16k+/Apache 2.0/9/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
