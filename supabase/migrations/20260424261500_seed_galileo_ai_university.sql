-- Session PS#3-S38: AI大学 172社化 — Galileo AI 追加
-- Google AI / Apple Siri / Google Brain 出身者創業の LLM 評価・ガードレールプラットフォーム。
-- 累計 $68M (Scale Venture Partners + Databricks Ventures + ServiceNow + Amex Ventures + SentinelOne)。
-- 顧客: HP / Twilio / Reddit / Comcast。Cisco との公式パートナーシップ。
-- Luna-2: Llama 3B/8B ベースの軽量評価モデル — 100% 本番トラフィック監視をコスト実現。
-- 3 製品: Evaluate (オフライン評価) / Observe (本番監視) / Protect (ガードレール・プロンプトインジェクション防御)。
-- Step 0: 8/9 (Google AI founders / $68M / Cisco提携 / Luna-2 eval models / HP Twilio Reddit採用 / 3-layer architecture)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'galileo',
  'overview',
  'Galileo AI — LLM 評価・ガードレール・本番監視 (Google AI 創業 / Cisco 提携)',
  $md$
# Galileo AI — AI Reliability Platform

Google AI・Apple Siri・Google Brain 出身の精鋭チームが創業した
**LLM 評価・ガードレール・本番監視**の統合プラットフォーム。

累計 **$68M** を調達 (Scale Venture Partners / Databricks Ventures / ServiceNow Ventures /
Amex Ventures / SentinelOne Ventures / Battery Ventures / HuggingFace CEO Clément Delangue 個人出資)。

**Cisco** と公式パートナーシップを締結し、エージェント評価レイヤーとして採用。
顧客: **HP / Twilio / Reddit / Comcast**。

## 3 製品構成

| 製品 | 役割 |
| :--- | :--- |
| **Galileo Evaluate** | オフライン評価 — 実験・テスト・プロンプト比較 |
| **Galileo Observe** | 本番監視 — リアルタイムアラート・ドリフト検出・デバッグ |
| **Galileo Protect** | ガードレール — プロンプトインジェクション防御・有害出力ブロック |

## Luna-2 評価モデル (独自技術)

Llama をベースに**評価タスク専用**にファインチューニングした 3B / 8B パラメータのモデル。

- **100% 本番トラフィック監視**がコスト現実的に
- GPT-4o 等の汎用 LLM 評価に匹敵する精度をはるかに低いコストで実現
- ハルシネーション検出 / 関連性スコア / 有害コンテンツ検出 に最適化

## 強み

- **評価 → 本番 → ガードレール** の一気通貫アーキテクチャ
- **Cisco エージェント評価レイヤー** として公式採用 (エンタープライズ信頼性)
- **Luna-2** — コスト効率のよいフル本番モニタリング
- **HP / Reddit / Twilio** — 大規模プロダクションで実証済み
$md$,
  'https://galileo.ai/',
  '2026-04-24',
  1
),

(
  'galileo',
  'models',
  'Galileo AI 機能・Luna-2 評価モデル詳細 (2026)',
  $md$
## Galileo Evaluate — オフライン評価

| 機能 | 説明 |
| :--- | :--- |
| **実験管理** | プロンプト・モデル・パラメータの A/B 比較 |
| **トレース可視化** | 評価スコアとトレースを紐づけた詳細ビュー |
| **ガードレールメトリクス** | 評価段階からセーフガードを組み込む |
| **チームコラボ** | 評価結果のレビュー・アノテーション共有 |

## Galileo Observe — 本番監視

| 機能 | 説明 |
| :--- | :--- |
| **リアルタイムトレーシング** | 全 LLM リクエストを span レベルで記録 |
| **品質メトリクス** | Luna-2 によるリアルタイム評価 (100% カバレッジ可) |
| **ドリフト検出** | 本番でのモデル品質劣化を早期検知 |
| **アラート** | Slack / PagerDuty / メール 通知 |
| **デバッグ** | 失敗ケースをワンクリックで掘り下げ |

## Galileo Protect — ガードレール

| 機能 | 説明 |
| :--- | :--- |
| **プロンプトインジェクション** | 悪意あるプロンプトをリアルタイムでブロック |
| **有害コンテンツ** | 差別・暴力・個人情報漏洩を自動検出・遮断 |
| **ハルシネーション防止** | 根拠のない回答を本番に出さないフィルタリング |
| **カスタムルール** | ビジネスルールに沿ったカスタムガードレール |

## Luna-2 vs 汎用 LLM 評価

| 比較軸 | Luna-2 (Galileo) | GPT-4o 評価 |
| :--- | :--- | :--- |
| **コスト** | 低 (Llama 3B/8B) | 高 ($0.015/1K output) |
| **速度** | 高速 (小モデル) | 遅い |
| **評価精度** | 同等 (ファインチューニング済) | 高い (汎用) |
| **100% カバレッジ** | ✅ 現実的コスト | ❌ 高コスト |
$md$,
  'https://galileo.ai/platform',
  '2026-04-24',
  2
),

(
  'galileo',
  'api',
  'Galileo AI API 入門 — 評価・ガードレール統合',
  $md$
## Galileo AI の始め方

### インストール & セットアップ

```bash
pip install galileo-sdk
export GALILEO_API_KEY="gal-..."
export GALILEO_PROJECT="ai-university-app"
```

### LLM トレーシング & 評価 (Python)

```python
from galileo import GalileoObserve
from anthropic import Anthropic

# Galileo Observe で Claude をトレース
observe = GalileoObserve(project="ai-university-app")
client = observe.wrap(Anthropic())

# トレースされた Claude コール
response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=512,
    messages=[{
        "role": "user",
        "content": "AI大学のカリキュラムを設計するには？"
    }]
)

# → Galileo Observe ダッシュボードでリアルタイム確認可能
# → Luna-2 が自動でハルシネーション・品質スコアを付与
print(response.content[0].text)
```

### ガードレール統合 (Galileo Protect)

```python
from galileo import GalileoProtect

protect = GalileoProtect(project="ai-university-app")

@protect.guard(
    rules=[
        "hallucination_threshold=0.8",    # ハルシネーション率 80% 超でブロック
        "toxicity_threshold=0.5",          # 有害コンテンツ検出でブロック
        "prompt_injection=block",          # プロンプトインジェクションをブロック
    ]
)
def safe_ai_response(user_input: str) -> str:
    from anthropic import Anthropic
    client = Anthropic()
    msg = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=256,
        messages=[{"role": "user", "content": user_input}]
    )
    return msg.content[0].text

# ガードレール適用済みの安全な呼び出し
result = safe_ai_response("AI大学の教授になるには？")
# → 有害・インジェクション・ハルシネーションは自動ブロック
print(result)
```

### オフライン評価 (Galileo Evaluate)

```python
from galileo import GalileoEvaluate

evaluator = GalileoEvaluate(project="ai-university-evals")

# テストデータセットを登録
evaluator.upload_dataset(
    name="ai-university-qa",
    data=[
        {"input": "Braintrust とは？", "expected": "AI 観測・評価プラットフォーム"},
        {"input": "Galileo の特徴は？", "expected": "LLM 評価・ガードレール・本番監視"},
    ]
)

# 実験として評価を実行
results = evaluator.run_experiment(
    name="claude-opus-4-7-eval",
    model="claude-opus-4-7",
    dataset="ai-university-qa",
    metrics=["factuality", "hallucination", "relevance"]
)
print(results.summary())
```

## クイックスタート

1. `pip install galileo-sdk` でインストール
2. `GALILEO_API_KEY` を設定
3. `observe.wrap(Anthropic())` で 1 行トレース統合
4. Galileo Protect でガードレールをデコレータとして付加
5. [galileo.ai](https://galileo.ai) の UI でリアルタイム品質モニタリング
$md$,
  'https://docs.galileo.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
