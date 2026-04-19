---
title: "Keeping Supabase Edge Functions Under 50 — The Hub Integration Architecture"
tags: Supabase,Flutter,buildinpublic,architecture,webdev
published: true
---

# Keeping Supabase Edge Functions Under 50

## Why the 50-Function Limit Matters

Supabase enforces a **deploy limit** on Edge Functions. The free plan is strict; even paid plans aren't unlimited.

The practical response: treat it as a hard cap and build your architecture around it.

```yaml
# deploy-prod.yml — checked before every deploy
- name: Check Edge Function deploy count
  run: |
    count=$(ls supabase/functions/ | wc -l)
    if [ "$count" -gt 50 ]; then
      echo "❌ EF count exceeds limit: ${count}"
      exit 1
    fi
    echo "✅ EF count: ${count}/50"
```

CI fails the deploy if you exceed 50. The constraint is enforced automatically.

## The Hub Pattern: Multiple Actions in One Function

```
# ❌ One EF per feature → count explodes
get-user-profile/
update-user-profile/
delete-user-profile/
get-user-settings/
update-user-settings/

# ✅ Hub with action dispatch
core-hub/  ← single endpoint, action param selects behavior
```

```typescript
// core-hub/index.ts
const { action, ...params } = await req.json();

switch (action) {
  case "user.get_profile":    return getUserProfile(params);
  case "user.update_profile": return updateUserProfile(params);
  case "user.delete":         return deleteUser(params);
  case "settings.get":        return getSettings(params);
  case "settings.update":     return updateSettings(params);
  default:
    return new Response(JSON.stringify({ error: "unknown action" }), { status: 400 });
}
```

One EF handles multiple actions → add features without adding functions.

## Current Hub Layout (16 Functions)

| EF | Example actions |
|----|----------------|
| `core-hub` | user, settings, notifications |
| `growth-hub` | goals, habits, streaks |
| `ai-hub` | tags.suggest, notes.bulk_summarize, notes.balance_review |
| `admin-hub` | users, analytics, reports |
| `app-hub` | dashboard, features, releases |
| `schedule-hub` | reminders, reports, digests |
| `tools-hub` | search, export, import |
| `media-hub` | upload, resize, cdn |
| `enterprise-hub` | teams, roles, billing |
| `social-commerce-hub` | posts, likes, products |
| `lifestyle-hub` | health, finance, calendar |
| standalone × 5 | dedicated single-purpose functions |

**Total: 16 / 50** — 34 slots remaining.

## Decision Flow for New Features

```
New feature needed →
  Can it be an action in an existing hub?
    Yes → add action (EF count unchanged)
    No  → consolidate existing EFs to free a slot → create new EF
```

```bash
# Check current EF count
ls supabase/functions/ | wc -l

# If approaching 50: identify consolidation candidates
ls supabase/functions/ | grep -v hub | head -20
# Standalone EFs are prime candidates for hub migration
```

## Flutter Side: Calling the Hub

```dart
// All AI features go through ai-hub
Future<List<String>> _suggestTags(String text) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {'action': 'tags.suggest', 'text': text},
  );
  return List<String>.from(response.data['tags'] ?? []);
}

Future<List<Map>> _bulkSummarize(List<Note> notes) async {
  final response = await Supabase.instance.client.functions.invoke(
    'ai-hub',
    body: {
      'action': 'notes.bulk_summarize',
      'notes': notes.map((n) => {'id': n.id, 'content': n.content}).toList(),
    },
  );
  return List<Map>.from(response.data['summaries'] ?? []);
}
```

One endpoint to remember: `ai-hub`. The `action` parameter selects the behavior.

## Hub vs Individual EFs

| | Hub | Individual EF |
|--|-----|---------------|
| Function count | Low | Grows with features |
| Deploy scope | Full hub redeploys | Per-function |
| File size | One large file | Small, isolated |
| Debugging | Need to identify action | Endpoint is obvious |
| Adding features | Just add an action | Requires new EF slot |

For indie/solo development, **hub consolidation wins**. Large teams might prefer individual EFs for ownership separation.

## The Constraint as Architecture

The 50-function cap functions as a design discipline. Every time a new feature appears, the question becomes: "does this actually need its own EF?"

Most of the time, the answer is no. The constraint keeps the codebase consolidated and the deploy count healthy.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #Flutter #buildinpublic #architecture
