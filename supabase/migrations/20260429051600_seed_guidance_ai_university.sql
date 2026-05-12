-- PS#3 S114: AI大学 322→323社化 — Guidance (Microsoft/制約付き生成/grammar/構造化出力)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'guidance', 'overview',
  'Guidance — Microsoft 制約付き LLM 生成・grammar 制御・構造化テンプレート (GitHub 19k+ / 9/9)',
  $$## Guidance とは

**Guidance** は **Microsoft が開発する制約付き LLM テキスト生成ライブラリ**。GitHub 19,000+ スター。「**LLM の出力を grammar (文法規則) で制約し、必ず正しい形式のテキストを生成する**」思想が核心。

Instructor が「生成後にバリデーション + リトライ」するのに対し、Guidance は **「生成中にトークンを制限して最初から正しい出力を保証する」**。正規表現・JSON スキーマ・BNF 文法・選択肢リストなど様々な制約を生成時にリアルタイム適用できる。ローカル LLM (llama.cpp / Transformers) でも動作する。

## Guidance のアーキテクチャ

```
Guidance のコアコンセプト:

  Template (テンプレート):
    ・Handlebars ライクなテンプレート構文
    ・{{gen "var"}} で変数を生成
    ・{{#select "var"}}...{{/select}} で選択
    ・{{#each}}...{{/each}} でループ生成

  Constraint (制約):
    ・regex: 正規表現でトークンを制限
    ・grammar: BNF/EBNF 文法で構造を定義
    ・stop: 停止文字列の指定
    ・list_append: リストへの追加
    ・options: 選択肢リストから選ぶ

  Backend (LLM バックエンド):
    ・OpenAI (GPT-4o)
    ・Anthropic Claude
    ・transformers (HuggingFace)
    ・llama_cpp (ローカル GGUF)
    ・VertexAI (Gemini)

  Stateful Generation:
    ・KV キャッシュを保持しながら生成を継続
    ・バックトラックなしで制約を満たす
```

## 主要機能

```
制約の種類:
  ・gen(regex=...): 正規表現制約
  ・gen(grammar=...): BNF 文法制約
  ・select(options=[...]): 列挙から選択
  ・gen(stop="..."): 停止文字列制約

JSON 生成:
  ・json(schema=...): JSON スキーマ準拠の生成
  ・pydantic モデルからスキーマ自動生成

ローカル LLM 対応:
  ・llama.cpp 経由で CPU 推論
  ・量子化モデル (GGUF) でもフル制約対応
  ・GPU 不要で本番運用可能
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬予想フォーマット保証** | 本命/対抗/単穴 を select で強制選択 | 予想フォーマットの 100% 統一 |
| **SQL 生成の安全化** | SQL grammar で不正クエリ生成を防止 | インジェクション対策 |
| **ローカル競馬 AI** | llama.cpp + Guidance で完全オフライン予想 | コスト 0 の高精度予想 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'guidance', 'api',
  'Guidance 実践 — インストール/テンプレート/regex制約/select/JSON生成/Claude統合/llama.cpp',
  $$## インストール

```bash
pip install guidance
pip install guidance[anthropic]   # Claude 統合
pip install guidance[transformers] # HuggingFace
pip install guidance[llama_cpp]    # ローカル GGUF
```

## Claude との基本使用

```python
import guidance
from guidance import models, gen, select

# Claude モデル設定
lm = models.Anthropic("claude-haiku-4-5", api_key="YOUR_ANTHROPIC_API_KEY")

# シンプルな生成
with guidance(lm):
    result = lm + "天皇賞春2026の注目馬は" + gen("horse_name", stop="。") + "です。"

print(result["horse_name"])
```

## select で選択肢を強制

```python
import guidance
from guidance import models, gen, select

lm = models.Anthropic("claude-haiku-4-5", api_key="YOUR_KEY")

@guidance
def predict_rank(lm, horse_name: str):
    lm += f"""
馬名: {horse_name}
競馬専門家として、この馬のレースでの予想ランクを選んでください。

予想ランク: """ + select(
        options=["本命", "対抗", "単穴", "連下", "消し"],
        name="rank",
    )
    lm += f"""
自信度 (1-10): """ + gen("confidence", regex=r"[1-9]|10")
    lm += f"""
一言コメント: """ + gen("comment", stop="\n", max_tokens=50)
    return lm

result = predict_rank(lm, "シャフリヤール")
print(f"ランク: {result['rank']}")
print(f"自信度: {result['confidence']}/10")
print(f"コメント: {result['comment']}")
```

## regex 制約で形式を保証

```python
import guidance
from guidance import models, gen

lm = models.Anthropic("claude-haiku-4-5", api_key="YOUR_KEY")

@guidance
def extract_race_info(lm, race_text: str):
    lm += f"以下のテキストからレース情報を抽出してください:\n{race_text}\n\n"
    lm += "距離: " + gen("distance", regex=r"\d{4}m") + "\n"
    lm += "開催場: " + gen("venue", regex=r"(東京|中山|阪神|京都|中京|札幌|函館|福島|新潟|小倉)") + "\n"
    lm += "グレード: " + gen("grade", regex=r"G[1-3]|OP") + "\n"
    return lm

race_text = "天皇賞春は阪神競馬場で行われる3200mのG1レースです。"
result = extract_race_info(lm, race_text)
print(f"距離: {result['distance']}")
print(f"開催場: {result['venue']}")
print(f"グレード: {result['grade']}")
```

## JSON スキーマ準拠の生成

```python
import guidance
from guidance import models, json as guidance_json
from pydantic import BaseModel
from typing import Literal, List

lm = models.Anthropic("claude-haiku-4-5", api_key="YOUR_KEY")

class HorsePrediction(BaseModel):
    horse_name: str
    rank: Literal["本命", "対抗", "単穴", "連下"]
    confidence: int  # 1-10
    reason: str

class RacePrediction(BaseModel):
    race_name: str
    top_picks: List[HorsePrediction]

@guidance
def structured_prediction(lm, race_name: str):
    lm += f"競馬専門家として{race_name}の予想を JSON で出力してください:\n"
    lm += guidance_json(name="prediction", schema=RacePrediction)
    return lm

result = structured_prediction(lm, "天皇賞春2026")
import json
prediction = json.loads(result["prediction"])
print(f"レース: {prediction['race_name']}")
for pick in prediction["top_picks"]:
    print(f"[{pick['rank']}] {pick['horse_name']} - {pick['reason']}")
```

## ローカル LLM (llama.cpp) で完全オフライン

```python
import guidance
from guidance import models, gen, select

# llama.cpp でローカル GGUF モデルを使用 (GPU 不要)
lm = models.LlamaCpp(
    model="./models/llama-3-8b-instruct.Q4_K_M.gguf",
    n_gpu_layers=0,  # CPU のみ
    n_ctx=4096,
)

@guidance
def offline_prediction(lm, horse_name: str):
    lm += f"競馬予想 - {horse_name}:\n"
    lm += "予想: " + select(["本命", "対抗", "単穴", "消し"], name="rank") + "\n"
    lm += "理由: " + gen("reason", stop="\n", max_tokens=100) + "\n"
    return lm

# API コスト 0 で予想生成
result = offline_prediction(lm, "シャフリヤール")
print(f"オフライン予想: {result['rank']} - {result['reason']}")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 322→323社化: Guidance 追加',
  'PS#3 S114。Guidance (Microsoft製/制約付きLLM生成/grammar制御/regex+select+JSON制約/Handlebarsテンプレート/KVキャッシュ保持/llama.cpp対応/完全オフライン可/GitHub 19k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
