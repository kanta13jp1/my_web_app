-- PS#3 S115: AI大学 324→325社化 — Outlines (dottxt-ai/FSM制約付き構造化生成)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'outlines', 'overview',
  'Outlines — FSM 制約付き構造化テキスト生成・正規表現/JSON/CFG (GitHub 10k+ / 9/9)',
  $$## Outlines とは

**Outlines** は **dottxt-ai (旧 .txt) が開発する FSM (有限状態機械) ベースの構造化テキスト生成ライブラリ**。GitHub 10,000+ スター。「**生成プロセス自体を有限状態機械で制約し、トークンレベルで不正な出力を完全にブロックする**」技術が核心。

Instructor が「生成後バリデーション」、Guidance が「生成中制約」であるのに対し、Outlines は **「LLM のサンプリング空間を FSM でマスクし、物理的に無効なトークンを選べなくする」**。リトライも不要で、100% の確率で正しいフォーマットを生成できる。vLLM・Transformers・llama.cpp と統合可能。

## Outlines のアーキテクチャ

```
Outlines の制約メカニズム:

  FSM (有限状態機械) ベース:
    ・正規表現 → NFAに変換 → 決定的DFAへ
    ・各生成ステップでDFAの状態遷移を追跡
    ・次のトークンが状態遷移を満たすもののみ許可
    ・ログit マスキングで物理的に制約

  JSON スキーマ制約:
    ・Pydantic モデル / JSON Schema → 制約グラフ
    ・キー・値・型・入れ子構造をトークンレベルで保証
    ・必須フィールド欠損が物理的に不可能

  CFG (文脈自由文法) 制約:
    ・BNF 文法でアプリ固有の言語を定義
    ・SQL / 数式 / DSL の安全な生成

  バックエンド:
    ・transformers (HuggingFace)
    ・llama.cpp (ローカル)
    ・vLLM (高速推論)
    ・OpenAI Compatible API
```

## 主要機能

```
制約タイプ:
  ・generate.text(): 自由生成
  ・generate.regex(pattern): 正規表現制約
  ・generate.json(schema): JSON スキーマ制約
  ・generate.choice(options): 選択肢制約
  ・generate.format(type): 型制約 (int/float/bool)
  ・generate.cfg(grammar): CFG 文法制約

特長:
  ・リトライ不要 (生成時に100%保証)
  ・ローカルLLMでも完全動作
  ・vLLM と統合でスループット最大化
  ・バッチ処理対応
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **SQL 安全生成** | CFG で SQL 文法を定義 → 不正クエリ物理的ブロック | インジェクション完全防止 |
| **競馬予想フォーマット** | 正規表現で予想テキスト形式を強制 | 100% 一貫したフォーマット |
| **ローカル LLM + 構造化** | llama.cpp + Outlines でオフライン構造化出力 | API コスト 0 + 型安全 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'outlines', 'api',
  'Outlines 実践 — インストール/regex/JSON/choice/cfg/Pydantic/vLLM統合/llama.cpp',
  $$## インストール

```bash
pip install outlines
pip install outlines[transformers]  # HuggingFace
pip install outlines[llamacpp]      # llama.cpp
pip install outlines[vllm]          # vLLM
```

## 基本: HuggingFace モデルで構造化生成

```python
import outlines

# ローカルモデルロード (HuggingFace)
model = outlines.models.transformers(
    "microsoft/Phi-3-mini-4k-instruct",
    device="cpu",  # GPU: "cuda"
)

# 正規表現制約で日付形式を保証
generator = outlines.generate.regex(
    model,
    r"\d{4}年\d{2}月\d{2}日",
)
date = generator("今日の天皇賞春の開催日は")
print(date)  # → "2026年05月03日" (必ず正しい形式)

# 選択肢から選ぶ
grade_generator = outlines.generate.choice(
    model,
    ["G1", "G2", "G3", "OP", "L"],
)
grade = grade_generator("天皇賞春のグレードは")
print(grade)  # → "G1" (必ずリスト内の値)
```

## JSON スキーマ制約 (Pydantic)

```python
import outlines
from pydantic import BaseModel, Field
from typing import Literal, List
from enum import Enum

# 出力スキーマ
class RaceRank(str, Enum):
    HONMEI = "本命"
    TAIKO = "対抗"
    TANNIKU = "単穴"
    RENKKA = "連下"
    KESHI = "消し"

class HorsePrediction(BaseModel):
    horse_name: str = Field(description="馬名")
    rank: RaceRank
    confidence: float = Field(ge=0.0, le=1.0)
    reason: str = Field(max_length=100)

class RacePrediction(BaseModel):
    race_name: str
    top_picks: List[HorsePrediction]
    commentary: str

# ローカルモデル (llama.cpp)
model = outlines.models.llamacpp(
    "./models/llama-3-8b-instruct.Q4_K_M.gguf",
    n_gpu_layers=0,
)

# JSON スキーマ制約 → 100% 正しい JSON が生成される
generator = outlines.generate.json(model, RacePrediction)

prediction = generator(
    "天皇賞春2026の予想をJSON形式で: 出走馬 シャフリヤール, タイトルホルダー"
)

# Pydantic インスタンスとして直接使用
print(f"レース: {prediction.race_name}")
for pick in prediction.top_picks:
    print(f"[{pick.rank.value}] {pick.horse_name} ({pick.confidence:.0%})")
```

## 正規表現制約の高度な使用

```python
import outlines

model = outlines.models.transformers("microsoft/Phi-3-mini-4k-instruct")

# 競馬馬券の金額フォーマット (100円単位)
bet_generator = outlines.generate.regex(
    model,
    r"(100|[1-9]\d{2}|[1-9]\d{3}|[1-9]\d{4})円",
)

# オッズのフォーマット
odds_generator = outlines.generate.regex(
    model,
    r"\d{1,3}\.\d",  # 例: 3.2 / 12.5 / 100.0
)

# 馬番フォーマット (1-18番)
number_generator = outlines.generate.regex(
    model,
    r"(1[0-8]|[1-9])番",
)

bet = bet_generator("推奨購入額は")
print(bet)  # → "500円" など
```

## CFG (文脈自由文法) で SQL 安全生成

```python
import outlines

model = outlines.models.transformers("microsoft/Phi-3-mini-4k-instruct")

# 簡易 SQL 文法 (SELECT のみ許可 → インジェクション防止)
simple_sql_grammar = r"""
    start: select_stmt
    select_stmt: "SELECT" fields "FROM" table_name where_clause?
    fields: field ("," field)*
    field: /[a-zA-Z_][a-zA-Z0-9_]*/
    table_name: /[a-zA-Z_][a-zA-Z0-9_]*/
    where_clause: "WHERE" condition
    condition: field op value
    op: "=" | ">" | "<" | ">="| "<="
    value: /[a-zA-Z0-9_']+/
"""

sql_generator = outlines.generate.cfg(model, simple_sql_grammar)

# DROP / DELETE / INSERT は文法上不可能
safe_query = sql_generator("競馬データから勝ち馬を取得するSQLを書いて")
print(safe_query)
# → "SELECT horse_name FROM race_results WHERE rank = '1'"
```

## vLLM との統合 (高スループット)

```python
import outlines
from pydantic import BaseModel

# vLLM バックエンドで高速推論
model = outlines.models.vllm(
    "meta-llama/Meta-Llama-3-8B-Instruct",
    gpu_memory_utilization=0.8,
)

class HorseData(BaseModel):
    name: str
    age: int
    wins: int

generator = outlines.generate.json(model, HorseData)

# バッチ処理でスループット最大化
prompts = [
    "シャフリヤールの馬データを生成",
    "タイトルホルダーの馬データを生成",
    "ディープボンドの馬データを生成",
]
results = generator(prompts)  # バッチ並列処理
for r in results:
    print(f"{r.name}: {r.age}歳 {r.wins}勝")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 324→325社化: Outlines 追加',
  'PS#3 S115。Outlines (dottxt-ai製/FSM制約付き構造化生成/トークンレベルマスキング/regex+JSON+choice+CFG/Pydantic統合/リトライ不要100%保証/vLLM+llama.cpp対応/GitHub 10k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
