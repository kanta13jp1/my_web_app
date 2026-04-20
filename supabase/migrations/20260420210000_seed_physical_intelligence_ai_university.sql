-- Session PS#3-S23: AI大学 141 社化 — Physical Intelligence (π) 追加
-- Sergey Levine (Berkeley) + Karol Hausman (Google DeepMind) 率いる
-- robotics foundation model ラボ。π-0 / π-0-FAST / π-0.5 を完全 OSS で公開。
-- Series A $400M (Jeff Bezos + OpenAI lead) / Series B $600M (CapitalG lead)
-- 2026-04 時点で $1B ラウンド交渉中 (valuation $11B+)
-- 既存 140 社に完全空白だった embodied AI / robotics VLA 軸を埋める。
-- Step 0: 9/9 (S19 Kyutai に続く 2 本目の満点)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'physical_intelligence',
    'overview',
    'Physical Intelligence (π) — robot foundation model の先端ラボ ($11B valuation)',
    $md$
# Physical Intelligence (π) — robot foundation model の先端ラボ (\$11B valuation)

2024 年創業。CEO **Karol Hausman** (元 Google DeepMind)、チーフサイエンティスト
**Sergey Levine** (UC Berkeley 教授 / Deep RL 第一人者)。
「あらゆる機械に汎用知能 (= π, Physical Intelligence)」をミッションに、
**vision-language-action (VLA)** foundation model を構築する robotics ラボ。

## 既存 140 社との差別化
| 観点 | Physical Intelligence | Figure AI | 1X Technologies |
|------|----------------------|-----------|------------------|
| レイヤー | 🦾 **foundation model** (hardware-agnostic) | humanoid hardware + AI | humanoid (Neo) |
| OSS | ✅ π-0 + π-0.5 weights 公開 | ❌ closed | ❌ closed |
| 対応 robot | ALOHA / DROID / Franka / UR5 / xArm 等 | Figure 02 専用 | Neo 専用 |
| ターゲット | 研究者 + robotics 企業 | 自社 humanoid | 自社 humanoid |
| 哲学 | 「AI を hardware から decouple」 | 垂直統合 | 垂直統合 |

## 主要モデル (3 世代)
- **π-0** (2025-02): 3B transformer / PaliGemma ベース / flow-based action / 10k+ 時間の robot データで事前学習
- **π-0-FAST**: autoregressive 版 / FAST action tokenizer で高速 inference
- **π-0.5** (2025-late): open-world generalization 強化 / 未知の家で「片付け」等を遂行

## 資金調達
- Series A: **\$400M** (2024-11, Jeff Bezos + OpenAI lead)
- Series B: **\$600M** (2025, CapitalG / Alphabet lead + Lux + Bond + Redpoint + Sequoia)
- 2026-04 時点: **\$1B ラウンド交渉中 @ valuation \$11B+** (PYMNTS 報道)

## 哲学 (Levine 公言)
> "We decouple the AI from the hardware. The same π-model should run
>  a warehouse arm in Texas and a humanoid in Tokyo. Robotics needs
>  its GPT-moment, and that requires a generalist foundation model."

## 自分株式会社での活用
- daily-judgment: π-0.5 の「open-world 未知タスクへの汎化」を自分 PHILOSOPHY 適用事例集めに応用
- AI大学: robotics 軸が完全に空白 → 第 11 カテゴリ (embodied AI) として展開可能性
- user-manual: physicalintelligence.company/blog の技術記事を日本語 summary 化
$md$,
    NOW()
  ),
  (
    'physical_intelligence',
    'models',
    'π-0 / π-0-FAST / π-0.5 — VLA モデル 3 世代詳解',
    $md$
# π-0 / π-0-FAST / π-0.5 — VLA モデル 3 世代詳解

## π-0 (初代 / 2025-02)
- 3B パラメータ transformer
- **PaliGemma (Google) vision-language backbone** + action generation head
- **flow-matching** action decoder (diffusion-like)
- 10k+ 時間の robot teleoperation データで事前学習
- 「最も有能な generalist robot policy」(公式主張)

## π-0-FAST
- **autoregressive** 版 (flow ではなく next-token prediction)
- FAST action tokenizer で inference 高速化
- リアルタイム制御向け variant

## π-0.5 (2025 late)
- **open-world generalization** を訓練目的に明示
- knowledge insulation (訓練中に world knowledge を action から分離)
- **未知の家** での片付け・食器洗い・ベッド整頓を試行
- 「初回は失敗しても、再試行で器用に回復」という定性特性

## Expert checkpoints (robot 別)
openpi リポジトリには platform 別 fine-tune 済みモデルも公開:
- **ALOHA** (Stanford) — 両手操作用
- **DROID** (Stanford 公開 dataset) — single-arm
- **Franka** / **UR5** / **xArm** 等への派生あり

## 訓練 infra
- JAX ベース (Google Cloud TPU で学習)
- HuggingFace が PyTorch port を公開 (community)
- weights 配布: `gs://openpi-assets/checkpoints/pi05_base/params`

## ライセンス
- code: Apache 2.0 (openpi repo)
- weights: 同 Apache 2.0 / Google Cloud Storage から直接 DL 可

## Philosophy (π₀ blog から)
> "We believe that the same kind of scaling law that transformed
>  language modeling will transform robotics, if we can build a large
>  enough, diverse enough generalist model. π is our attempt at that."
$md$,
    NOW()
  ),
  (
    'physical_intelligence',
    'api',
    'openpi SDK — 自分株式会社での組込手順',
    $md$
# openpi SDK — 自分株式会社での組込手順

## インストール (JAX 版・公式)
```bash
git clone https://github.com/Physical-Intelligence/openpi
cd openpi
pip install -e .
# JAX + CUDA が必要 (Linux + GPU 推奨)
```

## HuggingFace PyTorch port (軽量試用)
```bash
pip install lerobot  # HuggingFace LeRobot に π-0 port 収録
```

## π-0 で ALOHA 風 simulation を動かす (PyTorch 側最小例)
```python
from lerobot.common.policies.pi0 import Pi0Policy

policy = Pi0Policy.from_pretrained("lerobot/pi0")

# 観測 (image + robot state) を与えると行動予測
action = policy.select_action({
    "observation.images.top": rgb_image,
    "observation.state": joint_positions,
})
# action = joint_velocities 等
```

## LoRA fine-tune (π-0.5 / 自社データ対応)
```bash
# openpi の training config 例
python scripts/train.py \
    --config configs/pi05_lora.yaml \
    --data /path/to/my_robot_traces/ \
    --output_dir ./checkpoints/pi05_mybot/
```

## ai-hub 統合提案 (Win版 cross-instance-pr 候補・LOW 優先度)
```typescript
// supabase/functions/ai-hub/index.ts に追加
// ※ robotics 実機保有ゼロなので実運用は simulation only 前提
case 'robotics.vla_plan':
  // 観測 (画像 + 言語指示) を受け取り π-0.5 で action 系列を返却
  // simulation 用途 (MuJoCo / Isaac Sim) にのみ使用 — AI-DEV-23 原則 2 (deny-by-default)
  return await physicalIntelligenceVlaPlan(body);
```

## 試す
- Web: https://physicalintelligence.company/
- 旧 URL: https://pi.website/
- GitHub: https://github.com/Physical-Intelligence/openpi
- π-0 blog: https://www.pi.website/blog/pi0
- π-0.5 blog: https://www.physicalintelligence.company/blog/pi05
- 公開 blog: https://www.pi.website/blog/openpi
- HuggingFace port: https://huggingface.co/lerobot/pi0
- 論文 (π-0): arXiv 2410.24164

## 想定コラボ
- Snorkel AI (S21) との補完: Snorkel weak supervision で robot teleop データ量産 → π-0 fine-tune
- Haize Labs (S22) との補完: 物理世界 agent の safety audit を π-0 に適用
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
