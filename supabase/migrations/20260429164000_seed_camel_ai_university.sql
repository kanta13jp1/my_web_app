-- PS#3 S140: AI大学 374→375社化 — CAMEL (KAUST / 役割演技型マルチエージェント / 最初の大規模AI社会研究)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'camel', 'overview',
  'CAMEL (KAUST) — 役割演技型マルチエージェント・最初の大規模AI社会研究・Communicative Agents (9/9)',
  $$## CAMEL とは

**CAMEL** (Communicative Agents for "Mind" Exploration of Large Language Model Society) は **KAUST** (King Abdullah University of Science and Technology) が 2023年3月に発表した、**役割演技 (Role-Playing) によるマルチエージェント協調**の先駆的研究。

AutoGPT と同時期に公開され、「AI エージェント同士が役割を持って対話・協調する」アプローチを最初に体系化した論文として広く引用される。

## CAMEL の基本コンセプト: Inception Prompting

```
CAMEL の核心: Inception Prompting

  問題: 複数エージェントがどう協調するか？

  CAMEL の解決策:
    ・各エージェントに「役割」を与える
    ・AI_User と AI_Assistant の2種
    ・AI_User: 指示を出す役 (ユーザー側)
    ・AI_Assistant: 実行する役 (アシスタント側)
    ・両者とも LLM (人間は介在しない!)

  Inception Prompting とは:
    ・AI_User に「あなたは [役割A] として
      [AI_Assistant の役割B] に指示を出してください」
    ・AI_Assistant に「あなたは [役割B] として
      [AI_User の役割A] の指示に従ってください」
    ・この「役割の注入」で自律的な対話が始まる
```

## 役割演技の実際例

```python
from camel.agents import RolePlaying

# 役割設定
task = "Flutterでリアルタイムチャットアプリを作成する"

# 役割演技セッション開始
session = RolePlaying(
    assistant_role_name="Flutterエンジニア",
    user_role_name="プロダクトマネージャー",
    task_prompt=task,
    with_task_specify=True,  # タスクをより具体的に自動精緻化
    model_type="gpt-4"
)

# 自律的な対話が始まる
print("=== AI同士の対話 ===")
for i in range(20):  # 最大20ターン
    assistant_response, user_response = session.step(
        assistant_msg=session.init_chat()
    )

    print(f"[PM]: {user_response.msg.content}")
    print(f"[Engineer]: {assistant_response.msg.content}")

    # 終了条件チェック
    if session.is_done(assistant_response, user_response):
        break

# 出力例:
# [PM]: まずユーザー認証の要件を定義してください
# [Engineer]: Supabaseのauthを使い、email/passwordとGoogle OAuthに対応します
# [PM]: 次にリアルタイム機能の技術選定を...
# [Engineer]: Supabase Realtimeを採用。WebSocketで...
# (人間なしで開発計画が自律的に形成される)
```

## CAMEL のデータセット: AI社会の観察

```
CAMEL が構築したデータセット:

  camel-ai/camel データセット:
    ・50 役割 × 50 タスク = 2,500 対話
    ・AIが自律的に行った会話を記録
    ・研究用に公開 (Hugging Face)

  発見された興味深い現象:
    ・役割に没入するほど回答品質が向上
    ・AI_User が「人間らしい要求」を出す
    ・AI_Assistant が「プロの応答」を返す
    ・両者の「合意形成」パターンが出現

  役割の例:
    ・Stock Trader × Python Developer
    ・Mathematician × Programmer
    ・Doctor × Researcher
    ・Chef × Food Critic
```

## CAMEL フレームワークの進化

```
CAMEL (2023年3月) → CAMEL-AI 組織へ:

  camel-ai/camel OSS フレームワーク:
    ・Role-Playing Session
    ・Model: OpenAI / Anthropic / Gemini 対応
    ・Toolkits: Web Search / Code Execution / 他
    ・Multi-Modal: 画像・音声対応

  CAMEL Data Explorer:
    ・自律AI社会のデータ可視化
    ・対話パターンの分析ツール

  後継研究への影響:
    ・ChatDev: CAMEL の役割概念を発展
    ・MetaGPT: 固定役割をSOP化
    ・CrewAI: 商用化・プロダクション対応

  2024年: CAMEL-AI コミュニティ形成
    ・研究者・開発者の国際コミュニティ
    ・新しい役割・タスク・データセット追加
```

## 自分株式会社との関連

CAMEL の「役割演技 (Role-Playing) による AI 同士の対話」は、自分株式会社の 12 インスタンス fleet が日々実践していることそのもの。PS#3 が「AI大学コンテンツ専任」、Win版が「ドキュメント・設計専任」というように、各インスタンスに役割 (role) を与えて協調させる fleet 設計は CAMEL の Inception Prompting の実用版。CAMEL の研究データ (どの役割組み合わせが最も生産性が高いか) は、fleet の役割分担設計改善に活用できる。
$$,
  'https://github.com/camel-ai/camel',
  NOW(),
  375
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
