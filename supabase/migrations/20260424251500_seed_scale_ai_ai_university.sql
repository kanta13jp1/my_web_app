-- Session PS#3-S35: AI大学 166社化 — Scale AI 追加
-- Alexandr Wang が 2016 年 19 歳で創業したデータラベリング → Enterprise AI プラットフォーム企業。
-- 評価額 $13.8B (2024-05 Series F $1B / Accel・Tiger Global / 累計 $1.6B+)。
-- OpenAI・Meta・Microsoft・DoD・US Army などが最大顧客。
-- Scale Donovan: 米国防総省向け AI プラットフォーム (GAIA-1 プロジェクト)。
-- 年売上 $1B+ (2024) / 「AI の Palantir」と称される。
-- 既存 164 社の「データ品質・Enterprise AI」軸空白を埋める。
-- Step 0: 8.5/9 (OpenAI/Meta/DoD 顧客 / $13.8B / $1B+ 売上 / Alexandr Wang CEO / RLHF 標準供給者)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'scale_ai',
  'overview',
  'Scale AI — データ品質から Enterprise AI まで：「AI の Palantir」',
  $md$
# Scale AI — The Data Foundation for AI

2016 年、**Alexandr Wang** が 19 歳で創業。当初は AI モデルの学習データに
特化した **データラベリングプラットフォーム** としてスタートし、
OpenAI・Meta・Microsoft・Google・DoD (米国防総省) など業界最大手の
学習データ供給業者に成長。

2024 年 5 月に **Series F $1B** (Accel・Tiger Global 主導) を調達し、
評価額 **$13.8B** に到達。年間売上 **$1B 超** (2024) を達成。

「**AI の Palantir**」と評されるほど、米国政府・防衛省との深い関係を持ち、
**Scale Donovan** (国防 AI プラットフォーム) を通じて軍事分野にも展開。

## 主要プロダクト

| プロダクト | 説明 |
| :--- | :--- |
| **Scale Data Engine** | RLHF・モデル評価・データキュレーションプラットフォーム |
| **Scale Donovan** | 米国防総省向け AI オペレーション (GAIA-1) |
| **Scale Spellbook** | LLM の本番デプロイ・評価・A/B テスト |
| **Scale GenAI** | エンタープライズ向け生成 AI ソリューション |
| **SEAL Leaderboard** | LLM の独立評価・ランキング (OpenAI/Anthropic/Meta 提携) |

## 主な顧客

OpenAI / Meta / Microsoft / Google / Toyota / DoD / US Army / US Air Force / 他

## 強み

- **RLHF の標準サプライヤー** — GPT-4 / Llama 等の RLHF 訓練データを供給
- **政府 AI 案件** — 米国防総省との契約でデファクト国防 AI プラットフォーム
- **データ品質保証** — 単なるラベリングを超えた AI モデル評価 + 改善ループ
- **Alexandr Wang** — 最年少自力長者 (27 歳 2026 年時点)
$md$,
  'https://scale.com/',
  '2026-04-24',
  1
),

(
  'scale_ai',
  'models',
  'Scale AI プロダクト・サービス一覧 (2026)',
  $md$
## Scale Data Engine — AI 学習データ品質管理

| 機能 | 説明 |
| :--- | :--- |
| **データアノテーション** | 画像・テキスト・音声・動画の高精度ラベリング |
| **RLHF データ生成** | 人間フィードバック付き対話データの収集・品質管理 |
| **モデル評価** | Red Teaming / Safety Testing / ベンチマーク評価 |
| **データキュレーション** | 既存データセットの品質向上・重複除去 |
| **合成データ** | 本物のラベル付きデータが不足する場合の代替データ生成 |

## Scale Spellbook — LLM 本番管理

| 機能 | 説明 |
| :--- | :--- |
| **プロンプト管理** | バージョン管理・A/B テスト |
| **モデル比較** | GPT-4 vs Claude vs Llama のパフォーマンス比較 |
| **評価パイプライン** | 自動評価 + 人間評価の組み合わせ |
| **デプロイ** | API エンドポイントとして公開 |

## SEAL Leaderboard — 独立 LLM 評価

Scale AI が運営する業界最も信頼される LLM 独立評価。
OpenAI・Anthropic・Meta・Google が自社モデルの評価に活用。

## 資金調達履歴

| ラウンド | 金額 | 時期 | 主要投資家 |
| :--- | :--- | :--- | :--- |
| Series A | $4.5M | 2017 | Accel |
| Series B | $18M | 2018 | Accel, Index |
| Series C | $100M | 2019 | Founders Fund |
| Series D | $325M | 2021 | Tiger Global |
| Series E | $325M | 2022 | Tiger Global |
| **Series F** | **$1B** | **2024-05** | **Accel, Tiger** |
| **評価額** | **$13.8B** | **2024** | — |
$md$,
  'https://scale.com/products',
  '2026-04-24',
  2
),

(
  'scale_ai',
  'api',
  'Scale AI API 入門 (Spellbook / Data Engine)',
  $md$
## Scale AI の使い方

### Scale Spellbook — LLM プロダクション API

```python
# pip install scale-spellbook

from spellbook import Spellbook

client = Spellbook(api_key="YOUR_SCALE_API_KEY")

# プロンプトテンプレートをデプロイ
application = client.deploy(
    application_name="customer-support-bot",
    prompt_template="あなたはカスタマーサポート担当です。\n\n質問: {question}\n\n回答:",
    model="gpt-4o",
    temperature=0.3
)

# 本番 API として呼び出し
response = application.run(variables={"question": "AI大学の使い方は？"})
print(response.output)
```

### Scale Data Engine — データラベリング依頼

```python
import scaleapi

client = scaleapi.ScaleClient("YOUR_SCALE_API_KEY")

# テキスト分類タスクを作成
task = client.create_textannotation_task(
    project="product-review-sentiment",
    callback_url="https://your-app.com/webhook",
    instruction="以下のレビューのセンチメント (positive/negative/neutral) を分類してください",
    text="このアプリは使いやすくて最高です！",
    labels=["positive", "negative", "neutral"]
)

print(f"タスクID: {task.id}")
print(f"ステータス: {task.status}")
```

### SEAL — LLM 評価の依頼

Scale AI の SEAL (Scale Evaluation and Alignment) は
エンタープライズ向けの LLM 評価サービス。
自社 LLM を Scale の専門評価チームに送ると、
業界標準の Red Teaming + ベンチマークで評価レポートを提供。

## 企業ユースケース

| ユースケース | Scale のソリューション |
| :--- | :--- |
| LLM の RLHF データ作成 | Scale Data Engine |
| プロダクション LLM の評価 | SEAL Leaderboard / Spellbook |
| 自動車の物体検知データ | Scale Autonomy (Toyota 採用) |
| 政府・防衛 AI | Scale Donovan |

## アクセス方法

1. [scale.com](https://scale.com) でエンタープライズ問い合わせ
2. または [spellbook.scale.com](https://spellbook.scale.com) で開発者プランを申し込み
3. `pip install scaleapi` でデータラベリング API を利用
$md$,
  'https://scale.com/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
