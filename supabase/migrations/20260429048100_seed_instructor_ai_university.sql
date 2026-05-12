-- PS#3 S113: AI大学 321→322社化 — Instructor (構造化出力/Pydantic/Claude統合/Function Calling)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'instructor', 'overview',
  'Instructor — 構造化 LLM 出力・Pydantic バリデーション・自動リトライ (GitHub 9k+ / 9/9)',
  $$## Instructor とは

**Instructor** は **LLM の出力を Pydantic モデルで構造化するライブラリ**。GitHub 9,000+ スター。「**LLM に JSON を確実に出力させる**」ことに特化し、**Pydantic によるバリデーション + 自動リトライ**が核心機能。Claude・OpenAI・Gemini・Cohere・Ollama と統合できる。

従来の JSON 出力は `json.loads(response)` でパースするが、スキーマ違反・欠損フィールド・型ミスマッチが頻発。Instructor は **Function Calling / Tool Use を裏側で使って**、LLM が必ずスキーマに合致した出力をするまで自動リトライする。

## Instructor のアーキテクチャ

```
Instructor の動作フロー:

  1. Pydantic モデル (= 出力スキーマ) を定義
  2. client.chat.completions.create(..., response_model=MyModel)
  3. Instructor が内部で Function Calling / Tool Use に変換
  4. LLM がスキーマに沿った JSON を出力
  5. Pydantic でバリデーション
  6. バリデーション失敗 → 自動リトライ (ValidationError をフィードバック)
  7. 成功 → Pydantic インスタンスとして返却

モード (Anthropic):
  ・ANTHROPIC_TOOLS: Claude の Tool Use API
  ・ANTHROPIC_JSON: JSON モード (schema 埋め込み)
  ・ANTHROPIC_PARALLEL_TOOLS: 並列ツール呼び出し

Validation:
  ・Pydantic フィールドバリデーション (型・制約)
  ・@field_validator / @model_validator
  ・LLM バリデーション (@llm_validator)
```

## 主要機能

```
コア機能:
  ・response_model: Pydantic モデルを指定するだけ
  ・max_retries: バリデーション失敗時の最大リトライ数
  ・Partial モード: ストリーミング中も部分的に構造化
  ・Iterable モード: リストを逐次ストリーム

高度な機能:
  ・Maybe[T]: データが存在するか不明な場合の型
  ・Literal[...]: 列挙値の強制
  ・@llm_validator: LLM 自身にバリデーションを委ねる
  ・Hooks: on_error, on_retry のコールバック

LLM サポート:
  ・Anthropic Claude (ANTHROPIC_TOOLS モード)
  ・OpenAI (TOOLS / JSON モード)
  ・Google Gemini
  ・Cohere
  ・Ollama (ローカル)
  ・LiteLLM (100+ プロバイダー)
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想の構造化** | Claude に HorsePrediction モデルで予想を出力させる | Supabase への確実な INSERT |
| **AI大学 seed 生成** | Claude に ProviderContent モデルで SQL データを生成 | 型安全な provider 追加自動化 |
| **競合調査の構造化** | Competitor モデルで機能比較を確実に JSON 化 | comparison_page データ精度向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'instructor', 'api',
  'Instructor 実践 — インストール/Pydanticモデル定義/Claude統合/自動リトライ/Partial/Iterable/バリデーション',
  $$## インストール

```bash
pip install instructor
pip install anthropic  # Claude 統合
```

## 基本: Claude + Pydantic で構造化出力

```python
import anthropic
import instructor
from pydantic import BaseModel, Field
from typing import Literal

# Instructor でラップした Claude クライアント
client = instructor.from_anthropic(
    anthropic.Anthropic(api_key="YOUR_ANTHROPIC_API_KEY")
)

# 出力スキーマ定義
class HorsePrediction(BaseModel):
    horse_name: str = Field(description="馬名")
    rank: Literal["本命", "対抗", "単穴", "連下"] = Field(description="予想ランク")
    confidence: float = Field(ge=0.0, le=1.0, description="自信度 0.0-1.0")
    reason: str = Field(description="予想根拠 (100字以内)", max_length=100)
    recommended_bet: str = Field(description="推奨馬券種 (単勝/馬連/三連複)")

# Claude に構造化出力を要求
prediction = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=500,
    messages=[{
        "role": "user",
        "content": "天皇賞春2026でシャフリヤールの予想をしてください",
    }],
    response_model=HorsePrediction,
)

# Pydantic インスタンスとして返却
print(f"馬名: {prediction.horse_name}")
print(f"ランク: {prediction.rank}")
print(f"自信度: {prediction.confidence:.0%}")
print(f"根拠: {prediction.reason}")
print(f"推奨馬券: {prediction.recommended_bet}")
```

## リスト出力 (複数馬の予想)

```python
from pydantic import BaseModel, Field
from typing import List
import instructor, anthropic

client = instructor.from_anthropic(anthropic.Anthropic(api_key="YOUR_KEY"))

class RacePrediction(BaseModel):
    race_name: str
    predictions: List[HorsePrediction] = Field(description="上位3頭の予想")
    total_confidence: float = Field(ge=0.0, le=1.0)
    commentary: str = Field(description="レース全体の見解")

prediction = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=1000,
    messages=[{
        "role": "user",
        "content": "天皇賞春2026の上位3頭予想をしてください。出走馬: シャフリヤール, タイトルホルダー, ディープボンド",
    }],
    response_model=RacePrediction,
)

for p in prediction.predictions:
    print(f"[{p.rank}] {p.horse_name} - 自信度: {p.confidence:.0%}")
```

## 自動リトライ (バリデーション失敗時)

```python
from pydantic import BaseModel, field_validator
import instructor, anthropic

client = instructor.from_anthropic(
    anthropic.Anthropic(api_key="YOUR_KEY"),
    max_retries=3,  # バリデーション失敗時に最大3回リトライ
)

class StrictPrediction(BaseModel):
    horse_name: str
    odds: float = Field(gt=1.0, description="オッズ (1.0より大きい必要あり)")
    is_recommended: bool

    @field_validator("horse_name")
    @classmethod
    def name_must_be_japanese(cls, v):
        if not any(ord(c) > 127 for c in v):
            raise ValueError("馬名は日本語カタカナで入力してください")
        return v

# バリデーション失敗 → Claude にエラーをフィードバック → 自動リトライ
result = client.messages.create(
    model="claude-haiku-4-5",
    max_tokens=300,
    messages=[{"role": "user", "content": "シャフリヤールの単勝オッズ予測を教えて"}],
    response_model=StrictPrediction,
)
```

## Partial (ストリーミング中の逐次構造化)

```python
import instructor, anthropic
from instructor import Partial

client = instructor.from_anthropic(anthropic.Anthropic(api_key="YOUR_KEY"))

# ストリーミングしながら部分的に構造化
for partial_result in client.messages.stream(
    model="claude-haiku-4-5",
    max_tokens=500,
    messages=[{"role": "user", "content": "天皇賞春2026の詳細な予想レポートを書いて"}],
    response_model=Partial[RacePrediction],
):
    # フィールドが埋まるたびに更新
    if partial_result.race_name:
        print(f"レース: {partial_result.race_name}")
    if partial_result.commentary:
        print(f"見解: {partial_result.commentary}")
```

## Supabase への構造化 INSERT

```python
import instructor, anthropic
from pydantic import BaseModel
from supabase import create_client

client = instructor.from_anthropic(anthropic.Anthropic(api_key="YOUR_KEY"))
supabase = create_client("YOUR_SUPABASE_URL", "YOUR_SUPABASE_KEY")

class AIProviderContent(BaseModel):
    provider: str
    category: str
    title: str
    content: str

# Claude に provider 情報を構造化で生成させて直接 INSERT
content = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=2000,
    messages=[{"role": "user", "content": "Guidance フレームワークの overview を日本語で生成してください"}],
    response_model=AIProviderContent,
)

supabase.table("ai_university_content").insert(content.model_dump()).execute()
print(f"Inserted: {content.provider}/{content.category}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 321→322社化: Instructor 追加',
  'PS#3 S113。Instructor (構造化LLM出力/Pydanticバリデーション/自動リトライ/AnthropicツールUse/Partial streaming/Maybe型/LLMバリデーター/Supabase直接INSERT/GitHub 9k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
