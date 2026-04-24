-- Session PS#3-S34: AI大学 163社化 — Upstage 追加
-- Sung Kim (元 HKUST 教授) が 2020 年に韓国で創業。
-- 2026-04-15 に韓国初のジェネラティブ AI ユニコーン企業に認定 (Series C $125.9M 第1弾 / 累計 ~$279.7M)。
-- Solar Pro 2 (2025-07): GPT-4.1 および DeepSeek V3 を上回る韓国初のフロンティアモデル。
-- Document Parse: 複雑な PDF・表・図をLLM向けに高精度変換するAI文書処理ソリューション。
-- AWS パートナーとして APAC・米国で展開。KOSPI 上場を 2026 年に目指す。
-- 年収成長率 130%+・既存 162 社の「アジア AI フロンティア」軸空白を埋める。
-- Step 0: 8/9 (Solar Pro 2 GPT-4.1 超え / ユニコーン / AWS連携 / KOSPI IPO予定 / Document Parse 独自軸)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'upstage',
  'overview',
  'Upstage — 韓国初のジェネラティブ AI ユニコーン / Solar LLM & Document Parse',
  $md$
# Upstage — Korea's First Generative AI Unicorn

2020 年創業。**Sung Kim** (元 香港科技大学 教授) が「すべての企業が
世界最高の AI を使える世界」を目指して韓国で設立。

2026 年 4 月に **韓国初のジェネラティブ AI ユニコーン** に認定。
Series C 第 1 弾 $125.9M (約 1,800 億ウォン) を完了し、
累計調達額は約 **$279.7M** (約 4,000 億ウォン) に到達。
KOSPI (韓国主要株式市場) への 2026 年 IPO を準備中。

## 主要プロダクト

### Solar — フロンティア LLM
**Solar Pro 2** (2025 年 7 月リリース) は韓国初のフロンティアモデルとして国際的に認知され、
**GPT-4.1** および **DeepSeek V3** を複数ベンチマークで上回る性能を達成。

### Document Parse — AI 文書処理
複雑な PDF・表・図・手書きメモを、LLM が直接扱える構造化テキストに
高精度変換する AI ソリューション。RAG パイプラインの前処理として採用が急増。

## 強み

- **Solar Pro 2**: GPT-4.1 超えのフロンティア性能を韓国チームが独自開発
- **Document Parse**: PDF → LLM ready text の変換精度で業界最高水準
- **AWS パートナー**: APAC・US 展開に向けた公式パートナーシップ
- **企業実績**: 年間売上成長率 130%+ / グローバル 24,800 社超導入
- **アジア AI**: 日本・東南アジア市場への展開で地域特化 LLM の先駆者
$md$,
  'https://www.upstage.ai/',
  '2026-04-24',
  1
),

(
  'upstage',
  'models',
  'Upstage Solar モデル・API 一覧 (2026)',
  $md$
## Solar LLM ラインナップ

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Solar Pro 2** | 韓国初フロンティアモデル / GPT-4.1 超え | 高精度推論・エンタープライズ |
| **Solar Mini** | 軽量・高速・低コスト | エッジ推論・チャットボット |
| **Solar Embedding** | 文書検索・RAG 最適化 embedding | RAG パイプライン |

## Document Parse

| 機能 | 説明 |
| :--- | :--- |
| **PDF → Markdown** | 複雑なレイアウト・表・図を高精度変換 |
| **OCR** | 手書き・スキャン文書の文字認識 |
| **テーブル抽出** | Excel 相当の表構造をそのままマークダウンに |
| **数式認識** | LaTeX 形式での数式抽出 |
| **多言語対応** | 日本語・韓国語・英語・中国語 etc. |

## ベンチマーク (Solar Pro 2 / 2026 年 4 月時点)

| 比較対象 | 結果 |
| :--- | :--- |
| GPT-4.1 | Solar Pro 2 が上回る |
| DeepSeek V3 | Solar Pro 2 が上回る |
| グローバルランキング | 韓国初・アジア最高水準 |

## プラン (Upstage Console)

| プラン | 対象 | 詳細 |
| :--- | :--- | :--- |
| **Free** | 個人・スタートアップ | 無料枠あり (クレジット) |
| **Pay-as-you-go** | 従量課金 | トークン単価 |
| **Enterprise** | 大企業・金融・医療 | オンプレ / VPC 対応 |
$md$,
  'https://console.upstage.ai/',
  '2026-04-24',
  2
),

(
  'upstage',
  'api',
  'Upstage Solar API 入門',
  $md$
## Upstage Solar API の始め方

### OpenAI 互換 API (Python)

```python
# pip install openai  (Upstage は OpenAI SDK と互換)

from openai import OpenAI

client = OpenAI(
    api_key="YOUR_UPSTAGE_API_KEY",
    base_url="https://api.upstage.ai/v1"
)

# Solar Pro 2 でチャット補完
response = client.chat.completions.create(
    model="solar-pro2",
    messages=[
        {"role": "system", "content": "あなたは AI 大学の優秀な教授です。"},
        {"role": "user",   "content": "Upstage Solar Pro 2 の強みを教えてください。"}
    ]
)

print(response.choices[0].message.content)
```

### Document Parse API

```python
import requests

# PDF → LLM 向けテキスト変換
with open("document.pdf", "rb") as f:
    response = requests.post(
        "https://api.upstage.ai/v1/document-digitization",
        headers={"Authorization": "Bearer YOUR_UPSTAGE_API_KEY"},
        files={"document": f},
        data={"output_formats": '["markdown"]'}
    )

result = response.json()
print(result["content"]["markdown"])   # Markdown 形式で取得
```

### Embedding API

```python
# Solar Embedding でベクター生成
response = client.embeddings.create(
    model="solar-embedding-1-large",
    input="Upstage は韓国発のフロンティア AI 企業"
)

vector = response.data[0].embedding
print(f"次元数: {len(vector)}")  # 4096
```

## クイックスタート

1. [console.upstage.ai](https://console.upstage.ai) でアカウント作成 → API キー発行
2. `pip install openai` でインストール (OpenAI SDK 互換)
3. `base_url="https://api.upstage.ai/v1"` に変更するだけで既存コードを移行可能
4. `model="solar-pro2"` で韓国初フロンティアモデルを呼び出し
$md$,
  'https://console.upstage.ai/docs',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
