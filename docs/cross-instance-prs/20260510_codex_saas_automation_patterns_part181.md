# Codex Hand-off: SaaS Automation Patterns (Issue #1783)

**Source spec**: `docs/SCHEDULE_TASKS.md` §SaaS Operations Automation Patterns (= part 181 新設)
**期限**: 2026-05-24 | **Codex 完全案件** ([INSTANCE-ROLES] 5 質問 0/5 YES)

## Why now

NotebookLM ノートブック `9b8885ef` "Automating SaaS Operations with Claude Code Schedule" 蒸留. 既存 15 schedule workflow の gap 監査結果:

- **P2 multi-AI fallback chain**: 0/15 ✅ (= 完全 gap)
- **P3 self-heal recovery**: 1/15 ✅ (= ほぼ gap)
- **P5 task_budget throttling**: 0/15 ✅ (= 完全 gap)

ユーザー quota 危機 (= AI rate limit / cost 暴走) リスク + automation 信頼性低下リスク → 5 月中対処要.

## 実装スコープ (3 ファイル新設 + 既存 workflow 統合)

### A. `scripts/ai_fallback_invoke.sh` 新設

```bash
#!/usr/bin/env bash
# Usage: ai_fallback_invoke.sh <task_name> <prompt_file> <output_file>
# Tries: claude → codex → gemini (順)
# 各失敗 trace_id 付き log / 最終失敗時のみ exit 1
```

詳細: `docs/SCHEDULE_TASKS.md` §A.5.1

### B. recovery workflow template (3 件)

1. `.github/workflows/daily-report-recovery.yml`
2. `.github/workflows/cs-check-recovery.yml`
3. `.github/workflows/competitor-monitoring-recovery.yml`

template skeleton: `docs/SCHEDULE_TASKS.md` §A.5.2

### C. `scripts/budget_check.sh` 新設

既存 `supabase/functions/_shared/task_budget.ts` を CLI helper 化. 全 AI workflow の先頭で短絡.

詳細: `docs/SCHEDULE_TASKS.md` §A.5.3

## 受け入れ条件

- [ ] `scripts/ai_fallback_invoke.sh` 実装 + daily-report で実証
- [ ] 3 recovery workflow ship + 失敗 simulation 動作確認
- [ ] `scripts/budget_check.sh` 実装 + 全 AI workflow integration
- [ ] 1-week 観測後 gap 監査表更新 (P2: 0→3+ / P3: 1→4+ / P5: 0→5+)
- [ ] PR コメントで KPI: automation_fail_rate_7d / recovery_success_rate_7d / budget_block_count_7d / mttr_p95

## 参考

- 正本: `docs/SCHEDULE_TASKS.md` §SaaS Operations Automation Patterns
- 既存 helper: `supabase/functions/_shared/task_budget.ts` + `_shared/AiQuotaGuard`
- 既存 workflow audit: `.github/workflows/{daily-report,cs-check,competitor-monitoring}.yml`
- AI fallback: `docs/AI_FALLBACK_RUNBOOK.md`

## Workdir 注意 ([WORKDIR-ISOLATION])

- `scripts/` + `.github/workflows/` 編集は worktree (`.claude/worktrees/instance-codex`) 経由必須.
- `supabase/functions/_shared/task_budget.ts` 変更時は EF deploy 順序注意 (= EF-CAP-50 維持).
