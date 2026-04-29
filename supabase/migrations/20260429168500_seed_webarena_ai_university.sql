-- PS#3 S141: AI大学 376→377社化 — WebArena (CMU / Webナビゲーションベンチマーク / リアルサイト操作評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'webarena', 'overview',
  'WebArena (CMU) — Webナビゲーションベンチマーク・リアルサイト操作評価・812タスク (9/9)',
  $$## WebArena とは

**WebArena** は **Carnegie Mellon University** (CMU) の Shuyan Zhou, Frank F. Xu, Hao Zhu, Xuhui Zhou, Robert Lo, Abishek Sridhar, Xianyi Cheng, Tianyue Ou, Yonatan Bisk, Daniel Fried, Uri Alon, Graham Neubig らが 2023年7月に発表した、**AI エージェントが実際の Web サイトを操作するタスクを評価する**ベンチマーク。

「Webを自律操作できるAI」の性能を測る業界標準として、SWE-bench と並んでエージェント評価の双璧をなす。

## WebArena の設計

```
WebArena のタスク設計:

  環境 (実際のWebサイトを模したサーバー):
    ・Shopping (EC サイト / OneStopShop)
    ・CMS (コンテンツ管理 / GitLab 風)
    ・Reddit (掲示板 / Postmill)
    ・Map (地図 / OpenStreetMap)
    ・Wikipedia (情報検索)

  各タスクの構成:
    ・自然言語の指示: "商品Xの価格を Y に変更して"
    ・ブラウザ状態: URL + DOM スナップショット
    ・正解判定: 最終状態が期待値を満たすか

  規模:
    ・812 タスク (厳選・高品質)
    ・5 サイト × 多様なタスク種別

  難易度:
    ・複数ステップが必要なタスク
    ・例: "在庫切れ商品を 3 つ見つけて価格を 1 割引に設定して"
      → 検索 → リスト確認 → 各商品ページ → 価格編集 × 3
```

## WebArena のスコア推移

```
WebArena 解決率の進化:

  2023年初期:
    GPT-3.5 / GPT-4: ~10-15%
    ReAct: ~13.8%
    → Web 操作は AI に困難

  2024年:
    GPT-4V + SoM: ~18%
    Agent-E: ~73.2% (特化設計)

  2025年:
    Claude 3.5 Sonnet (Computer Use): ~70%+
    GPT-4o + Playwright Agent: ~60%+
    → 実用レベルに到達しつつある

  難しいタスクカテゴリ:
    ・複数サイトを跨ぐタスク
    ・動的コンテンツの変化を追跡
    ・CAPTCHA / セキュリティ対策
```

## WebArena のタスク例

```
WebArena タスクの具体例:

  Shopping タスク:
    "Find the cheapest product in the 'Camping & Hiking'
     category and add 5 units to the cart"
    → カテゴリページ → 価格ソート → 商品選択 → カート追加

  CMS タスク:
    "Create a new issue in the 'awesome-llm-apps' repo
     titled 'Add WebArena support' with label 'enhancement'"
    → リポジトリ移動 → Issues タブ → New Issue → 入力 → Submit

  Reddit タスク:
    "Find the post with the most comments in r/MachineLearning
     and reply 'Great discussion!'"
    → サブレディット → ソート変更 → 投稿開く → コメント入力

  Map タスク:
    "Find all coffee shops within 500m of CMU campus"
    → 検索 → 地図操作 → フィルタ → 結果確認
```

## WebArena の評価方法

```python
# WebArena の評価フロー (概念的)
from webarena import ScriptBrowserEnv, Evaluator

# ブラウザ環境を起動
env = ScriptBrowserEnv(
    headless=True,
    slow_mo=100,
    observation_type="accessibility_tree"  # DOM を木構造で取得
)

# タスクを設定
task = {
    "intent": "Find all 'Out of Stock' items on the Shopping site",
    "sites": ["shopping"],
    "eval": {
        "eval_types": ["string_match"],
        "reference_answers": ["item1", "item2", "item3"]
    }
}

# エージェントを実行
obs = env.reset(task)
done = False
while not done:
    # エージェントが次のアクションを決定
    action = agent.act(obs, task["intent"])
    obs, reward, done, info = env.step(action)

# 評価
evaluator = Evaluator()
score = evaluator.evaluate(
    trajectory=info["trajectory"],
    task=task,
    page=env.page
)
print(f"Task solved: {score > 0}")
```

## WebArena 派生・後継

```
WebArena エコシステム:

  WebArena-Lite:
    ・165 タスク (厳選)
    ・評価コスト削減版

  VisualWebArena:
    ・視覚的タスクを追加
    ・スクリーンショット + DOM
    ・画像認識が必要なタスク

  WorkArena:
    ・ServiceNow 上の業務タスク
    ・エンタープライズ向け
    ・IT 部門の自動化評価

  Mind2Web:
    ・より多様なサイト (137サイト)
    ・2,000+ タスク
    ・実際のクロールデータ使用

  AssistGUI:
    ・デスクトップ GUI タスク
    ・Windows / Mac アプリ操作
    ・Webに限らない評価
```

## 自分株式会社との関連

WebArena のタスク設計は、自分株式会社の「Manus AI によるブラウザ操作・外部SaaS確認」ユースケースと直結する。特に WebArena の Shopping タスク (EC サイト操作) は、競合 21 社のサイト変更監視 (`admin-hub:competitor.check`) と同型のタスク。WebArena のスコアで~70% を達成している Claude 3.5 Sonnet (Computer Use) は、自分株式会社の競合監視・Webスクレイピングタスクを Claude に委譲する判断材料になる。また WebArena の DOM/Accessibility Tree ベースの観測設計は、自分株式会社の Playwright テストの設計改善に活用できる。
$$,
  'https://github.com/web-arena-x/webarena',
  NOW(),
  377
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
