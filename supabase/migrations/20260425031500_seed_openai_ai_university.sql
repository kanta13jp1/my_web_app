-- Session PS#4-S37: AI大学 168社化 — OpenAI 追加
-- Sam Altman 率いる 2015 年創業の AI 研究企業。ChatGPT で「AI の大衆化」を実現。
-- 評価額 $730-852B (2026-03 調達ラウンド)。ARR $25B+。ChatGPT WAU 9 億人 (2026-02)。
-- GPT-5.5 "Spud" を 2026-04-23 にリリース。SWE-Bench Pro 58.6%。Terminal-Bench 2.0 で
-- Claude Mythos Preview をわずかに上回る。Agents SDK でマルチエージェント構築が可能。
-- Step 0: 9/9 (業界覇権企業 / ChatGPT 9 億 WAU / ARR $25B+ / GPT-5.5 最新 / $852B 評価額)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'openai',
  'overview',
  'OpenAI — ChatGPTで「AIの大衆化」を実現したリーディング企業',
  $md$
# OpenAI — AI を大衆の手に

**2015 年創業**、Sam Altman (CEO) が率いる AI 研究・製品企業。
2022 年 11 月の **ChatGPT 一般公開** で、生成 AI ブームの火付け役となった。

ChatGPT はサービス開始からわずか 5 日で **100 万ユーザー** を突破。
歴史上最速のユーザー獲得記録を持つ。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 2015 年 / Sam Altman・Greg Brockman ら (Elon Musk も共同創業者) |
| **評価額** | $730–852B (2026-03 資金調達ラウンド) |
| **ARR** | $25B+ (2026-02 時点、月次収益 $2B) |
| **ChatGPT WAU** | **9 億人** (2026-02、前年 4 億人から倍増) |
| **主な投資家** | Microsoft ($13B+)・SoftBank・Tiger Global |

## ChatGPT の軌跡

| 年月 | マイルストーン |
| :--- | :--- |
| 2018 | GPT-1 リリース |
| 2020 | GPT-3 (API 提供開始) |
| 2022-11 | **ChatGPT 一般公開** → 5 日で 100 万ユーザー |
| 2023-03 | GPT-4 / ChatGPT Plus |
| 2024 | GPT-4o (音声・画像マルチモーダル) |
| 2025 | o3 推論モデル / GPT-5 系 |
| 2026-04-23 | **GPT-5.5 "Spud" リリース** |

## 最新トピック: GPT-5.5 "Spud" (2026-04-23)

GPT-5.4 からわずか **6 週間** で次世代モデルをリリース。
コードネーム「Spud」として内部で開発、OpenAI 公式発表で名称公開。

**主な改善**:
- ARC-AGI-2: +11.7pp 向上
- SWE-Bench Pro: **58.6%** (実際の GitHub Issue 解決率)
- Terminal-Bench 2.0: Claude Mythos Preview を上回る
- トークン効率: 同品質を **少ないトークン** で達成 → コスト削減効果あり
$md$,
  'https://openai.com/',
  '2026-04-24',
  1
),

(
  'openai',
  'models',
  'GPT-5.5 / o3 / GPT-4.1 — 2026年OpenAIモデルファミリー完全ガイド',
  $md$
## OpenAI モデルファミリー (2026-04 時点)

### フラッグシップ系 (GPT-5 系)

| モデル | 用途 | Input ($/1M) | Output ($/1M) | Context |
| :--- | :--- | :--- | :--- | :--- |
| **GPT-5.5 (Spud)** | 最高性能・エージェント | $5.00 | $30.00 | 1M |
| **GPT-5.5 Pro** | 超高性能・研究 | $30.00 | $180.00 | — |
| **GPT-5.4** | 高性能 (前世代) | $2.50 | $15.00 | — |
| **GPT-5.4 mini** | 高速・廉価版 | $0.75 | $4.50 | — |
| **GPT-5.4 nano** | 最軽量 | $0.20 | $1.25 | — |

### 推論特化系 (o 系)

| モデル | 特徴 | Input ($/1M) | Output ($/1M) |
| :--- | :--- | :--- | :--- |
| **o3** | 数学・科学・コード推論 | $2.00 | $8.00 |
| **o4-mini** | コスト効率重視推論 | $1.10 | — |

### 長文コンテキスト系 (GPT-4.1 系)

| モデル | 用途 | Input ($/1M) | Output ($/1M) | Context |
| :--- | :--- | :--- | :--- | :--- |
| **GPT-4.1** | 長文書処理 | $2.00 | $8.00 | 1M |
| **GPT-4.1 mini** | 大コンテキスト・バリュー | $0.40 | $1.60 | — |
| **GPT-4.1 nano** | 最安 | $0.10 | $0.40 | — |

### 画像生成

| モデル | 用途 |
| :--- | :--- |
| **DALL-E 3** | テキスト→画像 (ChatGPT / API) |
| **GPT-4o Images** | テキスト+参照画像→画像 (高精度) |

### GPT-5.5 エージェント能力

GPT-5.5 は単なる「賢い回答者」ではなく、**自律エージェント**として設計:

1. 複雑なタスクを受け取り **計画立案**
2. ツール (Web 検索・コード実行・ファイル操作) を **自律選択**
3. 中間結果を **自己チェック** しながら進行
4. 最終成果物を **自律デリバリー**

SWE-Bench Pro 58.6% = 実際の GitHub Issue の **6 割近くを自律解決** できる水準。
$md$,
  'https://platform.openai.com/docs/models',
  '2026-04-24',
  2
),

(
  'openai',
  'api',
  'OpenAI API 入門 — GPT-5.5 / Agents SDK',
  $md$
## OpenAI API の基本

| 項目 | 内容 |
| :--- | :--- |
| **エンドポイント** | `https://api.openai.com/v1` |
| **公式 SDK** | Python (`openai`) / TypeScript (`openai`) |
| **認証** | `Authorization: Bearer sk-...` |
| **最大コンテキスト** | 1M トークン (GPT-5.5 / GPT-4.1) |

## Chat Completions API (GPT-5.5)

```python
from openai import OpenAI

client = OpenAI(api_key="sk-...")

response = client.chat.completions.create(
    model="gpt-5.5",               # 最新フラッグシップ
    messages=[
        {"role": "system", "content": "あなたはAIアシスタントです。"},
        {"role": "user", "content": "自分株式会社の特徴を教えて"}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)
print(f"使用トークン: {response.usage.total_tokens}")
```

## Responses API (ビルトインツール統合)

```python
response = client.responses.create(
    model="gpt-5.5",
    input="最新のAI業界ニュースをまとめて",
    tools=[
        {"type": "web_search_preview"},        # Web 検索
        {"type": "code_interpreter"},           # コード実行
        {"type": "file_search"}                 # ファイル検索
    ]
)
```

## Agents SDK (マルチエージェント)

```python
from openai import OpenAI
from openai.agents import Agent, Runner

# エージェントを定義
research_agent = Agent(
    name="リサーチエージェント",
    instructions="ユーザーの質問に対してWebで調査し、要点をまとめる",
    model="gpt-5.5",
    tools=["web_search_preview"]
)

writer_agent = Agent(
    name="ライターエージェント",
    instructions="リサーチ結果を元に日本語でブログ記事を書く",
    model="gpt-5.4",
)

# Orchestrator として実行
runner = Runner()
result = runner.run(
    agents=[research_agent, writer_agent],
    input="Flutter Web の 2026 年最新動向を調査して記事を書いて"
)
print(result.output)
```

## 画像生成 (DALL-E 3)

```python
response = client.images.generate(
    model="dall-e-3",
    prompt="自分株式会社のロゴ: シンプル、ミニマル、ダークブルー",
    size="1024x1024",
    quality="hd",
    n=1
)

image_url = response.data[0].url
```

## コスト最適化のヒント

1. **モデル選択**: 単純な質問応答 → `gpt-5.4-nano` ($0.10/$0.40)、複雑なエージェント → `gpt-5.5`
2. **キャッシュ活用**: 同じシステムプロンプトを繰り返す場合は Prompt Caching で最大 50% 削減
3. **Batch API**: 非同期タスクは Batch API で 50% オフ
4. **o3 vs GPT-5.5**: 数学・論理パズルは `o3` の方がコスト効率が高いことが多い

## アクセス方法

1. [platform.openai.com](https://platform.openai.com) でアカウント作成
2. API キーを生成 (`sk-...`)
3. `pip install openai` でインストール
4. 環境変数: `export OPENAI_API_KEY=sk-...`
$md$,
  'https://platform.openai.com/docs/api-reference',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
