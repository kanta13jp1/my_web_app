-- PS版#3 Session 14: Prime Intellect — 分散 RL 訓練 INTELLECT-3 (106B MoE / 131K ctx / $0.20-M)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'prime_intellect',
  'overview',
  'Prime Intellect — 分散 RL で 106B MoE を訓練 (INTELLECT-3 / AIME 90.8%)',
  $md$## Prime Intellect とは

Prime Intellect は 2024 年設立の AI インフラ企業。
**「Open Superintelligence Stack」** を掲げ、GPU マーケットプレイス・
分散強化学習フレームワーク (prime-rl)・オープンモデル (INTELLECT 系列) を
垂直統合で提供する。

Nous Research と並ぶ「分散学習」派の中核組織で、こちらは
**強化学習 (RL) に特化**している点が差別化軸。

## 既存 131 社との差別化軸

| 観点 | Prime Intellect | Nous Research | 既存大手 (OpenAI 等) |
|------|----------------|---------------|---------------------|
| **学習方式** | 🌐 **グローバル分散 RL** | Psyche 分散 SFT | 中央集権 GPU |
| **主力製品** | INTELLECT-3 (106B MoE) | Hermes 4 (405B) | GPT/Claude クローズド |
| **インフラ** | 🖥️ **GPU マーケット + RL 基盤** | OSS 重み配布のみ | 自社クラスタ |
| **価格** | 💰 **$0.20/1M input** (INTELLECT-3) | $0.20-2.00/M (OpenRouter) | $5-15/M |
| **OSS** | 完全 OSS (HF + GitHub) | 完全 OSS | クローズド |
| **ベンチマーク** | AIME 2024 **90.8%** | MMLU 88.6 | - |

## INTELLECT シリーズの系譜

| モデル | リリース | パラメータ | 特徴 |
|--------|---------|-----------|------|
| **INTELLECT-1** | 2024-11 | 10B (dense) | 初の本格的分散訓練 (30ノード / 3大陸) |
| **INTELLECT-2** | 2025-05 | 32B | 🌐 **初の分散 RL** (permissionless GPU contribution) |
| **INTELLECT-3** | 2025-12 | 106B MoE / 12B active | RL スケール + SOTA 小型モデル中 |

## INTELLECT-3 の成果 (2025-12 リリース)

```text
┌──────────────────────────────────────────────┐
│  INTELLECT-3 ベンチマーク                     │
│  ─────────────────                           │
│  ・AIME 2024          : 90.8%                │
│  ・LiveCodeBench      : GLM-4.5-Air を 8pt 超 │
│  ・MATH / Science     : Frontier-class        │
│  ・Active params      : 12B (効率的推論)       │
│  ・Context window     : 131,072 tokens        │
│  ・Training compute   : 512×H200 GPU          │
│                                              │
│  Why?                                        │
│  → ベース: GLM 4.5 Air                       │
│  → SFT + RL を end-to-end 適用               │
│  → 「RL スケーリング則」の実証                │
└──────────────────────────────────────────────┘
```

## GPU マーケットプレイス

Prime Intellect は単なるモデル提供者ではない。
**RunPod / Lambda Labs と競合する GPU pay-as-you-go マーケット**でもある。

- H100 / H200 / A100 / RTX 4090 を時間課金
- prime-rl フレームワークで分散 RL 学習ジョブを投入可
- 一般ユーザーも自分の GPU を貸し出せる (将来実装)

## 創業・資金

- 設立: 2024 年
- 共同創業者: Johannes Hagemann (技術) + Vincent Weisser (ビジネス)
- Series A: $15M (2025-02) — Founders Fund リード
- シードから 1 年で INTELLECT-1 → INTELLECT-3 の 3 モデル発表

## なぜ今この組織が重要か

1. **RL スケーリング検証** — GPT-4o/Claude が実証していない「RL で frontier」路線
2. **「Too cheap to meter」ビジョン** — AI 計算コストのコモディティ化
3. **分散 RL の実用化** — permissionless GPU でフロンティア訓練が可能という証明
4. **日本からのアクセス性** — API $0.20/M は Gemini Flash 級の安さ$md$,
  '2026-04-20'
),
(
  'prime_intellect',
  'models',
  'INTELLECT-3 モデル詳細 (106B MoE / prime-rl フレームワーク / GPU マーケット)',
  $md$## モデル一覧 (2026-04 時点)

| モデル | タイプ | パラメータ | コンテキスト | 用途 | $/M tokens |
|--------|--------|-----------|-------------|------|-----------|
| **INTELLECT-3** | Chat / Reasoning | 106B MoE (12B active) | 131K | 推論・数学・コード | **$0.20 in** |
| **INTELLECT-2** | RL ベースライン | 32B | 32K | 研究向け (OSS 重み) | HF DL |
| **INTELLECT-1** | 初期 SFT 実証 | 10B dense | 8K | 研究向け (OSS 重み) | HF DL |

## INTELLECT-3 詳細

```text
アーキテクチャ: Mixture of Experts (8 experts × ~13B)
ベース: Z.ai GLM 4.5 Air
訓練:
  - Stage 1: SFT (合成 + 人間データ 10M+ samples)
  - Stage 2: RL (グローバル分散 permissionless GPU)
  - 学習 compute: 512×NVIDIA H200
訓練インフラ:
  - prime-rl フレームワーク (OSS)
  - 全世界の GPU ノードが RL rollout に参加
  - ノード障害 fault tolerance
ベンチマーク:
  - AIME 2024        : 90.8%   (Claude Sonnet 4.6 88%)
  - LiveCodeBench    : SOTA-for-size
  - GPQA             : Frontier-class
  - MATH             : 88+%
強み:
  - 12B active でコスト効率
  - 131K ctx で長文解析
  - open weights + Apache 2.0
弱み:
  - 日本語サポートは標準的 (英語中心)
  - マルチモーダル非対応 (テキストのみ)
```

## prime-rl フレームワーク (OSS)

INTELLECT-2/3 の訓練を可能にした OSS RL ライブラリ:

```bash
# GitHub: PrimeIntellect-ai/prime
pip install prime-rl

# 分散 RL ジョブのキック (例)
from prime_rl import AsyncTrainer

trainer = AsyncTrainer(
    model="meta-llama/Llama-3.1-8B-Instruct",
    reward_model="PrimeIntellect/reward-8b",
    env="math_reasoning",
    nodes=100,        # 全世界 100 GPU ノード
    rollout_batch=512,
)
trainer.run()
```

### prime-rl の特徴

1. **非同期 RL** (async rollouts) — ノード間同期待ちを排除
2. **fault tolerance** — 1 ノード落ちてもジョブ継続
3. **heterogeneous GPU 対応** — A100 / H100 / RTX 4090 混成 OK
4. **permissionless** — 誰でも GPU を提供して報酬獲得可

## GPU マーケットプレイス

```text
┌─────────────────────────────────────────────┐
│  Prime Intellect GPU Marketplace            │
│  ─────────────────                          │
│  H200 80GB   : $3.99/hr  (on-demand)        │
│  H100 80GB   : $2.49/hr                     │
│  A100 80GB   : $1.29/hr                     │
│  RTX 4090    : $0.39/hr                     │
│                                             │
│  ・Spot 割引: 最大 70% オフ                 │
│  ・秒単位課金                                │
│  ・事前登録不要 (即時起動)                   │
│  ・prime CLI で RL ジョブ直接キック          │
└─────────────────────────────────────────────┘
```

## INTELLECT-3 API 経由での利用

```bash
# Prime Intellect 公式 API (2026-04 現在は beta waitlist / OpenRouter 経由が推奨)
curl https://api.primeintellect.ai/v1/chat/completions \
  -H "Authorization: Bearer $PRIME_INTELLECT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "intellect-3",
    "messages": [{"role": "user", "content": "Solve: integrate x^2 dx"}],
    "max_tokens": 1024
  }'
```

## OpenRouter 経由 (推奨・最速)

```typescript
// ai-hub/actions/chat.ts に provider 追加
const PRIME_MODELS = {
  'intellect-3': 'primeintellect/intellect-3',
  'intellect-2': 'primeintellect/intellect-2',
};

export async function callPrimeIntellectChat(payload: {
  model: keyof typeof PRIME_MODELS;
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
      model: PRIME_MODELS[payload.model],
      messages: payload.messages,
      max_tokens: 4096,
    }),
  });
  return await response.json();
}
```

## HuggingFace 直接利用 (OSS weights)

```python
# pip install transformers torch accelerate
from transformers import AutoModelForCausalLM, AutoTokenizer

model_id = "PrimeIntellect/INTELLECT-3"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(
    model_id,
    device_map="auto",
    load_in_4bit=True,  # H100 1 枚で動作
)

messages = [
    {"role": "system", "content": "You are INTELLECT, a reasoning assistant."},
    {"role": "user", "content": "証明: n^2 + n は常に偶数である"},
]
inputs = tokenizer.apply_chat_template(messages, return_tensors="pt").to("cuda")
outputs = model.generate(inputs, max_new_tokens=2048)
print(tokenizer.decode(outputs[0]))
```

## 既存 LLM との使い分け

| 用途 | 推奨モデル |
|------|-----------|
| 数学・推論 (コスト重視) | **INTELLECT-3** ($0.20/M で AIME 90.8%) |
| コード生成 | INTELLECT-3 / Claude Sonnet 4.6 |
| 自己ホスト分散 RL | **prime-rl + INTELLECT-2** |
| マルチモーダル | GPT-4o / Gemini 2.5 Pro |
| 日本語高品質 | Claude / Gemini (INTELLECT は英語中心) |
| エンタープライズ compliance | Anthropic / AWS Bedrock$md$,
  '2026-04-20'
),
(
  'prime_intellect',
  'api',
  'Prime Intellect 使い方 (OpenRouter / API / GPU マーケット / Flutter 統合)',
  $md$## 利用パスの 4 つの選択肢

### 1. OpenRouter 経由 (最速・最安) — 推奨

API キー 1 つで INTELLECT 系列にアクセス可。自分株式会社の ai-hub と相性◎。

```typescript
// supabase/functions/ai-hub/actions/chat.ts に prime_intellect provider 追加
const PRIME_MODELS = {
  'intellect-3': 'primeintellect/intellect-3',
  'intellect-2': 'primeintellect/intellect-2',
};

// OpenRouter 経由の呼び出しは既存 Nous Research 実装と同じ構造
```

### 2. 公式 API (waitlist / 2026-Q2 GA 予定)

```bash
curl https://api.primeintellect.ai/v1/chat/completions \
  -H "Authorization: Bearer $PRIME_INTELLECT_API_KEY" \
  -d '{"model": "intellect-3", "messages": [...]}'
```

### 3. HuggingFace 直接 OSS (フルコントロール)

```bash
# サーバー要件: H100 80GB×1 (4bit 量子化) / A100 80GB×2 (fp16)
pip install transformers accelerate bitsandbytes

huggingface-cli download PrimeIntellect/INTELLECT-3
```

### 4. GPU マーケット + prime-rl (分散 RL 実験)

```bash
# 自分で RL ジョブを走らせる (研究・実験用)
pip install prime
prime auth login
prime gpu launch --type h100 --nodes 4 --hours 24

# prime-rl で INTELLECT-2 ベースの独自 RL
git clone https://github.com/PrimeIntellect-ai/prime-rl
cd prime-rl
python train.py --config configs/intellect-2-continue.yaml
```

## Flutter Web (自分株式会社) からの呼出例

```dart
// lib/services/prime_intellect_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class PrimeIntellectService {
  static Future<String?> reason({
    required String prompt,
    String model = 'intellect-3',
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'ai-hub',
      body: {
        'action': 'chat',
        'provider': 'prime_intellect',
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'あなたは数学・論理推論を得意とする AI アシスタントです。',
          },
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

| 機能 | Prime Intellect 適用 |
|------|---------------------|
| **AI 大学** | 「分散 RL 体験」コース (prime-rl で小さな RL ジョブを走らせる教材) |
| **ai-hub** | 既存 ai-hub に `prime_intellect` provider 追加 (OpenRouter 経由) |
| **数学・推論タスク** | INTELLECT-3 を $0.20/M で呼び出し (Gemini Flash 級コスト) |
| **競馬予想の reasoning** | RL ネイティブモデルで予想ロジック強化 |
| **コスト最適化** | INTELLECT-3 で代替できる AI 判定タスクを洗い出し (daily-judgment 等) |
| **PHILOSOPHY 整合** | 原則 6 (資本=時間) → AI コスト低減で操作時間最小化 |

## 料金まとめ (推定 2026-04)

- **OpenRouter 経由**: $0.20-0.40 / M tokens (INTELLECT-3)
- **OSS 自前ホスト**: H100 コストのみ (1 枚 $2.49/hr × 稼働率)
- **GPU マーケット**: $0.39/hr (4090) 〜 $3.99/hr (H200) on-demand

## 注意事項・制約

- **日本語**: 英語中心訓練 — 日本語は標準的 (GLM 4.5 Air ベース)
- **マルチモーダル非対応**: テキストのみ (画像・音声は他プロバイダー併用)
- **公式 API**: 2026-04 現在 waitlist — OpenRouter 経由が現実的
- **分散 RL ジョブ**: H100 4 枚以上推奨 (小規模実験でも)
- **SOC 2 compliance**: 取得中 (エンタープライズ本番には時期尚早)

## 公式リソース

- Web: https://www.primeintellect.ai/
- INTELLECT-3 発表: https://www.primeintellect.ai/blog/intellect-3
- Tech Report: https://arxiv.org/abs/2512.16144
- HuggingFace: https://huggingface.co/PrimeIntellect
- prime-rl GitHub: https://github.com/PrimeIntellect-ai/prime-rl
- GPU マーケット: https://www.primeintellect.ai/dashboard/
- OpenRouter: https://openrouter.ai/primeintellect

## 類似サービスとの比較

| サービス | 強み | 差別化ポイント |
|---------|------|---------------|
| **Prime Intellect** | 分散 RL + GPU マーケット + OSS モデル | 3 層垂直統合 |
| Nous Research | Psyche 分散 SFT + Hermes | SFT 特化 (RL は Prime が先行) |
| Together AI | 大規模モデルホスティング | モデル自作せず配信のみ |
| Lambda Labs | GPU レンタル特化 | RL 基盤なし |
| OpenAI | 最強 frontier モデル | クローズドのみ$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
