-- PS版#3 Session 12 (part 2): Nous Research — 分散学習 (Psyche) + Open Hermes ($65M Paradigm)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'nous_research',
  'overview',
  'Nous Research — 分散学習 Psyche × オープン Hermes モデル ($65M Paradigm)',
  $md$## Nous Research とは

Nous Research は 2023 年設立、サンフランシスコ拠点のオープン AI 研究組織。
**「アライメントを外部から押し付けず、ユーザーが選べる」** を信条に
**Hermes** ファミリー (Llama 系 fine-tune) を OSS で公開している。

2025 年に Paradigm リードで **$65M 調達** — 商業部門 (Nous Research Inc.) が
エンタープライズ契約で OSS 開発を支える二層構造。

## 既存 130 社との差別化軸

| 観点 | Nous Research | 既存大手 (OpenAI/Anthropic 等) |
|------|--------------|-----------------------------|
| **学習方式** | 🌐 **Psyche 分散学習** (blockchain) | 中央集権 GPU クラスタ |
| **アライメント** | ユーザー側で steering | RLHF で固定的に組込 |
| **重み** | 完全 OSS (HuggingFace) | クローズド |
| **検閲** | 最小限 (uncensored stance) | 強い content filter |
| **コスト** | 無料 (重み DL) / OpenRouter $0.50-2/M | $5-15/M (商用 LLM) |

## Hermes ファミリーの系譜

| バージョン | リリース | ベース | 特徴 |
|-----------|---------|--------|------|
| **Hermes 1** | 2023-09 | Llama 2 7B | 初代 Nous fine-tune |
| **Hermes 2 Pro** | 2024-04 | Mistral 7B / Llama 3 | 関数呼出強化 |
| **Hermes 3** | 2024-08 | Llama 3.1 405B/70B/8B | 405B が業界初の OSS 大規模 |
| **Hermes 4** | 2025-08 | Llama 3.1 405B / Seed 36B | reasoning 強化・無検閲 |
| **Hermes 4.3** | 2025-08-25 | ByteDance Seed 36B | 🌐 **Psyche で初の分散学習生産モデル** |

## Psyche Network — 分散学習プロトコル

```text
┌──────────────────────────────────────────┐
│  Psyche Network                          │
│  ─────────────                           │
│  ・blockchain coordinated GPU pooling    │
│  ・インターネット越しの協調学習           │
│  ・参加者は GPU を提供して報酬を得る       │
│  ・中央集権クラスタへの依存を排除         │
│                                          │
│  Why?                                    │
│  → 巨大企業 (OpenAI/Anthropic) のみが   │
│     基盤モデルを訓練できる現状を打破      │
│  → 「分散型 AI」のインフラを提供          │
└──────────────────────────────────────────┘
```

Hermes 4.3 (Seed 36B base) はこのネットワーク上で訓練された **生産品質の最初の例**。

## 創業・組織

- 設立: 2023 年 (サンフランシスコ)
- 共同創業者: Karan Malhotra・Jeffrey Quesnelle・Shivani Mitra
- 主要研究者: Ryan Teknium (Hermes リード)・Roger Jin
- 投資家: Paradigm (リード) + 他 VC

## なぜ今この組織が重要か

1. **オープンアライメント運動の中心** — ユーザーがモデル挙動を選ぶ権利
2. **分散学習インフラの実証** — Psyche が成熟すれば AI 訓練の独占崩壊
3. **Llama 系 fine-tune のリファレンス** — Meta 公式 Instruct より自由度高
4. **Discord コミュニティ 30,000+ 名** — オープンソース AI の最大ハブの 1 つ$md$,
  '2026-04-20'
),
(
  'nous_research',
  'models',
  'Nous Research モデル詳細 (Hermes 4 405B / 4.3 Seed 36B)',
  $md$## モデル一覧 (2026-04 時点 OpenRouter 経由利用可能)

| モデル | パラメータ | コンテキスト | 用途 | $/M tokens |
|--------|-----------|-------------|------|-----------|
| **hermes-4-405b** | 405B | 128K | reasoning / 高品質生成 | $0.80 in / $2.00 out |
| **hermes-4-70b** | 70B | 128K | バランス型 | $0.30 in / $0.40 out |
| **hermes-4-3-seed-36b** | 36B (MoE) | 32K | 分散学習版 | $0.40 in / $0.80 out |
| **hermes-3-405b-fp8** | 405B FP8 | 128K | コスト最適化 | $0.50 in / $1.00 out |
| **hermes-3-llama-3.1-70b** | 70B | 128K | 旧主力 (今も人気) | $0.20 in / $0.30 out |
| **hermes-3-llama-3.1-8b** | 8B | 128K | エッジ・ローカル | OSS (HF DL) |

## Hermes 4 405B 詳細

```text
ベース: Meta Llama 3.1 405B Instruct
fine-tune データ:
  - Nous 独自合成データ (10M+ samples)
  - reasoning chains (math/code/logic)
  - 関数呼出 (tools / function calling)
  - 「拒否なし」品質回答
強化点:
  - chain-of-thought 強制有効化トリガー
  - JSON / XML 構造化出力の安定性
  - 倫理フィルタ最小限 (ユーザー責任モデル)
ベンチマーク:
  - MMLU: 88.6 (vs Claude Opus 88.7 / GPT-4o 88.7)
  - HumanEval: 89.0 (vs Claude Opus 84.9)
  - MATH: 73.8 (vs Llama 3.1 405B Instruct 73.8)
```

## Hermes 4.3 Seed 36B (Psyche 分散学習版)

```text
ベース: ByteDance Seed 36B (MoE 8 experts × 4.5B active)
fine-tune インフラ:
  - 🌐 Psyche Network 経由
  - 全世界 ~200 GPU ノード協調
  - 中央クラスタ非依存
特徴:
  - 学習コストが従来比 30-40% 削減
  - ノード障害に対する fault tolerance
  - 「学習の民主化」の実証モデル
```

## OpenRouter 経由での利用 (推奨)

Nous は自前 API を持たず、OSS 重み配布 + パートナー (OpenRouter / Together / Replicate) 経由が主流:

```bash
# OpenRouter 経由 (最速・最安)
curl https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nousresearch/hermes-4-405b",
    "messages": [{"role": "user", "content": "Explain quantum entanglement"}]
  }'
```

## OSS 重み (HuggingFace)

```bash
# pip install transformers torch
from transformers import AutoModelForCausalLM, AutoTokenizer

model_id = "NousResearch/Hermes-3-Llama-3.1-8B"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id, device_map="auto")

# Hermes は ChatML format
messages = [
    {"role": "system", "content": "You are Hermes, a helpful assistant."},
    {"role": "user", "content": "What is the meaning of life?"},
]
inputs = tokenizer.apply_chat_template(messages, return_tensors="pt").to("cuda")
outputs = model.generate(inputs, max_new_tokens=500)
print(tokenizer.decode(outputs[0]))
```

## 既存 LLM との使い分け

| 用途 | 推奨モデル |
|------|-----------|
| 「拒否なし」探索的質問 | hermes-4-405b |
| OSS で fully self-hosted | hermes-3-llama-3.1-8b/70b |
| 分散学習体験 | hermes-4-3-seed-36b |
| エンタープライズ | Anthropic Claude (compliance 強) |
| マルチモーダル | OpenAI GPT-4o / Gemini |$md$,
  '2026-04-20'
),
(
  'nous_research',
  'api',
  'Nous Research 使い方 (OpenRouter / Direct OSS / Psyche 参加)',
  $md$## 利用パスの 4 つの選択肢

### 1. OpenRouter (最速・最安) — 推奨

API キー 1 つで Hermes 全モデルにアクセス可。

```typescript
// supabase/functions/ai-hub/actions/chat.ts (既存) に nous_research provider 追加
const NOUS_MODELS = {
  'hermes-4-405b': 'nousresearch/hermes-4-405b',
  'hermes-4-70b': 'nousresearch/hermes-4-70b',
  'hermes-4-3-seed-36b': 'nousresearch/hermes-4-3-seed-36b',
  'hermes-3-llama-3.1-70b': 'nousresearch/hermes-3-llama-3.1-70b',
};

export async function callNousChat(payload: {
  model: keyof typeof NOUS_MODELS;
  messages: Array<{role: string; content: string}>;
}) {
  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${Deno.env.get("OPENROUTER_API_KEY")}`,
      "HTTP-Referer": "https://my-web-app-b67f4.web.app",
      "X-Title": "Jibun Kabushiki Kaisha",
    },
    body: JSON.stringify({
      model: NOUS_MODELS[payload.model],
      messages: payload.messages,
    }),
  });
  return await response.json();
}
```

### 2. HuggingFace 直接 OSS (フルコントロール)

```bash
# サーバー要件: A100 80GB×2 (405B 4bit) / RTX 3090 (8B)
pip install transformers accelerate bitsandbytes

# Hermes 4 405B を 4bit 量子化でロード
python -c "
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
import torch
config = BitsAndBytesConfig(load_in_4bit=True, bnb_4bit_compute_dtype=torch.float16)
model = AutoModelForCausalLM.from_pretrained(
    'NousResearch/Hermes-4-Llama-3.1-405B',
    quantization_config=config,
    device_map='auto',
)
"
```

### 3. Together AI / Replicate (中規模ホスティング)

```bash
# Together AI
curl -X POST https://api.together.xyz/v1/chat/completions \
  -H "Authorization: Bearer $TOGETHER_API_KEY" \
  -d '{
    "model": "NousResearch/Hermes-3-Llama-3.1-405B-fp8",
    "messages": [{"role": "user", "content": "Hi"}]
  }'
```

### 4. Psyche Network 参加 (分散学習に GPU を提供)

```bash
# 自分の GPU を Psyche Network にプール (報酬獲得)
git clone https://github.com/NousResearch/psyche
cd psyche
cargo build --release
./target/release/psyche-node --wallet <wallet_address> --gpu cuda:0

# 学習ジョブを受け取り報酬獲得 (詳細はホワイトペーパー参照)
```

## Flutter Web (自分株式会社) からの呼出例

```dart
// lib/services/nous_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class NousService {
  static Future<String?> chat({
    required String prompt,
    String model = 'hermes-4-70b',
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'ai-hub',
      body: {
        'action': 'chat',
        'provider': 'nous_research',
        'model': model,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      },
    );
    final data = response.data as Map?;
    return data?['choices']?[0]?['message']?['content'] as String?;
  }
}
```

## 自分株式会社からの活用イメージ

| 機能 | Nous Research 適用 |
|------|-------------------|
| **AI 大学** | 「分散学習体験」コース (Psyche に GPU 提供 → 学習論文を読む) |
| **ai-hub** | 既存 ai-hub に `nous_research` provider 追加 (OpenRouter 経由) |
| **検閲なし用途** | 競馬予想・SNS 分析など content filter 干渉が困る場面 |
| **コスト最適化** | hermes-3-llama-3.1-70b ($0.20/M) で簡単 chat タスク |
| **PHILOSOPHY 整合** | ユーザー判断モデル → 原則 1 (CEO感) と高整合 |

## 料金まとめ (推定 2026-04)

- **OpenRouter 経由**: $0.20-2.00 / M tokens (モデル別)
- **OSS 自前ホスト**: GPU コストのみ (A100 24h ~$50)
- **Psyche 参加**: GPU 提供で報酬獲得 (赤字回避目的なら net-positive 可)

## 注意事項・制約

- **検閲最小**: 違法・有害コンテンツの責任はユーザー側
- **日本語**: Hermes は英語中心 — 日本語は Llama 3.1 ベースのため標準的
- **マルチモーダル非対応**: テキストのみ (画像・音声は他プロバイダー併用)
- **関数呼出**: Hermes 2 Pro 系が最強 (Hermes 4 はやや弱)

## 公式リソース

- Web: https://nousresearch.com/
- HuggingFace: https://huggingface.co/NousResearch
- Hermes 4 Tech Report: https://arxiv.org/pdf/2508.18255
- Psyche Network: https://github.com/NousResearch/psyche
- Discord: https://discord.gg/jqVphNsB4H (30,000+ 名)
- OpenRouter: https://openrouter.ai/nousresearch$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
