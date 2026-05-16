# AI Orchestration 5 パターン (= sub-agent 編成思想)

> Win版#132 part 221u (2026-05-17): SNS で流通する 5 pattern (= Anthropic 2026-05 multi-agent / Outcomes Loop / Architect-Implementer Split / Memory + Dreaming / Phased Preamble) を本プロジェクト用に codify.
> 既存 [`docs/AGENT_COORDINATION_PATTERNS.md`](AGENT_COORDINATION_PATTERNS.md) と並列軸: **coordination = 内側 / 通信規約 / 5 パターン** / **orchestration = 外側 / 編成図 / 5 パターン**.

## TL;DR (= 1 行)

「プロンプトは "1 人の AI への指示" じゃない. **"AI チームの編成図"** を渡すこと.」

## 5 パターン早見表

| パターン | 採用基準 | 本プロジェクトでの dogfood 実例 |
| --- | --- | --- |
| **① Sub-Agent Orchestration** (リード司令官 + 専門 sub-agent) | リサーチ・分析を複数視点で並列処理 / 各 agent に独立 context + 指示書 | Claude Code `Agent` tool (= Plan / Explore / claude-code-guide / general-purpose) を **1 turn で複数 spawn** / 例: 競合 21 社調査を 4 agent 並列 (= ① ファクト ② 競合分析 ③ 構成 ④ 批評) → 最終統合 |
| **② Outcomes Loop** (評価者 AI で本体出力を採点) | 品質ゲート明文化可能 / rubric 定義済 | 既存 `claude-agent-review.yml` (= Generator-Verifier の orchestration 版) / 部 221u で `check_minimal_e2e_gate.py` + `check_high_risk_ultrareview_gate.py` が **deterministic rubric 評価者** として機能 / 80 点未満は body 差し戻し |
| **③ Architect-Implementer Split** (設計役 + 実装役を別 session で完全分離) | 大規模 feature 設計 + 実装 / 設計と実装の concerns 分離 | 2-instance fleet 自体が impl (Win Claude = architect/design/docs / Win Codex = implementation/PR/SQL) / `docs/CODEX_WORKFLOW.md` 5 質問 matrix で振分 |
| **④ Memory + Dreaming** (過去 session ログを夜間レビューして失敗パターン自動学習) | 反復タスク / 失敗 mode が累積する状況 | `memory/` + NotebookLM Master Brain + `consolidate-memory` skill + 月 1 cleanup cron / 既存 `feedback_correction_*` ファイルが **失敗パターン学習データ** / part 221u で gh rerun caveat = **新規 learning entry** |
| **⑤ Phased Preamble Prompting** (① 受領確認 → ② 計画提示 → ③ ユーザー承認 → ④ 実行 の 4 フェーズ強制) | 暴走防止 / scope creep 抑止 / user check point 必須 | 本 docs 自体が pattern ⑤ dogfood (= 部 221u で AskUserQuestion 経由で計画提示+承認後 ship) / `[NO-SCOPE-CREEP]` rule と相補 |

## 新タスク設計フロー (= AGENT_COORDINATION_PATTERNS と相補)

```text
[STEP 1: 編成判断 (= orchestration / 本 doc)]
複数視点並列で品質改善余地? → ① Sub-Agent Orchestration
↓ No
品質 rubric 明文化可能? → ② Outcomes Loop
↓ No
設計と実装を別 AI で並走? → ③ Architect-Implementer Split
↓ No
反復タスクで失敗 mode 累積? → ④ Memory + Dreaming
↓ Always
暴走/scope creep 抑止が必要? (= 新機能・大規模変更) → ⑤ Phased Preamble Prompting MUST

[STEP 2: 通信判断 (= coordination / AGENT_COORDINATION_PATTERNS.md)]
↓ Generator-Verifier / Orchestrator-Subagent / Agent Teams / Message Bus / Shared State
```

**推奨 default**: 新機能着手時は **⑤ Phased Preamble Prompting** を MUST (= ① 受領 → ② plan → ③ ask → ④ execute). 単純タスクは省略可だが、大規模変更・新機能 ship は強制.

## 各パターン詳細

### ① Sub-Agent Orchestration (= 並列専門 agent)

**コピペ用テンプレート**:
> あなたはリード司令官. このリサーチ案件を ① ファクト調査役 ② 競合分析役 ③ 構成設計役 ④ 批評役 の 4 つに分解し、各役に独立した context と指示書を渡し、最終出力を統合せよ.

**dogfood 起動例** (= Claude Code Agent tool):
```
Agent(description="競合 21 社比較", subagent_type="general-purpose", prompt="...")
Agent(description="UI design critique", subagent_type="design-skills", prompt="...")
Agent(description="codebase exploration", subagent_type="Explore", prompt="...")
```

**1 turn 並列 spawn**: 複数 `Agent` tool call を **同一 message で発行** (= 並列実行 / 直列より大幅高速).

**verify status** ✅ **VERIFIED** (= 部 221u sub-agent web research / 2026-05-17):
- Anthropic Claude Managed Agents 2026-05-06 public beta released → [Anthropic blog](https://claude.com/blog/new-in-claude-managed-agents)
- 90.2% metric verified (= Claude Opus 4 lead + Sonnet 4 subagents vs single Opus 4 / breadth-first queries) → [Anthropic engineering](https://www.anthropic.com/engineering/multi-agent-research-system)
- Netflix production use confirmed → [Netflix webinar](https://www.anthropic.com/webinars/scaling-ai-agent-development-at-netflix)
- Harvey 6x improvement confirmed (= multi-agent orchestration context).

### ② Outcomes Loop (= 評価者 AI で採点 + 差し戻し)

**コピペ用テンプレート**:
> ルーブリックを定義し、評価者 AI として本体出力を 100 点満点で採点、80 点未満なら具体的修正指示を書き出し再生成.

**dogfood 起動例**:
- `claude-agent-review.yml` (= PR 生成 → Claude レビュー で deterministic gate)
- `check_minimal_e2e_gate.py` (= PR body rubric: 3 declaration / app code change / exception reason)
- `check_high_risk_ultrareview_gate.py` (= 5 perspectives + unresolved 0 rubric)

**verify status** ⚠️ **PARTIALLY VERIFIED** (= 部 221u sub-agent web research):
- Outcomes Loop 公式 release 2026-05-06 確認 ✅ → [Anthropic Managed Agents](https://claude.com/blog/new-in-claude-managed-agents)
- 一般的な +10pt 改善 (= 全体タスク成功率) は Anthropic 公式 ✅ → [Anthropic engineering](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- **PowerPoint +10.1% / docx +8.4% 個別数値は不検出** (= fabricated or unofficial source)
- Wisedocs ケースで document review time -50% は確認 ✅ → [VentureBeat](https://venturebeat.com/orchestration/claude-codes-goals-separates-the-agent-that-works-from-the-one-that-decides-its-done)
- 本 project 既存 Generator-Verifier (= AGENT_COORDINATION_PATTERNS) と同根.

### ③ Architect-Implementer Split (= 設計 + 実装 分離)

**コピペ用テンプレート**:
> 構成設計役として ① 読者ペルソナ ② 訴求軸 ③ 見出し構成 ④ 各見出しの狙い を 1000 字で設計せよ. 執筆は別エージェントが次セッションで行う.

**dogfood 起動例**:
- 2-instance fleet 自体 (= Win Claude architect / Win Codex implementer)
- Codex 振分 5 質問 matrix (= `docs/CODEX_WORKFLOW.md` §6)
- 文書生成: Plan agent で骨子 → main session で本文
- Issue → PR: Win Claude で triage + spec → Win Codex で impl

**verify status** ⚠️ **PARTIALLY VERIFIED** (= 部 221u sub-agent web research):
- パターン原理は実在 ✅ (= [Rishi Baldawa blog](https://rishi.baldawa.com/posts/architect-implementer-split/) 等で論じられる)
- **「GPT-5.3-Codex 公式標準」claim は不検出** (= OpenAI 公式 prompting guide に "Architect-Implementer Split" 名称なし / fabricated label)
- Harvey Agent Builder の partner-model planning + subagent delegation は確認 ✅ → [Harvey Agent Builder](https://www.harvey.ai/blog/introducing-agent-builder)
- **「Harvey 6x」具体数値は Architect-Implementer Split に直接紐づかず** (= multi-agent orchestration 全体の数値)
- 本 project 2-instance fleet で先行実装済 (= adoption rationale は SNS claim 不要).

### ④ Memory + Dreaming (= 過去 session 夜間 review + 自動学習)

**コピペ用テンプレート**:
> 過去 30 session のログから頻出失敗パターンを抽出し、明日以降のシステムプロンプトに反映する設計を提案せよ.

**dogfood 起動例**:
- `memory/MEMORY.md` (= active session log / [[wikilink]] index)
- `memory/feedback_correction_*` (= 失敗 pattern absolute keep)
- `consolidate-memory` skill (= 月 1 cleanup / Distyl 500 rule limit 内 維持)
- NotebookLM `jibun-master-brain` (= 長期記憶 / cross-session brain)
- `~/.claude/hooks/inject-rules.txt` (= 学習 → 毎 turn inject)

**例**: 部 221u gh rerun caveat 発見 → `project_20260516_win132_part221u.md` 記録 → 部 222+ inject candidate / PR body checklist 6 項目 codify 候補.

**verify status** ✅ **VERIFIED** (= 部 221u sub-agent web research):
- Anthropic Dreaming 研究 preview 2026-05-06 release 確認 ✅ → [VentureBeat](https://venturebeat.com/technology/anthropic-introduces-dreaming-a-system-that-lets-ai-agents-learn-from-their-own-mistakes)
- 夜間自動 review + pattern 抽出 + 自己 memory 書き換えで性能改善 = Anthropic 公式 mechanism ✅ → [Let's Data Science writeup](https://letsdatascience.com/blog/anthropic-dreaming-claude-managed-agents-self-improving-may-6)
- Harvey の session 越し記憶活用 = Dreaming context で確認 ✅
- 本 project では NotebookLM + memory + Karpathy 4 cycle (= Ingest/Compile/Lint/Query) で類似実装済.

### ⑤ Phased Preamble Prompting (= 4 phase 強制)

**コピペ用テンプレート**:
> 実行前に必ず ① 1 文で受領確認 ② 1-2 文で計画提示 ③ ユーザー承認 ④ 着手 の順序を厳守せよ.

**dogfood 起動例**:
- 大規模 ship (= 47 issue 起票 / 5 doc 新規 / sub-agent 解禁) は MUST
- AskUserQuestion tool で ③ 承認質問 を強制
- `[NO-SCOPE-CREEP]` rule との相補 (= scope 拡大時に user check point 強制)
- 本 docs 自体の ship (= 部 221u) が dogfood 第 1 例

**verify status** ❌ **NOT VERIFIED** (= 部 221u sub-agent web research):
- **「GPT-5.3-Codex 公式 4-phase 標準」claim は完全 fabricated** (= OpenAI 公式 prompting guide で 4-phase + 日本語 label = 存在せず)
- OpenAI GPT-5.3-Codex docs は **2-phase** (= `commentary` + `final_answer` parameter で early stop 防止) のみ確認 → [OpenAI Codex Prompting Guide](https://developers.openai.com/cookbook/examples/gpt-5/codex_prompting_guide)
- 4-phase + 日本語 label (= 受領確認 / 計画提示 / ユーザー承認 / 実行) は SNS Twitter 経由の **未検証 fabricated standard**
- **但しパターンとしての価値は別** = [NO-SCOPE-CREEP] rule + AskUserQuestion tool 強制 + 本 doc で **本 project 独自標準化** (= SNS claim 不要 / 内部 rationale: 暴走防止 + scope creep 抑止 + user check point).

## Verify 結果 (= [AI-TOOL-VERIFY] 順守 / 部 221u sub-agent web research)

| Pattern | Verify status | Detail |
|---------|---------------|--------|
| ① Sub-Agent Orchestration | ✅ **VERIFIED** | Anthropic 2026-05-06 release / 90.2% metric / Netflix + Harvey prod すべて公式確認 |
| ② Outcomes Loop | ⚠️ **PARTIAL** | release + 一般 +10pt 改善は ✅ / **PowerPoint +10.1% + docx +8.4% 個別数値は fabricated** |
| ③ Architect-Implementer Split | ⚠️ **PARTIAL** | パターン原理 ✅ / **「GPT-5.3-Codex 公式標準」label は fabricated** / Harvey 6x は orchestration 全体の数値 |
| ④ Memory + Dreaming | ✅ **VERIFIED** | Anthropic Dreaming 2026-05-06 release / 夜間 review + self-memory rewrite すべて公式確認 |
| ⑤ Phased Preamble Prompting | ❌ **NOT VERIFIED** | **「GPT-5.3-Codex 公式 4-phase 日本語 label 標準」は完全 fabricated** / OpenAI 公式は 2-phase のみ |

**Lesson**: SNS で流通する AI tooling claim は **半分以上が verify 不能 or fabricated**. 採用判断は:
1. **公式 release URL** 直接確認 (= claim 4 中 2 のみ ✅)
2. **本 project 既存実装との対応関係** 優先 (= 2-instance fleet / NotebookLM / Generator-Verifier / [NO-SCOPE-CREEP] rule)
3. **パターン原理は採用可** / **数値・「公式」label は cautious citation** (= 「unverified」明示)
4. 本 doc の orchestration 5 pattern は **adoption rationale が内部一貫** (= verify 結果に関わらず本 project に有益) → ship 適切.

## 関連

- [`docs/AGENT_COORDINATION_PATTERNS.md`](AGENT_COORDINATION_PATTERNS.md) — 5 協調 pattern (= 通信規約軸)
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](AI_FLEET_SYNERGY_PLAYBOOK.md) — fleet 7 原則
- [`docs/MULTI_INSTANCE_FLEET.md`](MULTI_INSTANCE_FLEET.md) — 2 instance fleet
- [`docs/CODEX_WORKFLOW.md`](CODEX_WORKFLOW.md) — Codex 振分 5 質問 matrix
- [`docs/AI_FALLBACK_RUNBOOK.md`](AI_FALLBACK_RUNBOOK.md) — quota 超過時 fallback
- [`docs/NOTEBOOKLM_GUIDE.md`](NOTEBOOKLM_GUIDE.md) — Master Brain (= ④ Memory + Dreaming 実装)
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
