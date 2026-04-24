-- Session PS#4-S38: AI大学 176→178社化 — Meta (Llama 4) 追加
-- Mark Zuckerberg 率いる Meta が推進するオープンソース AI 戦略の中核。
-- Llama 4 Scout (17B×16E MoE / 10M コンテキスト) をオープンウェイトで公開。
-- Meta AI は WhatsApp・Instagram・Messenger・Facebook で 40 億 MAU に無料提供。
-- PyTorch: AI 研究コミュニティ最大シェアの ML フレームワーク (OSS)。
-- api.llama.com で公式 API 提供 (Llama-4-Scout-17B-16E-Instruct)。
-- Step 0: 8.5/9 (OSS AI戦略リーダー / Llama 4 10M ctx / Meta AI 40億MAU / PyTorch / $1.5T時価総額)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'meta',
  'overview',
  'Meta — Llama 4オープンウェイトとMeta AI 40億MAUの二刀流戦略',
  $md$
# Meta — AI をオープンウェイトで民主化する巨人

**Mark Zuckerberg** (CEO) が率いる Meta は、OpenAI・Google との差別化として
**オープンウェイト (OSS) AI 戦略**を核心に据える。

Llama シリーズを Apache 2.0 ライセンスで公開し、
「AI は誰でも使えるべき」という哲学でエコシステムを急拡大。
同時に **Meta AI** を WhatsApp・Instagram・Messenger・Facebook の 40 億 MAU に無料提供し、
世界最大規模の AI アシスタント展開を実現している。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 2004 年 / Mark Zuckerberg (CEO) |
| **本社** | Menlo Park, CA |
| **時価総額** | $1.5T+ (NASDAQ: META) |
| **売上高** | $165B+ (2025 年推定 / 広告収益主体) |
| **AI 研究部門** | FAIR (Meta AI Research) — 基礎研究 / 自然言語処理 / Computer Vision |

## Meta の AI 三本柱

### 1. Llama — オープンウェイト AI の旗手

Google・OpenAI のクローズドモデルへのアンチテーゼとして、
Llama 1 (2023-02) から始まり Llama 4 (2025) まで継続してオープン公開。
Apache 2.0 ライセンスで **商用利用・派生モデル作成が自由**。

- 研究者・スタートアップが自社インフラで動かせる唯一の最高水準 LLM
- Hugging Face での Llama 3.1 405B ダウンロード数: **1.5 億回超**
- Groq・Together AI・Fireworks AI など多数の推論プロバイダーが採用

### 2. Meta AI — 40 億 MAU のパーソナル AI

WhatsApp / Instagram / Messenger / Facebook の全プラットフォームに統合。
ユーザーは特別な操作なしに「@Meta AI」で呼び出せる。

**主な機能**:
- テキスト・画像生成 (Imagine コマンド)
- 検索・情報収集 (Bing リアルタイム連携)
- WhatsApp グループでの共同 AI 体験
- AR グラス (Ray-Ban Meta) での音声 AI

### 3. PyTorch — AI 研究の共通基盤

2016 年に Meta (旧 Facebook AI Research) が公開した ML フレームワーク。
**研究論文の 60%+ が PyTorch で実装**。Google の TensorFlow を市場シェアで逆転した。
$md$,
  'https://ai.meta.com/',
  '2026-04-24',
  1
),

(
  'meta',
  'models',
  'Llama 4 Scout / Maverick / Behemoth — MoEアーキテクチャと10Mコンテキスト',
  $md$
## Llama モデルファミリー (2026-04 時点)

### Llama 4 ファミリー (最新世代)

| モデル | パラメータ | 特徴 | ライセンス |
| :--- | :--- | :--- | :--- |
| **Llama 4 Scout** | 17B×16E (MoE) | **10M トークンコンテキスト** / 高速・軽量 | Apache 2.0 |
| **Llama 4 Maverick** | 17B×128E (MoE) | 高性能 / GPT-4.1 相当 / マルチモーダル | Apache 2.0 |
| **Llama 4 Behemoth** | 2T パラメータ (MoE) | 研究用超大規模 / Llama 4 family の teacher | 準備中 |

**MoE (Mixture of Experts) アーキテクチャ**:
- 全パラメータの一部 (active expert) だけを各トークンで計算
- Maverick は 128 の「専門家」から毎回 17B 分を選択
- 総パラメータ大 × 実計算量小 = 高性能・低コストを両立

### Llama 4 Scout のブレークスルー: 10M コンテキスト

**10M トークン** = 書籍 100 冊分を一度に処理可能。
長文文書・コードベース全体・複数ソースの同時分析が現実的に。

### 前世代 (参考)

| モデル | サイズ | 特徴 |
| :--- | :--- | :--- |
| Llama 3.1 405B | 405B | 最大 GPT-4 相当 (2024) / コミュニティ最人気 |
| Llama 3.1 70B | 70B | バランス型 / ほとんどのタスクで十分 |
| Llama 3.1 8B | 8B | 超軽量 / Edge デバイス対応 |
| Llama 3.2 Vision | 11B / 90B | 画像入力対応 |

### ベンチマーク比較 (Llama 4 Maverick)

| ベンチマーク | Llama 4 Maverick | GPT-4.1 | Claude Sonnet 4.6 |
| :--- | :--- | :--- | :--- |
| MMLU | **88.5%** | 89%+ | 91.5% |
| HumanEval | **77%** | 92%+ | 93%+ |
| GPQA | **69.8%** | 78% | 84% |
| 長文理解 (NIAH 1M) | **94%** | — | 98% |

Llama 4 は主要ベンチマークで GPT-4.1 と競合水準。**オープンウェイトとしては断然トップクラス**。
$md$,
  'https://ai.meta.com/blog/llama-4-multimodal-intelligence/',
  '2026-04-24',
  2
),

(
  'meta',
  'api',
  'Meta Llama API 入門 — api.llama.com / Groq / Together AI',
  $md$
## Meta Llama API のアクセス方法

Llama 4 には **複数のアクセスルート**がある:

| ルート | エンドポイント | 特徴 | 価格 |
| :--- | :--- | :--- | :--- |
| **Meta 公式** | `api.llama.com/v1` | OpenAI 互換 / Meta 運営 | 要確認 |
| **Groq** | `api.groq.com/openai/v1` | 超高速 (最速推論 LPU) | 無料枠あり |
| **Together AI** | `api.together.xyz/v1` | 豊富なオープンモデル | 無料 $25 |
| **Fireworks AI** | `api.fireworks.ai/inference/v1` | 低レイテンシ | 従量課金 |
| **Hugging Face** | Inference API / Spaces | OSS 最大コミュニティ | 無料枠あり |

## Meta 公式 API (Llama 4)

```python
from openai import OpenAI

client = OpenAI(
    api_key="LLAMA_API_KEY",
    base_url="https://api.llama.com/v1"  # Meta 公式エンドポイント
)

response = client.chat.completions.create(
    model="Llama-4-Scout-17B-16E-Instruct",  # このプロジェクトで採用
    messages=[
        {"role": "system", "content": "あなたは自分株式会社のAIアシスタントです。"},
        {"role": "user", "content": "今週のタスクを整理して"}
    ],
    max_tokens=1000
)

print(response.choices[0].message.content)
```

## Groq で Llama 4 を超高速推論

```python
from openai import OpenAI

client = OpenAI(
    api_key="GROQ_API_KEY",
    base_url="https://api.groq.com/openai/v1"
)

response = client.chat.completions.create(
    model="llama-4-scout-17b-16e-instruct",  # Groq での Llama 4 Scout
    messages=[{"role": "user", "content": "3秒でTODO整理して"}],
    max_tokens=500
)
# Groq LPU = 通常の10-20倍の推論速度
```

## Together AI で Llama 4 Maverick

```python
client = OpenAI(
    api_key="TOGETHER_API_KEY",
    base_url="https://api.together.xyz/v1"
)

response = client.chat.completions.create(
    model="meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8",
    messages=[{"role": "user", "content": "GPT-4.1 相当の性能が必要なタスク"}],
    max_tokens=2000
)
```

## ローカル実行 (Ollama)

```bash
# Ollama でローカル実行 (GPU 不要 / 8B まで M1 Mac で動く)
ollama pull llama3.1:8b    # 4.7 GB
ollama run llama3.1:8b

# Python から
import ollama
response = ollama.chat(
    model='llama3.1',
    messages=[{'role': 'user', 'content': '自分株式会社って何?'}]
)
print(response['message']['content'])
```

## 料金比較 (Llama 4 Scout)

| プロバイダー | Input ($/1M) | Output ($/1M) |
| :--- | :--- | :--- |
| Groq | $0.11 | $0.34 |
| Together AI | $0.18 | $0.59 |
| Fireworks AI | $0.15 | $0.60 |
| Meta 公式 | 要確認 | 要確認 |

Llama 4 Scout は **GPT-5.5 比で 10-30 倍安価** でありながら、
多くの実用タスクに十分な性能を持つ。

## アクセス方法 (公式 API)

1. [llama.developer.meta.com](https://llama.developer.meta.com) でアカウント作成
2. API キー発行
3. 環境変数: `export LLAMA_API_KEY=...`
4. `pip install openai` (OpenAI SDK 互換)
$md$,
  'https://llama.developer.meta.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
