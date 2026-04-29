-- PS#3 S116: AI大学 326→327社化 — Dify (OSS LLMアプリ開発プラットフォーム)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dify', 'overview',
  'Dify — OSS LLM アプリ開発プラットフォーム・RAG・エージェント・ワークフロー (GitHub 60k+ / 9/9)',
  $$## Dify とは

**Dify** は **中国発のオープンソース LLM アプリケーション開発プラットフォーム**。GitHub 60,000+ スター (2024年最速成長 OSS の一つ)。「**プロダクションレベルの AI アプリを最速で構築・運用するオールインワン基盤**」が特徴。

Flowise が「LangChain のビジュアル UI」なのに対し、Dify は **独自の LLM オーケストレーション・エンジンを持つフルスタックプラットフォーム**。RAG エンジン・エージェントビルダー・ワークフロービルダー・プロンプト管理・モニタリング・API 公開が一体化。**クラウド版 (dify.ai) と OSS 版 (自己ホスト) の両方**で利用できる。

## Dify のアーキテクチャ

```
Dify のコアコンポーネント:

  知識ベース (Knowledge Base):
    ・PDF / Web / Notion / GitHub / CSV 等をインポート
    ・自動チャンキング + 埋め込み
    ・ハイブリッド検索 (BM25 + ベクター)
    ・親チャンク / 子チャンク リトリーバル

  ワークフロービルダー:
    ・ノードベースの視覚的フロー設計
    ・LLM / Code / HTTP / ツール / 条件分岐ノード
    ・並列実行・ループ・反復処理
    ・変数とコンテキストの受け渡し

  エージェントビルダー:
    ・ReAct / Function Calling エージェント
    ・100+ 組み込みツール (Web検索/コード実行/DB)
    ・カスタムツール定義 (OpenAPI Schema)
    ・マルチエージェント協調

  チャットボット:
    ・基本チャット / RAG チャット / エージェントチャット
    ・セッション管理・会話履歴
    ・Webサイト/API/Slack/Telegram 埋め込み

  モデル対応:
    ・Claude / GPT / Gemini / Mistral / Llama
    ・Ollama (ローカル) / Azure / AWS Bedrock
    ・100+ プロバイダー (LiteLLM 経由)
```

## 主要機能

```
プロダクション機能:
  ・API キー管理・レート制限
  ・ログ・モニタリング・A/B テスト
  ・プロンプトバージョン管理
  ・チームコラボレーション (権限管理)

デプロイオプション:
  ・Docker Compose (セルフホスト)
  ・Kubernetes Helm Chart
  ・dify.ai クラウド (Free/Pro/Team)
  ・AWS / Azure / GCP 対応
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **AI大学 RAG Bot** | ai_university_content を知識ベースに取り込み → チャットボット公開 | ユーザーが AI ツールを即座に検索 |
| **競馬予想ワークフロー** | データ収集→分析→予想→配信の多段フローを Dify で構築 | 予想パイプラインの完全自動化 |
| **プロンプト管理** | 競馬予想プロンプトをバージョン管理・A/B テスト | 継続的な精度改善 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dify', 'api',
  'Dify 実践 — インストール/Docker/知識ベース/ワークフロー/Claude統合/REST API/Python SDK/埋め込み',
  $$## インストール (Docker Compose)

```bash
# リポジトリをクローン
git clone https://github.com/langgenius/dify.git
cd dify/docker

# 環境変数ファイルをコピー
cp .env.example .env

# .env を編集 (必須)
# SECRET_KEY=your-secret-key-here
# ANTHROPIC_API_KEY=your-anthropic-api-key

# 起動
docker compose up -d

# → http://localhost/install でセットアップ
```

## Claude (Anthropic) モデル統合

```text
UI での設定手順:
1. Dify ダッシュボード → Settings → Model Provider
2. "Anthropic" を選択
3. API Key: YOUR_ANTHROPIC_API_KEY を入力
4. 利用可能モデル:
   - claude-sonnet-4-6 (高精度タスク)
   - claude-haiku-4-5 (高速・低コスト)
5. デフォルトモデルに設定
```

## 知識ベースの構築 (API)

```python
import requests

DIFY_BASE_URL = "http://localhost"
API_KEY = "your-dify-api-key"  # Settings → API Keys から生成

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

# 知識ベース作成
kb = requests.post(
    f"{DIFY_BASE_URL}/v1/datasets",
    headers=headers,
    json={
        "name": "AI大学コンテンツ",
        "description": "ai_university_content テーブルの内容",
        "indexing_technique": "high_quality",  # high_quality or economy
        "permission": "only_me",
    },
).json()
dataset_id = kb["id"]
print(f"知識ベース作成: {dataset_id}")

# ドキュメントを追加 (テキスト直接)
doc = requests.post(
    f"{DIFY_BASE_URL}/v1/datasets/{dataset_id}/document/create-by-text",
    headers=headers,
    json={
        "name": "vLLM概要",
        "text": "vLLM は PagedAttention を使った高速 LLM 推論エンジンです。GitHub 25k+ スター。",
        "indexing_technique": "high_quality",
        "process_rule": {
            "mode": "automatic",
        },
    },
).json()
print(f"ドキュメント追加: {doc['document']['id']}")

# 検索テスト
search = requests.get(
    f"{DIFY_BASE_URL}/v1/datasets/{dataset_id}/retrieve",
    headers=headers,
    json={"query": "高速 LLM 推論", "top_k": 3},
).json()
for r in search["records"]:
    print(f"Score: {r['score']:.2f} | {r['segment']['content'][:50]}...")
```

## チャットボット API での呼び出し

```python
import requests, json

DIFY_BASE_URL = "http://localhost"
APP_API_KEY = "app-your-chatbot-api-key"  # アプリの API Key

def chat_with_dify(message: str, conversation_id: str = "", user_id: str = "user-1") -> dict:
    """Dify チャットボットに質問する"""
    response = requests.post(
        f"{DIFY_BASE_URL}/v1/chat-messages",
        headers={
            "Authorization": f"Bearer {APP_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "inputs": {},
            "query": message,
            "response_mode": "blocking",  # または "streaming"
            "conversation_id": conversation_id,
            "user": user_id,
        },
    )
    return response.json()

# 使用例
result = chat_with_dify("LlamaIndex と LangChain の違いを教えて")
print(result["answer"])

# 会話を継続
conv_id = result["conversation_id"]
follow_up = chat_with_dify("どちらが RAG に向いている？", conversation_id=conv_id)
print(follow_up["answer"])
```

## ストリーミングレスポンス

```python
import requests

def stream_chat(message: str, app_api_key: str):
    """ストリーミングでレスポンスを受け取る"""
    response = requests.post(
        "http://localhost/v1/chat-messages",
        headers={"Authorization": f"Bearer {app_api_key}"},
        json={
            "query": message,
            "response_mode": "streaming",
            "user": "stream-user",
        },
        stream=True,
    )

    for line in response.iter_lines():
        if line:
            line = line.decode("utf-8")
            if line.startswith("data: "):
                data = json.loads(line[6:])
                if data.get("event") == "message":
                    print(data["answer"], end="", flush=True)
                elif data.get("event") == "message_end":
                    print()  # 改行
                    break

stream_chat("天皇賞春2026の予想を教えて", "app-your-api-key")
```

## Workflow API

```python
# ワークフローを API から実行
workflow_result = requests.post(
    "http://localhost/v1/workflows/run",
    headers={"Authorization": f"Bearer {APP_API_KEY}"},
    json={
        "inputs": {
            "race_name": "天皇賞春2026",
            "horses": "シャフリヤール,タイトルホルダー,ディープボンド",
        },
        "response_mode": "blocking",
        "user": "api-user",
    },
).json()

print(f"ワークフロー結果: {workflow_result['data']['outputs']}")
```

## 埋め込みウィジェット

```html
<!-- Web サイトに Dify チャットボットを埋め込む -->
<script>
  window.difyChatbotConfig = {
    token: 'your-embed-token',  // App → Embed から取得
    baseUrl: 'http://localhost',
  }
</script>
<script
  src="http://localhost/embed.min.js"
  id="your-embed-token"
  defer>
</script>
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 326→327社化: Dify 追加',
  'PS#3 S116。Dify (中国発OSS LLMアプリ開発プラットフォーム/知識ベース+RAG/ワークフロービルダー/エージェントビルダー/Claude統合/REST API/Docker自己ホスト/GitHub 60k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
