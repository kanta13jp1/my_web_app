-- PS#3 S139: AI大学 372→373社化 — Voyager (NVIDIA Research / Minecraftエージェント / スキル獲得型学習 / 生涯学習AI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'voyager', 'overview',
  'Voyager (NVIDIA Research) — Minecraftで生涯学習するAIエージェント・スキル獲得・自動カリキュラム (9/9)',
  $$## Voyager とは

**Voyager** は **NVIDIA Research** が 2023年5月に発表した、**Minecraft の世界で自律的にスキルを学習し続ける**画期的な AI エージェント。

「タスクを与えてこなすエージェント」ではなく、**「自分で学ぶべきことを見つけ、スキルを獲得し続ける」生涯学習エージェント**として設計されており、AI エージェントの「継続的学習」研究において最も引用される論文の一つ。

## なぜ Minecraft なのか

```
Minecraft がエージェント研究に最適な理由:

  オープンエンドな環境:
    ・決まった「ゴール」がない
    ・無限にやることがある
    ・探索→収集→製作→建築...の連鎖

  スキルが階層化:
    ・木を切る → 木材入手
    ・木材 → 作業台 → ツール → 採掘
    ・銅採掘 → 炉 → 銅インゴット → ...
    ・難易度が自然に段階的に増加

  測定可能な進捗:
    ・技術ツリーの到達度で学習を定量化
    ・「ダイヤ採掘できた」= 具体的な成果

  → Minecraft は「人工社会のシミュレーター」として最適
```

## Voyager の 3 コンポーネント

```
Voyager のアーキテクチャ:

  1. Automatic Curriculum (自動カリキュラム):
     ・現在のスキルレベルを評価
     ・「次に学ぶべきこと」を自動決定
     ・難しすぎず簡単すぎない課題を選択
     例: 木を持っている → 「作業台を作る」を次の目標に設定

  2. Skill Library (スキルライブラリ):
     ・成功したタスクを JavaScript コードとして保存
     ・過去のスキルを再利用・組み合わせ
     ・ベクトル検索で類似スキルを取得
     例: "move_to(x, y, z)" "craft_item('wooden_pickaxe')"

  3. Iterative Prompting (反復プロンプティング):
     ・GPT-4 でコードを生成
     ・Minecraft で実行 → エラーが出たら修正
     ・成功するまで反復改善
     ・成功したコードをスキルとして保存
```

## 実際の学習過程

```python
# Voyager の動作イメージ (概念的)
from voyager import Voyager

agent = Voyager(
    openai_api_key="...",
    mc_port=25565,  # Minecraft サーバーポート
    skill_library_dir="./skill_library"  # スキル保存先
)

# エージェントが自律的に実行する内容:
# 1. 現在状態を観察: "木の近くにいる。道具なし。"
# 2. 目標決定: "木を集めよう" (カリキュラムが提案)
# 3. コード生成:
#    async function collectWood(bot) {
#      const wood = bot.findBlock({matching: 'oak_log'});
#      await bot.dig(wood);
#    }
# 4. 実行 → 成功
# 5. スキル保存: "collectWood" をライブラリに追加
# 6. 次の目標: "作業台を作ろう" (木材が手に入ったので)
# 7. 過去スキル再利用 + 新スキル生成...

# 結果: 人間が何も指定しなくても
# 木材→ツール→採掘→鉱石製錬→...と自律進化
agent.learn(reset_env=False)
```

## Voyager の驚異的な性能

```
他のエージェントとの比較 (Minecraft ベンチマーク):

  ReAct (標準エージェント):
    ・技術ツリー到達度: 100 分間で ~3 マイルストーン
    ・スキルの蓄積なし
    ・毎回最初から始める

  Reflexion (反省ループ付き):
    ・~5 マイルストーン
    ・エラーから学ぶが記憶なし

  Voyager:
    ・~15+ マイルストーン (5倍以上!)
    ・新しいワールドでも過去スキルを活用
    ・ダイヤ採掘まで到達 (多くのエージェントは不可能)

  成功の要因:
    → スキルの永続化 (やり直しがない)
    → 自動カリキュラム (適切な難易度)
    → コード実行による確実性
```

## Voyager が示す「生涯学習」の可能性

```
研究的意義:

  従来の機械学習:
    ・事前学習 → デプロイ → 固定
    ・新しいタスクは再学習が必要

  Voyager のアプローチ:
    ・デプロイ後も継続的にスキルを獲得
    ・経験が蓄積されるほど賢くなる
    ・LLM の知識 + 実経験スキルの組み合わせ

  応用可能性:
    ・ロボット学習 (実環境での自律スキル獲得)
    ・ゲームAI (全ゲームで自動攻略)
    ・製造業ロボット (新作業の自律習得)
    ・ソフトウェアエンジニアリング AI (新ツールを自学習)
```

## 自分株式会社との関連

Voyager の「スキルライブラリ (成功パターンをコードで保存) + 自動カリキュラム (次に学ぶべきことを自動決定)」は、自分株式会社の Claude Code スキルシステム (`.claude/skills/`) と直接対応する。現在 `session-start-check` / `wrap-up` / `mobile-bug-triage` などのスキルを手動で作成しているが、Voyager パターンを応用すれば「成功した作業を自動的にスキルとして保存 → 次回から再利用」に進化できる。また `auto-curriculum` の考え方は、WBS の次タスク自動提案機能に活用できる。
$$,
  'https://github.com/MineDojo/Voyager',
  NOW(),
  373
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
