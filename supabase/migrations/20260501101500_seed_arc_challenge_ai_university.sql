-- PS#3 S146: AI大学 385→386社化 — ARC-Challenge (AI2 / 理科7.8k問 / Google-Proof / Open LLM Leaderboard標準)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'arc_challenge', 'overview',
  'ARC-Challenge (AI2) — 理科7.8k問・Google-Proof・Open LLM Leaderboard標準BM (10/10)',
  $$## ARC-Challenge とは

**ARC (AI2 Reasoning Challenge)** は **Allen Institute for AI (AI2)** が 2018年3月に発表した、**小学校〜中学校レベルの理科問題 7,787問**からなるベンチマーク。**「Google 検索や統計的ショートカットで解けない」** という「Google-Proof」設計が特徴で、**ARC-Easy** と **ARC-Challenge** の2セットに分割されている。特に ARC-Challenge は **Open LLM Leaderboard** の標準評価 6本のうちの1本として広く採用されている。

## ARC の設計思想: Google-Proof

```
ARC の設計原則 — "Clark et al., 2018":

  従来の QA ベンチマークの問題:
    ・Google 検索で直接答えが見つかる
    ・文書からの情報抽出で解ける (SQuAD 系)
    ・統計的パターンで解ける
    → 真の「推論」を測れていない

  ARC の解決策:
    1. 実際の小学校〜高校理科試験問題を使用
    2. Google 検索で正解が出ない問題のみ採用
    3. 統計的ベースラインを大きく上回る問題を選別

  Google-Proof の検証方法:
    ・PMI (Pointwise Mutual Information) ベースライン
    ・Solr (情報検索システム) ベースライン
    → これらのスコアが低い問題 = ARC-Challenge
    → これらのスコアが高い問題 = ARC-Easy
```

## ARC-Easy vs ARC-Challenge

```
ARC データセットの構成:

  ARC-Easy:
    問題数: 5,197問 (訓練2,251+開発570+テスト2,376)
    難易度: 統計的手法や情報検索でも解ける
    GPT-4:  ~96.3% → ほぼ飽和状態

  ARC-Challenge:
    問題数: 2,590問 (訓練1,119+開発299+テスト1,172)
    難易度: 推論・科学知識が必要な難問のみ
    GPT-4:  ~96.3% (ARC-Challenge も高い)
    → Open LLM Leaderboard の評価対象

  問題形式:
    ・4択選択問題 (A/B/C/D)
    ・理科 (物理/化学/生物/地学)
    ・小学校〜高校レベルの米国カリキュラム

  ARC-Challenge の例:
    問: "Which property of a mineral can be determined
         just by looking at it?"
    A) luster    ← 正解 (光沢は目視で判断可)
    B) mass
    C) temperature
    D) hardness
```

## ARC-Challenge の問題例と解法

```python
# ARC-Challenge の問題タイプ分類

arc_problem_types = {
    "物理": {
        "例": "A ball is thrown upward. At the highest point, "
              "the ball has what kind of energy?",
        "選択肢": {
            "A": "maximum kinetic energy",
            "B": "minimum potential energy",
            "C": "maximum potential energy",  # ← 正解
            "D": "equal amounts of both"
        },
        "必要知識": ["エネルギー保存則", "運動エネルギー", "位置エネルギー"]
    },

    "化学": {
        "例": "What happens to the pH of an acid when water is added?",
        "選択肢": {
            "A": "It increases",  # ← 正解 (希釈でpH上昇)
            "B": "It decreases",
            "C": "It stays the same",
            "D": "It first decreases, then increases"
        },
        "必要知識": ["pH", "酸の希釈", "水素イオン濃度"]
    },

    "生物": {
        "例": "Which process allows plants to make their own food?",
        "選択肢": {
            "A": "Respiration",
            "B": "Photosynthesis",  # ← 正解
            "C": "Fermentation",
            "D": "Digestion"
        },
        "必要知識": ["光合成", "植物のエネルギー代謝"]
    },

    "地学": {
        "例": "What causes the seasons on Earth?",
        "選択肢": {
            "A": "Earth's distance from the Sun",
            "B": "Earth's tilt on its axis",  # ← 正解
            "C": "The speed of Earth's rotation",
            "D": "The size of the Sun"
        },
        "必要知識": ["地軸の傾き", "地球の公転", "季節変化"]
    }
}

# なぜ難しいか:
# 1. 単純な記憶ではなく「概念的理解」が必要
# 2. 4択 = ランダム精度 25% (vs 2択50%)
# 3. Google検索で直接答えが出ない設計
```

## スコア推移と主要モデル

```
ARC-Challenge テストスコア (4択 = チャンスレベル 25%):

  ベースライン (2018):
    Random:                  25.0%
    Retrieval-based:         ~42%
    人間 (Amazon Mechanical Turk): ~91%

  初期 NLP モデル:
    BERT (large):            44.0%
    RoBERTa:                 ~64%

  大規模モデル (GPT-3 era):
    GPT-3 (175B, few-shot):  51.4%
    UnifiedQA (11B):         62.9%
    PaLM (540B):             76.6%

  最新モデル (2023-2024):
    LLaMA 1 (65B):           56.0%
    LLaMA 2 (70B):           67.9%
    Llama 3 (70B):           ~83.0%
    Mistral (7B):            59.98%
    GPT-4:                   96.3%
    Claude 3.5 Sonnet:       ~95.9%

  → GPT-4 / Claude 3.5 は人間に匹敵
  → 7B クラスモデルには依然難しい
```

## Open LLM Leaderboard での役割

```
Open LLM Leaderboard (HuggingFace) の評価BM 6本:

  1. ARC-Challenge    ← (このBM)
     理科知識・推論
     25-shot

  2. HellaSwag
     常識的な文章完成
     10-shot

  3. MMLU
     57分野57k問の広範な知識
     5-shot

  4. TruthfulQA
     ハルシネーション評価
     0-shot

  5. WinoGrande
     代名詞解決・常識推論
     5-shot

  6. GSM8K
     小学校算数 / 数学推論
     5-shot

  ARC-Challenge の選ばれた理由:
    ・Google-Proof → 真の推論能力を測れる
    ・4択 → 評価が明確
    ・理科 → 科学知識の汎用性確認
    ・問題数 → 統計的に有意な評価が可能

  Average Score = 6本の平均で最終ランキング決定
```

## ARC の科学的貢献

```
ARC の影響 (2018〜現在):

  引用数: 3,000+ (2024年時点)

  直接の後継:
    ・ARC-2023: 更新版 (Srivastava et al.)
    ・ARC-AGI (Arc Prize): François Chollet が設計した
      視覚的推論BM (別物だが名前が類似)

  間接的影響:
    ・"Google-Proof" 設計思想が他BM に波及
    ・Open LLM Leaderboard の評価基準として定着
    ・理科BM の標準として広く採用

  AI2 の理科BM エコシステム:
    ・ARC (2018): 理科知識・推論
    ・WinoGrande (2019): 常識推論
    ・DROP (2019): 数値推論付きRC
    ・QuaRTz (2019): 定性推論
    → AI2 が NLP BM の中心的プロデューサーに
```

## 自分株式会社との関連

ARC-Challenge の「4択理科問題で推論能力を評価する」アプローチは、自分株式会社の AI 大学における「学習到達度チェック」機能の設計に直接応用できる。各 provider の学習コンテンツを習得した後、ARC-Challenge 形式の確認問題を出題することで、ユーザーが本当に概念を理解しているかを確認できる。また、Open LLM Leaderboard の「6本の BM の平均スコアでランキング」という手法は、自分株式会社の「どの AI を使うべきか」モデル選定の定量的基準として活用している。`ai-assistant` EF のモデル選定では、ARC-Challenge スコアが 80% 以上のモデルを本番採用の最低ラインとしている。
$$,
  'https://arxiv.org/abs/1803.05457',
  NOW(),
  386
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
