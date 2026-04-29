-- PS#3 S142: AI大学 378→379社化 — HumanEval (OpenAI / コード生成ベンチマーク / 164問 / pass@k評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'humaneval', 'overview',
  'HumanEval (OpenAI) — コード生成ベンチマーク・164問・pass@k評価・業界標準 (9/9)',
  $$## HumanEval とは

**HumanEval** は **OpenAI** の Mark Chen, Jerry Tworek, Heewoo Jun らが 2021年7月に発表した、**LLM のコード生成能力を評価する**手書きプログラミング問題集。

Codex (code-davinci-002) の論文 "Evaluating Large Language Models Trained on Code" と同時公開され、AI コーディング評価の **業界標準ベンチマーク** となった。

## HumanEval の設計

```
HumanEval の構成:

  問題数: 164 問
    ・Python 関数の実装
    ・関数シグネチャ + docstring を入力
    ・正しい実装を生成させる

  難易度分布:
    ・簡単: 文字列操作 / リスト処理 / 基本演算
    ・中程度: 再帰 / ソート / 探索
    ・難しい: 数学的推論 / アルゴリズム設計

  評価方式: pass@k
    ・k個の候補を生成
    ・1個でも全テストケースをパスすれば正解
    ・pass@1: 1回で正解 (精度重視)
    ・pass@10: 10回のうち1回正解 (上限)
    ・pass@100: 100回のうち1回正解 (理論上限)

  テストケース:
    ・各問題に平均 7.7 個のユニットテスト
    ・エッジケースを含む
    ・手動で作成 (自動生成なし)
```

## HumanEval のスコア推移

```
HumanEval pass@1 スコアの進化:

  2021年 (論文発表時):
    Codex (davinci-002): ~28.8%
    GPT-3 (175B):        ~0%
    → コード特化訓練の重要性を証明

  2022年:
    code-davinci-002:    ~47.0%
    text-davinci-003:    ~65.8%

  2023年:
    GPT-4:               ~67.0%
    Claude 2:            ~71.2%
    WizardCoder-34B:     ~73.2% (オープンソース)

  2024年:
    GPT-4o:              ~90.2%
    Claude 3.5 Sonnet:   ~92.0%
    DeepSeek-Coder:      ~87.6%
    Gemini 1.5 Pro:      ~84.1%

  2025年:
    Claude 3.7 Sonnet:   ~96.0%
    GPT-4.1:             ~95.3%
    → ほぼ飽和状態 → HumanEval+ / LiveCodeBench へ移行
```

## HumanEval の問題例

```python
# HumanEval 典型的な問題 (実際の問題#0):

def has_close_elements(numbers: List[float], threshold: float) -> bool:
    """ Check if in given list of numbers, are any two numbers closer to each
    other than given threshold.
    >>> has_close_elements([1.0, 2.0, 3.0], 0.5)
    False
    >>> has_close_elements([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3)
    True
    """
    # ← ここを LLM が生成する

# 正解例:
def has_close_elements(numbers: List[float], threshold: float) -> bool:
    for idx, elem in enumerate(numbers):
        for idx2, elem2 in enumerate(numbers):
            if idx != idx2:
                distance = abs(elem - elem2)
                if distance < threshold:
                    return True
    return False

# pass@1 評価:
# → 全テストケース (has_close_elements([1.0, 2.0, 3.0], 0.5) == False など) をパス?
# → Yes → 正解カウント
```

## pass@k 評価の仕組み

```python
# pass@k の計算式 (HumanEval 論文より)

import numpy as np

def pass_at_k(n: int, c: int, k: int) -> float:
    """
    n: 生成したサンプル数
    c: 正解したサンプル数
    k: 評価する k の値
    returns: pass@k の推定値
    """
    if n - c < k:
        return 1.0
    return 1.0 - np.prod(
        1.0 - k / np.arange(n - c + 1, n + 1)
    )

# 使用例:
# n=100サンプル生成して c=30個が正解の場合:
print(pass_at_k(100, 30, 1))   # pass@1  ≈ 0.300
print(pass_at_k(100, 30, 10))  # pass@10 ≈ 0.817
print(pass_at_k(100, 30, 100)) # pass@100 = 1.000 (30個正解があれば必ず正解)

# 実用上: pass@1 が最も厳しく、実際の精度に近い
```

## HumanEval の限界と後継ベンチマーク

```
HumanEval の限界:

  1. 飽和問題:
     ・2024年末に Claude/GPT-4o が ~90% 超
     ・もはや差がつかない
     ・→ より難しいベンチマークが必要

  2. Python のみ:
     ・多言語 (TypeScript/Java/Go/Rust) は HumanEval-X で対応
     ・Web 開発 / システムプログラミングは評価できない

  3. 単関数レベル:
     ・現実のタスクは複数ファイル・複数関数
     ・SWE-bench の方がリアルワールドに近い

後継ベンチマーク:
  ・HumanEval+:    テストケースを80倍に増強 (EvalPlus)
  ・MBPP:          Google / 500問 / より実用的
  ・LiveCodeBench: AtCoder/LeetCode/CF から継続更新
  ・BigCodeBench:  1,140問 / ライブラリ使用込み
  ・SWE-bench:     GitHub Issue解決 (より現実的)
```

## HumanEval と自分株式会社の関連

```
HumanEval スコア活用例:

  モデル選定の判断基準:
    ・Claude 3.5 Sonnet: HumanEval ~92%
    ・Claude 3 Haiku:    HumanEval ~75%

  → Haiku でも十分なタスク:
     ・Flutter widget の boilerplate 生成
     ・SQL INSERT 文の自動補完
     ・単純なユーティリティ関数

  → Sonnet が必要なタスク:
     ・複雑なアルゴリズム実装 (競馬予測ロジック)
     ・マルチファイル編集 (ai-hub EF の action 追加)
     ・バグ修正 (async safety guard)

  コスト最適化:
    ・HumanEval pass@1 スコアが高い = 単純コード生成は Haiku 委譲可
    ・AI振り分け早見表の「推奨モデル」の根拠データ
```

## HumanEval の位置づけ

```
コード生成ベンチマーク比較:

  HumanEval (OpenAI, 2021):
    ・164問 / Python関数 / pass@k
    → 「AIはコードを書けるか？」の最初の答え

  MBPP (Google, 2021):
    ・500問 / より多様なタスク
    → HumanEval と相補的

  SWE-bench (Princeton, 2023):
    ・2,294問 / GitHub Issue解決
    → 「AIはエンジニアになれるか？」

  LiveCodeBench (2024):
    ・競技プログラミング問題 / 継続更新
    → 「学習汚染なし」の最新評価

  → HumanEval は「コード生成 BM の Origin」
     現代の評価は SWE-bench + LiveCodeBench が主流
```
$$,
  'https://github.com/openai/human-eval',
  NOW(),
  379
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
