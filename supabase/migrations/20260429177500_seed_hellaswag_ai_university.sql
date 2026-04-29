-- PS#3 S143: AI大学 380→381社化 — HellaSwag (AI2/UW / 常識推論ベンチマーク / 70k問 / Winogrande派生)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hellaswag', 'overview',
  'HellaSwag (AI2/UW) — 常識推論ベンチマーク・70k問・文章補完・GPT-4 95.3% (9/9)',
  $$## HellaSwag とは

**HellaSwag** は **Allen Institute for AI (AI2)** および **University of Washington** の Rowan Zellers, Ari Holtzman, Yonatan Bisk, Ali Farhadi, Yejin Choi らが 2019年5月に発表した、**LLM の常識的な文脈理解・推論能力を評価する**多肢選択ベンチマーク。

"HellaSwag: Can a Machine Really Finish Your Sentence?" という論文タイトル通り、「AIは文章の続きを常識的に完成させられるか?」を問う。名前は "Harder Endings, Longer contexts, and Low-shot Activities for Situations With Adversarial Generations" の略。

## HellaSwag の設計

```
HellaSwag の構成:

  問題数: 70,000 問 (トレーニング: 39,905 / バリデーション: 10,042 / テスト: 10,003)
  問題形式: 4択多肢選択 (文章の続きを選ぶ)
  難易度: BERT 等の既存モデルを「だます」ように設計

  問題の種類:
    ActivityNet (活動説明):
      ・Wikihow 等の活動説明文の続き
      ・例: 料理の手順 / スポーツの説明 / 家事の手順

    WikiHow (手順説明):
      ・ステップバイステップの手順説明
      ・正解は自然な次のステップ
      ・不正解は文法的に正しいが意味が外れる文

  解答選択肢の特徴:
    ・正解: 常識的に正しい次のアクション/文
    ・不正解 (adversarial): 言語的に自然だが意味が外れる
    ・BERT はこれを区別できない (85.6%) ← 人間は 95.6%
    ・→ 当時の BERT の限界を実証した歴史的ベンチマーク
```

## HellaSwag のスコア推移

```
HellaSwag (acc_norm) スコアの進化:

  2019年 (論文発表時):
    BERT-Large:     47.3%  ← 人間との差が大きい
    GPT-2:          ~50%
    人間:           95.6%

  2020-2021年:
    GPT-3 (175B):   78.9%
    PaLM (540B):    83.4%

  2022-2023年:
    PaLM 2-L:       86.8%
    GPT-4:          95.3%  ← 人間に並ぶ
    Claude 2:       ~89%
    Llama 2 70B:    87.3%

  2024年:
    Claude 3 Opus:  ~95.4%
    GPT-4o:         ~95.6%  ← 人間超え
    Gemini Ultra:   87.8%
    Llama 3 70B:    88.0%

  2025年:
    → ほぼ飽和状態 (GPT-4系・Claude 3以降は全て 95%+)
    → より難しい WinoGrande / ARC / CommonsenseQA へ移行
```

## HellaSwag の問題例

```
HellaSwag 問題例 (ActivityNet カテゴリ):

Context: "A man is at the gym doing exercises with his arms.
          He then goes to a pull-up bar and starts doing pull-ups."

続きを選べ:
  A) "He does several pull-ups and then drops to the floor."  ← 正解
  B) "He takes off his shoes and starts dancing in the gym."  ← 不正解 (脈略なし)
  C) "He writes a letter to his friend about the gym."       ← 不正解 (全く関係ない)
  D) "The gym equipment starts floating in the air."         ← 不正解 (物理的に不可能)

HellaSwag の巧妙な点:
  ・不正解選択肢は文法的に正しく、英語として自然
  ・だが文脈から見ると全く場違い
  ・文章の表面的パターンだけを学習したモデルは騙される

WikiHow カテゴリ例:
Context: "How to make scrambled eggs. Step 1: Crack eggs into a bowl.
          Step 2: Whisk the eggs."

続きを選べ:
  A) "Step 3: Heat butter in a pan over medium heat."  ← 正解
  B) "Step 3: Plant the eggs in the garden to grow."   ← 不正解
  C) "Step 3: Use the bowl to play basketball."        ← 不正解
  D) "Step 3: Drink the raw eggs directly."            ← 不正解 (可能だが非常識)
```

## HellaSwag と敵対的データ生成 (AFLite)

```python
# HellaSwag のデータ生成手法 (AFLite: Adversarial Filtering)

# 概念的な擬似コード
def create_hellaswag_dataset(source_data: list[str]) -> list[dict]:
    dataset = []

    for context in source_data:
        # 1. 正解の続きを取得
        correct_continuation = get_next_sentence(context)

        # 2. 不正解候補を生成 (GPT-2 で生成)
        wrong_candidates = gpt2.generate(
            context,
            num_samples=100,
            temperature=1.0
        )

        # 3. AFLite で「強力なモデルが正解できる不正解」を除外
        # → 残ったのは「モデルが騙される高難度の不正解」
        hard_negatives = []
        for candidate in wrong_candidates:
            bert_score = bert.predict([context, candidate])
            if bert_score < 0.5:  # BERT が不正解と判定できる → 簡単すぎて除外
                continue
            hard_negatives.append(candidate)

        # 4. 最終的に 3 つの hard negative を選択
        dataset.append({
            "context": context,
            "correct": correct_continuation,
            "wrong": hard_negatives[:3]
        })

    return dataset

# → 結果: BERT は 47% しか解けない難問集
#   → しかし GPT-4 では 95% → AIの常識推論が急進化を証明
```

## HellaSwag の位置づけと後継

```
常識推論ベンチマーク比較:

  HellaSwag (AI2/UW, 2019):
    ・70k問 / 文章補完 / 常識的継続
    ・BERT の限界を実証 → LLM 時代の幕開け
    → 「AIは文脈を理解できるか?」

  WinoGrande (AI2, 2019):
    ・44k問 / 代名詞解決 / Winograd Schema
    ・例: "The trophy won't fit in the suitcase because IT is too big."
    → 「AIはコモンセンスで代名詞を解決できるか?」

  ARC-Challenge (AI2, 2018):
    ・1,172問 / 理科問題 / 小学校〜中学校
    ・Google で検索しても解けない問題を厳選
    → 「AIは科学的推論ができるか?」

  CommonsenseQA (TAU, 2019):
    ・12,102問 / 常識的QA / ConceptNet ベース
    → 「AIは知識グラフの常識を使えるか?」

  → HellaSwag は「常識推論 BM の標準」として今でも引用される
     GPT-4 が人間に並んだ最初の BM の一つ
```

## 自分株式会社との関連

HellaSwag の「文脈的継続性」評価は、自分株式会社の AI 機能における自然な対話フローに直結する。特に `ai-assistant` EF の会話コンテキスト維持、CS 返信 (`reply-support-request`) での文脈に沿った返信生成、AI 大学コンテンツの自然な説明文生成において、HellaSwag 高スコアモデル（Claude 3.5 Sonnet ~95%+）を採用することでユーザーにとって不自然な回答を避けられる。また HellaSwag の AFLite 手法（adversarial filtering）は、自分株式会社のテストデータ生成において「モデルを騙す難問」を自動生成するアプローチとして応用可能。
$$,
  'https://github.com/rowanz/hellaswag',
  NOW(),
  381
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
