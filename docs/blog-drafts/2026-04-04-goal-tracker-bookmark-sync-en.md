---
title: "Goal Tracker + Bookmark Sync in One Day: Flutter 3.33 BuildContext Trap & Edge Function First"
tags: Flutter,Supabase,buildinpublic,Dart,webdev
published: true
---

# Goal Tracker + Bookmark Sync in One Day: Flutter 3.33 BuildContext Trap & Edge Function First

## What We Built

Two features shipped in a single session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Goal Tracker** (competing with Notion + Liven) — short/mid/long-term goals with milestones
2. **Bookmark Sync** (competing with Pocket + Instapaper) — URL saving, tag management, read/unread tracking

Both use the same Edge Function First architecture. Both hit the same Flutter 3.33 gotcha.

---

## The Architecture: Edge Function First

All business logic lives in the Supabase Edge Function. Flutter is a thin rendering layer.

```dart
// Flutter: this is all it does
final res = await _supabase.functions.invoke(
  'goal-tracker',
  body: {'action': 'create', 'title': title, 'deadline': deadline},
);
```

The Edge Function handles DB access, validation, and RLS enforcement. Flutter never writes to the DB directly (except RLS-direct tables like scores).

**Why**: Business logic in Dart means it lives on the client, skips server-side validation, and can be bypassed. Logic in a Deno function is server-enforced and testable independently of the UI.

---

## The Bookmarks Schema

```sql
CREATE TABLE bookmarks (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  url        text NOT NULL,
  title      text NOT NULL DEFAULT '',
  tags       text[] DEFAULT '{}',
  is_read    boolean NOT NULL DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- GIN index for fast tag array queries
CREATE INDEX idx_bookmarks_tags ON bookmarks USING GIN (tags);
```

The GIN index on `tags` makes `WHERE tags @> ARRAY['flutter']` fast even at scale. Array columns with GIN beat a junction table for simple tag filtering.

---

## Flutter 3.33: `use_build_context_synchronously` Got Stricter

This was the main debugging session. Flutter 3.33 tightened the `use_build_context_synchronously` rule.

**Before (used to work, now fails)**:

```dart
await _supabase.functions.invoke('goal-tracker', body: {...});
if (!context.mounted) return;
Navigator.of(context).pop();  // ERROR: context used after async gap
```

The error: *"Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check."*

**After (correct pattern)**:

```dart
// Capture context-dependent objects BEFORE the await
final navigator = Navigator.of(context);
final messenger = ScaffoldMessenger.of(context);

await _supabase.functions.invoke('goal-tracker', body: {...});

if (!mounted) return;
navigator.pop();          // No BuildContext reference
messenger.showSnackBar(SnackBar(content: Text('Saved')));
```

**Rule**: Extract `Navigator.of(context)`, `ScaffoldMessenger.of(context)`, and any other context-dependent object *before* any `await`. Use the extracted reference after the async gap, not `context` directly.

---

## Deno: `dart:math` Has No `tanh`

Unrelated but worth documenting: while implementing audio soft-clipping for the guitar recording feature (same session), I reached for `Math.tanh()`. In Dart's `dart:math`, `tanh` doesn't exist.

Manual implementation using the definition:

```dart
import 'dart:math' as math;

double tanh(double x) {
  final e2 = math.exp(2 * x);
  return (e2 - 1) / (e2 + 1);
}
```

This is numerically stable for typical audio values (roughly -10 to 10).

---

## Deno: Don't Declare `const body` Twice

Another gotcha in Edge Functions: HTTP request body is a stream that can only be consumed once.

```typescript
// BUG: body declared twice in the same scope
const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
// ...more code...
const body = await req.json().catch(() => ({})); // Deno lint error + runtime bug
```

Fix: parse the body exactly once at the top of the handler.

```typescript
const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
// Use body throughout, never re-parse
```

---

## Results

| Feature | Competing with | Time to ship |
|---------|---------------|--------------|
| Goal Tracker | Notion, Liven | ~3h |
| Bookmark Sync | Pocket, Instapaper | ~2h |

The Edge Function First pattern keeps the Flutter side light. The main development time goes into the Deno function logic and DB schema, not widget trees.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #webdev
