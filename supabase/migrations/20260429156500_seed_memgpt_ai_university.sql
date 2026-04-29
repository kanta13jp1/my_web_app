-- PS#3 S138: AI大学 371→372社化 — MemGPT/Letta (UC Berkeley / 仮想コンテキスト管理 / 無限長期記憶 / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'memgpt', 'overview',
  'MemGPT / Letta (UC Berkeley) — 仮想コンテキスト管理・無限長期記憶・OS型LLMエージェント (9/9)',
  $$## MemGPT / Letta とは

**MemGPT** (Memory-GPT) は **UC Berkeley** の Charles Packer らが 2023年10月に発表した研究で、**OS の仮想メモリ管理をヒントに LLM の有限コンテキスト問題を解決する**画期的なアーキテクチャ。

2024年に製品版 **Letta** としてリブランドされ、エンタープライズ向けの長期記憶エージェントプラットフォームとして発展。

## MemGPT のコアコンセプト: OS型LLMエージェント

```
コンテキストウィンドウの問題:

  従来の LLM の限界:
    GPT-4: 128K トークン (= 約200ページ)
    長い会話: 古い情報が自動的に消える
    「先週話したことを覚えていますか？」→ 忘れる

  MemGPT の解決策 (OS の仮想メモリに着想):

    OS の仮想メモリ管理:
      CPU レジスタ (超高速・少量) = LLM の active context
      RAM (高速・中量) = 会話履歴・短期記憶
      HDD/SSD (低速・大量) = 長期記憶・外部ストレージ

    MemGPT のメモリ管理:
      Main Context (≤4K tokens) = 現在処理中の情報
      Recall Storage (SQLite) = 全会話履歴 (検索可能)
      Archival Storage (ベクトルDB) = 長期知識 (無限量)
```

## MemGPT のアーキテクチャ詳細

```
MemGPT のメモリ階層:

  1. Main Context (アクティブメモリ):
    ・LLM が直接参照できる情報
    ・System Prompt + Conversation History
    ・容量: モデルのコンテキスト上限
    ・揮発性: セッション終了で消える

  2. Recall Storage (想起ストレージ):
    ・全会話ログを SQLite に保存
    ・full-text search で検索
    ・関連する過去の会話を取得
    ・「あの話」を後から参照可能

  3. Archival Storage (アーカイブストレージ):
    ・外部知識 / ドキュメントをベクトル化
    ・意味的類似検索 (Faiss / Chroma)
    ・容量: 事実上無制限
    ・「覚えておいて」で追記可能

  Memory Functions (自己呼び出し可能):
    ・recall_memory(query): 過去会話を検索
    ・archival_memory_search(query): 知識検索
    ・archival_memory_insert(content): 新知識を保存
    ・core_memory_append(section, content): コアを更新
```

## 実際のコード例

```python
# Letta (旧MemGPT) の使用
from letta import create_client
from letta.schemas.memory import ChatMemory

# クライアント初期化 (ローカル or クラウド)
client = create_client()

# 長期記憶を持つエージェントを作成
agent = client.create_agent(
    name="個人アシスタント",
    memory=ChatMemory(
        human="名前: 田中 / 職業: エンジニア / 趣味: 将棋 / 目標: SaaS 起業",
        persona="あなたは田中さんの専属アシスタント。過去の会話を覚えている。"
    ),
    llm_config={"model": "gpt-4o"},
    embedding_config={"model": "text-embedding-3-small"}
)

# 会話 (セッション1)
response = client.send_message(
    agent_id=agent.id,
    message="最近 Flutter を勉強しています",
    role="user"
)
# エージェントが自動的に "Flutter 勉強中" を長期記憶に保存

# 1週間後の会話 (セッション2 - 別セッション!)
response = client.send_message(
    agent_id=agent.id,
    message="先週話した勉強の進捗はどうですか？",
    role="user"
)
# → 「先週 Flutter を勉強されていましたね。進捗はいかがですか？」
# (別セッションでも記憶が引き継がれる!)

# エージェントに知識を追加
client.add_archival_memory(
    agent_id=agent.id,
    memory="2026年4月: 自分株式会社のAI大学コンテンツを370社まで拡充"
)
```

## MemGPT / Letta の製品ラインアップ

```
Letta エコシステム (2024年〜):

  Letta OSS:
    ・セルフホスト型
    ・REST API + Python SDK
    ・MIT ライセンス
    ・PostgreSQL / SQLite バックエンド

  Letta Cloud:
    ・マネージドサービス
    ・スケーラブルなエージェント管理
    ・エンタープライズセキュリティ

  ADE (Agent Development Environment):
    ・エージェント開発専用 IDE
    ・デバッグ・メモリ可視化
    ・テスト環境

  主要ユースケース:
    ・カスタマーサポート (履歴完全記憶)
    ・パーソナルアシスタント (個人情報記憶)
    ・研究支援 (論文知識ベース)
    ・コードレビュー (プロジェクト文脈理解)
```

## 他の記憶管理アプローチとの比較

```
LLM 長期記憶の各アプローチ:

  MemGPT / Letta:
    ・OS仮想メモリ設計
    ・3層記憶 (Main/Recall/Archival)
    ・エージェント自身が記憶を管理
    ・最も体系的なアーキテクチャ

  ChatGPT Memory (OpenAI):
    ・ユーザー情報をシステム的に保存
    ・シンプルな key-value 形式
    ・ブラックボックス

  Mem0:
    ・記憶の抽出・格納・検索に特化
    ・外部ライブラリとして組み込み可
    ・OpenAI 互換 API

  claude-mem (自分株式会社):
    ・SQLite + Gemini 圧縮
    ・セッション横断記憶
    ・MemGPT の Recall Storage に相当

  → MemGPT = 研究的に最も完成度高い設計
  → Mem0 = 実用的な組み込みライブラリ
  → claude-mem = 軽量版 MemGPT
```

## 自分株式会社との関連

MemGPT のアーキテクチャは、自分株式会社の「3層メモリシステム (L1: claude-mem / L2: memory/ mdファイル / L3: NotebookLM)」と完全に対応する。自分株式会社の claude-mem = MemGPT の Recall Storage、MEMORY.md = Main Context の一部、NotebookLM Master Brain = Archival Storage に相当する。将来的に memory-search-hub EF (SECOND_BRAIN #7) を実装する際、MemGPT の 3層設計を参考にすることで、ユーザーの「昨日の自分」との継続的な対話を実現できる。特に MemGPT の「エージェント自身がいつ何を記憶するかを判断する」設計は、現在の手動 memory/ 保存を自動化する方向性として重要。
$$,
  'https://github.com/cpacker/MemGPT',
  NOW(),
  372
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
