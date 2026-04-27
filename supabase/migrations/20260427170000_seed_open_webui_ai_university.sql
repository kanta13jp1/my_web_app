-- PS#3 S75: AI大学 244→245社化 — Open WebUI 追加
-- Open WebUI: ブラウザ操作ローカルLLM UI / 旧Ollama WebUI / GitHub 50k+ / Docker / チーム共有 / RAG内蔵

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'open_webui',
  'overview',
  'Open WebUI — ブラウザ操作ローカルLLM (旧Ollama WebUI / GitHub 50k+ / Docker / チーム共有 / RAG内蔵)',
  $$## Open WebUI — セルフホスト型 AI チャットプラットフォーム

**カテゴリ**: Local LLM UI / Self-Hosted AI / Team Collaboration / Privacy-First AI
**開発元**: Timothy J. Baek (個人→コミュニティプロジェクト)
**前名称**: Ollama WebUI (2024年に Open WebUI に改名)
**ライセンス**: MIT (完全オープンソース)
**GitHub**: github.com/open-webui/open-webui (50,000+ スター)
**デプロイ方法**: Docker / pip / Kubernetes
**価格**: 完全無料 (セルフホスト) / Open WebUI Plus (クラウド版有料)
**評価**: 9/9

### 概要
Open WebUI は **「ブラウザで操作できるセルフホスト型 AI チャット UI」** として開発されたプラットフォーム。LM Studio や Jan.ai がデスクトップアプリである一方、Open WebUI は **Webブラウザ** でアクセスするため、**チームでの共有利用** に特化している。

**最大の強み**: Docker 1コマンドで起動 → チーム全員がブラウザでアクセス可能 → **社内プライベートChatGPT** として最も多く採用されているOSSツール。

**日本での普及**: Docker環境を持つエンジニアチームでの採用が急増。Zenn・Qiita での解説記事が豊富。

### 主な機能

**1. マルチバックエンド対応**
| バックエンド | 接続方法 |
|-------------|---------|
| Ollama (ローカル) | `http://host.docker.internal:11434` |
| OpenAI API | APIキー設定 |
| Anthropic Claude | APIキー設定 |
| Azure OpenAI | エンドポイント+キー設定 |
| 任意 OpenAI互換 | カスタムエンドポイント設定 |
| LM Studio | `http://host.docker.internal:1234/v1` |

→ ローカルLLMとクラウドAPIを **同一 UI** で切り替え可能

**2. マルチユーザー管理**
- ユーザー登録・認証 (メール/OAuth)
- 権限管理: Admin / User / Pending
- グループ機能: 部署ごとにモデルアクセス制御
- 利用量ログ: 誰がどのモデルを何回使ったか追跡

**3. RAG (Retrieval-Augmented Generation)**
- PDFやテキスト文書をアップロード
- ローカルベクターDB に埋め込みを保存
- チャット時に関連文書を自動参照
- コレクション: 文書をグループ化して管理

**4. Web検索統合**
- DuckDuckGo / Google / Brave Search / Searxng
- チャット中に「#」で検索結果をコンテキストに追加
- リアルタイム情報をローカルLLMに反映

**5. パイプライン / 機能拡張**
- Functions: Python関数をチャット内のツールとして定義
- Pipelines: 外部処理ステップを追加 (例: 翻訳→生成→翻訳)
- Tools: Web検索・Python実行・画像生成など
- Artifacts: 生成されたコードをブラウザ内で実行可能

### セットアップ (Docker)
```bash
# 基本起動 (Ollamaと同一ホストの場合)
docker run -d \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

# OpenAI API も使用する場合
docker run -d \
  -p 3000:8080 \
  -e OPENAI_API_KEY="sk-..." \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  ghcr.io/open-webui/open-webui:main

# → http://localhost:3000 でブラウザアクセス
```

### LM Studio / Jan.ai との使い分け
```
デスクトップ個人利用:
  → LM Studio / Jan.ai (インストーラーで簡単)

チーム・組織での共有:
  → Open WebUI (Docker + ブラウザ = 全員が同一UI)

社内サーバーへのデプロイ:
  → Open WebUI + Ollama (社内ネットワーク内でプライベートAI)

Kubernetes / クラウドインフラ:
  → Open WebUI Helm Chart (大規模展開)
```

### 自分株式会社での活用可能性
- **社内 AI ツール**: 開発チーム向けプライベートChatGPTをDockerで起動
- **ユーザー向け機能**: 将来的なRAG機能のUI参考設計
- **競合分析**: Open WebUI の UX デザインパターンを自分株式会社のAI大学UIに反映
- **AI大学コンテンツ**: 「Docker 1コマンドで社内プライベートChatGPTを構築する方法」→ 非常に高い検索需要$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'open_webui',
  'api',
  'Open WebUI API — REST API / Pipeline統合 / Supabase連携 / Functions定義',
  $$## Open WebUI API / 統合ガイド

### 概要
Open WebUI は OpenAI 互換 API を提供。外部アプリから Open WebUI を経由してバックエンドのLLMを呼び出せる。また、**Functions** 機能で Python コードをチャット内ツールとして登録できる。

### OpenAI互換APIとして使用
```python
from openai import OpenAI

# Open WebUI をプロキシとして使用
# ユーザー管理・ログ記録を Open WebUI に任せながら LLM を呼び出す
client = OpenAI(
    base_url="http://localhost:3000/api",  # Open WebUI のURL
    api_key="your-open-webui-api-key",    # Settings > Account > API Keys
)

response = client.chat.completions.create(
    model="llama3.2:latest",  # Ollama モデル名
    messages=[{"role": "user", "content": "日本語で挨拶して"}],
)
print(response.choices[0].message.content)
```

### Function の定義 (チャット内ツール)
```python
# Open WebUI の Functions 機能 (Settings > Functions から登録)
# Python関数をLLMが呼び出せるツールとして定義

"""
title: 天気取得ツール
description: 指定した都市の現在の天気を取得します
"""

import requests
from pydantic import BaseModel

class Tools:
    class Valves(BaseModel):
        WEATHER_API_KEY: str = ""

    def __init__(self):
        self.valves = self.Valves()

    def get_weather(self, city: str) -> str:
        """
        指定した都市の現在の天気情報を取得
        :param city: 都市名 (例: Tokyo, Osaka)
        :return: 天気情報のテキスト
        """
        if not self.valves.WEATHER_API_KEY:
            return "APIキーが設定されていません"

        resp = requests.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"q": city, "appid": self.valves.WEATHER_API_KEY, "units": "metric", "lang": "ja"},
        )
        data = resp.json()
        if resp.ok:
            return f"{city}: {data['weather'][0]['description']}, {data['main']['temp']}°C"
        return f"天気の取得に失敗しました: {data.get('message', '不明なエラー')}"
```

### Pipeline の定義 (処理パイプライン)
```python
# Open WebUI Pipelines (github.com/open-webui/pipelines)
# LLMへのリクエストに前処理・後処理を追加

from pydantic import BaseModel
from typing import Optional

class Pipeline:
    class Valves(BaseModel):
        MAX_TOKENS: int = 1000
        SYSTEM_PROMPT: str = "あなたは自分株式会社のAIアシスタントです。"

    def __init__(self):
        self.valves = self.Valves()

    async def on_startup(self):
        print("Pipeline started")

    async def inlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """リクエストをLLMに送る前に変換"""
        # システムプロンプトを先頭に追加
        messages = body.get("messages", [])
        if not any(m["role"] == "system" for m in messages):
            messages.insert(0, {
                "role": "system",
                "content": self.valves.SYSTEM_PROMPT,
            })
        body["messages"] = messages
        body["max_tokens"] = self.valves.MAX_TOKENS
        return body

    async def outlet(self, body: dict, user: Optional[dict] = None) -> dict:
        """LLMの回答を返す前に変換"""
        # 回答をログに記録する例
        print(f"User: {user}")
        return body
```

### Supabase × Open WebUI 統合パターン
```typescript
// Supabase Edge Function: Open WebUI を経由してローカルLLMを呼び出す
// (同一VPC/ネットワーク内でのデプロイ想定)

const OPEN_WEBUI_URL = Deno.env.get("OPEN_WEBUI_URL") ?? "http://localhost:3000";
const OPEN_WEBUI_KEY = Deno.env.get("OPEN_WEBUI_API_KEY") ?? "";

Deno.serve(async (req: Request) => {
  const { message, userId } = await req.json();

  const response = await fetch(`${OPEN_WEBUI_URL}/api/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPEN_WEBUI_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "llama3.2:latest",
      messages: [
        { role: "system", content: "あなたは自分株式会社のサポートAIです。" },
        { role: "user", content: message },
      ],
    }),
  });

  const data = await response.json();
  const reply = data.choices?.[0]?.message?.content ?? "";

  return new Response(JSON.stringify({ reply }), {
    headers: { "Content-Type": "application/json" },
  });
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'open_webui',
  'models',
  'Open WebUI 技術詳細 — アーキテクチャ / RAG設計 / セキュリティ / 大規模デプロイ',
  $$## Open WebUI 技術詳細

### システムアーキテクチャ

```
[Open WebUI の構成]

ブラウザ (React + TypeScript)
      ↓ WebSocket / HTTP
Open WebUI バックエンド (FastAPI + Python)
  ├── 認証: JWT / OAuth2
  ├── チャット管理: SQLite / PostgreSQL
  ├── RAG: ChromaDB (ベクターDB)
  ├── ファイル管理: ローカルストレージ / S3
  └── モデル管理: Ollama API / OpenAI API
      ↓
LLM バックエンド
  ├── Ollama (ローカルGGUF)
  ├── OpenAI API
  ├── Anthropic API
  └── 任意 OpenAI互換サーバー
```

### RAG パイプライン

```
[Open WebUI の組み込みRAG]

1. ドキュメントアップロード
   PDF/TXT/DOCX/MD/CSV → テキスト抽出 (PDFMiner/Unstructured)

2. チャンク分割
   デフォルト: 1500トークン / 100トークンオーバーラップ
   カスタム: Settings > Documents で変更可

3. 埋め込み生成
   デフォルト: sentence-transformers/all-MiniLM-L6-v2 (ローカル)
   カスタム: OpenAI Embeddings / カスタムモデル

4. ベクターDB保存
   ChromaDB (デフォルト) / Milvus / Qdrant (設定変更可)

5. クエリ処理
   ユーザー入力 → 埋め込み → コサイン類似度 → TOP-K 文書
   → [RAGプロンプト]: 関連文書を含めてLLMに送信

6. ハイブリッド検索 (オプション)
   セマンティック検索 + BM25 全文検索を組み合わせ
   → 検索精度向上
```

### セキュリティ設計

```
[マルチユーザー環境でのセキュリティ]

認証:
  - JWT (デフォルト) / OAuth2 (GitHub/Google/OIDC対応)
  - セッション有効期限: 設定可能
  - 2FA: TOTP 対応 (2024〜)

権限管理:
  Admin:  全機能 / ユーザー管理 / システム設定
  User:   チャット / RAG / 許可されたモデルのみ
  Pending: ログイン可・管理者承認待ち

モデルアクセス制御:
  特定モデルを特定グループのみに制限
  例: GPT-4o → 管理職のみ / Llama 3 8B → 全社員

ネットワーク分離:
  社内ネットワーク内のサーバーにデプロイ
  → インターネット非公開で GDPR/個人情報保護法に対応
  → Ollama 使用時は推論もローカル = 完全プライバシー
```

### 大規模デプロイ (Kubernetes)

```yaml
# Open WebUI Helm Chart (概略)
# helm repo add open-webui https://helm.openwebui.com

helm install open-webui open-webui/open-webui \
  --set openaiBaseApiUrl="http://ollama:11434/v1" \
  --set ollama.enabled=true \
  --set persistence.size=10Gi \
  --set replicaCount=3

# 本番設定
# - PostgreSQL (代わりにSQLite)
# - Redis (セッション管理)
# - S3 / MinIO (ファイルストレージ)
# - ChromaDB クラスター (RAG)
```

### パフォーマンス比較 (チャット応答速度)

| 構成 | 初回応答 | スループット |
|------|---------|------------|
| Open WebUI + Ollama (M3 Pro) | ~1.5秒 | ~35 t/s |
| Open WebUI + LM Studio | ~2.0秒 | ~38 t/s |
| Open WebUI + OpenAI API | ~0.5秒 | API依存 |
| ChatGPT (参考) | ~0.3秒 | API依存 |

### 自分株式会社との関連性

```
比較分析:
  自分株式会社の AI 機能 (EF + Flutter UI) と Open WebUI の比較
  → Open WebUI: チャット特化 / 汎用 / セルフホスト
  → 自分株式会社: ライフマネジメント統合 / モバイル対応 / 個人データ連携

活用シナリオ:
  1. 開発チーム内部ツール: Open WebUI で社内ドキュメントRAGを構築
  2. プロトタイピング: 新AI機能のUI設計を Open WebUI で検証してから本実装
  3. AI大学コンテンツ:
     「Docker 1コマンド: 社内プライベートChatGPT構築ガイド」
     「Open WebUI × Ollama で医療・法律データをプライベートに処理」
     → SEO効果高 / 企業のDXニーズに直結するテーマ
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 244→245社化: Open WebUI 追加',
  'PS#3 S75。Open WebUI (旧Ollama WebUI/MIT OSS/GitHub 50k+/Dockerデプロイ/チーム共有/マルチバックエンド/RAG内蔵/Web検索/Pipelines/Functions/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
