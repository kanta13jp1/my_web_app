-- Session PS#3-S22: AI大学 140 社化 — Haize Labs 追加
-- Haize Labs = "Moody's for AI" — 自動 red-teaming + hallucination 検出の safety rating lab
-- Harvard 3 人組 (Leonard Tang / Richard Liu / Steve Li) / 2023 創業 / $7.45M
-- ACG (44% attack success) + Cascade (multi-turn jailbreak) + Sphynx (hallucination OSS)
-- Step 0: 7.5/9 (API public 限定 -1 / seed stage のみ -0.5)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'haize_labs',
    'overview',
    'Haize Labs — "Moody''s for AI" 自動 red-teaming + 安全性格付け',
    $md$
# Haize Labs — "Moody's for AI" 自動 red-teaming + 安全性格付け

2023 年創業、ハーバード同級生 3 人 (CEO **Leonard Tang** / **Richard Liu** /
**Steve Li**) が立ち上げた AI 安全性診断スタートアップ。
「AI 版 Moody's」として大規模言語モデル・エージェントに対する
**自動 red-teaming** と safety rating を提供。

## 既存 139 社との差別化
| 観点 | Haize Labs | Lakera AI | Robust Intelligence |
|------|-----------|-----------|---------------------|
| アプローチ | 🛡️ 自動 algorithm ベース red-team | guardrail + prompt shield | eval + 防御 |
| 核技術 | ACG + Cascade + Sphynx | PII + prompt injection filter | MLOps eval suite |
| ポジショニング | AI 格付け機関 ("Moody's for AI") | runtime 防御 | 継続評価 |
| 顧客 | Anthropic / Scale AI / AI21 | enterprise 幅広 | Fortune 500 |
| OSS | ✅ Sphynx + get-haized 公開 | 🟡 一部 | 🟡 一部 |

## 主要プロダクト (3 algorithm)
- **ACG** (Accelerated Coordinate Gradient): jailbreak attack success **44%** (baseline 4x)
- **Cascade**: multi-turn 対話での段階的 jailbreak (Gray Swan RR / Llama 3 LAT で人手超越)
- **Sphynx**: hallucination 検出モデル (HDM) を破る adversarial 訓練データ生成 OSS

## 資金調達
- 累計: **\$7.45M** (seed ラウンド中心)
- Anthropic / Scale AI / AI21 との複数百万ドル契約 (2024-2025)
- Anthropic は「顧客かつ出資者候補」という稀な構図

## 顧客事例
- **Anthropic**: Claude の pre-release red-team
- **Scale AI**: 内製 red-team の自動化パートナー
- **AI21**: Jamba 系モデルの safety evaluation

## 自分株式会社での活用
- daily-judgment: AI 回答の hallucination score を Sphynx で事前チェック → 原則 1 (CEO 判断) の信頼性確保
- AI大学: 140 プロバイダーの safety rating 比較ページ生成
- ai-hub: LLM 応答の Cascade-style multi-turn leakage テストを CI に組込
$md$,
    NOW()
  ),
  (
    'haize_labs',
    'models',
    'ACG / Cascade / Sphynx — 3 algorithm 詳解',
    $md$
# ACG / Cascade / Sphynx — 3 algorithm 詳解

## ACG (Accelerated Coordinate Gradient)
- Gradient-based jailbreak 手法の高速化版
- 元手法 GCG (Greedy Coordinate Gradient) を 4x 高速化
- **攻撃成功率 44%** (baseline 手法 ~11% に対して圧倒的)
- 論文: arxiv.org/html/2411.01084v3 "Plentiful Jailbreaks with String Compositions"

## Cascade (multi-turn jailbreak)
- LLM が別 LLM を攻撃する attacker agent 構造
- tree search + prompt optimization heuristics で benign → unsafe へ段階的誘導
- benchmark: Gray Swan RR model / Llama 3 LAT model で Scale AI の人手 red-team を上回る ASR
- 用途: エンタープライズ agent が 10-turn 後に情報漏洩しないか事前検証

## Sphynx (hallucination haizing)
- 既存の hallucination detection model (HDM) を破る敵対事例を自動生成
- OSS: github.com/haizelabs
- 用途: RAG / grounded LLM の hallucination 検出器の robustness 訓練
- 法務・医療・金融などの「hallucination 許されない」領域向け

## Haize Suite (統合プラットフォーム)
- ACG + Cascade + Sphynx を統合した enterprise platform
- 顧客モデル (black-box) に対して attack corpus を自動生成
- **safety rating** を自動算出 → "Moody's for AI" 格付け

## 料金
- enterprise custom (契約ベース)
- self-serve / 無料 tier は未公開 (2026-04 時点)
- OSS (Sphynx + get-haized): Apache 2.0

## Philosophy (Tang 公言 VentureBeat)
> "We think of ourselves as Moody's for AI — an independent entity
> that quantitatively rates models before they're deployed in high-stakes
> settings like healthcare, finance, and legal."
$md$,
    NOW()
  ),
  (
    'haize_labs',
    'api',
    'Sphynx OSS + Haize Suite — 自分株式会社での組込手順',
    $md$
# Sphynx OSS + Haize Suite — 自分株式会社での組込手順

## OSS Sphynx インストール
```bash
git clone https://github.com/haizelabs/sphynx
cd sphynx
pip install -e .
```

## Sphynx で daily-judgment の hallucination 検証
```python
from sphynx import HallucinationHaizer

haizer = HallucinationHaizer(target_model="claude-opus-4-7")

# 自社 docs を ground truth に
ground_truth = open("docs/PHILOSOPHY.md").read()

# AI 回答を検証
candidate_answer = "自分株式会社の 9 原則は CEO 感・ミッション駆動・優しい mentor..."
is_hallucinating, score, adversarial = haizer.haize(
    context=ground_truth,
    claim=candidate_answer,
)

if is_hallucinating:
    print(f"Hallucination detected! score={score}")
    print(f"Adversarial example: {adversarial}")
    # → AI-DEV-23 原則 3 (trace_id + 検出) に組込
```

## get-haized サブセット (公開された jailbreak 事例集)
```python
# Haize Labs が発見した jailbreak 例を学習データに
from datasets import load_dataset
haized = load_dataset("haizelabs/get-haized")

# 自社 ai-hub guardrail の robustness テスト
for example in haized["train"]:
    response = ai_hub.invoke(body={
        "action": "chat.send",
        "messages": [{"role": "user", "content": example["prompt"]}],
    })
    assert not response.contains_harmful_content(), \
        f"Jailbreak via: {example['technique']}"
```

## ai-hub 統合提案 (Win版 cross-instance-pr 候補)
```typescript
// supabase/functions/ai-hub/index.ts に追加
case 'security.red_team_check':
  // candidate_prompt + target_action を受け取り Haize Suite 呼び出し
  // ACG / Cascade / Sphynx の 3 algorithm で attack 試行
  // safety_rating (A-F) を返却 / AI-DEV-23 原則 3 (trace_id + 5秒超検出)
  return await haizeRedTeamCheck(body);

case 'security.hallucination_score':
  // context + claim を受け取り Sphynx で hallucination 検出
  // score + adversarial_example を返却
  return await sphynxHallucinationScore(body);
```

## 試す
- Web: https://haizelabs.com/
- Blog: https://blog.haizelabs.com/
- GitHub: https://github.com/haizelabs
- Cascade blog: https://blog.haizelabs.com/posts/cascade/
- Benchmarks: https://haizelabs.com/benchmarks
- ACG 論文: https://arxiv.org/html/2411.01084v3

## 想定パートナーシップ
- Anthropic との既存関係 → Claude モデル自動 red-team 委託
- Snorkel AI (S21) との補完: Snorkel = data quality / Haize = safety quality
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
