-- PS#3 S116: AI大学 327→328社化 — LangFlow (LangChainビジュアルUI/ローコードAIビルダー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langflow', 'overview',
  'LangFlow — LangChain ビジュアル UI・ローコード AI ビルダー・DataStax (GitHub 40k+ / 9/9)',
  $$## LangFlow とは

**LangFlow** は **DataStax (Apache Cassandra 開発元) が支援するオープンソースの LangChain ビジュアル UI ビルダー**。GitHub 40,000+ スター。「**LangChain コンポーネントをドラッグ&ドロップで組み合わせ、RAG・エージェント・チャットボットを視覚的に構築する**」ツール。

Flowise と同じノーコードカテゴリだが、LangFlow は **Python ファーストで「コードとして書いたものをビジュアルで確認する」双方向性**が特徴。GUI で作ったフローを Python コードとして export でき、LangChain コードをそのまま import も可能。**DataStax Astra (クラウド) と深く統合**。

## LangFlow のアーキテクチャ

```
LangFlow のコアコンポーネント:

  Flow Editor:
    ・React Flow ベースのビジュアルエディタ
    ・コンポーネントをノードとして配置・接続
    ・リアルタイムプレビュー・チャットテスト

  Components (コンポーネント群):
    ・Models: Claude / GPT / Gemini / Ollama / Groq
    ・Vector Stores: Astra DB / Chroma / Pinecone / pgvector
    ・Document Loaders: PDF / Web / CSV / Confluence / GitHub
    ・Text Splitters: Recursive / Token / Sentence
    ・Embeddings: OpenAI / HuggingFace / Cohere
    ・Agents: ReAct / OpenAI Functions
    ・Tools: Bing Search / Wikipedia / Calculator / Custom

  Python 統合:
    ・GUI フロー → Python コードへ export
    ・Python コード → GUI フローへ import
    ・Custom Component (Python クラスで定義)

  デプロイ:
    ・ローカル (pip install langflow)
    ・Docker
    ・DataStax Langflow Cloud (マネージド)
    ・REST API + WebSocket
```

## 主要機能

```
ユニーク機能:
  ・Playground: フロー内でリアルタイムテスト
  ・Flow Bundles: 複数フローをパッケージ化
  ・Custom Components: Python で新コンポーネント追加
  ・Webhook: 外部トリガーで自動実行
  ・MCP (Model Context Protocol) サポート

DataStax Astra 統合:
  ・Astra DB (Cassandra) ベクターストア
  ・クラウドマネージドで運用不要
  ・グローバル分散データベース
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **プロトタイプ開発** | LangFlow で RAG フローを視覚的に構築 → Python export で本番化 | アイデア→本番の最速パス |
| **チーム共有** | 非エンジニアメンバーが AI フローを視覚的に理解・改善 | AI 活用のチーム展開 |
| **競馬 RAG** | 競馬ルール PDF + pgvector + Claude で Q&A フロー構築 | コードレスで競馬知識 Bot |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'langflow', 'api',
  'LangFlow 実践 — インストール/Docker/Claude統合/RAGフロー/REST API/Python export/Custom Component',
  $$## インストール

```bash
# pip でインストール
pip install langflow

# 起動
python -m langflow run
# → http://127.0.0.1:7860 でアクセス

# ポート変更
python -m langflow run --port 3000

# または uv で高速インストール
uv pip install langflow
```

## Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  langflow:
    image: langflowai/langflow:latest
    ports:
      - "7860:7860"
    environment:
      - LANGFLOW_SECRET_KEY=your-secret-key
      - ANTHROPIC_API_KEY=your-anthropic-api-key
      - OPENAI_API_KEY=your-openai-api-key
    volumes:
      - langflow-data:/var/lib/langflow

volumes:
  langflow-data:
```

## Claude 統合 (UI での設定)

```text
UI での設定手順:
1. LangFlow (http://localhost:7860) を開く
2. 新規フロー作成
3. Component パネルから "Claude" を検索
4. "Anthropic Chat Model" ノードをドラッグ
5. 設定:
   - Model Name: claude-haiku-4-5
   - Anthropic API Key: YOUR_ANTHROPIC_API_KEY
   - Max Tokens: 1000
6. 他のコンポーネントに接続
```

## REST API での呼び出し

```python
import requests
import json

LANGFLOW_URL = "http://localhost:7860"
FLOW_ID = "your-flow-id"  # UI の URL から取得
API_KEY = "your-api-key"  # Settings → API Keys

def run_flow(message: str, tweaks: dict = None) -> str:
    """LangFlow フローを実行する"""
    payload = {
        "input_value": message,
        "output_type": "chat",
        "input_type": "chat",
    }
    if tweaks:
        payload["tweaks"] = tweaks

    response = requests.post(
        f"{LANGFLOW_URL}/api/v1/run/{FLOW_ID}",
        headers={
            "x-api-key": API_KEY,
            "Content-Type": "application/json",
        },
        json=payload,
    )
    result = response.json()
    return result["outputs"][0]["outputs"][0]["results"]["message"]["text"]

# 基本呼び出し
answer = run_flow("LlamaIndex とはなんですか？")
print(answer)

# コンポーネント設定を上書き (tweaks)
answer_with_tweaks = run_flow(
    "天皇賞春の予想を教えて",
    tweaks={
        "AnthropicModel-xxxxx": {
            "model_name": "claude-sonnet-4-6",
            "max_tokens": 2000,
        },
    },
)
print(answer_with_tweaks)
```

## Python SDK (公式)

```python
from langflow.load import run_flow_from_json

# フローを JSON ファイルとして export してから Python で実行
result = run_flow_from_json(
    flow="./my_rag_flow.json",
    input_value="天皇賞春2026の注目馬は？",
    session_id="user-session-1",
    fallback_to_env_vars=True,  # 環境変数から API キーを取得
)

print(result[0].outputs[0].results["message"].text)
```

## Custom Component (Python)

```python
from langflow.custom import Component
from langflow.inputs import StrInput, IntInput
from langflow.outputs import MessageOutput
from langflow.schema import Data

class KeibaDataFetcher(Component):
    """競馬データを Supabase から取得するカスタムコンポーネント"""

    display_name = "Keiba Data Fetcher"
    description = "Supabase から競馬データを取得します"
    icon = "🐎"

    inputs = [
        StrInput(name="race_name", display_name="レース名", required=True),
        IntInput(name="top_n", display_name="上位N頭", value=5),
    ]

    outputs = [
        MessageOutput(name="race_data", display_name="レースデータ"),
    ]

    def fetch_race_data(self) -> Data:
        import requests
        url = f"https://your-project.supabase.co/rest/v1/races"
        params = {"race_name": f"eq.{self.race_name}", "limit": self.top_n}
        response = requests.get(url, params=params)
        data = response.json()
        return Data(text=str(data))

    def build_config(self):
        return {
            "race_name": {"display_name": "レース名"},
            "top_n": {"display_name": "上位N頭", "value": 5},
        }
```

## フローを JSON として export・import

```bash
# フローを JSON でエクスポート (UI から)
# Flow menu → Export → JSON ファイルをダウンロード

# コマンドラインで起動時にフローをロード
python -m langflow run --load ./my_racing_flow.json

# API でフローを直接アップロード
curl -X POST "http://localhost:7860/api/v1/flows/" \
  -H "x-api-key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d @my_racing_flow.json
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 327→328社化: LangFlow 追加',
  'PS#3 S116。LangFlow (DataStax支援/LangChainビジュアルUI/ローコードAIビルダー/Claude統合/REST API/Python export/Custom Component/Astra DB統合/MCP対応/GitHub 40k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
