-- PS版#3 Session 17: Imbue — 推論特化 70B 自社訓練 + CARBS cost-aware HPO OSS / $230M raised
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'imbue',
  'overview',
  'Imbue — 推論特化 AI エージェント研究所 ($230M / CARBS OSS / 70B 自社訓練)',
  $md$## Imbue とは

Imbue は 2021 年創業、サンフランシスコ拠点の **「推論できる AI エージェントを人と並走させる」** 研究所。
CEO **Kanjun Qiu** (Sourceful / Ought 出身) が率い、「agents that can reason and collaborate」を
コア信条に 70B 規模の **自社フル pretrain モデル** + OSS ツール群で研究開発を推進。

**差別化ポイント**: 他の AI ラボが「まず LLM」で agent は後付けなのに対し、
Imbue は「推論能力こそ agent のボトルネック」と明言 → pretrain 段階から推論特化設計。

## 既存 134 社との差別化軸

| 観点 | Imbue | Anthropic | OpenAI | Mistral |
|------|-------|-----------|--------|---------|
| **設計思想** | 🤔 **推論 first / agent 専用 pretrain** | 安全性 first | AGI 汎用 | オープン汎用 |
| **モデル規模** | 70B (自社 full train) | ~Claude 各サイズ | o1 / GPT-4 系 | 7B-123B |
| **HPO ツール** | ✅ **CARBS 完全 OSS** | internal | internal | internal |
| **オープンデータ** | ✅ sanitized eval datasets | 部分 | ❌ | ✅ |
| **Infra script** | ✅ **bare-metal 70B script OSS** | ❌ | ❌ | ❌ |
| **API 公開** | ❌ 研究所モード | ✅ | ✅ | ✅ |

## 製品・研究ライン (2026-04 時点)

```text
┌─────────────────────────────────────────────┐
│  Imbue Research Stack                       │
│  ─────────────                              │
│  1. 70B Reasoning LM (internal, first-try)  │
│     └ CARBS で loss spike 0 scale-up 成功   │
│  2. CARBS HPO (GitHub OSS)                  │
│     └ 学習率 + cost を Bayesian 同時最適化   │
│  3. Sanitized Eval Datasets (OSS)           │
│     └ test-train leakage を HashSet で除去  │
│  4. Bare-metal 70B Training Script (OSS)    │
│     └ GPU cluster setup → training 完全 repo│
│  5. Agent prototype (internal)              │
│     └ 「reasoning-first agent」研究ベッド   │
└─────────────────────────────────────────────┘
```

## CARBS (cost-aware HPO)

Imbue の最大の OSS 貢献。従来の HPO は「性能 vs 探索コスト」を分離するが、CARBS は
**Bayesian Optimization + Gaussian Process で性能+コストを同時モデリング**。

```text
従来 HPO:
  search_bounds = [(lr, 1e-5, 1e-2), (bs, 32, 512), ...]
  budget = 500 GPU-hours
  → 予算内でランダム探索 → 最良を選択

CARBS:
  search_bounds = 不要 (自動推定)
  budget = 不要 (打ち切り判定自動)
  → 性能↑1% が cost↑2x に見合うか連続評価
  → scale-up 時の HP を外挿可能
```

**実績**: Imbue は CARBS を使って 70B モデルを **「first attempt で loss spike なし」** で
訓練完了。これはフロンティアラボでも稀な achievement。

## 資金調達

- Series A+B 累計: **$230M**
- Backers: Astera Institute / Nat Friedman / Daniel Gross / Lachy Groom
- 2024: Nvidia DGX SuperPOD 導入 (70B 訓練基盤)
- 2025: agent プロダクト化モード突入 (公開 roadmap)

## なぜ今この組織が重要か

1. **OSS インフラ**: CARBS + 70B training script = 中小ラボ/個人が巨大モデル学習可
2. **推論特化思想**: o1 / DeepSeek-R1 登場前から「agent reasoning」に集中 (先見性)
3. **人材**: MIT CSAIL / Sourceful / Ought 出身の reasoning 研究エリート集結
4. **透明性**: 70B 訓練の学び (dataset / infra / HP) を blog で全公開
5. **エージェント未来**: 「agents don't work yet」を公言し reasoning を真正面から研究

## 日本語対応

- 70B model: 多言語訓練だが日本語精度は非公開 (API 非公開のため検証困難)
- CARBS: 言語非依存 (HPO ツール) — 日本語モデル学習にも適用可能
- Bare-metal script: 英語コメント中心だが 日本語モデル学習 (例 LLM-jp) に転用可$md$,
  '2026-04-20'
),
(
  'imbue',
  'models',
  'Imbue モデル・ツール詳細 (70B / CARBS / eval datasets / infra script)',
  $md$## 70B 推論モデル

Imbue 自社 pretrain 70B params. 公開モデル重みなしだが、以下ベンチマーク/設計が blog で全公開:

```text
アーキテクチャ: decoder-only transformer (Llama 2 ベース改変)
訓練 token: 2T+ (推論特化データセット混合)
HPO: CARBS 全段階適用
訓練時間: ~6 週間 (Nvidia DGX SuperPOD)
Loss spike: 0 (first attempt)
Eval: zero-shot MMLU / GSM8K / HumanEval 公開
```

## 公開ベンチマーク

| ベンチ | Imbue 70B | Llama-3.1-70B | Mistral Large 2 |
|-------|-----------|---------------|-----------------|
| MMLU (5-shot) | 74.8% | 79.5% | 81.2% |
| GSM8K (8-shot) | 81.3% | 88.2% | 88.6% |
| HumanEval (0-shot) | 68.9% | 72.5% | 77.1% |

**評価**: SOTA には劣るが 「first full train」で Llama 3.1 に肉薄。より重要なのは
**「reasoning-oriented eval」** での相対優位 (scratch-pad reasoning / multi-step QA)。

## CARBS (HuggingFace に近い位置)

```python
from carbs import CARBS, LinearSpace, LogSpace

search = [
    LogSpace(name="learning_rate", min_log=-6, max_log=-2),
    LinearSpace(name="batch_size", min=32, max=512),
    LogSpace(name="weight_decay", min_log=-4, max_log=-1),
]

carbs = CARBS(
    objective_name="val_loss",
    cost_name="gpu_hours",
    search_space=search,
    better_direction_sign=-1,  # minimize loss
)

for trial in carbs.suggest():
    result = run_training(trial.hyperparameters)
    carbs.observe(result.val_loss, result.gpu_hours)
```

## Sanitized Eval Datasets (test-train leakage 除去)

Imbue が公開した 「既存 eval dataset の sanitize 版」:

| オリジナル | Imbue 版 | 変更内容 |
|-----------|---------|---------|
| MMLU | `imbue-ai/mmlu-sanitized` | pretraining corpus と重複 1.2% 除去 |
| TruthfulQA | `imbue-ai/truthful_qa-sanitized` | 重複 3.8% 除去 |
| HumanEval | `imbue-ai/human_eval-sanitized` | fuzzy hash 重複 0.9% 除去 |

**背景**: 公開 LLM の多くは MMLU のテストデータがたまたま訓練 corpus に含まれ、
リーダーボード inflation → Imbue が 検出ツール + sanitize dataset を OSS 化。

## Bare-Metal 70B Training Script (OSS)

```bash
# imbue-ai/nitro リポジトリ (内部コード名)
git clone https://github.com/imbue-ai/nitro
cd nitro

# Phase 1: cluster setup (bare-metal)
ansible-playbook -i inventory bare_metal_setup.yml

# Phase 2: torch + CUDA + NCCL tuning
./scripts/install_stack.sh

# Phase 3: 70B distributed training
torchrun --nproc_per_node=8 --nnodes=64 \
  train.py --config configs/70b_reasoning.yaml
```

**特徴**:
- Nvidia DGX H100 x 512 GPU (64 nodes) 想定
- FP8 mixed precision (H100 native)
- CARBS による HP 自動選択
- checkpoint ~50GB / 15 分間隔 (fault tolerance)

## 研究論文

- [Scaling Laws For Every Hyperparameter Via Cost-Aware HPO](https://imbue.com/research/carbs/) (2023)
- [Open-sourcing CARBS](https://imbue.com/research/70b-carbs/) (2024)
- [Training a 70B model from scratch](https://imbue.com/research/70b-intro/) (2024)
- [Sanitized eval datasets](https://imbue.com/research/70b-evals/) (2024)

## 将来のロードマップ (CEO Kanjun Qiu 発言より)

- **reasoning-first agent プロダクト**: コード書ける agent を一般公開 (2026 予定)
- **CARBS v2**: multi-objective 対応 (速度 + コスト + 性能)
- **collaborative learning**: agent と user が共に学び合う UX 研究

## ライセンス

- **CARBS**: Apache 2.0 (商用 OK)
- **Sanitized datasets**: CC-BY 4.0 (attribution のみ)
- **70B model 重み**: 非公開 (社内研究用)
- **論文**: CC-BY 4.0 相当 (blog 公開)$md$,
  '2026-04-20'
),
(
  'imbue',
  'api',
  'Imbue 実践 (CARBS 導入 / sanitized dataset 活用 / 自分株式会社での利用)',
  $md$## CARBS 導入 (最も実用的な活用)

```bash
pip install carbs
```

```python
# 自分株式会社の AI 機能チューニング例
from carbs import CARBS, LogSpace, LinearSpace
from typing import Dict

def train_and_eval(hp: Dict) -> Dict:
    """
    例: daily-judgment の Claude/GPT 混合比率を CARBS で最適化
    """
    result = run_mixed_judgment(
        claude_weight=hp["claude_weight"],
        gpt_weight=hp["gpt_weight"],
        temperature=hp["temperature"],
    )
    return {
        "objective": result.user_satisfaction_score,
        "cost": result.total_tokens_usd,
    }

search_space = [
    LinearSpace(name="claude_weight", min=0.0, max=1.0),
    LinearSpace(name="gpt_weight", min=0.0, max=1.0),
    LogSpace(name="temperature", min_log=-2, max_log=0.3),
]

carbs = CARBS(
    objective_name="objective",
    cost_name="cost",
    search_space=search_space,
    better_direction_sign=1,  # maximize satisfaction
)

for i in range(50):
    trial = carbs.suggest()
    result = train_and_eval(trial.hyperparameters)
    carbs.observe(result["objective"], result["cost"])

best = carbs.get_best_trial()
print(f"Best HP: {best.hyperparameters}")
print(f"Score: {best.objective}, Cost: ${best.cost}")
```

## Sanitized Dataset 利用

```python
from datasets import load_dataset

# test-train leakage 除去済 MMLU で自社モデル評価
mmlu = load_dataset("imbue-ai/mmlu-sanitized")

# 既存モデルで精度比較 (leak なし → 真の一般化性能)
for split in ["validation", "test"]:
    score = evaluate_model(my_model, mmlu[split])
    print(f"{split}: {score:.3f}")
```

## 自分株式会社 (ai-hub) 統合案

```typescript
// supabase/functions/tools-hub/actions/carbs_optimize.ts (新規 action 候補)
// Note: CARBS 本体は Python — Deno では scipy wrapper 経由 or
//       Python subprocess / webhook で呼出し
export async function scheduleCarbsOptimization(payload: {
  task_name: string;
  search_space: Array<{ name: string; min: number; max: number; log?: boolean }>;
  budget_gpu_hours: number;
}) {
  // GitHub Actions で CARBS worker 起動 → 結果を Supabase に書込
  const result = await fetch("https://api.github.com/repos/kanta13jp1/my_web_app/actions/workflows/carbs-optimize.yml/dispatches", {
    method: "POST",
    headers: { Authorization: `token ${Deno.env.get("GH_PAT")}` },
    body: JSON.stringify({
      ref: "main",
      inputs: { task_name: payload.task_name, config: JSON.stringify(payload) },
    }),
  });
  return { dispatched: result.ok };
}
```

## Flutter Web からの活用イメージ

```dart
// lib/services/carbs_tuning_service.dart
// 管理画面で AI 機能の HP チューニングを可視化
class CarbsTuningService {
  static Future<Map<String, dynamic>> triggerOptimization({
    required String taskName,
    required List<Map<String, dynamic>> searchSpace,
    required int budgetGpuHours,
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'tools-hub',
      body: {
        'action': 'carbs_optimize',
        'task_name': taskName,
        'search_space': searchSpace,
        'budget_gpu_hours': budgetGpuHours,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }
}
```

## 自分株式会社からの活用イメージ

| 機能 | Imbue 適用 |
|------|------------|
| **daily-judgment** | Claude/GPT 重み + temperature を CARBS で週次再最適化 |
| **competitor-monitoring** | 各プロバイダー weight を CARBS で cost/精度 最適化 |
| **AI 大学** | LLM プロバイダー ranking の re-weight を CARBS で自動化 |
| **AI アシスタント** | retrieval top-k / rerank weight を CARBS で動的調整 |
| **admin analytics** | KPI 目標達成 HP 探索を CARBS タスクとして表示 |

## 料金試算 (自分株式会社スケール)

```text
CARBS 本体: OSS (Apache 2.0) → $0
GPU コスト: AWS g5.xlarge (A10G) $1/hr × CARBS 推奨 budget
  例: 50 trials × 2 hr × $1 = $100 で daily-judgment 最適化完了
  月次再最適化: $100/月 (年 $1.2K)

比較: 人間の ML エンジニア chief tuning 時間換算:
  20 時間/月 × $100/hr = $2,000/月
  → CARBS 自動化で 95% 工数削減
```

## 注意事項・制約

- **70B モデル非公開**: API 利用不可 — CARBS + datasets が主な接点
- **GPU 依存**: CARBS は CPU でも動くが scale-up 検証は GPU 必須
- **Python 限定**: CARBS 本体は Python/PyTorch — Deno/Dart からは subprocess
- **learning curve**: Bayesian Optimization 前提知識が必要
- **商用 SLA**: OSS のみ — enterprise サポートなし (コミュニティ Discord あり)

## 公式リソース

- Web: https://imbue.com/
- Blog: https://imbue.com/blog/
- CARBS GitHub: https://github.com/imbue-ai/carbs
- HuggingFace datasets: https://huggingface.co/imbue-ai
- Kanjun Qiu: https://www.kanjun.me/
- 70B 訓練記事: https://imbue.com/research/70b-intro/

## 類似サービス比較

| サービス | 強み | 差別化 |
|---------|------|--------|
| **Imbue** | reasoning-first + CARBS + OSS transparency | 中小ラボの scale-up を democratize |
| Anthropic | 安全性 + Claude SOTA | プロダクト成熟度 |
| OpenAI | o1 / Agent mode | クローズド |
| Optuna | HPO 定番 | cost-aware ではない |
| Ray Tune | 分散 HPO | Bayesian 以外も幅広い |

## 競合リスク

- **Optuna**: CARBS と同じ HPO カテゴリ / Bayesian 強 / コミュニティ最大
  → Imbue の差別化: cost 同時最適化 + scale-up 外挿
- **Ray Tune**: Ray ecosystem に統合 / 大規模分散強
  → Imbue の差別化: 単独 lib で軽量 + 研究重視
- **Tune (HuggingFace)**: transformers 統合 / コード最小
  → Imbue の差別化: 汎用 HPO / NN 以外にも適用可$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
