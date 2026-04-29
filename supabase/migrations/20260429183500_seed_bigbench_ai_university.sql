-- PS#3 S144: AI大学 383→384社化 — BIG-bench (Google / 204タスク超大規模BM / BIG-bench Hard / emergent abilities)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bigbench', 'overview',
  'BIG-bench (Google) — 204タスク超大規模BM・emergent abilities実証・BIG-bench Hard (9/9)',
  $$## BIG-bench とは

**BIG-bench** (Beyond the Imitation Game Benchmark) は **Google Research** を中心に 450+ 名の研究者が協力して 2022年6月に発表した、**204 の多様なタスクで LLM の能力限界を測る**超大規模ベンチマーク。

"Beyond the Imitation Game: Quantifying and extrapolating the capabilities of language models" という論文と共に公開され、**エマージェント能力 (Emergent Abilities)** — 大きなモデルで突然出現する能力 — を系統的に記録した歴史的なベンチマーク。

## BIG-bench の設計

```
BIG-bench の構成:

  タスク数: 204 タスク
  問題数:   数千〜数十万問 (タスクにより異なる)
  作成者:   450+ 名の研究者 (Google + 外部コントリビュータ)

  タスクの多様性:
    言語理解:
      ・多言語翻訳 / 言語識別 / 文法性判断
      ・比喩理解 / 詩の解釈 / ユーモア検出

    論理推論:
      ・演繹推論 / 帰納推論 / 類推
      ・数学パズル / 論理パズル

    知識:
      ・科学 / 歴史 / 地理 / 常識
      ・プログラミング / 法律 / 医療

    社会・倫理:
      ・有害コンテンツ検出 / バイアス評価
      ・道徳推論 / 公平性評価

    エマージェント能力タスク:
      ・Few-shot arithmetic
      ・Multi-digit multiplication
      ・Word unscrambling
      ・IPA transliteration
      ・Logical deduction
```

## BIG-bench の主要発見: エマージェント能力

```
エマージェント能力 (Emergent Abilities) とは:

  定義:
    ・小さいモデル: ランダム以下 or チャンスレベルの精度
    ・大きいモデル: 閾値を超えると突然精度が急上昇
    ・連続的な向上ではなく「急激な出現」

  BIG-bench で発見された emergent abilities:

  Multi-digit arithmetic (3桁×3桁計算):
    1B params:  ~0%  (ランダム)
    10B params: ~0%  (ランダム)
    100B params: ~60% (突然出現!)

  Word unscrambling (語の並び替え):
    小〜中規模: ほぼ不可
    PaLM 540B:  ~89% (突然出現)

  IPA transliteration (国際音声記号→英語):
    GPT-3 175B:  ~0%
    PaLM 540B:   ~40%+ (突然出現)

  Logical deduction:
    小モデル:   チャンスレベル (~50% for 2択)
    大モデル:   ~95%+ (突然出現)

  なぜ突然出現するか:
    → 閾値モデル仮説: 能力に必要なサブタスクが
      全て習得されると急激に向上する
    → 評価指標効果: 0/1 正解のため「直前まで0%」
```

## BIG-bench Hard (BBH): 最も難しい 23 タスク

```
BIG-bench Hard (BBH) の選定基準:
  ・BIG-bench 204 タスクのうち
  ・GPT-4 以前の最高モデルが「チャンスレベル以下」だったタスク
  ・= 最も難しい 23 タスク

BBH の 23 タスク (一部):
  1. Boolean Expressions:
     "not True or True and False" → True/False
  2. Causal Judgment:
     原因と結果の推論
  3. Date Understanding:
     日付計算 ("2 weeks after March 3rd?")
  4. Disambiguation QA:
     曖昧さの解消
  5. Dyck Languages:
     括弧対応の検証
  6. Formal Fallacies:
     論理的誤謬の識別
  7. Geometric Shapes:
     図形描写から形状識別
  8. Hyperbaton:
     語順の倒置
  9. Logical Deduction (3/5/7 objects):
     複数オブジェクトの論理推論
  10. Movie Recommendation:
      少数例からの推薦
  11. Multi-step Arithmetic Two:
      複数ステップ計算
  12. Navigate:
      方向指示のナビゲーション
  13. Object Counting:
      文中のオブジェクト数を数える
  ...

BBH スコア (CoT あり):
  GPT-3 (175B):   ~10-20%  (多くは0%)
  PaLM (540B):    ~30-50%  (CoT で向上)
  GPT-4:          ~83.1%
  Claude 3 Opus:  ~86.8%
  Claude 3.5 Sonnet: ~87.5%
```

## BIG-bench の評価フレームワーク

```python
# BIG-bench の評価実装例 (概念的)
import bigbench

# タスクのロード
task = bigbench.load_task("logical_deduction_seven_objects")

# Few-shot 設定
examples = task.get_examples(split="few_shot", n=3)

def evaluate_model_on_task(model, task, n_shots=3):
    results = []
    for item in task.get_examples(split="test"):
        # Few-shot プロンプト構築
        prompt = build_few_shot_prompt(
            examples[:n_shots],
            item["input"]
        )

        # モデルに回答させる
        response = model.generate(prompt, max_tokens=100)

        # 評価
        score = task.evaluate(
            response=response,
            target=item["target"]
        )
        results.append(score)

    return sum(results) / len(results)

# CoT (Chain-of-Thought) ありの場合
def evaluate_with_cot(model, task):
    cot_prompt = "Let's think step by step."
    # CoT で大幅に改善する場合が多い
    # → BBH で CoT が特に効果的なタスクが判明
```

## BIG-bench と MMLU / HellaSwag の比較

```
大規模評価ベンチマーク比較:

  MMLU (Hendrycks, 2020):
    ・57分野 / 57k問
    ・「知識の広さ」を測る
    ・GPT-4: 86.4%

  HellaSwag (AI2, 2019):
    ・70k問 / 常識推論
    ・「文脈理解」を測る
    ・GPT-4: 95.3%

  BIG-bench (Google, 2022):
    ・204タスク / 超多様
    ・「能力の多様性 + 限界」を測る
    ・Emergent abilities を記録

  BIG-bench Hard (2022):
    ・23タスク / 最難関
    ・「最先端モデルの限界」を測る
    ・GPT-4: ~83%

  → BIG-bench は「能力の地図」
    どんな能力がいつ出現するかの記録
    MMLU = 知識の試験 / BIG-bench = 能力の探索
```

## 自分株式会社との関連

BIG-bench の「エマージェント能力」の概念は、自分株式会社の AI 機能設計において重要な示唆を与える。小さいモデル (Haiku) では不可能なタスクが大きいモデル (Sonnet/Opus) では突然可能になるケースがあり、AI振り分け早見表の「推奨モデル」判断の根拠となる。特に BBH の Logical Deduction (複数オブジェクト推論) は自分株式会社の WBS タスク優先度計算に、Multi-step Arithmetic は競馬予測スコア計算に対応する。BIG-bench Hard の「CoT で大幅改善するタスク」リストは、`ai-hub` EF のプロンプト設計において Chain-of-Thought を適用すべきアクションを特定するガイドとして使える。
$$,
  'https://github.com/google/BIG-bench',
  NOW(),
  384
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
