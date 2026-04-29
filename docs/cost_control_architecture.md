# Cost Control Architecture

**Status**: Codex#2 implementation, 2026-04-29

## Decision

`task_budget` and `effort_router` are implemented as a paired platform primitive:

- `task_budget` caps spend.
- `effort_router` chooses the default reasoning effort and model family.

They are intentionally deployed together because budget without routing only blocks after waste happens, while routing without budget has no hard stop.

## Scope Hierarchy

Budgets are tracked at four scopes:

| Scope | Example | Default Limit |
| --- | --- | --- |
| `month` | `2026-04` | `$5000` |
| `instance` | `codex2` | `$400` |
| `ef` | `ai-hub` | `$50` |
| `gha` | `memory-search-sync` | `$20` |

`checkBudget(scope, scope_id)` checks the active month, optional instance, and requested scope. `recordSpend(...)` records estimated spend to the same chain.

## Effort Matrix

`effort_config` stores the first routing matrix:

| Action | Effort |
| --- | --- |
| `ai.assistant.chat` | `low` |
| `ai.university.quiz_grade` | `low` |
| `ai.competitor.monitor` | `medium` |
| `ai.daily.judgment` | `high` |
| `ai.cross_instance.routing` | `high` |
| `ai.horse_racing.predict` | `xhigh` |
| `ai.notebooklm.distill` | `xhigh` |
| `memory.rank` | `low` |

`ai-hub` now uses this routing when callers do not explicitly request a tier. Existing explicit tier behavior remains unchanged.

## Reference Integration

`provider.chat_auto` and `edge_llm.invoke` now:

1. select effort,
2. check the `ai-hub` EF budget,
3. execute the provider call,
4. estimate token cost from characters,
5. record spend into `task_budget`.

This is the reference pattern for rollout to other EF actions.
