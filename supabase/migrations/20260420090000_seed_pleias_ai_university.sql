-- PS版#3 Session 16: Pleias AI — Fully-open 小型推論モデル / Common Corpus 2T tokens / 出典引用ネイティブ
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'pleias',
  'overview',
  'Pleias AI — 完全オープン小型モデル (Common Corpus 2T / Apache 2.0 / 出典引用ネイティブ)',
  $md$## Pleias AI とは

Pleias は 2024 年創業、パリ拠点の **「倫理的に訓練された完全オープン SLM」** スタートアップ。
**「public domain + permissively licensed データのみで pretrain」** をコア信条とし、
著作権リスクなしの 2 兆トークン巨大データセット **Common Corpus** を公開している。

**差別化ポイント**: GPT-4 などが論争のあるスクレイピングデータで訓練される中、
Pleias はデータ出所が 100% 追跡可能。エンタープライズ/政府機関の RAG 向け安全モデル。

## 既存 133 社との差別化軸

| 観点 | Pleias | Mistral | Llama 3 | Gemma |
|------|--------|---------|---------|-------|
| **データ合法性** | ✅ **100% permissive** | ⚠️ 不透明 | ⚠️ 不透明 | ⚠️ 不透明 |
| **モデルサイズ** | 350M / 1.2B / 3B | 7B-123B | 8B-405B | 2B-27B |
| **ライセンス** | Apache 2.0 | Apache 2.0 (一部) | Llama CL | Gemma TOS |
| **RAG 特化** | ✅ **Pleias-RAG シリーズ** | 汎用 | 汎用 | 汎用 |
| **出典引用** | ✅ ネイティブ | ❌ | ❌ | ❌ |
| **CPU 動作** | ✅ **GGUF 最適化済** | limited | limited | limited |

## 製品ラインナップ (2026-04 時点)

```text
┌─────────────────────────────────────────────┐
│  Pleias 1.0 Family (base pretrain)          │
│  ─────────────                              │
│  Pleias-350M    :  350M params (EU 8 lang)  │
│  Pleias-1.2B    :  1.2B params (EU 8 lang)  │
│  Pleias-3B      :  3B params (EU 8 lang)    │
│                                             │
│  Pleias-RAG Family (RAG 特化)               │
│  ─────────────                              │
│  Pleias-RAG-350M  : 350M RAG + citation     │
│  Pleias-RAG-1B    : 1B RAG + citation       │
│  GGUF variants    : CPU-optimized           │
│                                             │
│  訓練データ: Common Corpus 2T tokens        │
│  ※ English / French / German / Italian /    │
│    Spanish / Polish / Dutch / Latin         │
└─────────────────────────────────────────────┘
```

## Common Corpus (訓練データセット)

- **容量**: 2 兆トークン (全公開)
- **ライセンス**: public domain + permissively licensed のみ
- **言語**: 30+ 言語 / 英語・フランス語が中心
- **内訳**: books / academic / government / web (Creative Commons) / code
- **公開**: HuggingFace で全ファイル DL 可 — 他組織も学習可
- **日本語**: 10 億トークン未満 (非メジャー) — 英訳併用推奨

## 性能ベンチマーク

| モデル | HotPotQA | 2wiki | TriviaQA |
|-------|---------|-------|----------|
| **Pleias-RAG-1B** | ✅ 勝 | ✅ 勝 | 競合 |
| Qwen-2.5-7B | 競合 | 敗 | 勝 |
| Llama-3.1-8B | 敗 | 敗 | 勝 |
| Gemma-3-4B | 敗 | 敗 | 競合 |

**要点**: 4B 以下 SLM で RAG 特化ベンチマーク最高スコア。
大型モデル (7B-8B) にも HotPotQA/2wiki で勝つシーンあり。

## なぜ今この組織が重要か

1. **EU AI Act 対応** — データ出所証明が義務化 → Pleias 一強カテゴリ
2. **エンタープライズ RAG** — 著作権リスクなしで商用利用可
3. **小型 + CPU 最適化** — エッジデバイス / オンプレ展開向き
4. **引用ネイティブ** — ハルシネーション対策に原文引用自動付与
5. **Apache 2.0** — ライセンス縛りなし (商用 OK)

## 日本語対応状況

- **Pleias 1.0**: EU 8 言語中心 — 日本語は非公式サポート
- **Common Corpus**: 日本語トークン < 1B — fine-tune ベース素材としては使用可
- **実用パターン**: ja→en 翻訳 → Pleias-RAG → en→ja 翻訳 の 3 段構成$md$,
  '2026-04-20'
),
(
  'pleias',
  'models',
  'Pleias モデル詳細 (RAG/base 両系統 + HuggingFace / GGUF 実行)',
  $md$## モデル一覧 (2026-04 時点)

| モデル | パラメータ | コンテキスト | 特徴 | HF Repo |
|-------|-----------|------------|------|---------|
| **Pleias-350M** | 350M | 4K | base pretrain 最小 | PleIAs/Pleias-350M |
| **Pleias-1.2B** | 1.2B | 4K | base pretrain 中堅 | PleIAs/Pleias-1.2B |
| **Pleias-3B** | 3B | 8K | base pretrain 最大 | PleIAs/Pleias-3B |
| **Pleias-RAG-350M** | 350M | 4K | RAG + citation | PleIAs/Pleias-RAG-350M |
| **Pleias-RAG-1B** | 1B | 4K | RAG + citation (推奨) | PleIAs/Pleias-RAG-1B |
| **Pleias-RAG-*-GGUF** | - | - | CPU 最適化 (Q4_K_M) | PleIAs/Pleias-RAG-*-GGUF |

## Pleias-RAG の特殊能力

```text
┌────────────────────────────────────────┐
│  Pleias-RAG Native Features            │
│  ─────────────                         │
│  1. Query reformulation                │
│     └ user query を検索最適化形に変換    │
│  2. Query routing                      │
│     └ 外部検索 or 内部知識で分岐判定     │
│  3. Source reranking                   │
│     └ retrieval 結果を信頼度順に並替    │
│  4. Literal quote citations            │
│     └ 回答内に [source:N] 付き原文引用   │
│  5. Multilingual output                │
│     └ EU 8 言語で structured 出力対応   │
└────────────────────────────────────────┘
```

## HuggingFace から使う

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model_id = "PleIAs/Pleias-RAG-1B"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id)

# RAG prompt (sources 注入)
prompt = """<|query|>What is Pleias and why was it created?<|query|>
<|sources|>
[source:1] Pleias is a French AI startup founded in 2024...
[source:2] The Common Corpus is 2 trillion tokens of...
<|sources|>
<|answer|>"""

inputs = tokenizer(prompt, return_tensors="pt")
out = model.generate(**inputs, max_new_tokens=200)
print(tokenizer.decode(out[0], skip_special_tokens=True))
```

## GGUF (CPU 最適化) から使う

```bash
# llama.cpp サーバ起動
llama-server -m pleias-rag-1b-Q4_K_M.gguf -c 4096 --port 8080

# 呼出 (OpenAI 互換 API)
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "Cite sources."},
      {"role": "user", "content": "Explain Common Corpus."}
    ],
    "max_tokens": 256
  }'
```

## Pleias-RAG 出力フォーマット

```json
{
  "answer": "Pleias is a French AI startup that created Common Corpus [source:1] ...",
  "citations": [
    {
      "source_id": 1,
      "quote": "Pleias, founded in 2024 in Paris...",
      "confidence": 0.92
    }
  ],
  "query_routing": "external_search_needed",
  "reformulated_query": "Pleias AI startup founding history"
}
```

## ベンチマーク詳細

| ベンチ | Pleias-RAG-1B | Qwen-2.5-7B | Llama-3.1-8B | Gemma-3-4B |
|-------|--------------|-------------|--------------|------------|
| HotPotQA (EM) | 🏆 48.2% | 45.1% | 42.3% | 38.9% |
| 2wiki (EM) | 🏆 52.1% | 48.7% | 44.2% | 41.5% |
| TriviaQA | 61.3% | 🏆 68.9% | 63.2% | 58.1% |
| citation_precision | 🏆 0.87 | N/A | N/A | N/A |

**注**: Pleias は citation_precision (引用の正確性) で他モデルが未対応の領域を独占。

## ライセンス

- **モデル**: Apache 2.0 (商用再配布 / 修正 / fine-tune 自由)
- **Common Corpus**: CC-BY / public domain / permissive (組み合わせ)
- **論文**: arxiv 2504.18225 (arxiv に公開)
- **制約**: なし — 法務審査をパスしやすい

## CPU / GPU 要件

| モデル | RAM | GPU | スループット |
|-------|-----|-----|------------|
| Pleias-RAG-350M | 2 GB | Optional | 60 tok/s (CPU) |
| Pleias-RAG-1B | 4 GB | Optional | 30 tok/s (CPU) |
| Pleias-3B | 8 GB | 推奨 | 80 tok/s (RTX 4090) |
| GGUF Q4_K_M | -40% | - | +50% スループット |

## ファインチューニング

公式 recipe 公開 (HuggingFace + TRL):

```python
from trl import SFTTrainer

trainer = SFTTrainer(
    model="PleIAs/Pleias-RAG-1B",
    train_dataset=custom_dataset,
    max_seq_length=4096,
    peft_config=LoraConfig(r=16, lora_alpha=32),
)
trainer.train()
```$md$,
  '2026-04-20'
),
(
  'pleias',
  'api',
  'Pleias 実践 (自前ホスト / HuggingFace Inference / 自分株式会社活用例)',
  $md$## デプロイ方式 (4 つ)

### 1. ローカル llama.cpp (GGUF / 最軽量)

```bash
# モデル DL
huggingface-cli download PleIAs/Pleias-RAG-1B-GGUF \
  pleias-rag-1b-Q4_K_M.gguf --local-dir ./models/

# サーバ起動
llama-server -m ./models/pleias-rag-1b-Q4_K_M.gguf \
  -c 4096 --port 8080 --host 0.0.0.0
```

### 2. HuggingFace Inference API (SaaS)

```python
from huggingface_hub import InferenceClient

client = InferenceClient(model="PleIAs/Pleias-RAG-1B", token="hf_xxx")
response = client.text_generation(
    prompt="Explain Common Corpus briefly.",
    max_new_tokens=200,
)
```

### 3. HuggingFace Endpoints (専用 GPU)

GUI で PleIAs/Pleias-RAG-1B を選択 → 1-click デプロイ → API URL 発行。
料金: $0.06/hour (CPU) / $0.60/hour (GPU T4) から。

### 4. Together AI / Replicate (マネージド)

```typescript
// Together AI 経由 (互換 API)
import Together from "together-ai";
const client = new Together();
const res = await client.chat.completions.create({
  model: "pleias/pleias-rag-1b",
  messages: [{ role: "user", content: "..." }],
});
```

## 自分株式会社 (ai-hub) 統合例

```typescript
// supabase/functions/ai-hub/actions/pleias_rag.ts
export async function callPleiasRag(payload: {
  query: string;
  sources: Array<{ id: number; text: string }>;
}) {
  const HF_TOKEN = Deno.env.get("HF_TOKEN")!;
  const sourcesBlock = payload.sources
    .map((s) => `[source:${s.id}] ${s.text}`)
    .join("\n");
  const prompt = `<|query|>${payload.query}<|query|>\n<|sources|>\n${sourcesBlock}\n<|sources|>\n<|answer|>`;

  const response = await fetch(
    "https://api-inference.huggingface.co/models/PleIAs/Pleias-RAG-1B",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${HF_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        inputs: prompt,
        parameters: { max_new_tokens: 256, temperature: 0.3 },
      }),
    },
  );
  return await response.json();
}
```

## Flutter Web からの呼出例

```dart
// lib/services/pleias_rag_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class PleiasRagService {
  static Future<Map<String, dynamic>> ask({
    required String query,
    required List<Map<String, dynamic>> sources,
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'ai-hub',
      body: {
        'action': 'pleias_rag',
        'query': query,
        'sources': sources,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }
}
```

## 自分株式会社からの活用イメージ

| 機能 | Pleias 適用 |
|------|------------|
| **AI 大学** | 学習コンテンツの出典引用を自動付与 (ハルシネーション対策) |
| **AI アシスタント** | 軽量版 (Haiku 代替) として 1B モデルを自前ホスト |
| **CS 対応 EF** | FAQ 回答に literal quote を添えて信頼性向上 |
| **daily-judgment** | 過去の自己判断履歴を sources として与えて「昨日の自分」対話 |
| **EU 向けコンプライアンス** | GDPR/AI Act 対応が必要な機能で main モデルに採用 |

## 料金試算 (自分株式会社スケール)

```text
想定: RAG 応答 500 queries/day × 30 = 15K/月

Option A: HuggingFace Inference API
  $0.0002/1K tok × 500 tok/query × 15K = $1.50/月
  → ほぼ無料級

Option B: HF Endpoint (CPU 占有)
  $0.06/hour × 24h × 30d = $43.20/月 (24h 連続稼働前提)
  → 500 queries 程度なら Option A が圧倒的有利

Option C: 自前 VPS (llama.cpp + GGUF)
  VPS $5/月 (2GB RAM) で常時稼働可
  → プライバシー重視 + バースト対応困難
```

## Sentinel / Quality Gate 連携 (AI_DEV 7 原則)

```typescript
// Pleias RAG 出力を Sentinel で検証
const rag = await callPleiasRag({ query, sources });
const sentinel = await verifyWithClaude({
  answer: rag.answer,
  citations: rag.citations,
  minCitationConfidence: 0.85,
});
if (!sentinel.passed) {
  return { error: "citation_quality_below_threshold" };
}
```

## 注意事項・制約

- **日本語精度**: 低い — 英訳 → Pleias → 和訳 の 3 段推奨
- **コンテキスト長**: 最大 8K tok (Pleias-3B 以外は 4K) — 長文 RAG 非対応
- **instruction following**: 大型 LLM 比弱い — template 厳密化必要
- **商用 SLA**: なし (完全 OSS) — enterprise は HF Endpoints 等経由推奨
- **sampling**: temperature 低め (0.1〜0.3) が citation 精度に好影響

## 公式リソース

- Web: https://pleias.fr/
- HuggingFace: https://huggingface.co/PleIAs
- GitHub: https://github.com/Pleias/Pleias-Rag
- 論文 (arxiv): https://arxiv.org/html/2504.18225v1
- Common Corpus: https://huggingface.co/datasets/PleIAs/common_corpus

## 類似サービス比較

| サービス | 強み | 差別化 |
|---------|------|--------|
| **Pleias** | 完全オープンデータ / citation ネイティブ | 法務安全 最強 |
| Mistral | 大型高性能 / Apache 2.0 | 汎用 LLM 王道 |
| Llama | Meta 巨大ラインナップ | コミュニティ最大 |
| Gemma | Google 品質 + 小型 | 多言語 balanced |
| Qwen | Alibaba 大規模 / 中国語強 | アジア圏 1 強 |

## 競合リスク

- **Allen AI (OLMo)**: 同じく「完全オープン」系 — 英語のみ / 7B 中心
- **Falcon (TII)**: UAE 産 / データ透明度やや低 / 40B までスケール
- **Mistral Small 3**: ライセンス純度は Pleias に劣るが性能は圧倒的$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
