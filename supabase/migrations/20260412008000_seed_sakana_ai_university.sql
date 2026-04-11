-- Sakana AI コンテンツシード
-- AI大学: Sakana AI プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 東京発日本語AI研究ラボ / 進化的モデルマージング独自技術 / 日本語特化モデル / Hugging Face 公開 / 日本人開発者必須知識

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('sakana', 'overview', 'Sakana AI 概要',
$$Sakana AI は2023年に東京で創業された日本発の AI 研究スタートアップです。元 Google Brain の研究者 **Llion Jones** (Transformer 論文の著者の一人) と **David Ha** が共同創業し、「自然界のアルゴリズムに学ぶ AI」をコンセプトに革新的な研究を進めています。

Sakana AI の最大の特徴は **進化的モデルマージング (Evolutionary Model Merging)** という独自技術です。既存のオープンソースモデルを「進化」させて組み合わせることで、少ない計算コストで高性能な日本語モデルを生み出せます。

## 主要研究・プロダクト
- **EvoLLM-JP** — 進化的マージングで作成した日本語特化 LLM
- **EvoVLM-JP** — 日本語マルチモーダルモデル (画像+テキスト理解)
- **AI Scientist** — AI が自律的に研究論文を生成・実験・執筆するシステム
- **Continuous Thought Machines (CTM)** — 人間の思考プロセスを模倣した推論モデル
- **Tanuki** — 日本語特化の軽量実用モデルシリーズ

## 強み
- **日本語 AI の最先端**: 日本語理解・生成において国内トップクラス
- **効率的な手法**: 大量の計算コストなしに高性能モデルを実現
- **OSS 公開**: 主要モデルを Hugging Face で無料公開 (研究・商用利用可)
- **国内初のユニコーン候補**: SoftBank / NTT / 住友商事が出資
- **論文品質の研究**: Nature・NeurIPS・ICML 等に採択実績$$,
'https://sakana.ai/', '2026-04-12', 1),

('sakana', 'models', 'Sakana AI モデル一覧 (2026)',
$$## EvoLLM / EvoVLM シリーズ (進化的モデルマージング)

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **EvoLLM-JP-A-v1-7B** | 7B | 日本語特化 LLM・Mistral ベース進化版 | 日本語テキスト生成 |
| **EvoLLM-JP-v1-7B** | 7B | 多言語日本語バランス型 | 日英混在タスク |
| **EvoVLM-JP-v1-7B** | 7B | マルチモーダル (日本語画像理解) | 日本語VQA・説明生成 |

## Tanuki シリーズ (実用軽量モデル)

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Tanuki-8B** | 8B | 日本語実用モデル・商用可 | 業務文書処理 |
| **Tanuki-8x8B** | 47B (MoE) | 高精度・Mixture of Experts | 複雑な日本語タスク |

## 研究プロジェクト

| プロジェクト | 概要 |
| :--- | :--- |
| **AI Scientist** | AI が仮説立案→実験→論文執筆を完全自動化 (世界初) |
| **Continuous Thought Machines** | ニューラルネットに「考える時間」を与える新アーキテクチャ |
| **TreeQuest** | 木探索 × LLM で複雑推論を改善 |

## 進化的モデルマージングの仕組み

```text
既存OSS モデル A (数学特化)
         ↓ 進化的アルゴリズムで最適な
既存OSS モデル B (日本語特化)  → 組み合わせ方を発見 → 新モデル (日本語+数学)
         ↓
既存OSS モデル C (推論特化)

計算コスト: 通常のファインチューニングの 1/100 以下
```$$,
'https://huggingface.co/SakanaAI', '2026-04-12', 2),

('sakana', 'api', 'Sakana AI モデル利用方法',
$$## Hugging Face 経由でモデルを無料利用

Sakana AI のモデルは Hugging Face で公開されており、transformers ライブラリで即利用できます。

```python
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

# EvoLLM-JP (日本語特化 7B モデル)
model_id = "SakanaAI/EvoLLM-JP-A-v1-7B"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto"  # GPU があれば自動利用
)

# 日本語で質問
messages = [
    {"role": "system", "content": "あなたは親切な日本語AIアシスタントです。"},
    {"role": "user", "content": "進化的モデルマージングとはどういう技術ですか？"}
]

# chat template 適用
text = tokenizer.apply_chat_template(
    messages, tokenize=False, add_generation_prompt=True
)
inputs = tokenizer(text, return_tensors="pt").to(model.device)

with torch.no_grad():
    outputs = model.generate(
        **inputs,
        max_new_tokens=512,
        temperature=0.7,
        do_sample=True
    )

response = tokenizer.decode(outputs[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)
print(response)
```

## EvoVLM-JP (画像+日本語理解)

```python
from transformers import AutoProcessor, AutoModelForVision2Seq
from PIL import Image
import torch

model_id = "SakanaAI/EvoVLM-JP-v1-7B"
processor = AutoProcessor.from_pretrained(model_id)
model = AutoModelForVision2Seq.from_pretrained(
    model_id, torch_dtype=torch.bfloat16, device_map="auto"
)

# 画像を読み込んで日本語で説明させる
image = Image.open("japanese_garden.jpg")
messages = [
    {
        "role": "user",
        "content": [
            {"type": "image"},
            {"type": "text", "text": "この画像を日本語で詳しく説明してください。"}
        ]
    }
]

prompt = processor.apply_chat_template(messages, add_generation_prompt=True)
inputs = processor(text=prompt, images=[image], return_tensors="pt").to(model.device)

outputs = model.generate(**inputs, max_new_tokens=256)
print(processor.decode(outputs[0], skip_special_tokens=True))
```

## Hugging Face Inference API (クラウド実行・無料枠あり)

```python
import requests

HF_TOKEN = "your-hf-token"

# Hugging Face Inference API 経由で EvoLLM-JP を利用
response = requests.post(
    "https://api-inference.huggingface.co/models/SakanaAI/EvoLLM-JP-A-v1-7B",
    headers={"Authorization": f"Bearer {HF_TOKEN}"},
    json={
        "inputs": "日本のAI研究の現状について教えてください。",
        "parameters": {"max_new_tokens": 300, "temperature": 0.7}
    }
)
print(response.json()[0]["generated_text"])
```

## 利用条件・料金

| 利用方法 | 料金 | 条件 |
| :--- | :--- | :--- |
| **Hugging Face からダウンロード** | 無料 | 研究・商用利用可 (モデルごとにライセンス確認) |
| **Hugging Face Inference API** | 無料枠あり | HF アカウント必要 |
| **ローカル実行** | 無料 | VRAM 16GB+ 推奨 (7B モデル) |
| **企業向けパートナーシップ** | 要相談 | Sakana AI 直接問い合わせ |

- モデルページ: [huggingface.co/SakanaAI](https://huggingface.co/SakanaAI)
- 研究論文: [sakana.ai/research](https://sakana.ai/research)
- GitHub: [github.com/SakanaAI](https://github.com/SakanaAI)
- SDK: `pip install transformers torch` で即利用可$$,
'https://sakana.ai/research', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Sakana AI 追加 (17社目)',
  'Sakana AI (東京発・進化的モデルマージング・日本語AI最前線) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、EvoLLM-JP/EvoVLM-JP/Tanuki モデル・AI Scientist プロジェクト・HuggingFace Inference API利用方法を収録。AI大学プロバイダー数 16社→17社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
