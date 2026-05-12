-- PS#3 S142: AI大学 379→380社化 — MMLU (UC Berkeley / Hendrycks et al. / 57分野57k問 / 多タスク言語理解)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mmlu', 'overview',
  'MMLU (UC Berkeley) — 57分野57,000問・多タスク言語理解・GPT-4 86.4%・業界標準 (9/9)',
  $$## MMLU とは

**MMLU** (Massive Multitask Language Understanding) は **UC Berkeley** の Dan Hendrycks, Collin Burns, Steven Basart らが 2020年9月に発表した、**57の学術分野にわたる57,000問以上の多肢選択問題で LLM の知識と推論能力を評価する**包括的ベンチマーク。

「人間が持つべき幅広い知識を AI は持っているか?」を問う、GPT-4 論文でも中心的評価指標として採用された**業界最重要ベンチマーク**の一つ。

## MMLU の設計

```
MMLU の構成:

  総問題数: 14,042 問 (テスト) / 57,000+ 問 (全体)
  問題形式: 4択多肢選択問題
  分野数:   57 カテゴリ

  分野の内訳:
    STEM (理数系):
      ・Abstract Algebra (抽象代数)
      ・Anatomy (解剖学)
      ・Astronomy (天文学)
      ・College Biology / Chemistry / Mathematics / Physics
      ・Computer Security / Conceptual Physics
      ・Electrical Engineering / Elementary Mathematics
      ・High School Biology / Chemistry / Computer Science
      ・High School Mathematics / Physics / Statistics
      ・Machine Learning
      ・Medical Genetics / Microbiology
      ・Nutrition / Virology

    人文・社会科学:
      ・Econometrics / Economics (Macro/Micro)
      ・Global Facts / International Law
      ・Jurisprudence / Logical Fallacies
      ・Management / Marketing
      ・Moral Disputes / Moral Scenarios
      ・Philosophy / Political Science
      ・Professional Accounting / Business Ethics
      ・Public Relations / Sociology
      ・US Foreign Policy / World Religions

    医療・法律・専門:
      ・Clinical Knowledge
      ・Human Aging / Human Sexuality
      ・Medical Genetics / Medical Knowledge (?)
      ・Professional Law / Medicine / Psychology
      ・Security Studies

  難易度:
    ・各分野とも高校生〜大学院レベルの問題
    ・専門家の判断を要する問題も含む
```

## MMLU のスコア推移

```
MMLU スコアの進化 (5-shot accuracy):

  2021年 (論文発表時):
    GPT-3 (175B):          43.9%
    人間の専門家平均:       89.8%
    → GPT-3 はほぼランダム回答レベル

  2022年:
    Flan-PaLM 540B:        59.6%
    Chinchilla:            67.5%

  2023年:
    GPT-4:                 86.4% ← 論文発表時の最高点
    Claude 2:              78.5%
    PaLM 2-L:              78.3%
    Llama 2 70B:           68.9%

  2024年:
    Claude 3 Opus:         86.8%
    GPT-4o:                88.7%
    Gemini Ultra:          90.0%
    Claude 3.5 Sonnet:     88.7%
    Llama 3 70B:           82.0%

  2025年:
    Claude 3.7 Sonnet:     90.0%+
    GPT-4.5:               ~91%
    → 90%台に突入 → MMLU-Pro / GPQA へ移行

  人間の参考値:
    ・5-shot (=4択問題の例題ありで):
      一般人平均: ~34.5%
      大学卒業生: ~55%
      専門家:    89.8%
```

## MMLU の問題例

```
MMLU 問題例 (Machine Learning カテゴリ):

Q: "Which of the following is a supervised learning algorithm?"
  A) K-means clustering
  B) Principal Component Analysis
  C) Random Forest ← 正解
  D) t-SNE

Q: "What is the purpose of dropout regularization?"
  A) To increase model complexity
  B) To reduce overfitting by randomly deactivating neurons ← 正解
  C) To speed up training
  D) To normalize the input data

医療分野の問題例 (Clinical Knowledge):
Q: "Which antibiotic is used to treat Helicobacter pylori infection?"
  A) Amoxicillin ← 正解 (他の抗菌薬との組合せで使用)
  B) Tetracycline
  C) Vancomycin
  D) Gentamicin

法律分野の問題例 (Professional Law):
Q: "Under the Fifth Amendment, which of the following rights is protected?"
  A) Right to bear arms
  B) Protection against self-incrimination ← 正解
  C) Freedom of speech
  D) Protection against unreasonable searches
```

## MMLU の評価方法

```python
# MMLU 評価の実装 (5-shot 評価の概念)

from datasets import load_dataset
from transformers import pipeline

def evaluate_mmlu(model, subject="machine_learning"):
    dataset = load_dataset("cais/mmlu", subject)
    test_data = dataset["test"]

    # 5-shot: 5つの例を few-shot として提示
    few_shot_examples = dataset["dev"].select(range(5))

    correct = 0
    total = 0

    for item in test_data:
        # プロンプト構築
        prompt = build_5shot_prompt(few_shot_examples) + f"""
Question: {item['question']}
A) {item['choices'][0]}
B) {item['choices'][1]}
C) {item['choices'][2]}
D) {item['choices'][3]}
Answer:"""

        # モデルに回答させる
        response = model.generate(prompt, max_new_tokens=1)
        predicted = extract_choice(response)  # A/B/C/D を抽出

        # 正誤判定
        correct_answer = ["A", "B", "C", "D"][item['answer']]
        if predicted == correct_answer:
            correct += 1
        total += 1

    return correct / total  # accuracy

# 全57分野の平均を取る
all_scores = {}
for subject in MMLU_SUBJECTS:
    all_scores[subject] = evaluate_mmlu(model, subject)
average_score = sum(all_scores.values()) / len(all_scores)
print(f"Overall MMLU accuracy: {average_score:.1%}")
```

## MMLU の後継ベンチマーク

```
MMLU 飽和への対応:

  MMLU-Pro (2024):
    ・10択 (4択 → 10択に変更)
    ・より複雑な推論問題
    ・GPT-4o が ~72.6% (同モデルで MMLU より低い)

  GPQA (Google-Proof QA, 2023):
    ・448問 / 博士レベル (生物・化学・物理)
    ・「Google で検索しても解けない」問題
    ・Claude 3.7 Sonnet ~71% / 専門家 ~65%
    ・→ AI が専門家を超えた最初の証拠

  ARC-Challenge (2018):
    ・Science 問題 / 簡単な MMLU 代替
    ・小規模モデルの評価に使用

  AGIEval (2023):
    ・人間向け公式試験 (SAT/LSAT/GRE)
    ・より現実的な知識評価

  → MMLU は「知識評価 BM の Origin」
     現代の評価は GPQA / MMLU-Pro が主流
```

## 自分株式会社との関連

```
MMLU スコア活用例:

  モデル選定の補完情報:
    ・HumanEval = コード生成能力
    ・MMLU       = 一般知識・推論能力
    ・両方で高スコア = 汎用 AI として信頼できる

  自分株式会社での具体的活用:
    ・CS 返信 (customer support):
      MMLU Medical/Law/Business が高い → 正確な回答
    ・AI 大学コンテンツ生成:
      MMLU の分野知識 = AI大学の説明精度
    ・競合分析レポート:
      MMLU Econometrics/Marketing → ビジネス分析精度

  コスト最適化への示唆:
    ・Haiku 4.5: MMLU ~75% (日常タスクは十分)
    ・Sonnet 4.6: MMLU ~88% (専門的判断が必要な場合)
    ・Opus 4.7: MMLU ~90%+ (最高精度が必要な場合)

  SECOND_BRAIN との連携:
    ・memory/ のコンテンツ品質 = 実質的な MMLU スコアに比例
    ・高精度モデルで memory/ を整備 → 全セッションの精度向上
```
$$,
  'https://github.com/hendrycks/test',
  NOW(),
  380
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
