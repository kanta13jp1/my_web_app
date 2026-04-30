-- PS#3 S131: AI大学 357→358社化 — AutoGen (Microsoft / マルチエージェント会話 / ヒューマンインザループ)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'autogen', 'overview',
  'AutoGen (Microsoft) — マルチエージェント会話フレームワーク・Human-in-the-Loop・AG2 (9/9)',
  $$## AutoGen とは

**AutoGen** は Microsoft Research が開発したマルチエージェント会話フレームワーク。「エージェント同士が自然言語で会話しながら問題を解く」という独自のアーキテクチャが特徴で、**Human-in-the-Loop** (人間が途中で介入できる設計) を重視している。

2024年に **AutoGen v0.4** として大幅リアーキテクチャ。コミュニティ版は **AG2** として分岐している。

## AutoGen の会話型アーキテクチャ

```
AutoGen の独自設計:

  従来のエージェント:
    LLM → Tool → LLM → Tool → 完了
    (モノローグ型)

  AutoGen の会話型:
    Agent A ←→ Agent B (会話)
    Agent A ←→ Agent C (会話)
    Agent A ←→ Human (承認要求)
    (ダイアローグ型)

  → 会話ログが「エージェントの思考プロセス」として可視化
  → 人間が任意のステップで介入可能
```

## AutoGen の主要エージェントタイプ

```python
from autogen import AssistantAgent, UserProxyAgent, GroupChat

# AssistantAgent: LLM ベースのエージェント
assistant = AssistantAgent(
    name="Assistant",
    llm_config={
        "model": "gpt-4o",
        "api_key": "sk-..."
    }
)

# UserProxyAgent: 人間またはコード実行を代行
user_proxy = UserProxyAgent(
    name="User",
    human_input_mode="TERMINATE",  # 終了時のみ人間介入
    code_execution_config={
        "work_dir": "coding",
        "use_docker": False
    }
)

# 2エージェントで会話してタスクを解く
user_proxy.initiate_chat(
    assistant,
    message="フィボナッチ数列を計算するPythonコードを書いて実行して"
)

# → AssistantがコードをUserProxyに送信
# → UserProxyがコードを実行して結果をAssistantに返す
# → Assistantが結果を検証して改善
# → 自動ループ
```

## Human-in-the-Loop の設定

```python
# 人間介入モード
human_input_mode="ALWAYS"     # 毎回人間が承認
human_input_mode="NEVER"      # 完全自動 (人間不要)
human_input_mode="TERMINATE"  # 終了時のみ

# 実際のユースケース:
# 本番デプロイ前 → ALWAYS (人間が最終確認)
# ドキュメント生成 → NEVER (完全自動)
# コード PR 作成 → TERMINATE (完成後に人間確認)
```

## GroupChat: 多対多の会話

```python
# 複数エージェントで会議を開く
group_chat = GroupChat(
    agents=[planner, engineer, critic],
    messages=[],
    max_round=10,
    speaker_selection_method="auto"  # 誰が発言するか自動決定
)

manager = GroupChatManager(
    groupchat=group_chat,
    llm_config={"model": "gpt-4o"}
)

# 会議を開始
user_proxy.initiate_chat(
    manager,
    message="新機能のアーキテクチャを設計して"
)
```

## AutoGen v0.4 (AG2) の進化

```
AutoGen 進化の歴史:

  v0.1-v0.2 (2023): 基本的なマルチエージェント会話
  v0.3 (2024): GroupChat 安定化
  v0.4 (2024): 完全リアーキテクチャ
    ・非同期ファースト設計
    ・型安全な API
    ・AG2 コミュニティフォーク誕生
  AG2: コミュニティ主導の継続開発
    ・Microsoft から独立
    ・より頻繁なリリース
```

## Microsoft との統合

AutoGen は **Azure AI** / **Azure OpenAI** との統合が深く、Microsoft のエンタープライズ顧客向けに最適化されている。Copilot Studio との統合も進行中。

## 自分株式会社との関連

AutoGen の「Human-in-the-Loop」設計は、自分株式会社の AI 開発プロセスの根幹。`claude-agent-review.yml` (AI がコードレビューして → 人間が最終マージ判断) は AutoGen の `TERMINATE` モードと同一。12 インスタンスフリートの cross-instance-pr も「AI が提案 → 人間が承認」の Human-in-the-Loop パターン。
$$,
  'https://github.com/microsoft/autogen',
  NOW(),
  358
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
