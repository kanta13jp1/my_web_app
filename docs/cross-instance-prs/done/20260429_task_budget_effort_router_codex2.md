# Done: task_budget + effort_router

**FROM**: Win版 part 74
**TO**: Codex#2
**完了**: 2026-04-29

## 実装

- `supabase/functions/_shared/task_budget.ts`
- `supabase/functions/_shared/effort_router.ts`
- `supabase/migrations/20260429110000_create_task_budget.sql`
- `supabase/migrations/20260429120000_create_effort_config.sql`
- `scripts/check_budget.py`
- `docs/cost_control_architecture.md`
- `docs/PLATFORM_EVOLUTION_PRINCIPLES.md`
- `docs/FLEET_SCALING_ROADMAP.md`

## ai-hub 参照実装

`provider.chat_auto` と `edge_llm.invoke` に次を追加:

- effort selection
- EF budget check
- estimated API cost calculation
- `task_budget` spend recording

## 検証

- `deno check supabase/functions/ai-hub/index.ts` pass
- `python scripts/check_budget.py --scope gha --scope-id local-test --limit 1` pass with local secrets missing warning
