-- Session PS#3-S38: AI大学 171社化 — Braintrust 追加
-- 2023年創業の AI 観測・評価プラットフォーム。
-- 2026-02 Series B $80M (ICONIQ Capital + a16z + Greylock + Elad Gil) @ $800M / 累計 $121M。
-- 顧客: Notion / Stripe / Vercel / Zapier / Ramp / Instacart。
-- Loop AI エージェント: 自律的に評価実行・テストケース生成・プロンプト改善を繰り返す。
-- 無料: 1M spans / 10k scores / 14日保存 (業界最大) / Pro: $249/月 (無制限ユーザー)。
-- Step 0: 9/9 (2026-02 $800M Series B / ICONIQ+a16z / Notion Stripe Vercel 採用 / Loop AI / 最大無料枠)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'braintrust',
  'overview',
  'Braintrust — AI 観測・評価インフラ / $800M 評価 / Loop AI エージェント',
  $md$
# Braintrust — Production AI Observability Platform

AI アプリケーションの**観測・評価・改善**を一貫して行うインフラプラットフォーム。

2026 年 2 月、**Series B $80M** (ICONIQ Capital 主導 / a16z / Greylock / Elad Gil) を完了し、
評価額 **$800M** に到達。累計調達額 **$121M**。

Notion・Stripe・Vercel・Zapier・Ramp・Instacart など**先進的 AI チームに選ばれる**事実上の標準プラットフォーム。

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **トレーシング** | 全 LLM コール・ツール呼び出し・レイテンシーをリアルタイム収集 |
| **評価 (Evals)** | カスタムスコアリング・LLM-as-judge・自動回帰テスト |
| **A/B 実験** | プロンプト・モデルを並列比較 (サイドバイサイド) |
| **Prompt Playground** | インタラクティブにプロンプトを編集・テスト |
| **Datasets** | ゴールデンデータセット管理・テストケース蓄積 |
| **アノテーション** | 人間フィードバック収集・ラベリングワークフロー |
| **CI/CD 統合** | PR ごとに自動評価実行・退行を防ぐ |

## Loop AI エージェント (2026 最新機能)

Braintrust 独自の AI エージェントが**自律的**に以下を実行:
- 評価を実行してスコアを解析
- テストケースを自動生成
- プロンプトを繰り返し改善
- モデル選択肢を探索

**「人間が指示しなくても品質が向上し続ける」**仕組みを実現。

## 採用企業

Notion / Stripe / Vercel / Zapier / Ramp / Instacart — AI を製品コアに据えた企業が利用。
$md$,
  'https://www.braintrust.dev',
  '2026-04-24',
  1
),

(
  'braintrust',
  'models',
  'Braintrust 料金・プラン比較 (2026)',
  $md$
## Braintrust 料金プラン (2026)

| プラン | 価格 | Spans | スコア | 保存期間 |
| :--- | :--- | :--- | :--- | :--- |
| **Free** | $0 | 1M/月 | 10k/月 | 14 日 |
| **Pro** | $249/月 | 5GB データ | 無制限 | 1 ヶ月 |
| **Enterprise** | カスタム | カスタム | カスタム | カスタム |

> Free プランの 1M spans は業界最大級 — 開発チームがすぐ使い始められる設計

### Free vs 競合比較

| プラットフォーム | 無料 spans | 無料 scores |
| :--- | :--- | :--- |
| **Braintrust** | **1M/月** | **10k/月** |
| LangSmith | 5k traces/月 | — |
| Arize Phoenix | OSS (制限なし) | — |

### Enterprise 追加機能

- SSO / SAML / RBAC
- データ所在地 (EU / US 選択)
- 専任 CSM / SLA 保証
- プライベートデプロイ

## 技術仕様

| 項目 | 詳細 |
| :--- | :--- |
| **SDK** | Python / TypeScript |
| **統合** | OpenAI / Anthropic / Google / LangChain / LlamaIndex 等 |
| **CI/CD** | GitHub Actions / CircleCI / Jenkins |
| **保存** | プロプライエタリクラウド |
$md$,
  'https://www.braintrust.dev/pricing',
  '2026-04-24',
  2
),

(
  'braintrust',
  'api',
  'Braintrust API 入門 — 評価・トレーシング',
  $md$
## Braintrust の始め方

### インストール & セットアップ

```bash
pip install braintrust autoevals
export BRAINTRUST_API_KEY="sk-..."
```

### LLM 関数を評価する

```python
import braintrust
from autoevals import Levenshtein, Factuality

# 評価したい関数を定義
def answer_question(input: str) -> str:
    from anthropic import Anthropic
    client = Anthropic()
    msg = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=512,
        messages=[{"role": "user", "content": input}]
    )
    return msg.content[0].text

# Braintrust で評価を実行
eval_result = braintrust.Eval(
    "AI大学 Q&A 評価",
    data=lambda: [
        {"input": "LangSmith とは？", "expected": "LangChain の LLM 観測プラットフォーム"},
        {"input": "Braintrust の特徴は？", "expected": "AI 観測・評価・Loop AI エージェント"},
    ],
    task=answer_question,
    scores=[Levenshtein, Factuality],
)
print(eval_result)
# → Braintrust UI でスコア・差分・トレースを確認可能
```

### プロダクショントレーシング

```python
import braintrust

# Anthropic トレーシング (自動)
from braintrust.wrappers import wrap_anthropic
from anthropic import Anthropic

client = wrap_anthropic(Anthropic())

with braintrust.start_span("ai-university-query"):
    response = client.messages.create(
        model="claude-opus-4-7",
        max_tokens=256,
        messages=[{"role": "user", "content": "AI大学で学べることは？"}]
    )
    braintrust.log(
        input="AI大学で学べることは？",
        output=response.content[0].text,
        scores={"quality": 0.9}
    )
```

### CI/CD 統合 (GitHub Actions)

```yaml
# .github/workflows/eval.yml
- name: Run Braintrust Eval
  run: |
    pip install braintrust autoevals
    python evals/test_ai_university.py
  env:
    BRAINTRUST_API_KEY: ${{ secrets.BRAINTRUST_API_KEY }}
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

## クイックスタート

1. `pip install braintrust autoevals` でインストール
2. `BRAINTRUST_API_KEY` を設定
3. `braintrust.Eval()` で評価セットを定義・実行
4. [braintrust.dev](https://www.braintrust.dev) の UI でスコア・トレースを確認
5. GitHub Actions に組み込んで自動回帰テストを有効化
$md$,
  'https://www.braintrust.dev/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
