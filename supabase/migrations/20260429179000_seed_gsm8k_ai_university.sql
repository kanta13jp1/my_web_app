-- PS#3 S143: AI大学 381→382社化 — GSM8K (OpenAI / 小学校算数8k問 / 数学的推論 / Chain-of-Thought)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gsm8k', 'overview',
  'GSM8K (OpenAI) — 小学校算数8,500問・数学的推論・Chain-of-Thought評価・GPT-4 92% (9/9)',
  $$## GSM8K とは

**GSM8K** (Grade School Math 8K) は **OpenAI** の Karl Cobbe, Vineet Kosaraju, Mohammad Bavarian らが 2021年11月に発表した、**小学校レベルの算数文章題 8,500 問で LLM の数学的推論能力を評価する**ベンチマーク。

"Training Verifiers to Solve Math Word Problems" という論文と同時公開され、**Chain-of-Thought (CoT) prompting** の効果を実証した最も重要なベンチマークの一つ。「AI は数学の文章題を段階的に解けるか?」を問う。

## GSM8K の設計

```
GSM8K の構成:

  問題数: 8,500 問
    ・トレーニング: 7,473 問
    ・テスト:       1,319 問

  問題の特徴:
    ・小学校 (Grade School) レベルの算数
    ・2〜8 ステップの推論が必要
    ・四則演算 (+/-/×/÷) のみ
    ・自然言語の文章題 (word problems)
    ・プロの数学の教師が手動作成

  難易度設定の意図:
    ・大人には簡単 (10秒で解ける)
    ・しかし LLM には 2021年時点で難しかった
    ・「単純な計算」ではなく「文脈理解 + 多段階推論」が必要

  評価方式: exact match
    ・最終答えの数値が一致するか
    ・途中の計算式は不問 (ただし CoT 評価では重要)
```

## GSM8K のスコア推移と Chain-of-Thought

```
GSM8K スコアの進化 (accuracy %):

  2021年 (論文発表時):
    GPT-3 (175B) direct:      15.2%
    GPT-3 (175B) CoT:         35.0%  ← CoT で 2倍以上に向上
    Verifier (100 samples):   55.0%  ← 検証器で大幅向上

  2022年:
    code-davinci-002 CoT:     63.1%
    PaLM 540B CoT:            56.9%

  2023年:
    GPT-4 CoT:                92.0%  ← 人間並みの精度
    Claude 2 CoT:             88.0%
    Llama 2 70B CoT:          56.8%
    WizardMath-70B:           81.6%  (数学特化 fine-tune)

  2024年:
    Claude 3 Opus:            95.0%
    GPT-4o:                   96.4%
    Gemini Ultra:             94.4%
    Llama 3 70B:              93.0%

  2025年:
    Claude 3.7 Sonnet:        97.1%
    o1 (reasoning model):     99.1%  ← ほぼ飽和
    → MATH / AIME / Omni-MATH へ移行

  Chain-of-Thought の効果:
    ・direct: 答えだけ出力
    ・CoT:    "Step 1: ... Step 2: ... Therefore: ..."
    → CoT で GPT-3 が 15%→35% (2.3倍)
    → GPT-4 で CoT が必須技術として確立
```

## GSM8K の問題例

```
GSM8K 問題例:

簡単な問題:
  Q: "Janet has 3 more apples than Tom. Tom has 5 apples.
      How many apples does Janet have?"

  Direct answer: "8"
  CoT: "Tom has 5 apples.
        Janet has 3 more than Tom.
        5 + 3 = 8.
        Janet has 8 apples."

中程度の問題 (2-3ステップ):
  Q: "A store sells notebooks for $3 each and pens for $1.50 each.
      Sarah buys 4 notebooks and 6 pens.
      How much does Sarah spend in total?"

  CoT: "4 notebooks × $3 = $12
        6 pens × $1.50 = $9
        Total: $12 + $9 = $21
        Sarah spends $21."

難しい問題 (5-8ステップ):
  Q: "A train travels from City A to City B at 60 mph.
      The return journey at 40 mph takes 1 hour longer.
      How far apart are the cities?"

  CoT:
  "Let distance = d miles.
   Time A→B = d/60 hours.
   Time B→A = d/40 hours.
   B→A takes 1 hour longer:
   d/40 - d/60 = 1
   (3d - 2d) / 120 = 1
   d/120 = 1
   d = 120 miles."
```

## Chain-of-Thought と検証器 (Verifier)

```python
# GSM8K の評価: CoT + Verifier の実装例

def solve_gsm8k_with_cot(problem: str, model) -> str:
    # Step 1: Chain-of-Thought でステップごとに解く
    cot_prompt = f"""Solve the following math problem step by step.

Problem: {problem}

Solution:
Step 1:"""

    solution = model.generate(cot_prompt, max_tokens=512)

    # 最終答えを抽出
    answer = extract_final_answer(solution)
    return answer, solution

def solve_with_verifier(problem: str, model, verifier) -> str:
    # Step 2: 複数の解答候補を生成
    candidates = []
    for _ in range(100):  # 100個の解答を生成
        answer, chain = solve_gsm8k_with_cot(problem, model)
        candidates.append((answer, chain))

    # Step 3: 検証器で最良の解答を選ぶ
    scores = verifier.score(problem, candidates)
    best_answer = candidates[scores.argmax()][0]
    return best_answer

# GSM8K 論文の主要発見:
# - CoT alone:          GPT-3 35%
# - Verifier (n=1):     GPT-3 43%
# - Verifier (n=100):   GPT-3 55%
# → 検証器 + 多数決が重要 = o1 の前身発想
```

## GSM8K が証明したこと

```
GSM8K の主要な発見:

  1. CoT は多段階推論に必須:
     ・direct prompting では GPT-3 は 15%
     ・CoT で 35% → 思考過程を書かせることで大幅向上
     ・→ "Let's think step by step" プロンプトの発明に繋がる

  2. モデルサイズと CoT の相互作用:
     ・小さいモデル: CoT の効果が薄い
     ・100B+ モデル: CoT で急激に性能向上
     ・→ emergent ability の最初の実証例の一つ

  3. 検証器 (Verifier) の重要性:
     ・生成 × 検証の分離 = 精度向上
     ・→ OpenAI o1 の「思考する前に検証する」設計の先祖

  4. 算数は「簡単に見えて難しい」:
     ・人間の子供が解ける問題をAIが解けなかった
     ・→ LLM の数学的推論能力の体系的改善を促した
```

## GSM8K の後継ベンチマーク

```
数学推論ベンチマーク系統:

  GSM8K (OpenAI, 2021):
    ・小学校算数 / 8,500問 / CoT
    → 飽和 (2024年末)

  MATH (Hendrycks, 2021):
    ・高校〜大学数学 / 12,500問
    ・7分野 (代数/幾何/確率/etc.)
    ・GPT-4 ~42% → Claude 3.7 ~80%

  AIME (数学オリンピック):
    ・米国数学招待試験 / 難問
    ・GPT-4o ~9% → o1 ~74%

  Omni-MATH (2024):
    ・4,428問 / 数学オリンピック級
    ・GPT-4 ~5% → o1-preview ~60%

  → GSM8K は「数学推論 BM の Origin」
     現代評価は MATH / AIME / Omni-MATH が主流
```

## 自分株式会社との関連

GSM8K の「多段階推論 + 検証」設計は、自分株式会社の AI 機能に直接応用できる。競馬予測 (`netkeiba-hub`) での複数ボーナス計算の積み上げ (confidence 計算 = GSM8K 型多段推論)、家計管理 (MoneyForward 競合機能) での収支計算、WBS タスク工数見積もり (`tools-hub:wbs`) など。特に GSM8K の Verifier アプローチ (複数候補生成→検証→最良選択) は、AI 大学コンテンツの品質確認フロー (Generator-Verifier パターン) に対応する。GSM8K が飽和して o1 型モデルが台頭した歴史は、自分株式会社のモデル選定において reasoning model (o1/claude-3.7) の採用を検討する根拠になる。
$$,
  'https://github.com/openai/grade-school-math',
  NOW(),
  382
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
