-- Session PS#3-S45: AI大学 189社化 — Pydantic AI 追加
-- Pydantic (Samuel Colvin) チームが開発する型安全な Python エージェントフレームワーク。
-- Pydantic V2 の型検証基盤の上に構築。依存性注入・ストリーミング・テストツール完備。
-- GitHub 6k+ Stars / MIT License / 本番グレード / FastAPI との親和性が高い。
-- Step 0: 7/9 (Pydantic 実績 / 型安全性 / 本番品質重視 / MIT / Python エコシステム統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'pydantic_ai',
  'overview',
  'Pydantic AI — 型安全な本番グレード Python エージェントフレームワーク',
  $md$
# Pydantic AI — Production-Grade Agents with Type Safety

**Samuel Colvin** (Pydantic v1/v2 作者) と Pydantic チームが開発する
Python エージェントフレームワーク。

Python データ検証の標準ライブラリ **Pydantic V2** の上に構築し、
AI エージェントに型安全性・依存性注入・テスト容易性をもたらす。

GitHub Stars **6,000+** / MIT ライセンス / 2024年12月リリース。

## なぜ Pydantic AI か

Python エコシステムでは FastAPI が Pydantic を採用したことで、
「型安全な Web フレームワーク」が普及した。
Pydantic AI は同じ思想を AI エージェント領域に持ち込む。

| 課題 | Pydantic AI の解決策 |
| :--- | :--- |
| エージェント出力の型不一致 | **`result_type`** で Pydantic モデルを指定 → 検証済み出力 |
| テスト困難 (LLM 非決定論的) | **`TestModel`** でモック差し替え可能 |
| 外部依存のハードコード | **Dependency Injection** で疎結合 |
| ストリーミング処理の複雑さ | **`run_stream()`** で型安全な非同期ストリーム |

## マルチモデル対応

| プロバイダー | モデル名例 |
| :--- | :--- |
| **Anthropic** | `claude-sonnet-4-6` |
| **OpenAI** | `gpt-4o` / `gpt-4.1` |
| **Google** | `gemini-2.5-pro` |
| **Ollama** | `qwen2.5:7b` (ローカル) |
| **Groq** | `llama-3.3-70b-versatile` |
| **Mistral** | `mistral-large-latest` |

## 設計哲学

- **型安全性**: mypy / pyright で静的チェック可能
- **テスト優先**: `pytest` と `TestModel` でユニットテスト容易
- **依存性注入**: FastAPI スタイルの `deps` パターン
- **最小 API**: 複雑な抽象化を避け、Python 本来の構造を活用
$md$,
  'https://ai.pydantic.dev/',
  '2026-04-25',
  1
),

(
  'pydantic_ai',
  'api',
  'Pydantic AI 入門 — Agent・ツール定義・依存性注入・型安全な出力',
  $md$
## インストール

```bash
pip install pydantic-ai

# プロバイダー別
pip install pydantic-ai-slim[anthropic]
pip install pydantic-ai-slim[openai]
pip install pydantic-ai-slim[google-gla]  # Gemini
pip install pydantic-ai-slim[groq]
```

---

## 基本的な Agent

```python
from pydantic_ai import Agent

# シンプルなエージェント
agent = Agent(
    'anthropic:claude-sonnet-4-6',
    system_prompt='あなたは Python の専門家です。'
)

result = agent.run_sync('デコレータとは何ですか？')
print(result.data)
# → "デコレータは関数やクラスを修飾するための構文です..."
```

---

## 型安全な出力 — Pydantic モデルで検証

```python
from pydantic import BaseModel
from pydantic_ai import Agent

class CodeReview(BaseModel):
    rating: int          # 1-10
    issues: list[str]    # 指摘事項
    suggestion: str      # 改善提案
    approved: bool

agent = Agent(
    'anthropic:claude-sonnet-4-6',
    result_type=CodeReview,   # 出力型を指定
    system_prompt='コードレビューを行うエンジニアです。'
)

result = agent.run_sync('''
def add(a, b):
    return a + b
''')
review = result.data   # CodeReview 型が保証される
print(review.rating)   # int 確定
print(review.issues)   # list[str] 確定
```

---

## ツール定義

```python
from pydantic_ai import Agent, RunContext
import httpx

agent = Agent('openai:gpt-4o')

@agent.tool_plain
def get_weather(city: str) -> str:
    """指定都市の現在の天気を取得します。"""
    resp = httpx.get(f'https://api.weather.example.com/{city}')
    return resp.json()['description']

@agent.tool_plain
def search_docs(query: str) -> list[str]:
    """ドキュメントを検索して関連箇所を返します。"""
    # 検索ロジック
    return ["関連文書1...", "関連文書2..."]

result = agent.run_sync('東京の天気と、FastAPI のインストール方法を教えて')
print(result.data)
```

---

## 依存性注入 (Dependency Injection)

```python
from dataclasses import dataclass
from pydantic_ai import Agent, RunContext

@dataclass
class AppDeps:
    db_connection: Any   # DB コネクション
    user_id: str
    api_client: httpx.AsyncClient

agent = Agent(
    'anthropic:claude-sonnet-4-6',
    deps_type=AppDeps,   # 依存型を指定
    system_prompt='ユーザーデータに基づいて回答します。'
)

@agent.tool
async def fetch_user_data(ctx: RunContext[AppDeps]) -> dict:
    """現在のユーザーデータを取得。"""
    user = await ctx.deps.db_connection.get_user(ctx.deps.user_id)
    return user.model_dump()

# 本番環境
async def handle_request(user_id: str):
    async with httpx.AsyncClient() as client:
        deps = AppDeps(
            db_connection=real_db,
            user_id=user_id,
            api_client=client
        )
        result = await agent.run('プロフィールを教えて', deps=deps)
        return result.data
```

---

## ストリーミング

```python
import asyncio
from pydantic_ai import Agent

agent = Agent('anthropic:claude-sonnet-4-6')

async def main():
    async with agent.run_stream('長い説明文を生成してください') as result:
        async for chunk in result.stream():
            print(chunk, end='', flush=True)
    print()
    print(f'\n総トークン: {result.usage().total_tokens}')

asyncio.run(main())
```

---

## テスト — TestModel でモック

```python
import pytest
from pydantic_ai import Agent
from pydantic_ai.models.test import TestModel

agent = Agent('anthropic:claude-sonnet-4-6', result_type=str)

def test_agent_response():
    # LLM を呼ばずにテスト可能
    with agent.override(model=TestModel()):
        result = agent.run_sync('テスト質問')
        assert isinstance(result.data, str)
```
$md$,
  'https://ai.pydantic.dev/agents/',
  '2026-04-25',
  2
),

(
  'pydantic_ai',
  'models',
  'Pydantic AI マルチターン会話・エラーハンドリング・本番デプロイパターン',
  $md$
## マルチターン会話 (会話履歴の管理)

```python
from pydantic_ai import Agent

agent = Agent('anthropic:claude-sonnet-4-6')

# 会話を継続するには message_history を渡す
result1 = agent.run_sync('Python の asyncio とは？')
print(result1.data)

# 前の会話を引き継ぐ
result2 = agent.run_sync(
    'それの主なユースケースは？',
    message_history=result1.new_messages()
)
print(result2.data)
```

---

## エラーハンドリング & リトライ

```python
from pydantic_ai import Agent
from pydantic_ai.exceptions import UnexpectedModelBehavior

agent = Agent(
    'anthropic:claude-sonnet-4-6',
    retries=3,   # 失敗時に最大3回リトライ
)

try:
    result = agent.run_sync('...')
except UnexpectedModelBehavior as e:
    print(f"モデルエラー: {e}")
```

---

## FastAPI との統合

```python
from fastapi import FastAPI, Depends
from pydantic_ai import Agent
from pydantic import BaseModel

app = FastAPI()
agent = Agent('anthropic:claude-sonnet-4-6')

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str
    tokens_used: int

@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    result = await agent.run(req.message)
    return ChatResponse(
        reply=result.data,
        tokens_used=result.usage().total_tokens
    )
```

---

## LangChain / CrewAI との比較

| 比較項目 | Pydantic AI | LangChain | CrewAI |
| :--- | :--- | :--- | :--- |
| 型安全性 | **★★★★★** | ★★☆☆☆ | ★★★☆☆ |
| テスト容易性 | **★★★★★** | ★★★☆☆ | ★★☆☆☆ |
| 依存性注入 | **FastAPI スタイル** | 独自 | 独自 |
| マルチエージェント | 基本的サポート | **豊富** | **★★★★★** |
| ドキュメント量 | 少 (新しい) | **豊富** | 豊富 |
| 学習コスト | 低 (Python 標準的) | 中〜高 | 中 |

## クイックスタート (3 ステップ)

1. `pip install pydantic-ai` でインストール
2. `Agent('anthropic:claude-sonnet-4-6')` でエージェント作成
3. `result = agent.run_sync('質問')` で即実行
$md$,
  'https://ai.pydantic.dev/multi-agent-applications/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
