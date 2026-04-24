-- Session PS#4-S37: AI大学 168社化 — xAI (Grok) 追加
-- Elon Musk が 2023年7月に創業。X (Twitter) リアルタイムデータへの直接アクセスが最大の差別化軸。
-- SpaceX が 2026年2月に買収 (評価額 $250B)。Series E $20B (2026年1月 / Nvidia・Cisco・QIA 等)。
-- Grok 4 Heavy: AIME 2025 100%満点達成 (15/15)。Grok 4.3 beta: SuperGrok Heavy ($300/月) 限定。
-- API は api.x.ai で OpenAI SDK 完全互換。2M トークンコンテキスト (Grok 4.20)。
-- Step 0: 8.5/9 (Elon Musk ブランド / X リアルタイムデータ独占 / $250B / Grok 4 AIME 100% / $20B Series E)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'x',
  'overview',
  'xAI (Grok) — Xリアルタイムデータ×AGI最前線企業',
  $md$
# xAI — X リアルタイムデータ × AGI 研究企業

**Elon Musk** が 2023 年 7 月に設立した AI 研究企業。
Twitter (現 X) を 2022 年に買収した Musk が、X の膨大なリアルタイムデータを
学習・推論に活用できる **唯一の主要 LLM 企業** として立ち上げた。

2026 年 2 月、**SpaceX が xAI を all-stock 取引で買収**。
xAI 評価額 $250B・SpaceX $1T を合算した **$1.25T 複合エンティティ**に統合。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 2023 年 7 月 / Elon Musk |
| **本社** | サンフランシスコ (旧 Twitter HQ 活用) |
| **評価額** | $250B (SpaceX 買収 2026-02 時点) |
| **Series E** | $20B (2026-01) / Nvidia・Cisco・QIA・Abu Dhabi MGX |
| **累計調達** | $42B+ |
| **関連企業** | X (旧 Twitter)・SpaceX・Tesla・Neuralink・Boring Company |

## 最大の差別化: X リアルタイムデータアクセス

Grok は **X (旧 Twitter) の投稿・トレンド・ユーザー会話** にリアルタイムでアクセスできる唯一の主要 LLM。

- 速報ニュース・SNS の最新トレンドを即時参照
- X プレミアム加入者は Grok を無料で利用可能
- **DeepSearch**: X + Web をリアルタイムスキャンして複合リサーチ回答を生成

## ビジネスモデル

| プラン | 価格 | 主な機能 |
| :--- | :--- | :--- |
| **Free** | $0 | 利用回数制限あり |
| **SuperGrok** | $30/月 ($300/年) | 無制限画像生成 (Grok Imagine) + DeepSearch |
| **SuperGrok Heavy** | $300/月 | Grok 4 Heavy (16 エージェント並列) + Grok 4.3 beta + Grok Computer |
$md$,
  'https://x.ai/',
  '2026-04-24',
  1
),

(
  'x',
  'models',
  'Grok 4.3 beta — AGI水準のコーディング・科学推論モデル',
  $md$
## Grok モデルファミリー (2026-04 時点)

| モデル | リリース | 主な特徴 |
| :--- | :--- | :--- |
| **Grok 3** | 2025-02-17 | 1M コンテキスト / MMLU 92.7% / AIME 2025 93.3% |
| **Grok 4** | 2025-07-09 | 200,000 GPU で学習 / Humanity's Last Exam ~50% |
| **Grok 4 Heavy** | 2025-07 | **AIME 2025 100%満点** (15/15) / HMMT25 96.7% / GPQA 88.4% |
| **Grok 4.20** | 2026-02 | **2M トークンコンテキスト** (西側クローズドモデル最大) / 16 エージェント並列 |
| **Grok 4.3 beta** | 2026-04-17 | ネイティブ PDF 生成 / PowerPoint / スプレッドシート / 動画入力 |

### Grok 4.3 beta (SuperGrok Heavy 限定)

2026 年 4 月 17 日、**SuperGrok Heavy ($300/月)** のみに先行公開。

**新機能**:
- 📄 **PDF ネイティブ生成** — マークアップなしで直接 PDF ファイルを出力
- 📊 **PowerPoint スライド出力** — プレゼン資料を直接生成
- 📈 **スプレッドシート出力** — データ分析結果を直接 Excel/CSV に
- 🎥 **動画入力** — 動画ファイルをそのままプロンプトに添付可能

**モデル規模**: 約 0.5T パラメータ (1T チェックポイントで訓練)

### AGI ベンチマーク比較

| ベンチマーク | Grok 4 Heavy | GPT-5.4 | Claude 3.7 |
| :--- | :--- | :--- | :--- |
| AIME 2025 | **100%** (15/15) | 72% | 80% |
| HMMT 2025 | **96.7%** | — | — |
| GPQA | **88.4–88.9%** | 78% | 84% |
| Humanity's Last Exam | ~50% | 34% | — |

Grok 4 Heavy は競合他社比で数学・科学推論ベンチマークで トップクラスの性能を示している。
$md$,
  'https://x.ai/news/grok-4',
  '2026-04-24',
  2
),

(
  'x',
  'api',
  'xAI API 入門 — OpenAI SDK 互換・2Mコンテキスト',
  $md$
## xAI API の特徴

xAI の API は **OpenAI SDK と完全互換**。
`base_url` を切り替えるだけで既存の OpenAI コードをそのまま移行できる。

| 項目 | 内容 |
| :--- | :--- |
| **エンドポイント** | `https://api.x.ai/v1` |
| **SDK 互換** | OpenAI Python SDK / TypeScript SDK / Anthropic SDK |
| **コンテキスト** | 最大 2M トークン (Grok 4.20) |
| **Batch API** | 標準価格 50% 引き |
| **キャッシュ** | 最大 90% 割引 (Grok 4.20) |

## 料金 (2026-04 時点)

| モデル | Input ($/1M) | Output ($/1M) | Context |
| :--- | :--- | :--- | :--- |
| **Grok 4.1 Fast** | $0.20 | — | 2M |
| **Grok 4.20** | $2.00 | $6.00 | 2M |
| **Grok 4** | $3.00 | $15.00 | — |

新規登録で **$25 無料クレジット**、データ共有プログラムで **月 $150 追加クレジット** 取得可能。

## OpenAI SDK で Grok を使う

```python
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_XAI_API_KEY",
    base_url="https://api.x.ai/v1"  # ← ここだけ変更
)

response = client.chat.completions.create(
    model="grok-4-20",
    messages=[
        {"role": "system", "content": "あなたはAIアシスタントです。"},
        {"role": "user", "content": "X (Twitter) の最新トレンドを教えて"}
    ],
    max_tokens=1000
)

print(response.choices[0].message.content)
```

## Anthropic SDK でも使える

```python
import anthropic

client = anthropic.Anthropic(
    api_key="YOUR_XAI_API_KEY",
    base_url="https://api.x.ai"
)

message = client.messages.create(
    model="grok-4-20",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Grok 4.3の新機能は？"}]
)
```

## DeepSearch API

X リアルタイムデータへのアクセスを活用したリサーチ:

```python
response = client.chat.completions.create(
    model="grok-4-20",
    messages=[{"role": "user", "content": "今日のAI業界の最新ニュースは？"}],
    tools=[{"type": "web_search_preview"}]  # DeepSearch 有効化
)
```

## アクセス方法

1. [console.x.ai](https://console.x.ai) でアカウント作成
2. API キーを生成
3. 環境変数: `export XAI_API_KEY=xai-xxxxxxxx`
4. `pip install openai` (または `pip install anthropic`) でインストール
$md$,
  'https://docs.x.ai/developers/models',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
