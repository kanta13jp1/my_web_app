-- PS#3 S117: AI大学 328→329社化 — Open WebUI (Ollama UI/ローカルLLMフロントエンド)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'open-webui', 'overview',
  'Open WebUI — ローカル LLM フロントエンド・Ollama UI・オフライン AI チャット (GitHub 50k+ / 9/9)',
  $$## Open WebUI とは

**Open WebUI** は **ローカル LLM (Ollama 等) のための高機能 Web フロントエンド**。GitHub 50,000+ スター (2024年最速成長 OSS の一つ)。「**ChatGPT のような UI でローカル LLM を使う**」ことを実現。Ollama と Docker だけで完全オフライン AI チャット環境を構築できる。

OpenAI API 互換のため、**Claude / OpenAI / Groq / LiteLLM 等のクラウド LLM とも接続可能**。**RAG 機能内蔵** (ドキュメントアップロード→ベクター検索)、**画像生成** (Stable Diffusion / DALL-E 統合)、**TTS/STT** (音声対話) も搭載。多言語対応・ユーザー管理・チーム機能付き。

## Open WebUI のアーキテクチャ

```
Open WebUI のコンポーネント:

  フロントエンド (SvelteKit):
    ・ChatGPT ライクなチャット UI
    ・マルチモーダル (画像・音声)
    ・マークダウン / LaTeX / コードハイライト
    ・会話履歴・フォルダ管理

  バックエンド (FastAPI + Python):
    ・Ollama API プロキシ
    ・OpenAI API 互換エンドポイント
    ・RAG パイプライン (ChromaDB)
    ・ユーザー管理 (JWT)

  LLM 接続:
    ・Ollama (ローカル): llama3 / Phi-3 / Gemma / Mistral
    ・OpenAI API 互換: Claude / GPT / Groq / LiteLLM
    ・直接 API (Anthropic / OpenAI / Google)

  内蔵機能:
    ・Documents RAG: PDF / TXT / CSV をアップロード
    ・Web 検索 (Brave / Google / Searxng)
    ・画像生成 (AUTOMATIC1111 / ComfyUI / DALL-E)
    ・TTS (OpenAI / ElevenLabs / ローカル)
    ・STT (Whisper)
    ・Artifacts (コード実行・プレビュー)
    ・Pipelines (カスタム処理パイプライン)
```

## 主要機能

```
チャット機能:
  ・モデルセレクター (複数モデル切り替え)
  ・System Prompt テンプレート
  ・Persona (キャラクター設定)
  ・会話のフォーク・ブランチ
  ・共有リンク生成

管理機能:
  ・ユーザー登録・権限管理
  ・モデルアクセス制御
  ・使用量ログ・モニタリング
  ・LDAP / SSO 対応 (Enterprise)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **チーム AI ツール** | Open WebUI を社内サーバーにデプロイ → チーム全員が Claude / Ollama を使用 | API コスト最適化 + チーム展開 |
| **競馬研究 RAG** | 競馬規則 PDF + Open WebUI RAG でオフライン Q&A | ネット不要の知識検索 |
| **競馬 Persona** | 競馬専門家キャラクターを System Prompt で設定 | 特化した予想 AI の即席作成 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'open-webui', 'api',
  'Open WebUI 実践 — インストール/Docker/Ollama連携/Claude統合/RAG/Pipelines/API利用',
  $$## インストール (Docker + Ollama)

```bash
# Ollama を先にインストール・起動
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llama3.2  # モデルダウンロード

# Open WebUI を Docker で起動
docker run -d \
  -p 3000:8080 \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main

# → http://localhost:3000 でアクセス
# 初回: 管理者アカウント作成
```

## Docker Compose (Ollama 同梱版)

```yaml
# docker-compose.yml
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama:/root/.ollama
    restart: unless-stopped

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    ports:
      - "3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      # Claude (Anthropic) を外部 LLM として追加
      - ANTHROPIC_API_KEY=your-anthropic-api-key
      # OpenAI API 互換エンドポイント (Claude 経由)
      - OPENAI_API_BASE_URL=https://api.anthropic.com/v1
      - OPENAI_API_KEY=your-anthropic-api-key
    volumes:
      - open-webui:/app/backend/data
    depends_on:
      - ollama
    restart: unless-stopped

volumes:
  ollama:
  open-webui:
```

## Claude を Open WebUI に追加 (UI)

```text
設定手順:
1. Admin Panel → Settings → Connections
2. "OpenAI API" セクション:
   - API Base URL: https://api.anthropic.com/v1
   - API Key: YOUR_ANTHROPIC_API_KEY
3. 保存 → モデルリストに claude-sonnet-4-6 が追加される
4. チャット画面のモデルセレクターから選択可能
```

## Open WebUI Pipelines (カスタム処理)

```python
# pipelines/keiba_pipeline.py
# Open WebUI に配置するカスタムパイプライン

from typing import List, Optional, Generator, Iterator
from pydantic import BaseModel

class Pipeline:
    class Valves(BaseModel):
        SUPABASE_URL: str = ""
        SUPABASE_KEY: str = ""

    def __init__(self):
        self.name = "競馬予想パイプライン"
        self.valves = self.Valves()

    async def on_startup(self):
        print(f"競馬パイプライン起動: {self.name}")

    async def on_shutdown(self):
        print("競馬パイプライン停止")

    def pipe(
        self,
        user_message: str,
        model_id: str,
        messages: List[dict],
        body: dict,
    ) -> str | Generator | Iterator:
        """
        Open WebUI のメッセージ処理パイプライン
        ユーザーメッセージを前処理して競馬データを追加
        """
        # 競馬関連クエリの場合、Supabase からデータを追加
        if any(kw in user_message for kw in ["競馬", "レース", "馬", "予想"]):
            enhanced = f"""
[競馬データシステム]
Supabase から最新データを取得中...

ユーザー質問: {user_message}

以下のコンテキストで回答してください:
- データソース: Supabase (race_results, horses テーブル)
- 分析観点: 血統・騎手・調教師・コース適性・近走成績
"""
            return enhanced

        return user_message
```

## REST API でのチャット送信

```python
import requests

OPENWEBUI_URL = "http://localhost:3000"
API_KEY = "your-open-webui-api-key"  # Profile → API Keys

def chat(message: str, model: str = "claude-haiku-4-5") -> str:
    """Open WebUI の OpenAI 互換 API でチャット"""
    response = requests.post(
        f"{OPENWEBUI_URL}/api/chat/completions",
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "model": model,
            "messages": [{"role": "user", "content": message}],
            "stream": False,
        },
    )
    return response.json()["choices"][0]["message"]["content"]

# Claude で質問
answer = chat("天皇賞春2026の注目馬は？", model="claude-haiku-4-5")
print(answer)

# ローカル Ollama で質問
answer_local = chat("競馬の三連複の買い方を教えて", model="llama3.2")
print(answer_local)
```

## RAG: ドキュメントをアップロードして質問

```text
UI での RAG 手順:
1. チャット画面の + ボタン → "Upload Files"
2. 競馬規則 PDF / 血統表 CSV をアップロード
3. ファイルがベクター化されて会話コンテキストに追加
4. "このファイルに基づいて答えてください" で RAG 質問

または Documents タブ:
1. Documents → "+ Add Docs"
2. コレクション作成 (例: "競馬規則")
3. PDF を複数アップロード
4. チャットで "#競馬規則" とタグ付けして質問
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 328→329社化: Open WebUI 追加',
  'PS#3 S117。Open WebUI (ローカルLLMフロントエンド/Ollama UI/ChatGPT風/Claude+Ollama統合/内蔵RAG/画像生成/TTS/Pipelines/チームデプロイ/GitHub 50k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
