-- PS#3 S65: AI大学 225→226社化 — Relevance AI 追加
-- Relevance AI: AIエージェントチームビルダー / ノーコード / BDR Agent / Research Agent

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'relevance-ai',
  'overview',
  'Relevance AI — AIエージェントチームビルダー (BDR Agent/Research Agent/ノーコード/Tool統合)',
  $$## Relevance AI — AIエージェントチームビルダー

**カテゴリ**: AI Agent Builder / Workforce Automation / No-Code AI Platform
**設立**: 2020年 / 本社: Sydney, Australia / 資金調達: ~$15M (Galileo Ventures / King River Capital)
**特徴**: 「AIエージェントのチーム」を構築・管理するプラットフォーム。BDR Agent・Research Agent・Support Agentなど業務特化エージェントをノーコードで作成し、実務に投入できる
**ユーザー**: セールスチーム / マーケター / リサーチャー / オペレーション / 中〜大企業
**評価**: 8/9

### 概要
Relevance AI は **「AI従業員を採用する」** コンセプトで、業務特化型AIエージェントを企業が構築・デプロイするプラットフォーム。単にLLMを呼ぶだけでなく、**Tool (検索/CRM/Email/Web)** と **Memory (会話履歴/ナレッジ)** と **Planning (複数ステップ推論)** を組み合わせた本格的なエージェントを、ドラッグ&ドロップで構築できる。2024年の主要製品は **BDR (Business Development Representative) Agent** ― 見込み客のリサーチ・パーソナライズメール作成・CRM登録を自律実行するエージェント。

### 主な製品・機能

**AIエージェントテンプレート**
| エージェント | 機能 |
|------------|------|
| **BDR Agent** | LinkedIn/Web調査 → パーソナライズメール生成 → HubSpot/Salesforce追加 → フォローアップ自動化 |
| **Research Agent** | キーワード → Web検索 → 情報統合 → 構造化レポート生成 |
| **Support Agent** | チケット受信 → 知識ベース検索 → 自動回答 or エスカレーション |
| **Outbound Agent** | ICP定義 → リード発掘 → スコアリング → アウトリーチ |
| **Content Agent** | キーワード → リサーチ → 下書き → 編集 → 公開 |

**ノーコードビルダー (Agent Studio)**
- Tool ブロック: Web Search / Email / CRM / Webhook / Code Execution
- LLM ブロック: GPT-4o / Claude 3.5 / Gemini / Mistral
- Logic ブロック: 条件分岐 / ループ / エラーハンドリング
- Memory: ベクターDB (会話履歴 + ドキュメント知識)
- Trigger: Schedule / Webhook / 手動 / Zapier

**Multi-Agent Orchestration**
- 複数エージェントをチームとして連携
- 例: Research Agent → BDR Agent → Outreach Agent の順に自律パスオフ
- Agent A の出力が Agent B の入力になるパイプライン

### BDR Agent の詳細ワークフロー
```
1. ICP (Ideal Customer Profile) 定義入力
   → 業種 / 規模 / 役職 / 技術スタック 等
2. Lead Generation:
   → Apollo.io / LinkedIn Sales Navigator / Hunter.io でリード収集
3. Research (Web + LLM):
   → 各リードの会社ニュース / LinkedIn投稿 / 資金調達情報を収集
   → 「なぜ自分株式会社に興味があるか」のパーソナライズ角度を生成
4. Email Composition:
   → GPT-4o が個別パーソナライズメールを作成
   → スパムスコアチェック / A/Bテストバリアント生成
5. CRM更新:
   → HubSpot / Salesforce に自動追加 + 活動ログ記録
6. Follow-up Scheduling:
   → 未返信を検知 → 3日後/7日後フォローアップを自動スケジュール
7. 結果レポート:
   → 送信数 / 返信率 / ミーティング設定数 を週次Slack投稿
```

### 競合との差別化
| 項目 | Relevance AI | Clay | Instantly | Apollo |
|------|-------------|------|-----------|--------|
| ノーコード Agent | ✅ 高度 | △ | ❌ | ❌ |
| カスタムエージェント | ✅ 完全自由 | △ | ❌ | ❌ |
| マルチAgent | ✅ | ❌ | ❌ | ❌ |
| LLM選択 | ✅ マルチ | △ | ❌ | ❌ |
| Lead発掘 | △ (統合) | ✅ | ✅ | ✅ |
| メール配信 | △ (統合) | △ | ✅ | ✅ |

### 導入コスト
- **Free**: 月100クレジット / エージェント3体 / 基本ツール
- **Starter**: 月$19 / 月500クレジット / エージェント無制限 / 全ツール
- **Pro**: 月$99 / 月2,000クレジット / Multi-Agent / API
- **Team**: 月$299 / 月8,000クレジット / チーム管理 / 優先サポート
- **Enterprise**: カスタム / SSO / SAML / 専任CSM$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'relevance-ai',
  'api',
  'Relevance AI API — エージェント実行・ツール呼び出し・Multi-Agent Orchestration (Python)',
  $$## Relevance AI API

### 概要
Relevance AI は REST API + Python SDK を提供。エージェントをプログラムからトリガー・管理できる。

### セットアップ
```bash
pip install relevanceai
export RELEVANCE_API_KEY="your_api_key_here"
export RELEVANCE_REGION="us-east-1"  # or ap-southeast-2 (Australia)
export RELEVANCE_PROJECT_ID="your_project_id"
```

### Python SDK でエージェント実行
```python
from relevanceai import RelevanceAI
import os

client = RelevanceAI(
    api_key=os.environ["RELEVANCE_API_KEY"],
    region=os.environ["RELEVANCE_REGION"],
    project=os.environ["RELEVANCE_PROJECT_ID"],
)

# エージェント一覧取得
agents = client.agents.list_agents()
for agent in agents["results"]:
    print(f"{agent['name']} (ID: {agent['agent_id']}): {agent['metadata'].get('description','')}")

# BDR Agent を実行
def run_bdr_agent(company_name: str, contact_name: str, linkedin_url: str) -> str:
    """BDR Agentで見込み客のリサーチ + メール生成"""
    conversation = client.agents.trigger_agent(
        agent_id="bdr-agent-id",  # Relevance AI管理画面でコピー
        message=f"""
        会社: {company_name}
        担当者: {contact_name}
        LinkedIn: {linkedin_url}

        この担当者にパーソナライズされたコールドメールを作成してください。
        自分株式会社のAIライフマネジメントアプリの提案として。
        """,
    )
    # 応答を待機してポーリング
    import time
    for _ in range(60):
        status = client.agents.get_agent_conversation(
            agent_id="bdr-agent-id",
            conversation_id=conversation["conversation_id"],
        )
        if status["status"] in ("completed", "failed"):
            return status.get("answer", "")
        time.sleep(2)
    return ""

email_draft = run_bdr_agent(
    company_name="ABC株式会社",
    contact_name="田中 太郎",
    linkedin_url="https://linkedin.com/in/tanaka-taro",
)
print(f"生成メール:\n{email_draft}")
```

### Tool 実行 (単体)
```python
# Tool (Relevance AI組み込み機能) を単体で呼び出す
def run_tool(tool_id: str, params: dict) -> dict:
    resp = client.tools.run_tool(
        tool_id=tool_id,
        params=params,
    )
    return resp

# Web Search Tool
search_result = run_tool(
    tool_id="web-search",
    params={"query": "自分株式会社 競合 Notion 比較 2026"},
)
print(search_result["output"])

# Research Agent Tool (深層調査)
research = run_tool(
    tool_id="research-agent",
    params={
        "topic": "Notion vs 自分株式会社 ライフマネジメントアプリ 市場比較",
        "depth": "deep",
        "output_format": "markdown_report",
    },
)
print(research["output"])
```

### Multi-Agent Orchestration (Webhook連携)
```python
# エージェントA完了 → Webhook → エージェントB起動
import flask

app = flask.Flask(__name__)

@app.route("/relevance-webhook", methods=["POST"])
def handle_agent_completion():
    data = flask.request.json
    if data.get("event") == "agent.completed" and data.get("agent_id") == "research-agent-id":
        # Research Agent完了 → BDR Agent起動
        research_output = data["output"]
        client.agents.trigger_agent(
            agent_id="bdr-agent-id",
            message=f"以下のリサーチ結果を基にコールドメールを作成:\n{research_output}",
        )
    return {"status": "ok"}
```

### GHA × Relevance AI 週次リサーチ自動化
```yaml
# .github/workflows/weekly-competitive-research.yml
# 毎週月曜 09:00 JST → Relevance AI Research Agent → 競合分析レポート生成
steps:
  - name: Run competitive research agent
    env:
      RELEVANCE_API_KEY: ${{ secrets.RELEVANCE_API_KEY }}
      RELEVANCE_PROJECT_ID: ${{ secrets.RELEVANCE_PROJECT_ID }}
    run: python scripts/weekly_competitive_research.py
  - name: Commit research report
    run: |
      git add docs/competitor-reports/
      git commit -m "chore: 週次競合リサーチ $(date +%Y-%m-%d)"
      git push
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'relevance-ai',
  'models',
  'Relevance AI技術詳細 — Agent Orchestration + ReAct/PlanAct + Vector Memory + Multi-LLM',
  $$## Relevance AI 技術詳細

### エージェントアーキテクチャ
```
[エージェント実行フロー]

ユーザーメッセージ / Trigger
       ↓
Planner (LLM: GPT-4o / Claude 3.5):
  - タスクを複数ステップに分解
  - 必要なToolを選択 (Tool Registry から)
  - 実行順序・依存関係を計画
       ↓
ReAct Loop:
  Reason → Act → Observe → Reason → Act ...

  Reason: 現状確認 + 次のアクション決定
  Act: Tool実行 (Web Search / CRM API / Email / Code等)
  Observe: Tool結果を受け取り
  → LLMが結果を解釈して次のステップへ
       ↓
Memory Manager:
  - Short-term: 会話コンテキスト (セッション内)
  - Long-term: ベクターDB (Pinecone/Qdrant) → 過去の会話・ドキュメント
  - Episodic: 過去の実行ログ (成功/失敗パターン学習)
       ↓
Output Formatter:
  - 最終出力をユーザー指定フォーマットに変換
  - Slack / Email / Webhook / CRM へ配信
```

### Multi-LLM オーケストレーション戦略
```
Relevance AI のモデル使い分け:

Planning (複雑な推論が必要):
  → Claude 3.5 Sonnet: 長文推論・複数ステップ計画

Tool Calling (高速・精度):
  → GPT-4o: Function Calling の精度が業界最高

Summarization (大量テキスト処理):
  → Gemini 1.5 Pro: 100万トークンコンテキスト活用

Classification (高速・安価):
  → GPT-4o-mini / Claude Haiku: バッチ処理

→ 1エージェント内で複数モデルを目的別に使い分けることでコスト最適化
```

### Vector Memory の実装
```python
# Relevance AI が内部で使うベクターメモリ概念
# (外部からの直接操作より Agent Studioで設定推奨)

知識ベース追加:
  - PDF / URL / テキスト → Embedding → ベクターDB
  - エージェントが質問時に自動RAG検索

会話メモリ:
  - 過去の会話をembeddingして保存
  - 類似会話を自動参照 → 文脈の継続性
```

### Relevance AI vs AutoGPT / AgentGPT (2026年比較)
| 項目 | Relevance AI | AutoGPT | AgentGPT | LangGraph |
|------|-------------|---------|----------|-----------|
| ノーコード | ✅ | ❌ | △ | ❌ |
| 本番デプロイ | ✅ | △ (実験的) | △ | ✅ (コード) |
| マルチAgent | ✅ | △ | ❌ | ✅ |
| エンタープライズ | ✅ | ❌ | ❌ | ✅ |
| 対応LLM | 6+ | GPT中心 | GPT中心 | 全対応 |
| SaaS費用 | 安〜中 | OSSのみ | 無料 | OSSのみ |

### 自分株式会社での活用可能性
- **AI大学 Research Agent**: Relevance AI Research Agent → 各AIプロバイダーの最新情報を週次収集 → Supabase ai_university_content 自動更新
- **競合モニタリング自動化**: 190社の競合変化を Research Agent が毎週調査 → competitor_features テーブルを自動更新
- **BDR Bot for 自分株式会社**: スタートアップ創業者 / CTO をターゲットに BDR Agent でアウトリーチ自動化
- **マルチAgent連携**: Research Agent (調査) → Content Agent (記事生成) → Writesonic API (SEO最適化) → GHA (公開) のフルパイプライン
- **Multi-LLM実験**: Claude/GPT-4/Gemini を同一タスクで比較実行 → AI大学コンテンツの品質向上に活用$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 225→226社化: Relevance AI 追加',
  'PS#3 S65。Relevance AI (AIエージェントチームビルダー/BDR Agent/Research Agent/ノーコード/Multi-Agent Orchestration/ReAct/Multi-LLM/~$15M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
