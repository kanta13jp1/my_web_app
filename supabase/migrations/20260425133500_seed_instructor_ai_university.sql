-- Session PS#3-S46: AI大学 192→193社化 — Instructor 追加
-- LLM から Pydantic モデルで型安全な構造化出力を得るための Python ライブラリ。
-- Jason Liu (jxnl) 作。OpenAI・Anthropic・Gemini・Mistral など全主要 LLM 対応。
-- 自動バリデーション・リトライ・パーシャルストリーミングを提供。GitHub 10k+ Stars / MIT。
-- Step 0: 8/9 (構造化出力は LLM 実用化の基礎 / 全 LLM 対応 / 10k+ Stars / 本番採用多数)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'instructor',
  'overview',
  'Instructor — Pydantic モデルで LLM から型安全な構造化出力を得るライブラリ',
  $md$
# Instructor — Structured Outputs from LLMs

**LLM のレスポンスを Pydantic モデルで型安全に受け取る**ための Python ライブラリ。

"LLM が JSON を返す" という難題を、Pydantic の型システムと組み合わせて解決。
自動バリデーション・エラー時リトライ・ストリーミング対応を提供する。

**Jason Liu (jxnl)** — 元 Apple・元 Stitch Fix のエンジニアが開発。
GitHub **10,000+ Stars** / MIT ライセンス。

## なぜ Instructor か

| 課題 | Instructor の解決策 |
| :--- | :--- |
| LLM の JSON 出力が不安定 | **Pydantic バリデーション** — 型検証を自動実行 |
| バリデーション失敗時の処理が複雑 | **自動リトライ** — エラーメッセージを LLM にフィードバック |
| ストリーミングで構造化データを扱えない | **Partial Streaming** — 中間状態でも型安全 |
| プロバイダーごとに実装が違う | **Universal API** — 単一インターフェース |
| ネスト構造が難しい | **Complex Nesting** — Pydantic の全機能が使える |

## 対応 LLM プロバイダー

| プロバイダー | モード |
| :--- | :--- |
| **OpenAI / Azure** | function calling, json_mode, structured_outputs |
| **Anthropic (Claude)** | tool_use |
| **Google Gemini** | json_mode |
| **Mistral** | function calling |
| **Cohere** | tool_use |
| **Ollama** | json_mode |
| **Groq** | json_mode |

## 主要ユースケース

- **情報抽出**: テキスト/PDF から構造化データを抽出
- **フォーム処理**: 自然言語入力を型安全なオブジェクトに変換
- **分類タスク**: 複数クラスへの分類をEnum型で受け取る
- **RAG**: 検索クエリを構造化してベクターDBに渡す
- **エージェント**: ツール呼び出しの引数を型安全に生成
$md$,
  'https://python.useinstructor.com/',
  '2026-04-25',
  1
),

(
  'instructor',
  'api',
  'Instructor 入門 — Pydantic モデルで OpenAI・Anthropic・Gemini から構造化出力を得る',
  $md$
## インストール

```bash
pip install instructor

# プロバイダー別の追加依存
pip install anthropic    # Claude 用
pip install google-generativeai  # Gemini 用
```

---

## 基本的な使い方 (OpenAI)

```python
import instructor
from openai import OpenAI
from pydantic import BaseModel, Field

# Instructor でクライアントをパッチ
client = instructor.from_openai(OpenAI())

# 返してほしいデータ構造を Pydantic で定義
class UserProfile(BaseModel):
    name: str = Field(description="ユーザーの氏名")
    age: int = Field(description="年齢", ge=0, le=120)
    email: str = Field(description="メールアドレス")
    interests: list[str] = Field(description="趣味・関心リスト")

# 通常の chat.completions.create に response_model を追加するだけ
user = client.chat.completions.create(
    model="gpt-4o",
    response_model=UserProfile,  # ← これだけ追加
    messages=[{
        "role": "user",
        "content": "山田太郎、35歳、yamada@example.com、趣味はプログラミングと読書"
    }]
)

print(user.name)       # "山田太郎"
print(user.age)        # 35
print(user.interests)  # ["プログラミング", "読書"]
```

---

## Anthropic (Claude) との統合

```python
import instructor
import anthropic
from pydantic import BaseModel

# Claude クライアントに Instructor をパッチ
client = instructor.from_anthropic(anthropic.Anthropic())

class IssueAnalysis(BaseModel):
    severity: str          # "low", "medium", "high", "critical"
    category: str          # "bug", "feature", "docs"
    summary: str
    suggested_labels: list[str]
    estimated_effort: int  # 時間

# GitHub Issue を Claude に解析させる
issue_text = """
タイトル: ログイン後にダッシュボードが表示されない
説明: メールアドレスとパスワードでログインすると、
      「ページが見つかりません」エラーが出る。
      再現率 100%。
"""

analysis = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    response_model=IssueAnalysis,
    messages=[{
        "role": "user",
        "content": f"この GitHub Issue を分析してください:\n{issue_text}"
    }]
)

print(f"重要度: {analysis.severity}")   # "high"
print(f"カテゴリ: {analysis.category}") # "bug"
print(f"推奨ラベル: {analysis.suggested_labels}")
```

---

## バリデーションとリトライ

```python
import instructor
from openai import OpenAI
from pydantic import BaseModel, field_validator
import re

client = instructor.from_openai(OpenAI())

class Email(BaseModel):
    address: str

    @field_validator("address")
    @classmethod
    def validate_email(cls, v: str) -> str:
        # 正規表現でメール形式を検証
        if not re.match(r"[^@]+@[^@]+\.[^@]+", v):
            raise ValueError(f"無効なメールアドレス: {v}")
        return v.lower()

# バリデーション失敗時はエラーメッセージを LLM にフィードバックして自動リトライ
email = client.chat.completions.create(
    model="gpt-4o",
    response_model=Email,
    max_retries=3,  # 最大3回リトライ
    messages=[{
        "role": "user",
        "content": "私のメールは yamada at example dot com です"
    }]
)
print(email.address)  # "yamada@example.com"
```

---

## 複雑なネスト構造

```python
from typing import Optional
from pydantic import BaseModel

class Author(BaseModel):
    name: str
    github_handle: str

class PullRequest(BaseModel):
    title: str
    description: str
    author: Author
    reviewers: list[Author]
    labels: list[str]
    priority: int = Field(ge=1, le=5)
    breaking_change: bool
    related_issue: Optional[int] = None

# ネストした構造も自動で解析
pr = client.chat.completions.create(
    model="gpt-4o",
    response_model=PullRequest,
    messages=[{
        "role": "user",
        "content": """
        PR情報: 山田太郎(@yamada)がレビュアーに佐藤花子(@sato)を指定して
        「認証バグ修正」というPRを作成。Issue #123 に関連。優先度4。
        破壊的変更あり。ラベル: bug, urgent
        """
    }]
)
print(pr.author.github_handle)  # "yamada"
print(pr.breaking_change)       # True
```

---

## ストリーミング (部分的な構造化出力)

```python
import instructor
from openai import OpenAI
from pydantic import BaseModel

client = instructor.from_openai(OpenAI(), mode=instructor.Mode.TOOLS)

class BlogPost(BaseModel):
    title: str
    summary: str
    tags: list[str]
    content: str

# Partial でストリーミング中も型安全
for partial_post in client.chat.completions.create_partial(
    model="gpt-4o",
    response_model=BlogPost,
    messages=[{"role": "user", "content": "AI エージェントについてのブログ記事を書いて"}],
    stream=True,
):
    # フィールドが埋まるたびにリアルタイム更新
    if partial_post.title:
        print(f"タイトル: {partial_post.title}")
    if partial_post.tags:
        print(f"タグ: {partial_post.tags}")
```
$md$,
  'https://python.useinstructor.com/concepts/patching/',
  '2026-04-25',
  2
),

(
  'instructor',
  'models',
  'Instructor 本番実装 — 情報抽出・分類・RAG・エージェント連携パターン',
  $md$
## 情報抽出パイプライン

```python
import instructor
import anthropic
from pydantic import BaseModel, Field
from typing import Optional
import json

client = instructor.from_anthropic(anthropic.Anthropic())

class CompanyInfo(BaseModel):
    name: str
    founding_year: Optional[int] = None
    headquarters: Optional[str] = None
    funding_total_usd: Optional[int] = None
    key_products: list[str] = Field(default_factory=list)
    competitors: list[str] = Field(default_factory=list)
    public_company: bool = False

def extract_company_info(article_text: str) -> CompanyInfo:
    return client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=2048,
        response_model=CompanyInfo,
        messages=[{
            "role": "user",
            "content": f"以下の記事から企業情報を抽出してください:\n\n{article_text}"
        }]
    )

# 競合企業の記事を解析
article = "Notion は 2016 年創業、サンフランシスコ本拠地の..."
info = extract_company_info(article)
print(json.dumps(info.model_dump(), ensure_ascii=False, indent=2))
```

---

## 多段階分類 (階層的カテゴリ)

```python
from enum import Enum
from pydantic import BaseModel

class MainCategory(str, Enum):
    BUG = "bug"
    FEATURE = "feature"
    DOCS = "docs"
    PERFORMANCE = "performance"

class SubCategory(str, Enum):
    UI = "ui"
    API = "api"
    AUTH = "auth"
    DATABASE = "database"
    DEPLOYMENT = "deployment"

class IssueClassification(BaseModel):
    main_category: MainCategory
    sub_category: SubCategory
    confidence: float = Field(ge=0.0, le=1.0)
    reasoning: str

# GitHub Issue の自動分類
issue = "ログイン後にダッシュボードが 500 エラーになる"
classification = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=512,
    response_model=IssueClassification,
    messages=[{"role": "user", "content": f"Issue を分類: {issue}"}]
)
print(f"{classification.main_category.value}/{classification.sub_category.value}")
# "bug/auth"
```

---

## RAG との統合

```python
from pydantic import BaseModel, Field

class SearchQuery(BaseModel):
    query: str = Field(description="ベクターDBへの検索クエリ")
    filters: dict = Field(default_factory=dict, description="メタデータフィルタ")
    limit: int = Field(default=5, ge=1, le=20)

class RAGAnswer(BaseModel):
    answer: str
    sources: list[str] = Field(description="参照したソースのリスト")
    confidence: float = Field(ge=0.0, le=1.0)
    follow_up_questions: list[str] = Field(description="関連質問の提案")

# Step 1: クエリを構造化
query = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=256,
    response_model=SearchQuery,
    messages=[{"role": "user", "content": "Composio と LangChain の違いを教えて"}]
)

# Step 2: ベクターDB を検索 (仮)
docs = vector_db.search(query.query, limit=query.limit)

# Step 3: 構造化回答を生成
answer = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    response_model=RAGAnswer,
    messages=[{
        "role": "user",
        "content": f"以下のドキュメントを参照して回答:\n\n{docs}\n\n質問: {query.query}"
    }]
)
print(f"信頼度: {answer.confidence}")
print(f"フォローアップ: {answer.follow_up_questions}")
```

---

## このプロジェクト (自分株式会社) での活用例

```python
# GitHub Issue を解析して WBS タスクに自動変換
class WBSTask(BaseModel):
    title: str
    description: str
    instance: str = Field(description="ps1-6, win, vscode, web のいずれか")
    estimated_hours: float
    priority: int = Field(ge=1, le=5)
    related_ef: Optional[str] = None

def issue_to_wbs(issue_body: str) -> WBSTask:
    return client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        response_model=WBSTask,
        messages=[{
            "role": "user",
            "content": f"この Issue を WBS タスクに変換:\n{issue_body}"
        }]
    )
```

## クイックスタート (3 ステップ)

1. `pip install instructor anthropic` でインストール
2. `client = instructor.from_anthropic(anthropic.Anthropic())` でパッチ
3. `client.messages.create(..., response_model=YourPydanticModel)` で型安全な出力を取得
$md$,
  'https://python.useinstructor.com/concepts/retrying/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
