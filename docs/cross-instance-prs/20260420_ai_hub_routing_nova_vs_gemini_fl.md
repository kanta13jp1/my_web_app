# PS#4 → Win版 cross-instance-pr: ai-hub routing — Nova 2 Lite vs Gemini 3.1 Flash-Lite

**起票**: PS版#4 S28 (2026-04-20 夜 last 5)
**宛先**: Win版 (ai-hub / migration / EF cleanup 担当)
**Priority**: 🟡 MEDIUM (cost optimization)
**棄却条件**: (a) Gemini FL preview 期間中の rate limit が production usage に耐えない (b) Nova 2 Lite が次期版で output 50% 以下に値下げ (c) ai-hub の既存 routing がすでに output-bound 用途で Gemini FL 優先になっている

---

## 背景

S28 で軽量 LLM 2 モデルを 16 ソース交差検証。**output 価格に 40% の差** (Nova 2 Lite $2.50/M vs Gemini FL $1.50/M) を発見。

| Model | Input ($/M) | Output ($/M) | Release | 強み |
|---|---|---|---|---|
| Nova 2 Lite | $0.30 | $2.50 | 2025-12-02 | 1M context (Gemini FL 上限不明・調査要) |
| Gemini 3.1 Flash-Lite | $0.25 | $1.50 | preview 2026-03-19 | 2.5x faster TTFT + 45% output speed (Artificial Analysis) |

## 検証ソース

- AWS 公式: `aws.amazon.com/bedrock/pricing` + `aws.amazon.com/nova/pricing`
- Google 公式: `blog.google/innovation-and-ai/models-and-research/gemini-models/gemini-3-1-flash-lite/` + `ai.google.dev/gemini-api/docs/pricing` + `cloud.google.com/vertex-ai/generative-ai/pricing`
- 独立: pricepertoken / sim.ai / caylent / cloudprice / getmaxim / dev.to / benchlm / openrouter / aipricing.guru / eweek / businessanalytics.substack / metacto

## 提案

### A. routing 分割 (短期・推奨)

ai-hub の `provider.chat` action または routing 表で:

```ts
// 用途ベース routing
function selectLightModel(task: 'read' | 'write' | 'chat'): string {
  if (task === 'read') return 'nova-2-lite';   // input-bound (1M context 強み)
  if (task === 'write') return 'gemini-3.1-fl'; // output-bound (40% 安)
  return 'gemini-3.1-fl'; // chat balanced (overall 30% 安)
}
```

### B. default 昇格 (中期・条件付き)

自分株式会社の典型用途は output-bound (AI 大学コンテンツ生成 / blog draft / SCOREBOARD 自動更新):

- **AI 大学コンテンツ追加**: Deep Research → 1 社あたり 2-5K output tokens × 月 30 社 ≈ 100K output → **Gemini FL で月 $0.15** (Nova 2 Lite なら $0.25 = 67% 増)
- **blog 自動化**: 1 記事 1-3K output × 週 5 本 × 4 週 = 60K → Gemini FL $0.09 (Nova $0.15)
- 月間 light-LLM cost 概算: **Gemini FL ≈ $0.30 / Nova 2 Lite ≈ $0.50 → 月 $0.20 削減**

額は小さいが、**[原則 6 (資本=時間)] と [原則 7 (BS 原則)] 整合**で「使わなくても自然に最適化される」状態作り。

### C. 検証要件 (Win版判断)

棄却条件 (a) 検証:
- Gemini FL preview tier の rate limit (現在は free tier 含むが production scale で詰まる可能性)
- 公式 docs `ai.google.dev/gemini-api/docs/rate-limits` 要確認

棄却条件 (b) 検証:
- AWS re:Invent 2026 (12月) または mid-year update で Nova 2 Lite が大幅値下げの噂なし (S28 検索で観測されず)
- 6 月以前の値下げ可能性は低い

棄却条件 (c) 検証:
- 既存 ai-hub `provider.chat` の routing 表 (lib/services/ai_*.dart の `LightProviderResolver` か EF 内 switch) を Win 側で確認

## 実装案 (Win版判断後)

1. ai-hub に `provider.chat` の `task_type` パラメータ追加 (read/write/chat)
2. routing 表に Gemini FL 優先ロジック追加
3. 既存 caller (AI 大学 / blog draft / SCOREBOARD 更新 EF) の呼び出しに `task_type='write'` 追加
4. `ai_quota_usage` で Gemini FL カウント追跡 (rate limit 早期検出)

## Backlinks

- SCOREBOARD §[S28] 数字 2 社交差 audit round 4: `docs/competitor-reports/SCOREBOARD_2026-04-20.md`
- S28 memo: `memory/project_20260420_ps4_s28.md`
- S8 既存 placeholder: `docs/cross-instance-prs/20260420_nova2_lite_integration.md` + `20260420_gemini_flash_lite_migration.md`

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 単価差を構造分析して routing 判断 ✅
- 原則 5 (商品=ユーザー価値): output 速度 2.5x = UX 改善材料 ✅
- 原則 6 (資本=時間): 月 $0.20 削減 = 自動最適化 ✅
- 原則 7 (BS 原則): 単一 vendor 依存 (Anthropic + Nova) → Google 多角化 = リスク資産化 ✅

→ **4/9 ✅** (routing 提案系は判断を Win に委ねるため philosophy 数限定)
