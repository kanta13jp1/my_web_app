-- PS#3 S146: AI大学 384→385社化 — WinoGrande (AI2 / 44k問 / 代名詞解決 / AFLite / GPT-4 87.5%)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'winogrande', 'overview',
  'WinoGrande (AI2) — 44k大規模代名詞解決BM・AFLiteで難化・常識推論の金字塔 (10/10)',
  $$## WinoGrande とは

**WinoGrande** は **Allen Institute for AI (AI2)** が 2019年7月に発表した、**44,000問の大規模代名詞解決ベンチマーク**。Winograd Schema Challenge (WSC) の難点「問題数が少なすぎる」を解決するために設計され、**AFLite (Adversarial Filtering)** で既存 NLP モデルへのショートカット学習を排除した高品質なベンチマーク。

## WinoGrande の設計背景

```
従来の Winograd Schema Challenge (WSC) の問題点:
  ・問題数: 273問のみ (少なすぎてモデル選別に不十分)
  ・問題の多様性: 限定的 / 特定パターンに偏り
  ・バイアス: ショートカット学習に脆弱

WinoGrande の解決策:
  ・問題数: 44,000問 (約161倍!)
  ・クラウドソーシング: 多様な執筆者
  ・AFLite: 敵対的フィルタリングで偏り除去
  ・2択選択式: シンプルで評価しやすい形式

タスク形式:
  文: "The trophy doesn't fit into the brown suitcase
       because it's too small."
  問: "What does 'it' refer to?"
  選択肢:
    A: the trophy
    B: the brown suitcase
  正解: B (suitcase が小さすぎる)
```

## AFLite (Adversarial Filtering Lite)

```python
# AFLite の仕組み (概念的)

class AFLite:
    """
    WinoGrande の品質を保証する敵対的フィルタリング

    目的: 表面的な手がかりで解ける問題を除去し
          真の常識推論を必要とする問題のみ残す
    """

    def filter(self, questions, model_ensemble):
        """
        複数の軽量モデルが解けてしまう問題を除外
        """
        surviving_questions = []

        for question in questions:
            # 複数のシンプルなモデルで評価
            model_scores = []
            for model in model_ensemble:
                score = model.predict(question)
                model_scores.append(score)

            # 多くのモデルが正解できる = ショートカット存在
            # → 除外
            avg_score = sum(model_scores) / len(model_scores)

            if avg_score < THRESHOLD:  # モデルが苦手な問題のみ残す
                surviving_questions.append(question)

        return surviving_questions

# 結果:
# 元の問題数: ~67,000問
# AFLite後:   44,000問 (約34%除去)
# → 除去された問題 = ショートカットで解ける簡単問題
# → 残った問題 = 真の常識推論が必要な難問
```

## WinoGrande のデータセット構成

```
WinoGrande データセット:

  総問題数: 44,000問
    訓練データ: 40,398問
    開発データ:  1,267問
    テストデータ: 1,767問

  訓練データのサイズバリアント:
    xs:   160問  (Few-shot 研究用)
    s:    640問
    m:   2,558問
    l:   5,120問
    xl: 10,234問
    full: 40,398問

  問題の構造:
    ・文: 代名詞を含む自然文
    ・空所: 代名詞が指す対象を問う
    ・選択肢: 必ず2択
    ・文脈: 常識的な知識で解ける

  難易度の工夫:
    ・twin-sentence pairs: 1つの文に対して
      2つの正解が異なる対問を作成
      例:
        文A: "Daniel picked up the ball and put it in the box
              because ____ was empty." → box
        文B: "Daniel picked up the ball and put it in the box
              because ____ was full."  → ball
    → 表面的な手がかりを除去
```

## スコア推移と主要モデル

```
WinoGrande テストスコア (2-択 = チャンスレベル 50%):

  ベースライン:
    ランダム:         50.0%
    人間専門家:       94.0%

  初期モデル (2019-2020):
    GPT-2 (117M):     52.0%  (ほぼランダム)
    BERT (large):     59.4%
    RoBERTa (large):  71.3%

  大規模モデル (2020-2022):
    GPT-3 (175B):     70.2%  (few-shot)
    PaLM (540B):      81.1%
    Chinchilla:       74.9%

  最新モデル (2023-2024):
    GPT-4:            87.5%
    Claude 3 Opus:    ~88.0%
    Claude 3.5 Sonnet: ~88.5%
    Llama 3 (70B):    ~83.7%

  → GPT-4 でも人間 (94%) に届かない難関BM
  → 常識推論の「最後の壁」の1つ
```

## WinoGrande が測る能力

```
WinoGrande の難しさの本質:

  必要な常識知識:
    1. 物理常識:
       "The ball rolled off the table because it was steep."
       → "it" = table (テーブルが急勾配)

    2. 社会常識:
       "Tom passed the gun to Adam. He was afraid."
       → 文脈から誰が怖いか推論

    3. 因果関係:
       "The surgeon was talking to the patient.
        She was explaining the risks."
       → "She" = surgeon (外科医が説明する)

    4. 時間・空間関係:
       "When Alice finished the book, she put it
        on the shelf because it was done."
       → "it" = book (本が完成した)

  なぜ難しいか:
    ・単語の共起統計だけでは解けない
    ・文脈全体の理解が必要
    ・世界知識と言語理解の統合が必要
    ・AFLiteで「ズル」できない
```

## WinoGrande の影響と後継

```
WinoGrande の学術的貢献:

  NLP への影響:
    1. WSC の実用化:
       273問 → 44,000問で実用的評価が可能に
    2. AFLite 手法の確立:
       → 他ベンチマークの品質管理に応用
    3. Few-shot learning の研究促進:
       → xs/s/m/l/xl 分割で学習効率の研究

  引用数: 2,000+ (2024年時点)

  後継・関連BM:
    ・WinoDict: 辞書知識での解釈可能性
    ・Winogrande-Arabic: 多言語拡張
    ・WinoMT: 機械翻訳への応用

  Open LLM Leaderboard での位置:
    ・AI Reasoning の標準評価BM 6本のうちの1本
    ・ARC, HellaSwag, MMLU, TruthfulQA と並列評価
```

## 自分株式会社との関連

WinoGrande の「代名詞が指す対象を推論する」能力は、自分株式会社の AI チャット機能において重要な示唆を持つ。ユーザーが「それ」「これ」「あれ」と指示語を使う場合、前後の文脈から参照対象を正確に特定できるかが、自然な会話品質を左右する。WinoGrande スコアの高いモデル (Claude 3.5 Sonnet / GPT-4) を `ai-assistant` EF に採用している理由の一つがこの能力。また、AFLite の「敵対的フィルタリングで品質保証」アプローチは、自分株式会社の `cs-check` EF での FAQ 品質管理 (誤った回答のパターンを除去するフィルタリング) に応用できる設計思想。
$$,
  'https://arxiv.org/abs/1907.10641',
  NOW(),
  385
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
