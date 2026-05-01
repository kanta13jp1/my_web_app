-- PS#3 S147: AI大学 386→387社化 — MATH benchmark (UC Berkeley / 12.5k競技数学問 / 7科目 / o1 94% / NeurIPS2021)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'math_benchmark', 'overview',
  'MATH Benchmark (UC Berkeley) — 競技数学12.5k問・7科目・AMC/AIME難度・AI数学推論の最難関 (10/10)',
  $$## MATH Benchmark とは

**MATH** は **Dan Hendrycks** (UC Berkeley / Scale AI) らが 2021年 NeurIPS で発表した、**12,500問の競技数学ベンチマーク**。AMC・AIME レベルの難問を含む 7 科目で構成され、**GPT-3 では正答率わずか 5%** という衝撃的な結果から「AI の数学推論の壁」として広く認知された。2024年に o1 が 94% を達成したことで注目を集め直した。

## MATH の設計背景

```
従来の数学ベンチマークの問題点:
  ・GSM8K: 小学校算数 → GPT-4で飽和 (97%+)
  ・単純計算: 暗算レベル → LLM 得意分野
  ・選択式: ランダム25%のチャンスレベル

MATH の解決策:
  ・難度: AMC/AIME/オリンピック レベル
  ・形式: 自由記述 (選択肢なし) → ズル不可
  ・記号数学: LaTeX 形式の数式を含む解答
  ・多科目: 代数〜微積分まで広範囲
  ・難度5段階: 1(易)〜5(AIME難) で難易度明示

タスク例 (難度5):
  問: "Let f(x) = x^4 + ax^3 + bx^2 + cx + d.
       Given that all roots of f are negative integers,
       and a+b+c+d = 2009, find d."
  答: d = 2010 (VieteaTranslation + 条件式解法)
```

## データセット構成

```
MATH データセット:
  総問題数: 12,500問
    訓練データ: 7,500問
    テストデータ: 5,000問

  7つの科目分類:
    1. Prealgebra (前代数): 基礎計算・比率・整数
    2. Algebra (代数): 方程式・関数・多項式
    3. Number Theory (整数論): 素数・合同式・GCD
    4. Counting & Probability (組合わせ/確率)
    5. Geometry (幾何): 平面・立体・座標幾何
    6. Intermediate Algebra (中級代数): 複素数・行列
    7. Precalculus (微積前): 三角関数・極座標

  難度分布 (1〜5 レベル):
    Level 1: 最易 (~20%) AMC 入門相当
    Level 2: 初級 (~20%)
    Level 3: 中級 (~20%)
    Level 4: 上級 (~20%) AMC 10/12 相当
    Level 5: 最難 (~20%) AIME/オリンピック相当
```

## スコア推移と主要モデル

```
MATH テストスコア (全5000問):

  初期 (2021-2022):
    GPT-3 (few-shot):    4.5%  ← 衝撃的な低スコア
    GPT-3 (finetuned):   6.9%
    Minerva (62B):      33.6%  ← 数学専用学習で躍進
    Minerva (540B):     50.3%

  大規模モデル (2023):
    GPT-4 (2023-03):    42.2%
    Claude 3 Opus:      60.1%  ← Claude が GPT-4 超え
    Gemini Ultra:       53.2%
    Llama 3 (70B):      ~50%

  推論強化モデル (2024):
    GPT-4o:             76.6%
    Claude 3.5 Sonnet:  71.1%
    o1-preview:         85.5%
    o1 (full):          94.8%  ← ほぼ人間トップレベル
    o3-mini (high):     97.0%

  人間比較:
    高校生トップ層:     ~70%
    競技数学選手:       ~90%
    → o1/o3 が競技選手レベルに到達

  MATH-500 (人気サブセット: 各科目均等500問):
    評価効率 のため研究で広く使用
    GPT-4: ~42% / o1: ~95%
```

## MATH が測る能力

```
MATH の難しさの本質:

  必要な能力:
    1. 記号操作:
       LaTeX 形式の数式を正確に変換・展開
       例: \\frac{d}{dx}[x^n] = nx^{n-1}

    2. 多ステップ推論:
       平均7-12ステップの論理的証明
       → 途中でミスると完全不正解

    3. 戦略選択:
       複数の解法から最適を選ぶ
       例: 幾何 → 座標 vs 純幾何 vs 三角

    4. 数学的創造性:
       補助線 / 変数置換 / 対称性発見
       → 暗記ではなく創造的思考

    5. 正確な計算:
       Long division / 行列計算 / 積分
       → ケアレスミス 1つで失点

  GPT-3 で 5% だった理由:
    ・単語予測モデルは「数学的真実」を学習できない
    ・確率的生成 → 計算ミスが多発
    ・長い推論チェーンの維持が困難
    ・新しい問題組合せへの汎化不能

  o1 で 94% になった理由:
    ・強化学習で「正解まで考え続ける」能力獲得
    ・Chain-of-Thought を自律的に延長
    ・内部検証ループで計算ミスを修正
```

## Chain-of-Thought (CoT) との関係

```python
# MATH での CoT 効果 (概念的)

class MathSolver:
    """
    MATH ベンチマーク解法の進化

    直接回答 (Direct Answer) — GPT-3時代:
      問: "3x + 7 = 22 を解け"
      答: "x = 5"  # 合ってるが過程なし
      問題: 複雑な問題では 5% 正解

    Chain-of-Thought (CoT) — GPT-4時代:
      問: "同上"
      思考: "両辺から7を引くと 3x = 15
             両辺を3で割ると x = 5"
      答: "x = 5"
      改善: 42% 正解 (8倍向上!)

    Process Reward Model (PRM) — o1時代:
      問: "複雑なAIME問題"
      思考: 内部で100+ ステップの試行錯誤
            → 間違いを検出して別手法に切替
            → 答えを複数経路で検証
      答: "確信度付き解答"
      改善: 94% 正解
    """

    def solve_with_prm(self, problem):
        """Process Reward Model の核心"""
        attempts = []
        for strategy in self.enumerate_strategies(problem):
            solution = self.execute_strategy(strategy)
            reward = self.reward_model.evaluate_step(solution)
            if reward > THRESHOLD:
                attempts.append(solution)
        return self.verify_and_select_best(attempts)
```

## Minerva と数学専用学習

```
Minerva (Google / 2022) の MATH における革新:

  アプローチ:
    ・PaLM 540B を数学・理科論文データで追加学習
    ・Mathematical Web Pages + arXiv + 教科書
    ・LaTeX を ネイティブ入出力として扱う

  MATH スコア:
    PaLM 540B (一般学習):    8.8%
    Minerva 540B (数学学習): 50.3%  ← 5.7倍向上!

  示したこと:
    ・ドメイン特化学習が数学推論に劇的効果
    ・「数学的思考」は学習可能なスキル
    → o1 の基礎研究となった重要論文
```

## 自分株式会社との関連

MATH Benchmark の「記号数学推論」能力は、自分株式会社の家計管理機能に直接応用できる。複利計算・ROI 試算・ローン返済シミュレーションなど、**誤差ゼロを要求される金融計算**では GPT-4 (42%) より o1 系モデル (94%) の採用が望ましい。`daily-judgment` EF での財務アドバイスや `growth-weekly-digest` での成長率計算に高精度数学推論モデルを組み合わせることで、ユーザーへの信頼性向上が期待できる。また MATH の「難度5段階分類」設計は AI 大学のコンテンツ難易度管理 (入門→上級) の参考事例。
$$,
  'https://arxiv.org/abs/2103.03874',
  NOW(),
  387
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
