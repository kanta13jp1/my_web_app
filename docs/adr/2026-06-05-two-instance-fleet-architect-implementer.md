# ADR: 2-instance fleet — Architect + Implementer 役割分担

Date: 2026-06-05
Status: Accepted

> 注: 12→2 instance 移行 ([`../FLEET_2_INSTANCE_TRANSITION.md`](../FLEET_2_INSTANCE_TRANSITION.md))
> で確定済の運用判断を、ADR 運用開始 (part 241) にあわせて backfill 記録したもの。

## Context

複数の AI コーディングツール (Claude Code / Codex / Gemini / Copilot 等) が利用可能だが、
かつての 12-instance 体制 (PS#1-6 / VSCode / WEB / mobile / Codex 複数) は:

- 担当の重複と作業衝突 (= 同一 file / migration / EF の並行編集)
- merge コンフリクトと「誰が何を持っているか」の不透明化
- 通信・調整オーバーヘッドの増大

を生んでいた。明確なオーナーシップで衝突を減らす必要があった。

## Decision

アクティブ instance を **2 つ** に絞り、役割を分ける ([INSTANCE-ROLES]):

- **Win Claude (Architect / L3)**: 設計・docs・memory・UI design・triage・AI 大学・競合分析・
  mobile UAT・動画。**本 ADR 運用自体もこのレーンの成果物**。
- **Win Codex (Implementer / L2)**: 実装・修正 PR・SQL・Edge Function (Deno)・GHA・
  T-1 dispatch・競馬・Karpathy Compile/Lint。

振り分けは 5 質問マトリクス (`docs/CODEX_WORKFLOW.md` §6) で判定: **1 つでも YES → Win Claude /
全 NO → Win Codex**。各 instance は別 worktree で作業し main 直接編集は禁止 ([WORKDIR-ISOLATION])。
旧 12 instance は dormant。

## Consequences

- オーナーシップが明確になり、重複作業と clobber が構造的に減る。
- Architect (設計/handoff) → Implementer (実装) の **Architect-Implementer パターン**
  ([`../AGENT_ORCHESTRATION_PATTERNS.md`](../AGENT_ORCHESTRATION_PATTERNS.md) ③) が標準フローになる。
- worktree 分離により並行 push でも互いの作業を壊さない ([REBASE] / [STASH-SAFETY] と整合)。
- Claude Code quota 超過時は Codex CLI / Gemini / Copilot に fallback できる
  ([`../AI_FALLBACK_RUNBOOK.md`](../AI_FALLBACK_RUNBOOK.md))。
- トレードオフ: 2 instance に絞ったぶん、瞬間的な並列度は下がる。スループットより
  「衝突しない・追える」を優先する判断。

## Links

- 運用 docs: [`../MULTI_INSTANCE_FLEET.md`](../MULTI_INSTANCE_FLEET.md) /
  [`../FLEET_2_INSTANCE_TRANSITION.md`](../FLEET_2_INSTANCE_TRANSITION.md) /
  [`../AI_DRIVEN_DEV_OPERATING_MODEL.md`](../AI_DRIVEN_DEV_OPERATING_MODEL.md)
- 運用ルール: [INSTANCE] / [INSTANCE-ROLES] / [WORKDIR-ISOLATION] (= inject-rules.txt)
