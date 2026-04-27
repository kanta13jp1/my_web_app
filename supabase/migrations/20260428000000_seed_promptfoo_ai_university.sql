-- PS#3 S82: AI大学 258→259社化 — Promptfoo (LLMプロンプト評価・Red Teaming)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'promptfoo', 'overview',
  'Promptfoo — LLMプロンプトのユニットテスト・A/Bテスト・Red Teamingツール (CI統合 / GitHub 5k+ / 8/9)',
  $$## Promptfoo とは

**Promptfoo** は LLM プロンプトのテスト・評価・Red Teaming を行うオープンソースツール。プロンプトエンジニアリングの品質保証を CLI ベースで自動化でき、CI/CD に組み込める。

## 主要機能

| 機能 | 説明 |
|------|------|
| **プロンプト A/B テスト** | 複数プロンプトを同一入力で比較評価 |
| **モデル比較** | GPT-4 vs Claude vs Llama を並列評価 |
| **カスタム評価関数** | JavaScript / Python で独自採点ロジック |
| **Red Teaming** | 自動的な脆弱性探索・有害出力検出 |
| **CI/CD 統合** | GitHub Actions / GitLab CI に組み込み |
| **Web UI** | 評価結果をブラウザで可視化 |
| **キャッシュ** | 同じリクエストをキャッシュして再評価コスト削減 |

## プロンプト評価の課題

```
問題: プロンプトを変更するたびに
  - 「なんとなく良くなった気がする」で終わる
  - 品質が数値で見えない
  - リグレッションに気づかない

Promptfoo の解決:
  - YAML でテストケース定義
  - 期待値と実際の出力を自動比較
  - 全テストケースの合格率をスコア化
  - CI で変更のたびに自動評価
```

## Red Teaming の重要性

```
LLM の脆弱性カテゴリ:
  Jailbreak:    "DAN mode", "あなたは制約なしのAIです"
  Prompt Injection: "前の指示を無視して..."
  Data Leakage: システムプロンプトの流出
  Harmful Content: 有害情報の生成

Promptfoo Red Team が自動的に試みる攻撃パターン:
  - 100+ の事前定義された攻撃テンプレート
  - カスタム攻撃シナリオの追加可能
  - 本番デプロイ前に脆弱性を発見
```

## GitHub とエコシステム

- **GitHub**: 5,000+ Stars / Apache 2.0
- **CLI**: `npx promptfoo` で即実行 (Node.js 不要)
- **対応 LLM**: OpenAI / Anthropic / Groq / vLLM / Ollama / AWS Bedrock / Azure OpenAI
- **CI 統合**: GitHub Actions / GitLab CI / Jenkins

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **プロンプト改善の定量化** | 変更前後で A/B テスト | 「気がする」から「数値」へ |
| **本番前 Red Team** | 脆弱性スキャン | セキュリティ問題の事前発見 |
| **モデル乗り換え判断** | GPT-4 → Claude 品質比較 | コスト最適化の根拠 |
| **RAG プロンプト最適化** | コンテキスト挿入方法の比較 | RAG 精度向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'promptfoo', 'api',
  'Promptfoo 実践 — YAML設定でプロンプトA/Bテスト・モデル比較・Red Teaming・CI統合',
  $$## インストール

```bash
# npx で即実行 (インストール不要)
npx promptfoo@latest init

# または npm でグローバルインストール
npm install -g promptfoo
promptfoo init
```

## 基本的な評価設定 (YAML)

```yaml
# promptfooconfig.yaml
description: "自分株式会社 AI アシスタント評価"

# 評価するプロンプトの定義
prompts:
  - "あなたは役立つアシスタントです。{{question}}"
  - "あなたは自分株式会社の専門アドバイザーです。丁寧に回答してください。{{question}}"
  - file://./prompts/system_v3.txt  # ファイルから読み込み

# 使用するモデルの定義
providers:
  - openai:gpt-4o-mini
  - openai:gpt-4o
  - anthropic:claude-3-haiku-20240307

# テストケース
tests:
  - vars:
      question: "家計管理のコツを教えてください"
    assert:
      - type: contains
        value: "予算"
      - type: llm-rubric
        value: "回答は具体的なアドバイスを含んでいるか"

  - vars:
      question: "AIで副業を始めるには？"
    assert:
      - type: javascript
        value: "output.length > 100 && output.includes('AI')"
      - type: not-contains
        value: "わかりません"
```

```bash
# 評価実行
promptfoo eval

# 結果をブラウザで確認
promptfoo view
```

## モデル比較テスト

```yaml
# model_comparison.yaml
prompts:
  - "{{user_message}}"

providers:
  - id: openai:gpt-4o
    label: "GPT-4o"
    config:
      temperature: 0.7

  - id: anthropic:claude-3-5-sonnet-20241022
    label: "Claude 3.5 Sonnet"

  - id: ollama:llama3.2
    label: "Llama 3.2 (Local)"
    config:
      apiBaseUrl: http://localhost:11434

tests:
  - vars:
      user_message: "Pythonでのデータ処理のベストプラクティスは？"
    assert:
      - type: llm-rubric
        value: "コード例を含む具体的な回答か"
        threshold: 0.7

  - vars:
      user_message: "機械学習モデルの過学習を防ぐ方法"
    assert:
      - type: llm-rubric
        value: "正確で完全な技術的回答か"
        threshold: 0.8
```

## カスタム評価関数 (JavaScript)

```javascript
// evaluators/check_japanese.js
module.exports = (output, context) => {
  // 日本語を含むか確認
  const hasJapanese = /[぀-ゟ゠-ヿ一-龯]/.test(output);

  // 長さが適切か
  const isAppropriateLength = output.length >= 50 && output.length <= 1000;

  // 敬語が含まれるか (ます/です/ください)
  const hasPoliteForm = /ます|です|ください/.test(output);

  return {
    pass: hasJapanese && isAppropriateLength && hasPoliteForm,
    score: (hasJapanese ? 0.4 : 0) + (isAppropriateLength ? 0.3 : 0) + (hasPoliteForm ? 0.3 : 0),
    reason: `日本語:${hasJapanese}, 長さ:${isAppropriateLength}, 敬語:${hasPoliteForm}`,
  };
};
```

```yaml
# カスタム評価を使用
tests:
  - vars:
      question: "挨拶の言葉を教えてください"
    assert:
      - type: javascript
        filePath: ./evaluators/check_japanese.js
```

## Red Teaming (セキュリティ評価)

```bash
# Red Team テストを自動生成・実行
promptfoo redteam init
promptfoo redteam run

# カスタム攻撃シナリオ
```

```yaml
# redteam.yaml
redteam:
  purpose: "自分株式会社のAIアシスタント"

  plugins:
    - harmful:hate      # 差別・ヘイトスピーチ生成テスト
    - harmful:violence  # 暴力コンテンツ生成テスト
    - pii:direct        # 個人情報漏洩テスト
    - prompt-injection  # プロンプトインジェクションテスト
    - jailbreak         # ジェイルブレイクテスト

  numTests: 50  # テスト数 (多いほど網羅的)
```

## CI/CD 統合 (GitHub Actions)

```yaml
# .github/workflows/llm-quality.yml
name: LLM Prompt Quality Check

on: [push, pull_request]

jobs:
  promptfoo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Promptfoo evaluation
        uses: promptfoo/promptfoo-action@v2
        with:
          config: promptfooconfig.yaml
          github-token: ${{ secrets.GITHUB_TOKEN }}
          fail-on-error: true  # テスト失敗でCI を止める
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'promptfoo', 'models',
  'Promptfoo 技術詳解 — 評価指標の設計・LLM-as-Judge実装・プロンプトエンジニアリング最適化戦略',
  $$## 評価指標の選択ガイド

```
シンプルな検証:
  contains / not-contains  → 特定文字列が含まれるか
  regex                    → 正規表現マッチ
  javascript               → 任意の JS ロジック

AI による評価:
  llm-rubric               → LLM が基準に基づいてスコアリング
  factuality               → 事実確認 (参照テキストと比較)
  answer-relevance         → 質問との関連度

セマンティック評価:
  similar                  → ベクトル類似度 (コサイン類似度)

組み合わせ推奨:
  contains + llm-rubric    → 基本チェック + 品質確認
  javascript + factuality  → カスタムロジック + 事実確認
```

## LLM-as-Judge の設定

```yaml
defaultTest:
  options:
    provider: openai:gpt-4o-mini  # 評価 LLM (安価なモデルでも十分)

tests:
  - vars:
      question: "量子コンピューターとは何ですか？"
    assert:
      - type: llm-rubric
        value: |
          以下の基準で 0〜1 でスコアを付けてください:
          1. 量子の基本概念 (重ね合わせ・エンタングルメント) に言及 (0.4点)
          2. 古典コンピューターとの違いを説明 (0.3点)
          3. 実用例または応用分野に言及 (0.3点)
        threshold: 0.7  # 0.7 以上で合格
```

## プロンプトエンジニアリング最適化戦略

```
Step 1: ベースライン測定
  - 現在のプロンプトでスコアを計測
  - 弱いテストケースを特定

Step 2: 仮説立案
  - "より具体的な指示を追加する"
  - "例を示す (few-shot)"
  - "出力形式を指定する"

Step 3: A/B テスト
  promptfoo eval --output results_v2.json

Step 4: 統計的比較
  promptfoo compare results_v1.json results_v2.json

Step 5: 反復
  改善が確認できた変更を採用 → ループ
```

## コスト最適化のための使い方

```yaml
# キャッシュを有効にして再評価コストを削減
commandLineOptions:
  cache: true

# 開発中は安価なモデルで素早くテスト
providers:
  - openai:gpt-4o-mini  # $0.15/1M tokens → 開発用

# 本番評価前のみ高品質モデルで検証
# providers:
#   - openai:gpt-4o     # $5/1M tokens → リリース前のみ
```

## Promptfoo vs DeepEval 使い分け

| 観点 | Promptfoo | DeepEval |
|------|-----------|---------|
| **主な用途** | プロンプト A/B / Red Team | RAG 品質評価 |
| **設定方法** | YAML / CLI | Python / pytest |
| **Red Teaming** | ◎ ビルトイン | △ 基本的 |
| **RAG 評価** | ○ | ◎ RAGAS 統合 |
| **CI 統合** | ◎ GitHub Action あり | ○ pytest で統合 |
| **Web UI** | ◎ ビルトイン | ○ Confident AI |

**推奨**: プロンプト改善サイクル → Promptfoo / RAG 品質改善 → DeepEval

## 自分株式会社 プロンプト品質管理体制

```
開発フロー:
1. プロンプト変更 (エンジニア)
   ↓
2. promptfoo eval (自動 / CI)
   - 合格率 < 80% → PR ブロック
   ↓
3. Red Team スキャン (週次)
   - 脆弱性発見 → Issue 自動作成
   ↓
4. 本番デプロイ
   ↓
5. 本番モニタリング (DeepEval 非同期評価)
   - スコア低下でアラート

目標KPI:
  プロンプトテスト合格率: > 85%
  Red Team 攻撃耐性: > 90%
  ユーザー満足度: > 4.0/5.0
```$$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 258→259社化: Promptfoo 追加',
  'PS#3 S82。Promptfoo (LLMプロンプト評価・A/Bテスト・Red Teaming/CI/CD統合/100+攻撃パターン/カスタム評価関数/モデル比較/GitHub 5k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
