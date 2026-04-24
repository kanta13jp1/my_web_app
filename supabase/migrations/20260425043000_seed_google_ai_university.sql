-- Session PS#4-S38: AI大学 172→174社化 — Google Gemini (DeepMind) 追加
-- Google + DeepMind が 2023 年合併して Google DeepMind を設立。AI インフラ・研究・製品の垂直統合体制へ。
-- Gemini 2.5 Pro: 1M トークンコンテキスト / 最高推論性能 / Thinking mode。
-- Gemini 2.5 Flash: 高速・低コスト / このプロジェクト本番採用 (Casper 役)。
-- Vertex AI (エンタープライズ) + Google AI Studio (無料 playground) の二本立て。
-- NotebookLM: Deep Research 機能でリサーチ効率を革命的に向上 — このプロジェクトでも活用中。
-- Step 0: 9/9 (Alphabet $2T / DeepMind合併 / Gemini 2.5 1Mコンテキスト / NotebookLM / TPU独占 / AI Studio無料)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'google',
  'overview',
  'Google Gemini / DeepMind — AI インフラ垂直統合の巨人',
  $md$
# Google Gemini — 検索・TPU・DeepMind の三位一体

Alphabet ($2T 超の時価総額) が擁する **Google DeepMind** は、
2023 年に Google Brain と DeepMind を統合して誕生した AI 研究・製品部門。
独自 TPU (Tensor Processing Unit) インフラ・世界最大の検索データ・
YouTube 動画データという「3 つの護城河」を持つ唯一の AI 企業。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **設立** | 1998 年 (Google) / 2023 年 Google DeepMind 統合 |
| **CEO** | Sundar Pichai (Alphabet) / Demis Hassabis (Google DeepMind) |
| **親会社** | Alphabet Inc. (NASDAQ: GOOGL) 時価総額 $2T+ |
| **AI 部門** | Google DeepMind (2023-04 統合) |
| **研究実績** | AlphaFold・AlphaGo・Transformer 論文 (2017) の産みの親 |

## Google の AI 競争優位

### 1. TPU (Tensor Processing Unit) 独占

独自設計の AI 専用チップ。v5e / v5p で GPU 比 **3-5 倍** のコスト効率。
Gemini を学習・推論させるインフラを自社で完全制御できる唯一の大手 AI 企業。

### 2. 検索 + YouTube = 世界最大のデータ資産

Google 検索は 1 日あたり **85 億クエリ** を処理し、
ユーザー意図・最新情報・多言語データを継続収集。
YouTube は動画コンテンツの最大レポジトリ。
Gemini の学習データ品質で競合を圧倒。

### 3. NotebookLM — リサーチの革命

長文 PDF・YouTube・URL を AI が自律的に分析・要約・クロス参照する
**無料リサーチツール**。Deep Research 機能で数百ページを数分で調査可能。
学術・ビジネスリサーチの効率を劇的に向上させると口コミで急拡大中。

## Gemini エコシステム

| プロダクト | 用途 |
| :--- | :--- |
| **Gemini (Chat)** | ChatGPT 対抗の汎用 AI チャット |
| **Google AI Studio** | 無料 API Playground (開発者向け) |
| **Vertex AI** | エンタープライズ AI プラットフォーム |
| **NotebookLM** | AI リサーチアシスタント (Deep Research 搭載) |
| **Gemma** | オープンソース軽量モデルファミリー |
$md$,
  'https://deepmind.google/',
  '2026-04-24',
  1
),

(
  'google',
  'models',
  'Gemini 2.5 Pro / Flash — 1Mコンテキストと最高推論性能',
  $md$
## Gemini モデルファミリー (2026-04 時点)

### フラッグシップ系 (Gemini 2.5)

| モデル | 特徴 | Input ($/1M) | Output ($/1M) | Context |
| :--- | :--- | :--- | :--- | :--- |
| **Gemini 2.5 Pro** | 最高性能・複雑推論・コーディング | $1.25 | $10.00 | **1M** |
| **Gemini 2.5 Flash** | 高速・低コスト・実用最強 | $0.075 | $0.30 | 1M |
| **Gemini 2.5 Flash-8B** | 超軽量・超安価 | $0.0375 | $0.15 | 1M |

### 前世代 (Gemini 2.0)

| モデル | 特徴 | Context |
| :--- | :--- | :--- |
| **Gemini 2.0 Flash** | 軽量・実用 | 1M |
| **Gemini 2.0 Flash Experimental** | 新機能テスト | 1M |

### オープンソース系 (Gemma 3)

| モデル | サイズ | 特徴 |
| :--- | :--- | :--- |
| **Gemma 3 27B** | 27B | 最高性能 OSS / Apache 2.0 |
| **Gemma 3 12B** | 12B | バランス型 |
| **Gemma 3 4B** | 4B | モバイル対応 |
| **Gemma 3 1B** | 1B | エッジデバイス |

### Gemini 2.5 Pro のブレークスルー性能

**1M トークンコンテキスト** — 書籍 10 冊分を一度に処理可能。

**Thinking mode** — 推論前に内部で「思考」し、
数学・科学・コーディングで大幅に精度向上:
- AIME 2025: **92.0%** (Thinking モード)
- GPQA Diamond: **86.4%**
- SWE-Bench Verified: **63.8%**
- LiveCodeBench: **70.4%**

### 画像・音声・動画マルチモーダル

Gemini 2.5 は **ネイティブ マルチモーダル** 設計:

| 入力形式 | サポート |
| :--- | :--- |
| テキスト | ✅ |
| 画像 (PNG/JPG/WebP/GIF) | ✅ |
| 音声 (WAV/MP3/AIFF 等) | ✅ |
| 動画 (MP4/MOV 等) | ✅ |
| PDF | ✅ |
$md$,
  'https://deepmind.google/technologies/gemini/',
  '2026-04-24',
  2
),

(
  'google',
  'api',
  'Google Gemini API 入門 — AI Studio / Vertex AI / 無料枠活用',
  $md$
## Google Gemini API の 2 ルート

Gemini API には **2 つのアクセス方法** があり、用途で使い分ける:

| | Google AI Studio | Vertex AI |
| :--- | :--- | :--- |
| **対象** | 個人開発者 / スタートアップ | エンタープライズ |
| **無料枠** | 60 RPM / 1500 RPD (Gemini 1.5 Flash) | 無し |
| **認証** | API キー | Google Cloud IAM |
| **SDK** | `google-generativeai` | `google-cloud-aiplatform` |
| **SLA** | 無し | あり |

## Google AI Studio API (推奨スタート)

```python
import google.generativeai as genai

genai.configure(api_key="AIza...")

model = genai.GenerativeModel("gemini-2.5-flash")

response = model.generate_content(
    "自分株式会社の今日のタスクを整理して"
)
print(response.text)
```

## マルチモーダル (画像 + テキスト)

```python
import PIL.Image

model = genai.GenerativeModel("gemini-2.5-pro")
img = PIL.Image.open("screenshot.png")

response = model.generate_content([
    img,
    "このスクリーンショットのUIの問題点を指摘して"
])
print(response.text)
```

## Thinking mode (深い推論)

```python
model = genai.GenerativeModel("gemini-2.5-pro")

response = model.generate_content(
    "フィボナッチ数列の一般項を求めて",
    generation_config=genai.GenerationConfig(
        thinking_config=genai.ThinkingConfig(
            thinking_budget=10000  # 思考トークン上限
        )
    )
)
print(response.text)
```

## 長文コンテキスト (1M tokens)

```python
# 100ページのPDFを丸ごと処理
import pathlib

pdf_data = pathlib.Path("long_document.pdf").read_bytes()

response = model.generate_content([
    {"mime_type": "application/pdf", "data": pdf_data},
    "この文書の要点を箇条書きで"
])
```

## NotebookLM API (リサーチ自動化)

NotebookLM は直接 API 公開はしていないが、
**Google AI Studio の Grounding 機能**で類似の Web 検索統合が可能:

```python
model = genai.GenerativeModel("gemini-2.5-flash")

# Google 検索グラウンディング有効化
response = model.generate_content(
    "2026年のAI業界最新動向",
    tools=[genai.Tool(google_search_retrieval=genai.GoogleSearchRetrieval())]
)
```

## コスト比較 (Gemini 2.5 Flash の優位性)

| モデル | Input ($/1M) | Output ($/1M) |
| :--- | :--- | :--- |
| **Gemini 2.5 Flash** | **$0.075** | **$0.30** |
| Claude Sonnet 4.6 | $3.00 | $15.00 |
| GPT-5.5 | $5.00 | $30.00 |

Gemini 2.5 Flash は **Claude/GPT 比で 40-100 倍安価** でありながら、
多くの実用タスクで同等以上の性能を発揮する。
大量バッチ処理・RAG パイプライン・監視タスクに最適。

## アクセス方法

1. [aistudio.google.com](https://aistudio.google.com) でアカウント作成
2. API キーを発行 (`AIza...`)
3. `pip install google-generativeai` でインストール
4. 環境変数: `export GEMINI_API_KEY=AIza...`
$md$,
  'https://ai.google.dev/gemini-api/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
