-- PS#3 S103: AI大学 300→301社化 — Appen (大規模データ収集・アノテーション・言語多様性)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'appen', 'overview',
  'Appen — 大規模AIトレーニングデータ収集・多言語アノテーション・Ground Truth (8/9)',
  $$## Appen とは

**Appen** は **AIモデルのトレーニングデータ収集・アノテーション・評価を大規模に提供するデータサービス企業**。1996年設立のオーストラリア上場企業 (ASX: APX)。180ヶ国以上に100万人超のクラウドワーカーネットワークを保有。

Google / Microsoft / Amazon / Meta などの主要テック企業が採用。特に**多言語・多文化データ収集**と**検索エンジン品質評価 (Search Quality Rater)** で圧倒的な実績を持つ。

## Appen の主要サービス

```
Appen のサービスカテゴリ:

  1. データ収集 (Data Collection):
     ・音声データ収集 (100+ 言語/方言)
     ・画像・動画収集 (特定シナリオ指定可)
     ・テキストデータ収集 (多言語 FAQ / 会話ログ)
     ・センサーデータ (IoT / 自動運転向け)

  2. データアノテーション (Annotation):
     ・画像ラベリング (CV / YOLO / COCO 形式)
     ・音声書き起こし + タグ付け
     ・感情分析 / 意図分類 (NLP)
     ・LLM 応答品質評価 (RLHF)

  3. AI 評価 (Model Evaluation):
     ・検索品質評価 (Search Quality Raters)
     ・LLM 応答の有害性評価
     ・広告関連性スコアリング
     ・推薦システムの品質評価
```

## 多言語・多文化対応の強み

```
Appen の言語カバレッジ:

  対応言語: 235+ 言語
  ・主要言語: 英語 / 中国語 / スペイン語 / アラビア語 / 日本語 / 韓国語
  ・希少言語: スワヒリ語 / ベンガル語 / タミル語 / カタルーニャ語 など

  なぜ多言語が重要か:
    → LLM のトレーニングデータが英語に偏ると非英語圏でパフォーマンス低下
    → 日本語 LLM ファインチューニングには日本語ネイティブによる品質評価が必須
    → 文化的ニュアンス (敬語 / 皮肉 / ユーモア) は地域ネイティブしか判断できない
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **日本語 LLM 評価** | 日本語ネイティブによる AI 応答品質評価 | 日本語特有の敬語・文脈を正確に評価 |
| **多言語競合調査** | 各言語の競合 SaaS の特徴収集 | グローバル展開の市場調査効率化 |
| **競馬実況音声** | 日本語競馬実況の書き起こし + タグ付け | 音声認識モデルの学習データ構築 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'appen', 'api',
  'Appen 実践 — Appen Connect/プロジェクト設計/品質管理/Figure Eight/CML/データ収集ガイドライン',
  $$## Appen Connect: クラウドワーカー管理プラットフォーム

```
Appen Connect でできること:

  プロジェクト設定:
    ・タスクタイプ選択 (画像分類 / テキスト評価 / 音声 etc.)
    ・品質要件定義 (必要精度 / サンプリング率)
    ・ワーカー資格要件 (言語 / 地域 / 専門性)
    ・支払い設定 (タスクあたり / 時間あたり)

  品質管理:
    ・Gold Standard Questions (正解わかっているテスト問題を埋め込み)
    ・Trust Score (ワーカーの精度スコアをリアルタイム追跡)
    ・Inter-Annotator Agreement (複数ワーカーの一致率測定)
    ・自動フィルタリング (信頼度低いワーカーを自動除外)
```

## Figure Eight (CrowdFlower) 統合

```python
# Appen は Figure Eight (旧 CrowdFlower) を統合
# Figure Eight API でプロジェクトを操作

import requests

API_KEY = "YOUR_FIGURE_EIGHT_API_KEY"
BASE_URL = "https://api.figure-eight.com/v1"

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}

# ジョブ一覧取得
jobs = requests.get(f"{BASE_URL}/jobs", headers=headers).json()
print(f"Active jobs: {len(jobs)}")

# 新しいジョブ作成 (画像分類)
new_job = {
    "job": {
        "title": "競馬レース画像の馬番号分類",
        "instructions": """
        ## タスク概要
        競馬レース画像を見て、先頭の馬の馬番号を特定してください。

        ## 手順
        1. 画像を注意深く確認する
        2. 先頭の馬のゼッケン番号を読む
        3. 番号が見えない場合は「不明」を選択する

        ## 品質基準
        - 鮮明に見える場合は正確に番号を入力すること
        - 複数の馬が同着の場合は全員の番号をカンマ区切りで入力
        """,
        "language": "ja",  # 日本語ワーカー優先
        "units_per_assignment": 5,
        "judgments_per_unit": 3,  # 3人で多数決
        "gold_per_assignment": 1,  # テスト問題 1問/タスク
    }
}

response = requests.post(
    f"{BASE_URL}/jobs",
    headers=headers,
    json=new_job
)
job = response.json()
print(f"Job ID: {job['id']}")
```

## データアップロード (CSV 形式)

```python
import pandas as pd
import requests

API_KEY = "YOUR_API_KEY"
JOB_ID = "YOUR_JOB_ID"

# アノテーション対象データを CSV 形式で準備
df = pd.DataFrame({
    "image_url": [
        "https://example.com/race_001.jpg",
        "https://example.com/race_002.jpg",
        "https://example.com/race_003.jpg",
    ],
    "race_date": ["2026-04-28", "2026-04-28", "2026-04-28"],
    "race_number": [1, 2, 3],
    # Gold Standard データ (正解あり) は _golden: true と正解を指定
    "_golden": [True, False, False],
    "horse_number_gold": ["3", None, None],  # 正解データ
    "horse_number_gold_reason": ["3番が明確に先頭", None, None],
})

# CSV をアップロード
csv_data = df.to_csv(index=False)

response = requests.put(
    f"https://api.figure-eight.com/v1/jobs/{JOB_ID}/upload",
    headers={"Authorization": f"Bearer {API_KEY}"},
    data=csv_data,
    params={"force": True}
)
print(f"Upload status: {response.status_code}")
```

## 結果のダウンロード & 処理

```python
import requests
import pandas as pd
import io

API_KEY = "YOUR_API_KEY"
JOB_ID = "YOUR_JOB_ID"

# 完了したアノテーション結果をダウンロード
response = requests.get(
    f"https://api.figure-eight.com/v1/jobs/{JOB_ID}/judgments.csv",
    headers={"Authorization": f"Bearer {API_KEY}"},
    params={"type": "full"}
)

# CSV を読み込み
df = pd.read_csv(io.StringIO(response.text))

print(f"Total judgments: {len(df)}")
print(f"Columns: {df.columns.tolist()}")

# 信頼度フィルタリング (Trust Score > 0.7 のワーカーのみ)
trusted = df[df["trust"] > 0.7]
print(f"Trusted judgments: {len(trusted)}")

# 多数決集計
aggregated = (
    trusted
    .groupby("unit_id")["horse_number"]
    .agg(lambda x: x.mode()[0] if len(x) > 0 else "不明")
    .reset_index()
)

print(f"\nAggregated results:")
print(aggregated.head(10))
```

## LLM 応答品質評価プロジェクト

```python
# RLHF / RLAIF 用の LLM 応答評価タスク設計

llm_eval_job = {
    "job": {
        "title": "AI競馬予想の品質評価 (日本語)",
        "instructions": """
        ## タスク概要
        AIが生成した競馬予想の説明文を評価してください。

        ## 評価基準 (各5点満点)
        1. **有用性**: 馬券購入の判断に役立つか
        2. **正確性**: 統計・事実に基づいているか
        3. **明確性**: わかりやすい日本語で書かれているか
        4. **根拠**: 予想の理由が具体的に説明されているか

        ## 注意事項
        - 実際の競馬知識がある方を優先します
        - 評価は客観的に行ってください
        """,
        "language": "ja",
        "judgments_per_unit": 5,  # 5人で評価
        "worker_qualifications": {
            "countries": ["JP"],  # 日本語ネイティブ限定
        }
    }
}
```

## 音声データ収集プロジェクト

```python
# 日本語音声データ収集 (音声認識モデル用)

speech_collection_job = {
    "job": {
        "title": "競馬実況音声の読み上げ収集",
        "instructions": """
        ## タスク概要
        以下の競馬実況テキストを自然な日本語で読み上げ、録音してください。

        ## 録音要件
        - 静かな場所で録音すること
        - マイクから 20-30cm の距離を保つこと
        - 自然なスピードで読む (速すぎず / 遅すぎず)
        - 録音時間: 10-30秒/タスク

        ## 評価対象テキスト
        {{text_to_read}}
        """,
        "language": "ja",
        "audio_format": "wav",
        "sample_rate": 16000,
    }
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 300→301社化: Appen 追加',
  'PS#3 S103。Appen (大規模AIトレーニングデータ収集/235+言語多言語対応/Figure Eight統合/Gold Standard品質管理/Trust Score/音声+画像+テキスト収集/LLM RLHF評価/ASX上場/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
