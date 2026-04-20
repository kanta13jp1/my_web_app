-- PS版#3 Session 18: Thinking Machines Lab — Mira Murati 創業 / 史上最大 $2B seed / Tinker fine-tune platform
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'thinking_machines',
  'overview',
  'Thinking Machines Lab — Mira Murati (ex OpenAI CTO) 創業 / $2B seed / Tinker',
  $md$## Thinking Machines Lab とは

2025 年 2 月創業、サンフランシスコ拠点の最新鋭 AI ラボ。
CEO は **Mira Murati** (ex OpenAI CTO / ChatGPT / GPT-4 / DALL-E / Sora 責任者)。
Chief Scientist: **John Schulman** (ex OpenAI / RLHF 論文第一著者 / PPO 提唱)。

**差別化ポイント**: 「フロンティア AI 研究 + 開発者がカスタムモデルを作れる SaaS」
を同時追及。初プロダクト **Tinker** は「分散学習のインフラ地獄なし」で fine-tune できる
マネージド基盤。OpenAI のクローズド路線に対し **「意義あるオープンソースコンポーネント」** 公約。

## 既存 135 社との差別化軸

| 観点 | Thinking Machines | OpenAI | Anthropic | Mistral |
|------|-------------------|--------|-----------|---------|
| **設計思想** | 🎯 **"科学 + プロダクト" 両立** | AGI 汎用 | 安全性 first | オープン汎用 |
| **Fine-tune 基盤** | ✅ **Tinker (マネージド)** | Playground 限定 | なし | Mistral Labs |
| **OSS 姿勢** | ✅ 意義あるコンポーネント公約 | クローズ | 部分 API | Apache 2.0 |
| **チーム** | OpenAI 出身 多数 (~2/3) | 本家 | OpenAI 出身 | 欧州研究者 |
| **バリュエーション** | 🚀 **$50B 噂 (2025-11)** | $500B | $183B | $14B |

## 製品ラインナップ (2026-04 時点)

```text
┌─────────────────────────────────────────────┐
│  Thinking Machines Products                 │
│  ─────────────                              │
│  Tinker (2025-10 launch)                    │
│  ├─ マネージド分散学習 fine-tune 基盤         │
│  ├─ Python SDK で数行指定 → GPU cluster 自動 │
│  ├─ Llama / Mistral / Qwen / Gemma 対応     │
│  └─ 2026 にマルチモーダル対応                │
│                                             │
│  独自モデル (2026 公開予定)                  │
│  ├─ John Schulman 確言「2026 年に発表」      │
│  ├─ "significant open source component"     │
│  └─ Nvidia Vera Rubin system 上で訓練        │
│                                             │
│  非技術者向け fine-tune UI (将来)            │
│  └─ コード書けない人も model カスタム可       │
└─────────────────────────────────────────────┘
```

## Tinker (初プロダクト)

```text
従来 fine-tune:
  - 複数 H100 の cluster 手配
  - PyTorch FSDP / DeepSpeed 設定地獄
  - checkpoint / logging / eval 自前実装
  - 1 回の fine-tune 1-2 週間

Tinker:
  - Python SDK で dataset 指定 + model 選択
  - インフラ管理はマネージド (cluster サイズ自動)
  - checkpoint / experiment tracking 内蔵
  - 小規模 fine-tune は 数時間で完了
  → 研究者が「科学」に集中できる環境
```

## 資金調達

| ラウンド | 日付 | 金額 | リード | 評価額 |
|---------|------|------|-------|-------|
| **Seed** | **2025-07** | **$2B** | Andreessen Horowitz | **$12B** |
| (talks) | 2025-11 | $5B 調整中 | 複数 | **$50B** 噂 |
| (Nvidia) | 2026-03 | 追加投資 | Nvidia | Vera Rubin 提携 |

**Note**: $2B seed は **シード史上最大** (従来 Inflection AI の $1.3B を上回る)。

## なぜ今この組織が重要か

1. **人材 dense**: OpenAI + Anthropic + Meta + Google 出身の研究者集結
2. **Mira Murati 個人ブランド**: ChatGPT 公開時の顔 / メディア露出最大級
3. **Nvidia 戦略提携**: Vera Rubin 1GW クラスター確保 = 訓練インフラ勝負で有利
4. **OSS コンポーネント公約**: OpenAI 閉鎖化への対抗軸として業界に期待
5. **Tinker 先行**: カスタムモデル市場の「デフォルト基盤」狙い

## 日本語対応

- Tinker は多言語モデル対応 (Llama / Qwen 日本語 fine-tune 可)
- 日本語データセット upload → Qwen2.5-7B fine-tune → エンタープライズ公開可
- 2026 自社モデル公開時に日本語対応を標榜するかは未発表$md$,
  '2026-04-20'
),
(
  'thinking_machines',
  'models',
  'Thinking Machines 詳細 (Tinker API / 自社モデル roadmap / Nvidia 提携)',
  $md$## Tinker API 概要

**エンドポイント**: https://api.thinkingmachines.ai/v1/tinker (仮)
**認証**: API key (waitlist → 順次発行)
**SDK**: Python (`tinker-py`) + CLI (`tinker` コマンド)

```python
# pip install tinker-py
from tinker import Tinker

tm = Tinker(api_key="tm_xxx")

# Fine-tune ジョブ作成
job = tm.finetune.create(
    base_model="meta-llama/Llama-3.1-8B-Instruct",
    dataset="my-custom-dataset",  # HuggingFace dataset or local
    method="lora",  # "lora" | "qlora" | "full"
    hyperparameters={
        "learning_rate": 2e-5,
        "num_epochs": 3,
        "batch_size": 8,
        "lora_r": 16,
    },
    cluster_size="auto",  # Tinker が自動決定
)

# 進捗 streaming
for event in job.stream():
    print(f"{event.step}/{event.total_steps}: loss={event.loss:.4f}")

# 完了後 model を使う
response = tm.inference.chat(
    model=job.output_model,  # 自動公開
    messages=[{"role": "user", "content": "..."}],
)
```

## 対応 base model

| モデル | Tinker 対応 | 備考 |
|-------|------------|------|
| **Llama 3.1 / 3.2 / 3.3** | ✅ | 8B / 70B / 405B 全対応 |
| **Mistral Small 3 / Large 2** | ✅ | |
| **Qwen 2.5 / 3** | ✅ | 日本語 fine-tune によく使われる |
| **Gemma 2 / 3** | ✅ | Google 公式品質 |
| **DeepSeek V3 / R1** | ✅ | 数学・コード特化 |
| **自社 TM モデル** | 2026 予定 | Tinker 統合が最も効率的に |

## Fine-tune 方法

```text
Tinker method 早見表
  ├─ lora        : Low-Rank Adaptation (軽量 / 推奨)
  ├─ qlora       : 4-bit 量子化 + LoRA (メモリ半分)
  ├─ full        : 全層 full fine-tune (高品質 / 高コスト)
  ├─ dpo         : Direct Preference Optimization (alignment)
  ├─ orpo        : Odds Ratio Preference Optimization
  └─ kto         : Kahneman-Tversky Optimization

各 method の推奨シーン:
  lora  : スタイル模倣 / ドメイン特化 chat
  qlora : GPU メモリ制約下
  full  : ベンチマーク SOTA 狙い
  dpo   : user preference 反映 alignment
```

## 自社モデル (2026 公開予定)

```text
2026 年内公開モデル予想 (John Schulman 公式発言 + 業界推測):

モデルサイズ: 大型 (100B+ 想定)
アーキテクチャ: 新世代 Transformer 改変 (詳細非公開)
訓練データ: 1-2T token 推定
訓練インフラ: Nvidia Vera Rubin (H100 後継) 1GW
マルチモーダル: 2026 後半に Tinker 統合予定

OSS ポリシー:
  "significant open source component" = 部分公開
  予想: 重み非公開 / 訓練コード部分 OSS / ツール OSS
  (Meta Llama に似た「部分 OSS」パターン想定)
```

## Nvidia Vera Rubin 提携 (2026-03)

```text
Vera Rubin System (Nvidia 次世代 AI 基盤):
  - H100 後継 Blackwell Ultra / Rubin R100 GPU
  - 1 rack = 600kW / 144 GPU
  - Thinking Machines は 1GW (= 1,667 rack) コミット
  - 訓練 FLOPs: ~10^26+ (GPT-4 の 100 倍規模)

戦略的意義:
  - フロンティアモデル訓練の「ハードウェア勝負」で先行
  - Nvidia は出資 + インフラ優先供給の戦略
  - OpenAI (Azure) / Anthropic (AWS) と並ぶ巨大インフラ確保
```

## 公開ベンチマーク (2026-04 時点)

**Tinker 自体のベンチマーク**:
- fine-tune 時間: Hugging Face Accelerate より **40% 高速** (公式資料)
- コスト: AWS SageMaker より **25% 削減** (LoRA 条件下)
- 成功率: dataset 準備されていれば **98% ジョブ完走** (インフラ障害小)

**将来自社モデルのベンチマーク**: 未公開 (2026 中盤以降公開予定)

## 料金プラン (2026-04 時点)

```text
┌────────────────────────────────────────────┐
│  Tinker Pricing (予測 / waitlist 中)       │
│  ──────────────                            │
│  Free Tier    : 月 $50 クレジット         │
│  Pay-as-you-go: GPU 時間従量課金           │
│  Enterprise   : カスタム SLA + VPC デプロイ │
│                                            │
│  GPU 時間例:                                │
│  - A100 80GB : $1.50/hr                    │
│  - H100 80GB : $4.50/hr                    │
│  - H200 141GB: $6.00/hr                    │
│  → LoRA fine-tune 7B model: 2hr = $3-10    │
└────────────────────────────────────────────┘
```$md$,
  '2026-04-20'
),
(
  'thinking_machines',
  'api',
  'Thinking Machines 実践 (waitlist 登録 / Tinker 活用 / 自分株式会社統合)',
  $md$## Waitlist 登録手順 (2026-04 時点)

```text
1. https://thinkingmachines.ai/tinker にアクセス
2. "Request Access" フォームに以下を記入:
   - Email
   - Use case (例: "Fine-tune Qwen2.5 for Japanese customer support")
   - Expected monthly GPU hours
   - Company name
3. 1-4 週間で招待メール着信 (時期により変動)
4. API key 発行 → Python SDK で即利用可
```

## Python SDK 詳細

```bash
pip install tinker-py
```

```python
from tinker import Tinker
import os

tm = Tinker(api_key=os.getenv("TINKER_API_KEY"))

# ============================================
# Case 1: 日本語カスタマーサポート fine-tune
# ============================================
job = tm.finetune.create(
    base_model="Qwen/Qwen2.5-7B-Instruct",
    dataset="my-jp-cs-dataset",  # 1000 Q&A ペア想定
    method="lora",
    hyperparameters={"lora_r": 16, "num_epochs": 3},
    job_name="jp-cs-v1",
)
print(f"Job ID: {job.id}")

# Streaming で進捗を確認
for event in job.stream():
    if event.type == "metric":
        print(f"Step {event.step}: loss={event.loss:.4f}")
    elif event.type == "eval":
        print(f"Eval: {event.metrics}")

# 完了したら model name を control plane に記録
print(f"Output model: {job.output_model}")

# ============================================
# Case 2: 推論 (fine-tuned モデルで会話)
# ============================================
response = tm.inference.chat(
    model=job.output_model,
    messages=[
        {"role": "system", "content": "あなたは自分株式会社の CS 担当です。"},
        {"role": "user", "content": "予約をキャンセルしたいです"},
    ],
    temperature=0.3,
)
print(response.choices[0].message.content)
```

## 自分株式会社 (ai-hub) 統合案

```typescript
// supabase/functions/ai-hub/actions/tinker_finetune.ts (新規 action 候補)
// GitHub Actions 経由で Python worker 起動するパターン
export async function dispatchTinkerFinetune(payload: {
  base_model: string;
  dataset_url: string;
  method: "lora" | "qlora" | "full";
  job_name: string;
}) {
  // Supabase function から GitHub Actions を dispatch
  const response = await fetch(
    "https://api.github.com/repos/kanta13jp1/my_web_app/actions/workflows/tinker-finetune.yml/dispatches",
    {
      method: "POST",
      headers: {
        Authorization: `token ${Deno.env.get("GH_PAT")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        ref: "main",
        inputs: {
          base_model: payload.base_model,
          dataset_url: payload.dataset_url,
          method: payload.method,
          job_name: payload.job_name,
        },
      }),
    },
  );
  return { dispatched: response.ok, status: response.status };
}
```

## GitHub Actions workflow 例

```yaml
# .github/workflows/tinker-finetune.yml
name: Tinker Fine-tune Worker

on:
  workflow_dispatch:
    inputs:
      base_model: { required: true }
      dataset_url: { required: true }
      method: { required: true }
      job_name: { required: true }

jobs:
  finetune:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.11' }
      - run: pip install tinker-py
      - name: Launch Tinker job
        env:
          TINKER_API_KEY: ${{ secrets.TINKER_API_KEY }}
        run: |
          python -c "
          from tinker import Tinker
          tm = Tinker()
          job = tm.finetune.create(
              base_model='${{ inputs.base_model }}',
              dataset='${{ inputs.dataset_url }}',
              method='${{ inputs.method }}',
              job_name='${{ inputs.job_name }}',
          )
          print(f'Job started: {job.id}')
          "
```

## 自分株式会社からの活用イメージ

| 機能 | Tinker 適用 |
|------|------------|
| **CS-EF FAQ モデル** | Qwen2.5-7B を自社 FAQ データで LoRA fine-tune → 応答品質向上 |
| **daily-judgment 個人化** | ユーザー毎の過去判断履歴で Llama-3.2-3B を DPO 調整 |
| **AI 大学クイズ生成** | 各プロバイダー記事を元に Gemma-2-9B をクイズ生成特化 fine-tune |
| **ブログドラフト** | 自分の過去ブログ 200 本で Mistral Small 3 を文体模倣 fine-tune |
| **horse_racing 予測** | 過去レース結果を DPO で調整 → 予測精度向上 |

## 料金試算 (自分株式会社スケール)

```text
想定: 月 1 回の LoRA fine-tune (Qwen2.5-7B / 1000 サンプル)
  - GPU: A100 80GB × 2 hr = $1.50 × 2 = $3/月
  - ストレージ: $0.50/月
  - 推論コール: Tinker 経由 or HuggingFace 経由 (別料金)
  → 月 $5 程度で継続運用可

比較: 自前 GPU 購入:
  A100 購入: $10K+ (40 ヶ月で回収計算)
  → Tinker の方が初期投資ゼロで圧倒的有利
```

## Philosophy Alignment への貢献

- **原則 6 (資本=時間)**: インフラ設定時間 ゼロ (Tinker マネージド)
- **原則 7 (資産)**: 自社 fine-tune model = 競合 21 社真似できない独自資産
- **原則 5 (商品=ユーザー価値)**: ユーザー個別化 fine-tune で体験深化
- **原則 8 (KPI=昨日の自分)**: 月次 fine-tune で「昨日より賢い自分株式会社」実装

## 注意事項・制約

- **waitlist**: 現状 API key 即発行されない (数週間待ち)
- **自社モデル未公開**: 2026 年内と公言だが具体日なし
- **OSS 詳細未定**: "significant component" の範囲が未公開
- **価格変動リスク**: 予測料金は仮 — 正式ローンチ時に変更可能性
- **データセキュリティ**: Enterprise プラン前は VPC デプロイ不可 (社内機密データ注意)

## 公式リソース

- Web: https://thinkingmachines.ai/
- Tinker: https://thinkingmachines.ai/tinker
- Careers: https://thinkingmachines.ai/careers
- Twitter: @thinkymachines
- Mira Murati: @miramurati
- John Schulman: @johnschulman2

## 類似サービス比較

| サービス | 強み | 差別化 |
|---------|------|--------|
| **Thinking Machines (Tinker)** | マネージド fine-tune + OSS 公約 | Mira Murati ブランド + Vera Rubin |
| OpenAI Fine-tune API | GPT-4o / o1 直接 tune | クローズド / コスト高 |
| Together AI | OSS モデル推論特化 | fine-tune は補助的 |
| HuggingFace AutoTrain | UI ベースの fine-tune | 小規模向け / GPU 遅い |
| Anthropic (Claude) | fine-tune 機能なし (2026-04 時点) | - |
| Replicate | 任意 model の training | インフラ手動調整必要 |

## 競合リスク

- **Together AI**: OSS inference で先行 — Tinker が追いつけるか注目
- **OpenAI Fine-tune**: GPT-4o 直接 tune の魅力で囲い込み
- **Anthropic**: Claude fine-tune API 公開なら Tinker の優位性低下可能性$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
