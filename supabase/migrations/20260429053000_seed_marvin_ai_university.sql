-- PS#3 S114: AI大学 323→324社化 — Marvin (AI Function Decorator/型安全なAI関数)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'marvin', 'overview',
  'Marvin — AI Function Decorator・型安全 AI 関数・@ai_fn・自動プロンプト生成 (GitHub 5k+ / 8/9)',
  $$## Marvin とは

**Marvin** は **Prefect 社が開発する AI Function Decorator ライブラリ**。GitHub 5,000+ スター。「**Python の関数に `@ai_fn` デコレータを付けるだけで、その関数が AI で動作するようになる**」という革新的なアプローチ。

関数のシグネチャ・型アノテーション・docstring から自動的にプロンプトを生成し、LLM を呼び出して型安全な結果を返す。**AI をコードに自然に統合する「AI as Code」**思想の体現。Instructor や Guidance と並ぶ構造化出力系の重要ライブラリ。

## Marvin のアーキテクチャ

```
Marvin のコアコンセプト:

  @ai_fn (AI 関数):
    ・Python 関数 + デコレータ = AI 実装
    ・型アノテーションで出力型を強制
    ・docstring がプロンプトになる
    ・sync / async 両対応

  AI Components:
    ・ai_fn: 汎用 AI 関数
    ・ai_classifier: 分類 (Enum から選ぶ)
    ・ai_model: Pydantic モデル生成
    ・cast: 任意の型にキャスト
    ・extract: テキストからエンティティ抽出
    ・generate: リスト生成
    ・classify: 分類 (ラベルリスト)
    ・summarize: サマリー生成

  Settings:
    ・marvin.settings.openai.api_key
    ・marvin.settings.anthropic.api_key
    ・モデル・温度・max_tokens の設定
```

## 主要機能

```
コア関数群:
  ・marvin.cast(text, target_type): 型変換
  ・marvin.extract(text, target_type): 抽出
  ・marvin.classify(text, labels): 分類
  ・marvin.generate(target_type, n): 生成
  ・marvin.summarize(text): 要約

AI クラス:
  ・AIApplication: ステートフルなAIアプリ
  ・AIModel: Pydantic ベースの AI モデル生成

LLM サポート:
  ・OpenAI (デフォルト)
  ・Anthropic Claude
  ・Azure OpenAI
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬データ分類** | ai_classifier で馬の適性を自動分類 | 手動ルール不要の自動分類 |
| **コメント抽出** | extract で競馬記事から馬名・オッズを抽出 | スクレイピング後処理の AI 化 |
| **予想関数 1 行化** | @ai_fn で予想ロジックを宣言的に定義 | 予想コードの劇的簡素化 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'marvin', 'api',
  'Marvin 実践 — インストール/@ai_fn/cast/extract/classify/generate/Claude統合/AIApplication',
  $$## インストール

```bash
pip install marvin
pip install "marvin[anthropic]"  # Claude 統合
```

## Claude 設定

```python
import marvin

# Claude をデフォルト LLM に設定
marvin.settings.anthropic.api_key = "YOUR_ANTHROPIC_API_KEY"
marvin.settings.anthropic.chat.completions.model = "claude-haiku-4-5"
```

## @ai_fn (AI 関数デコレータ)

```python
import marvin
from marvin import ai_fn
from pydantic import BaseModel

marvin.settings.anthropic.api_key = "YOUR_KEY"

# 関数定義 = プロンプト定義
@ai_fn
def predict_horse(horse_name: str, race_name: str) -> str:
    """競馬専門家として、指定した馬のレース予想を日本語で簡潔に述べてください。
    本命/対抗/単穴/消しのどれかを最初に書き、理由を50字以内で説明してください。"""

result = predict_horse("シャフリヤール", "天皇賞春2026")
print(result)
# → "本命: 長距離適性と直近の好調を考慮すると最有力候補。騎手相性も良好。"

# 型安全な返却値
class HorseScore(BaseModel):
    rank: str
    score: int
    reason: str

@ai_fn
def score_horse(horse_name: str, race_info: str) -> HorseScore:
    """競馬データを分析して馬のスコアリングを行う。
    rank は本命/対抗/単穴/連下/消し から選ぶ。
    score は 1-100 の整数。reason は 80字以内。"""

score = score_horse("シャフリヤール", "天皇賞春2026 3200m 阪神 G1")
print(f"ランク: {score.rank}, スコア: {score.score}")
print(f"根拠: {score.reason}")
```

## marvin.cast (型変換)

```python
import marvin
from enum import Enum

marvin.settings.anthropic.api_key = "YOUR_KEY"

class RaceType(Enum):
    FLAT = "平地"
    OBSTACLE = "障害"
    BANEI = "ばんえい"

class Surface(Enum):
    TURF = "芝"
    DIRT = "ダート"

# テキストから型安全に変換
race_type = marvin.cast("阪神大賞典は芝3000mのレース", target=RaceType)
print(race_type)  # → RaceType.FLAT

surface = marvin.cast("フェブラリーステークスはダート1600m", target=Surface)
print(surface)  # → Surface.DIRT

# 数値変換
distance = marvin.cast("天皇賞春の距離は三千二百メートル", target=int)
print(distance)  # → 3200
```

## marvin.extract (エンティティ抽出)

```python
import marvin
from pydantic import BaseModel
from typing import List

marvin.settings.anthropic.api_key = "YOUR_KEY"

class RaceEntry(BaseModel):
    horse_name: str
    jockey: str
    odds: float

# テキストから複数エンティティを自動抽出
race_text = """
天皇賞春の出走馬: シャフリヤール(デムーロ 3.2倍)、
タイトルホルダー(横山武史 4.5倍)、ディープボンド(和田竜二 8.1倍)
"""

entries = marvin.extract(race_text, target=RaceEntry)
for entry in entries:
    print(f"{entry.horse_name} / {entry.jockey} / {entry.odds}倍")
```

## marvin.classify (分類)

```python
import marvin
from typing import Literal

marvin.settings.anthropic.api_key = "YOUR_KEY"

# ラベルリストへの分類
def classify_race_comment(comment: str) -> str:
    return marvin.classify(
        comment,
        labels=["好調", "普通", "不調", "判断不可"],
    )

comments = [
    "先週の調教で最高タイムをマーク、状態は万全",
    "やや重く映るが許容範囲内",
    "前走から馬体重が大幅減、心配される",
]

for c in comments:
    label = classify_race_comment(c)
    print(f"[{label}] {c[:30]}...")
```

## marvin.generate (リスト生成)

```python
import marvin
from pydantic import BaseModel

marvin.settings.anthropic.api_key = "YOUR_KEY"

class RaceStrategy(BaseModel):
    strategy_name: str
    description: str
    suitable_race_type: str

# AI が複数の競馬戦略を生成
strategies = marvin.generate(
    target=RaceStrategy,
    n=3,
    instructions="日本競馬での実践的な馬券戦略を3つ生成してください",
)

for s in strategies:
    print(f"戦略: {s.strategy_name}")
    print(f"説明: {s.description}")
    print(f"適したレース: {s.suitable_race_type}\n")
```

## AIApplication (ステートフルな AI アプリ)

```python
from marvin import AIApplication
from pydantic import BaseModel

class RacingState(BaseModel):
    current_race: str = ""
    analyzed_horses: list[str] = []
    final_picks: list[str] = []

# ステートを保持する AI アプリ
racing_advisor = AIApplication(
    name="競馬予想アドバイザー",
    description="日本競馬の予想をサポートするAIアシスタント。会話履歴を記憶して一貫した予想を提供する。",
    state=RacingState(),
)

# 会話形式で予想
racing_advisor.say("今週の天皇賞春について教えて")
racing_advisor.say("シャフリヤールの評価は？")
racing_advisor.say("最終的な買い目を教えて")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 323→324社化: Marvin 追加',
  'PS#3 S114。Marvin (Prefect製/AI Function Decorator/@ai_fn/cast+extract+classify+generate/Pydantic型安全/docstring自動プロンプト化/AIApplication/Claude統合/GitHub 5k+/8/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
