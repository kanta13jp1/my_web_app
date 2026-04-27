---
title: "The Hub Pattern: Keeping Supabase Edge Functions Under 50"
tags: supabase,ai,postgresql,indiedev
published: false
---

# The Hub Pattern: Keeping Supabase Edge Functions Under 50

Supabase Edge Functions have an implicit constraint: there's a practical limit to how many you should deploy. In my project, I've made this explicit as the `[EF-CAP-50]` rule: **50 functions maximum, enforced by CI**.

The pattern that makes this possible is the **hub pattern**.

## The Problem: EF Count Creeps Up

Early in the project, I followed the natural path of one-feature-one-EF:

```
check-competitor-updates
get-competitor-features
update-competitor-pricing
check-competitor-availability
competitor-monitoring-run
...
```

That's 5 functions just for competitor monitoring. At 20 features, you've consumed 20 slots. The trajectory is unsustainable.

## The Hub Pattern: N Features in 1 EF

```typescript
// supabase/functions/admin-hub/index.ts
serve(async (req) => {
  const { action, params } = await req.json();

  switch (action) {
    case 'competitor.check':    return competitorCheck(params);
    case 'competitor.pricing':  return competitorPricing(params);
    case 'competitor.features': return competitorFeatures(params);
    case 'wbs.priority_for_instance': return wbsPriority(params);
    case 'wbs.update_progress': return wbsUpdateProgress(params);
    default:
      return new Response('Unknown action', { status: 400 });
  }
});
```

One `admin-hub` EF handles multiple actions. Features grow; the EF count doesn't.

## Current Hub Structure

| Hub EF | Actions handled |
|---|---|
| `admin-hub` | competitor.check / pricing / features / wbs.* |
| `schedule-hub` | digest.run / daily.report / cs.check |
| `ai-hub` | judgment.get / horse.predict / writing.assist |
| `tools-hub` | wbs.priority_for_instance / wbs.update_progress / notify.* |

Four hubs handle ~35 actions. If each action were a separate EF, that would be 35 functions. Instead: **4**.

## Type-Safe Action Routing

```typescript
// _shared/action-types.ts
type AdminHubAction =
  | 'competitor.check'
  | 'competitor.pricing'
  | 'competitor.features'
  | 'wbs.priority_for_instance'
  | 'wbs.update_progress';

type AdminHubRequest = {
  action: AdminHubAction;
  params: Record<string, unknown>;
};
```

TypeScript union types catch misspelled action names at compile time.

## CI Enforcement: EF-CAP-50

```yaml
# .github/workflows/ef-audit.yml
- name: Count Edge Functions
  run: |
    EF_COUNT=$(ls supabase/functions/ | grep -v '_shared' | wc -l)
    echo "EF count: $EF_COUNT"
    if [ "$EF_COUNT" -gt 50 ]; then
      gh issue create \
        --title "EF-CAP-50 violated: $EF_COUNT functions" \
        --body "Add to existing hub instead of creating new EF"
      exit 1
    fi
```

PRs that push EF count over 50 automatically generate a GitHub Issue and fail CI.

## Deny-by-Default: Security Through Explicit Allowlists

A critical piece of the hub pattern: **new actions are denied by default**.

```typescript
const ALLOWED_ACTIONS = new Set([
  'competitor.check',
  'competitor.pricing',
  // only explicitly permitted actions work
]);

if (!ALLOWED_ACTIONS.has(action)) {
  return new Response(
    JSON.stringify({ error: 'Action not permitted' }),
    { status: 403 }
  );
}
```

This is the same principle as MCP server security (principle of least privilege): no action is available unless it's been explicitly reviewed and added.

## EF Count Over Time

| Phase | EF Count | Notes |
|---|---|---|
| Initial (one-EF-per-feature) | 23 | Natural growth |
| After hub migration | 15 | 7 competitor EFs → 1 hub |
| Today | **18** | 50+ features absorbed as hub actions |

Features went from 23 → 50+. EF count went from 23 → **18**.

## The Mental Model

The hub pattern works because there are two different kinds of boundaries in the system:

- **EF boundaries** = domain boundaries (competitor, scheduling, AI, tools)
- **Action boundaries** = feature boundaries (check, pricing, features, predict)

EFs grow with domains (which are stable). Actions grow with features (which keep growing). Separate the two, and you stop paying the EF cost for every new feature.

**The rule of thumb**: if the new feature belongs to an existing domain, add it as an action. Only create a new EF when you're adding an entirely new domain.
