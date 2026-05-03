-- PS#3 S148: AI大学 388→389社化 — SWE-bench Verified (Princeton/Stanford / 実GitHub Issues / コード修正能力 / Claude 3.5 Sonnet 初の50%超)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'swe_bench', 'overview',
  'SWE-bench Verified (Princeton/Stanford) — 実GitHub Issues修正・コード生成能力の業界標準ベンチマーク (10/10)',
  $$## SWE-bench とは

**SWE-bench** は **Princeton NLP / Stanford / 他研究機関** が 2023年11月に発表した、
**実際のGitHub Issueを解決できるか**を評価するLLMベンチマーク。
12の有名OSSリポジトリ（Django・scikit-learn・Flask・sympy等）から収集した
**2,294件の実タスク**をもとに、AI が実際に動くコードパッチを生成できるかを測定する。

## SWE-bench の設計背景

```
従来のコード生成ベンチマークの問題点:
  ・HumanEval / MBPP:
    - 単独関数を実装するタスク (ゼロから書く)
    - 実際の開発では「既存コードの修正」が大半
    - テストセット漏洩 (訓練データ汚染) が問題化
  ・合成タスクの限界:
    - 実際の依存関係・コンテキストなし
    - 真の「デバッグ力」が測れない

SWE-bench の解決策:
  ・実タスク収集:
    - GitHub の実際の Issue + Pull Request ペア
    - 既存のテストスイートで合否を自動判定
    - 漏洩リスク: リポジトリのコミット履歴から取得 → テスト汚染なし
  ・エンドツーエンド評価:
    - 問題文 (Issue) → コードパッチ生成 → テスト実行
    - 単純な補完ではなく「理解・推論・修正」を要求
```

## 評価タスク構成

| 項目 | 詳細 |
|------|------|
| 総タスク数 | 2,294 件（オリジナル） / 500 件（Verified サブセット） |
| 収集元リポジトリ | Django / Flask / scikit-learn / sympy / pytest / astropy 等 12 種 |
| 評価言語 | Python 100% |
| 判定方法 | 生成パッチ適用後、既存テストスイートでパス/フェイル |
| 評価指標 | % Resolved（テストが全パスしたタスク割合） |

## Verified サブセットとは

**SWE-bench Verified** は Anthropic と OpenAI が共同で設計した 500 件の精選サブセット：
- オリジナルの 2,294 件はノイズ（あいまいなタスク・複数正解あり）が多い
- **人手検証**: 各タスクを作業者が実際に解いてみて「解けるタスク」のみ選定
- Verified スコアが現在の業界標準比較指標

## スコア推移と記録

| モデル | SWE-bench Verified スコア | 達成時期 |
|--------|-------------------------|----------|
| GPT-4 (2023) | ~1.7% | 2023/11 |
| Claude 2 Haiku | ~3.8% | 2024/03 |
| SWE-agent (GPT-4) | 12.5% | 2024/04 |
| GPT-4o | 33.2% | 2024/07 |
| Claude 3.5 Sonnet | **50.8%** | 2024/10（初の50%超） |
| Claude 3.7 Sonnet | **70.3%** | 2025/02 |
| Claude Opus 4.7（推定） | ~80%+ | 2026/05 |

**Claude 3.5 Sonnet** が初めて 50% を超え、「実用的なコード修正 AI」の閾値を越えた
とされる歴史的なマイルストーン。

## なぜ SWE-bench が重要か

1. **実用性が高い**: 合成問題でなく実GitHub Issues → 実際の開発能力と相関
2. **リーダーボード効果**: Papers with Code で公開 → AI企業が競争的にスコアを更新
3. **Claude 差別化**: OpenAI GPT-4o を抜いて Claude 3.5 が初の50%超 → Claude の強みを証明
4. **Agentic AI評価**: コード修正はマルチステップ（理解→計画→実装→検証）を要求
   → 単純なLLM能力ではなくAgent能力の評価

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 学術研究 / AIベンチマーク学部 / コード生成・ソフトウェアエンジニアリング学科
- **関連プロバイダー**: HumanEval（関数レベル）/ SWE-bench（リポジトリレベル）/ LiveCodeBench（競技）
- **実用的示唆**: Claude Code（このプロジェクトで使用中）のエージェント能力がSWE-benchで実証済み
$$,
  'https://www.swebench.com/',
  '2023-11-01',
  90
)
ON CONFLICT (provider, category) DO NOTHING;
