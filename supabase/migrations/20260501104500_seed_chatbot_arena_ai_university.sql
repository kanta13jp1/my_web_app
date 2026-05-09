-- PS#3 S147: AI大学 387→388社化 — Chatbot Arena (LMSYS/UC Berkeley / クラウドソースELO / 1M+投票 / 業界標準)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'chatbot_arena', 'overview',
  'Chatbot Arena (LMSYS/UC Berkeley) — クラウドソースELO・1M+人間投票・チャットモデル業界標準ランキング (10/10)',
  $$## Chatbot Arena とは

**Chatbot Arena** (旧 LMSYS Chatbot Arena) は **LMSYS Org** (UC Berkeley の研究グループ) が 2023年4月に公開した、**人間の好みに基づくLLM評価プラットフォーム**。ユーザーが 2 つの匿名モデルと同時にチャットし、どちらの回答が優れているかを投票する「ブラインド A/B テスト」方式で、**1,000,000 回以上の人間評価**を蓄積した。**ELO レーティング**を用いた「Arena Score」が事実上の業界標準ランキングとなっている。

## Chatbot Arena の設計背景

```
従来の LLM 評価の問題点:
  ・自動ベンチマーク (MMLU/HellaSwag 等):
    - 学術的だが実用性との乖離
    - テストセット汚染 (訓練データに含まれる可能性)
    - 「実際に使いやすいか」を測れない
  ・GPT-4 as Judge (MT-Bench 等):
    - GPT-4 の評価バイアス (自社モデル優遇?)
    - コスト高 / スケール困難

Chatbot Arena の解決策:
  ・人間が評価者:
    - 実際のユーザーが「どちらが好きか」を選ぶ
    - バイアスのない多様なユーザー層
    - 実用性 (面白さ / 流暢さ / 役立ち度) を直接測定
  ・ブラインド評価:
    - モデル名を隠す → ブランドバイアス排除
    - ユーザーは純粋に内容で判断
  ・大規模データ:
    - 1M+ 投票 → 統計的信頼性確保
    - 継続的更新 → 最新モデルも評価可能
```

## ELO レーティングシステム

```python
# Chatbot Arena の ELO 計算 (簡略版)

class ArenaRating:
    """
    Bradley-Terry モデルに基づく Elo 計算

    チェスで使われる Elo を LLM 評価に応用:
    - 各モデルに初期スコア 1000 を付与
    - 勝敗のたびにスコアを更新
    - 強いモデルへの勝利 = 大きなスコア上昇
    """

    K_FACTOR = 32  # スコア変動の最大幅

    def expected_score(self, rating_a: float, rating_b: float) -> float:
        """モデル A が勝つ期待確率"""
        return 1 / (1 + 10 ** ((rating_b - rating_a) / 400))

    def update_ratings(
        self,
        winner_rating: float,
        loser_rating: float
    ) -> tuple[float, float]:
        """勝敗後のレーティング更新"""
        expected_win = self.expected_score(winner_rating, loser_rating)

        # 勝者のスコア上昇
        new_winner = winner_rating + self.K_FACTOR * (1 - expected_win)
        # 敗者のスコア下降
        new_loser = loser_rating + self.K_FACTOR * (0 - (1 - expected_win))

        return new_winner, new_loser

    def confidence_interval(self, n_battles: int, rating: float) -> tuple:
        """
        ブートストラップで 95% 信頼区間を計算
        → 少ない対戦数のモデルは幅広い CI
        """
        ...

# 実際の Arena Score 例 (2024年時点):
# GPT-4o:          1287
# Claude 3.5 Sonnet: 1271
# Gemini 1.5 Pro:  1261
# GPT-4-Turbo:     1257
# Claude 3 Opus:   1251
# Llama 3 70B:     1213
# Mistral Large:   1158
```

## MT-Bench との関係

```
同一チーム (LMSYS) が開発した補完的な評価:

MT-Bench:
  ・自動評価: GPT-4 が審査員
  ・80問の多ターン質問 (8カテゴリ)
  ・カテゴリ: 推論/数学/コーディング/抽出/STEM/人文/
              ロールプレイ/作文
  ・スコア: 1〜10 (GPT-4 採点)
  ・メリット: 再現性高い / コスト低い / カテゴリ別分析
  ・限界: GPT-4 バイアス / 最新モデルへの対応遅れ

Chatbot Arena:
  ・人間評価: 実ユーザーが審査員
  ・オープンエンド質問 (無制限カテゴリ)
  ・スコア: ELO レーティング
  ・メリット: 実用性直接測定 / バイアス少 / 大規模
  ・限界: 再現性低い / 特定タスク評価困難

両者の組み合わせ:
  Arena Score 上位 ≒ MT-Bench 上位 (相関: ~0.8)
  → どちらか単独より組み合わせが信頼性高い
```

## Chatbot Arena が発見した知見

```
Chatbot Arena の主な発見 (2023-2024):

  1. GPT-4 の圧倒的優位 (2023 初期):
     GPT-4 vs GPT-3.5: 人間は 60:40 で GPT-4 を好む
     → 「GPT-4 は確実にGPT-3.5より優れる」を人間規模で確証

  2. Claude の競争力:
     Claude 3 Opus が GPT-4-Turbo と同水準
     → Anthropic の技術力を業界に示す

  3. オープンソースの台頭:
     Llama 3 70B が GPT-3.5-Turbo を上回る
     → 「オープンモデルは商用に劣る」神話の崩壊

  4. ロールプレイ / 創作での格差:
     特定タスクでは小型モデルが大型に勝つケース
     → タスク特化チューニングの重要性

  5. 言語別格差:
     英語 > 日本語 >> アラビア語 の傾向
     → 多言語アリーナ (multi-lingual arena) の必要性

  言語別 Arena (2024 〜):
     日本語 / 中国語 / 韓国語 等で別途集計開始
     → 多言語での実力差を可視化
```

## 評価プロセスとユーザー参加

```
Chatbot Arena の使い方:

  参加方法 (誰でも無料):
    1. https://arena.lmsys.org にアクセス
    2. 質問を入力 (何でも可)
    3. 2つの匿名モデルから同時に回答を受け取る
    4. どちらが良かったか投票 (A 勝ち / B 勝ち / 引き分け)
    5. モデル名が公開される

  質問ジャンルの分布 (ユーザー自由入力):
    コーディング:   ~25%
    一般的な質問:   ~20%
    創作・ライティング: ~15%
    推論・数学:     ~12%
    ロールプレイ:   ~10%
    日本語等非英語: ~8%
    その他:        ~10%

  品質管理:
    ・スパム検出 (同一 IP の過多投票)
    ・意図的操作検出 (特定モデルへの偏向投票)
    ・最低質問長 フィルタ
```

## 業界への影響

```
Chatbot Arena が変えたもの:

  AI 企業のベンチマーク戦略:
    Before: 「MMLU XX% 達成!」を宣伝
    After:  「Arena Score 1250 超え!」を宣伝
    → Arena Score が実質的な PR 指標に

  モデル開発の方向性:
    Before: 学術ベンチマーク最適化
    After:  人間が「使いたい」と思う回答の最適化
    → RLHF (人間フィードバック強化学習) の重要性再認識

  オープンソース評価の民主化:
    → Hugging Face Open LLM Leaderboard と並ぶ
      コミュニティ主導の評価基盤
    → 大企業以外も公平に評価される

  引用数: 2,500+ (2024年)
  NeurIPS 2023 採択
```

## 自分株式会社との関連

Chatbot Arena の「ユーザーが実際に好む回答」という視点は、自分株式会社の AI アシスタント改善に直接応用できる。`ai-assistant` EF に採用するモデルを選ぶ際、Arena Score 上位モデルを優先することで**実際のユーザー満足度**を最大化できる。また、自分株式会社独自の「ミニ Arena」を実装し、ユーザーが AI 回答を評価する仕組み (`daily-judgment` EF の投票機能拡張) を追加することで、自社サービス専用のモデルランキングを蓄積できる。Arena の「ブラインド評価」設計は、`cs-check` EF での FAQ 品質評価にも応用可能。
$$,
  'https://arxiv.org/abs/2306.05685',
  NOW(),
  388
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
