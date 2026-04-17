---
title: "Scaling Supabase Edge Functions Past the 50-Function Cap: Hub-and-Action Architecture"
tags: Flutter,Supabase,buildinpublic,Dart,architecture
published: false
---

# Scaling Supabase Edge Functions Past the 50-Function Cap: Hub-and-Action Architecture

## The Problem

Supabase's free and Pro tiers have a hard cap of **50 Edge Functions per project**. When building a full-stack app that replaces 21 competitors (notes, tasks, finance, scheduling, AI, horse racing, real estate...), you hit that cap fast.

[自分株式会社](https://my-web-app-b67f4.web.app/) peaked at **99 deployed Edge Functions** before the cap was enforced. Then: 402 errors on every new deployment. The solution wasn't deleting features — it was restructuring.

---

## The Hub Pattern

One EF can route to many independent action handlers. Instead of 50 separate EFs, you get 1 hub EF with 50+ action routes:

```typescript
// tools-hub/index.ts
const body = await req.json();
const { action, ...rest } = body;

switch (action) {
  case 'horseracing.today':       return getHorseRacingToday(supabase);
  case 'horseracing.predict_all': return predictAllRaces(supabase, rest);
  case 'realestate.search':       return searchProperties(supabase, rest);
  case 'realestate.estimate':     return estimatePrice(supabase, rest);
  case 'guitar.analyze':          return analyzeTab(supabase, rest);
  // ... 20 more actions
}
```

One cold start, one CORS config, one deploy step. Zero new EF slots consumed for each new action.

---

## Hub Inventory

Final state: **16 EFs total**, all feature-complete:

| Hub EF | Domain | Actions |
|--------|--------|---------|
| `core-hub` | User management, profile, settings | ~8 actions |
| `growth-hub` | Analytics, CVR, referrals | ~6 actions |
| `ai-hub` | Gemini, Claude, GPT routing | ~10 actions |
| `tools-hub` | Horse racing, guitar, real estate | ~12 actions |
| `lifestyle-hub` | Health, finance, calendar | ~8 actions |
| `schedule-hub` | Cron jobs, reminders | ~5 actions |
| Standalone ×5 | `ai-assistant`, `get-home-dashboard`, etc. | 1 action each |

99 → 16. Every feature still works.

---

## Migration: Old EF → Hub Action

The steps to absorb a standalone EF into a hub:

### Step 1: Add the action handler

```typescript
// In tools-hub/index.ts
case 'guitar.analyze':
  return analyzeGuitarTab(supabase, body);
```

Copy the logic from the old EF's handler into the new function.

### Step 2: Update the Flutter caller

```dart
// Before: called standalone EF
final response = await _supabase.functions.invoke('guitar-recording-studio');

// After: calls hub with action param
final response = await _supabase.functions.invoke(
  'tools-hub',
  body: {'action': 'guitar.analyze', ...params},
);
```

### Step 3: Update CORS handling

The hub needs to handle CORS once, at the top:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

if (req.method === 'OPTIONS') {
  return new Response(null, { headers: corsHeaders, status: 200 });
}
```

Every action response includes these headers — no per-action CORS config needed.

### Step 4: Delete the old EF from deploy-prod.yml

```yaml
# deploy-prod.yml — remove the old standalone entry
functions:
  - guitar-recording-studio  # ← delete this line
  - tools-hub                # ← hub already listed
```

The old EF still exists in `supabase/functions/` as dead code but is no longer deployed. Delete it if you're tidying up.

---

## NO_AUTH Zone Pattern

Some hub actions are called by GitHub Actions cron jobs — no user JWT available. Adding a bypass list keeps cron working without opening the whole hub:

```typescript
const NO_AUTH_ACTIONS = [
  'horseracing.today',       // public race data fetch
  'horseracing.predictions', // public prediction GET
];

if (!NO_AUTH_ACTIONS.includes(action)) {
  // validate JWT here
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return new Response('Unauthorized', { status: 401 });
}
```

Actions in `NO_AUTH_ACTIONS` bypass JWT validation but still require the Supabase service key at the API gateway level. Good balance of security and automation.

---

## Dart: Centralized Hub Caller

To avoid scattering `'tools-hub'` strings across 20 files, a thin wrapper:

```dart
class ToolsHub {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>> call(
    String action, {
    Map<String, dynamic> params = const {},
  }) async {
    final response = await _supabase.functions.invoke(
      'tools-hub',
      body: {'action': action, ...params},
    );
    if (response.status != 200) throw Exception('Hub error: ${response.status}');
    return response.data as Map<String, dynamic>;
  }
}

// Usage:
final data = await ToolsHub.call('horseracing.today');
final result = await ToolsHub.call('realestate.search', params: {'city': 'Tokyo'});
```

One change if the hub EF name ever changes. Type-safe with a `params` map.

---

## What the Hub Pattern Doesn't Solve

**Execution time**: Hub actions share the 30-second Deno timeout. Long-running operations (bulk AI calls, large file processing) need their own EF slot or an async queue pattern.

**Error isolation**: A bug in one action's import can crash the entire hub. Keep handlers in separate files and import them:

```typescript
// tools-hub/handlers/horseracing.ts
export async function getHorseRacingToday(supabase: SupabaseClient) { ... }

// tools-hub/index.ts
import { getHorseRacingToday } from './handlers/horseracing.ts';
```

**Bundle size**: Deno's cold start time scales with bundle size. If 20 handlers import 20 different libraries, cold start gets slow. Group actions by shared dependencies.

---

## Summary

| Problem | Solution |
|---------|----------|
| 50 EF hard cap | Hub-and-action routing (1 EF, many actions) |
| GitHub Actions cron (no JWT) | `NO_AUTH_ACTIONS` bypass list |
| 20 Dart callers with different EF names | `ToolsHub.call(action, params)` wrapper |
| Long-running actions timeout | Keep those on standalone EF slots |

99 deployed EFs → 16. Features: unchanged.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #architecture
