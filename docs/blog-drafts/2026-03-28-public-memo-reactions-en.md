---
title: "Anonymous Emoji Reactions Without Login: UNIQUE Index Toggle + IP Hash in Supabase"
tags: Flutter,Supabase,buildinpublic,Dart,PostgreSQL
published: true
---

# Anonymous Emoji Reactions Without Login: UNIQUE Index Toggle + IP Hash in Supabase

## The Pattern

[自分株式会社](https://my-web-app-b67f4.web.app/) public memos support emoji reactions — 👍❤️🔥💡🎉 — without requiring a login. Like Medium Claps or Twitter reactions, but with two constraints:

1. One reaction per emoji per IP (no spam-clicking)
2. IP addresses must not be stored (privacy)

Solution: SHA-256 IP hashing + UNIQUE index toggle.

---

## Schema

```sql
CREATE TABLE memo_reactions (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  memo_id    integer     NOT NULL REFERENCES public_memos(id) ON DELETE CASCADE,
  reaction   text        NOT NULL CHECK (reaction IN ('👍','❤️','🔥','💡','🎉')),
  ip_hash    text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- One IP × one emoji × one memo = no duplicates
CREATE UNIQUE INDEX memo_reactions_dedup
  ON memo_reactions (memo_id, ip_hash, reaction);
```

`ip_hash` is `SHA-256(salt + IP).slice(0, 16)` — 16 hex characters. Irreversible: you can't get the original IP from the hash. The salt prevents rainbow table attacks.

RLS is fully open (SELECT/INSERT/DELETE allowed for anon). The Edge Function enforces all limits.

---

## Edge Function: Toggle via UNIQUE Violation

```typescript
const { error: insertErr } = await client.from("memo_reactions").insert({
  memo_id:  memoId,
  reaction: reaction,
  ip_hash:  ipHash,
});

if (insertErr) {
  // UNIQUE violation = user already reacted → toggle off
  await client.from("memo_reactions").delete()
    .eq("memo_id",  memoId)
    .eq("ip_hash",  ipHash)
    .eq("reaction", reaction);
  added = false;
}
```

The UNIQUE index does the deduplication check. No explicit `EXISTS` query needed — just attempt the INSERT and interpret the error. Two network round-trips in the worst case (toggle-off path), one in the best case (new reaction).

GET returns counts + which reactions the current IP has already added:

```
GET /memo-reactions?memo_id=42
→ { reactions: {"👍":3,"❤️":1,"🔥":0,...}, userReactions: ["👍"] }
```

`userReactions` lets the Flutter client highlight which emojis the user already pressed.

---

## Flutter: AnimatedContainer Reaction Bar

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  decoration: BoxDecoration(
    color: active
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: active ? colorScheme.primary : Colors.transparent,
    ),
  ),
  child: Row(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    if (count > 0) Text('$count'),
  ]),
)
```

`AnimatedContainer` interpolates decoration properties — color, border — in 150ms. No `AnimationController` or `Tween` needed. The border appears only when `active: true`, giving the "selected" feel.

`if (count > 0) Text('$count')` — zero-count emojis show no number, keeping the bar uncluttered.

---

## Keeping DB and Dart in Sync

The allowed reactions are defined in two places:

```sql
-- DB CHECK constraint
reaction text NOT NULL CHECK (reaction IN ('👍','❤️','🔥','💡','🎉'))
```

```dart
// Dart list
static const _kAllReactions = ['👍', '❤️', '🔥', '💡', '🎉'];
```

And in the Edge Function:

```typescript
const ALLOWED_REACTIONS = ['👍','❤️','🔥','💡','🎉'];
```

All three must match. If they diverge, the DB constraint rejects inserts that pass the Dart validation. Keep them in a shared config or document the sync requirement explicitly.

---

## CORS for Anonymous Calls

The Edge Function needs permissive CORS since it's called from a browser without auth headers:

```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

if (req.method === 'OPTIONS') {
  return new Response(null, { headers: corsHeaders });
}
```

Every response includes these headers. Missing CORS headers on the OPTIONS preflight is the most common failure point for anonymous (no JWT) Edge Function calls.

---

## Summary

| Decision | Why |
|----------|-----|
| UNIQUE index toggle (not EXISTS check) | One INSERT attempt, error = toggle state |
| IP hash (not IP) | GDPR / privacy — irreversible, no original IP stored |
| Open RLS + EF enforcement | Anon access needs open SELECT/INSERT; EF validates reaction type and IP hash |
| `AnimatedContainer` | Smooth color/border transition with zero boilerplate |

Under 200 lines total. The UNIQUE index pattern is the key insight — it makes toggle logic database-native.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #PostgreSQL
