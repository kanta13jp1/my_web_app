-- PS#3 S137: AI大学 368→369社化 — AgentVerse (OpenBMB/清華大学 / マルチエージェントシミュレーション / 役割ベース協調)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'agentverse', 'overview',
  'AgentVerse (OpenBMB/清華大学) — マルチエージェントシミュレーション・役割ベース協調・動的チーム編成 (9/9)',
  $$## AgentVerse とは

**AgentVerse** は **OpenBMB** (Open Big Model Base / 清華大学 NLP Lab 発) が開発した、複数の AI エージェントが**役割を持って協調し、シミュレーション環境で問題を解決する**マルチエージェントフレームワーク。

「エージェントの社会」をシミュレーションすることで、単一エージェントでは解決困難な複雑なタスクに対応する。

## AgentVerse の設計思想

```
AgentVerse のコアコンセプト:

  エージェント社会のシミュレーション:
    ・各エージェントが人間のように役割を持つ
    ・エージェント同士がコミュニケーション
    ・集合知で複雑な問題を解く

  動的チーム編成 (Dynamic Recruitment):
    ・タスクに応じて必要なエージェントを招集
    ・専門スキルを持つエージェントを自動選択
    ・チームを動的に拡大・縮小

  OpenBMB との連携:
    ・ChatGLM / MiniCPM などのオープンモデルと統合
    ・ローカル LLM 対応
    ・エンタープライズプライバシー対応
```

## AgentVerse のアーキテクチャ

```
AgentVerse のコンポーネント:

  Agent (エージェント個体):
    ・Role (役割): 医者・弁護士・エンジニアなど
    ・Memory: 短期・長期記憶
    ・Tools: 使用可能なツールセット
    ・LLM Backend: GPT-4 / ChatGLM / 任意

  Environment (環境):
    ・エージェントが活動する仮想空間
    ・Rule Engine: 環境のルールを定義
    ・Task Manager: タスクの割り当て・進捗管理

  Selector (選択器):
    ・どのエージェントが発言するかを制御
    ・ラウンドロビン / 優先度付き / 自由発言
    ・Human-in-the-Loop 組み込み可

  Visibility (可視性):
    ・全エージェント公開 vs 一部のみ
    ・プライベートチャンネル対応
    ・情報の非対称性をシミュレート
```

## 実際のコード例

```python
from agentverse import AgentVerse
from agentverse.agents import ConversationAgent

# エージェントを定義
agents = [
    ConversationAgent(
        name="プロダクトマネージャー",
        role_description="ユーザーニーズを分析し、機能要件を定義する",
        llm_config={"model": "gpt-4"},
        tools=["web_search"]
    ),
    ConversationAgent(
        name="シニアエンジニア",
        role_description="技術的な実装方法を提案し、工数を見積もる",
        llm_config={"model": "gpt-4"},
        tools=["code_executor"]
    ),
    ConversationAgent(
        name="デザイナー",
        role_description="UI/UX を設計し、ユーザー体験を最適化する",
        llm_config={"model": "gpt-4"}
    ),
    ConversationAgent(
        name="QAエンジニア",
        role_description="テスト計画を立て、品質を保証する",
        llm_config={"model": "gpt-4"}
    )
]

# 環境を設定してシミュレーション開始
agentverse = AgentVerse(
    agents=agents,
    task="Flutter Web アプリにリアルタイム通知機能を追加する計画を立てる",
    max_rounds=10,
    visibility="all"  # 全エージェントが全会話を見える
)

# 実行
result = agentverse.run()
print(result.final_output)
# 各エージェントの視点を統合した実装計画が出力される
```

## Dynamic Recruitment の仕組み

```python
# 動的なエージェント招集の例
from agentverse import TaskDrivenAgentVerse

# タスクを渡すと必要なエージェントを自動決定
agentverse = TaskDrivenAgentVerse(
    task="ECサイトのセキュリティ脆弱性を診断して修正案を出す",
    agent_pool=[  # 利用可能なエージェントプール
        "security_expert",
        "backend_engineer",
        "frontend_engineer",
        "devops_engineer",
        "compliance_officer"
    ],
    auto_recruit=True  # タスクに必要なエージェントを自動選択
)

# AgentVerse が判断:
# → セキュリティ専門家 + バックエンド + フロントエンドを招集
# → DevOps と Compliance は不要と判断してスキップ
result = agentverse.run()
```

## ChatDev / MetaGPT との比較

```
マルチエージェント「ソフトウェア開発」フレームワーク比較:

  ChatDev (清華大学):
    ・固定役割: CEO+CPO+CTO+Programmer+Tester
    ・ウォーターフォール式の Chat-Chain
    ・コード生成特化

  MetaGPT (DeepWisdom):
    ・固定役割: PM+Architect+Engineer+QA
    ・SOPに基づく厳格なフロー
    ・ドキュメント重視

  AgentVerse (OpenBMB/清華大学):
    ・動的役割: タスクに応じて変化
    ・フレキシブルな協調パターン
    ・シミュレーション研究用途も対応
    ・オープンモデル統合重視

  → 研究・実験用途 = AgentVerse
  → プロダクション = CrewAI / MetaGPT
```

## 自分株式会社との関連

AgentVerse の「動的チーム編成 → タスクに応じたエージェント招集」は、自分株式会社の 12 インスタンス fleet の運用と同型。現在は手動で「Win版はここ、PS#3 はここ」と分担を決めているが、AgentVerse パターンを応用すれば「タスクの種類を判定して → 最適なインスタンスに自動ルーティング」に進化できる。また AgentVerse の環境定義 (Rule Engine) は ai-hub EF の action ルーティングマトリクスの設計参考になる。
$$,
  'https://github.com/OpenBMB/AgentVerse',
  NOW(),
  369
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
