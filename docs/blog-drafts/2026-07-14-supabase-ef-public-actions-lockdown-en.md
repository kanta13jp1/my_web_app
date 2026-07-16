---
title: "That anon Key Is Effectively Public: Closing an Auth Hole in a Supabase Edge Function's publicActions"
tags: supabase, security, deno, buildinpublic
published: false
---

# That anon Key Is Effectively Public: Closing an Auth Hole in a Supabase Edge Function's publicActions

## Intro

While building "Jibun Inc.", a solo Flutter Web + Supabase SaaS, I found and closed an authorization hole in a Supabase Edge Function (Deno). **Write operations — auto-publishing blog posts, posting to X (Twitter), backfilling from external APIs — were callable by anyone, with no authentication.**

The root cause, up front: I was treating the Supabase **anon key** — which ships inside the web app — as if it were a secret. Here's how to find this bug, how to fix it, and importantly, **how to verify the fix in production without any side effects**.

## What was wrong

The Edge Function `schedule-hub` is a "hub" that dispatches on an `action` field. At its entrance was a `publicActions` array that exempts requests from auth.

```typescript
const publicActions = [
  "health.check",
  "blog.recent_posted",   // public read — fine
  "blog.auto_publish",    // ← posts articles with the OWNER's Qiita/dev.to token
  "blog.create",          // ← inserts rows into DB as "system"
  "blog.backfill_from_apis", // ← external fetch + DB insert
  "x.post_with_media",    // ← posts arbitrary tweets from the OWNER's X account
  // ...
];

const serviceRoleRequest = isServiceRoleRequest(req);
let userId: string | null = null;
if (!publicActions.includes(action)) {
  if (!serviceRoleRequest) {
    userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);
  }
}
```

Read-only actions like `health.check` being public is intentional. The problem: **four write actions had slipped into the same list.**

- `blog.auto_publish` — uses the server-side `QIITA_ACCESS_TOKEN` / `DEVTO_API_KEY` to **publish an article with any title and body**.
- `x.post_with_media` — uses the server-side X API credentials to **post any tweet**.
- `blog.create` / `blog.backfill_from_apis` — write rows into `hub_data` as `user_id="system"`.

Being in `publicActions` means they reach their handlers without ever passing `getUserId()` or `isServiceRoleRequest()`.

## Why "anyone" can call it — the anon key misconception

"But you need the Supabase anon key in the `Authorization` header to call an Edge Function, right?" That's exactly the trap.

The Supabase anon key is a **public key meant to be embedded in and shipped with your frontend.** My Flutter Web build (`main.dart.js`) carries the anon key in cleartext. Anyone who opens the app can pull it out via DevTools or by reading the source.

```dart
// lib/main.dart — ends up in the build output in cleartext
await Supabase.initialize(
  url: 'https://<project>.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiI...', // NOT a secret
);
```

The Edge Function's platform JWT check passes with this anon key. So "anon key required = authenticated" is **flatly wrong**; the reality was "any third party who opened the web app can run posts using the owner's credentials." The only thing actually protected by a secret is the `SERVICE_ROLE_KEY` (server-to-server only, never shipped to clients).

## The fix: extract auth levels into pure logic

The fix is simple in principle: **move write actions out of `publicActions` and behind a `SERVICE_ROLE_KEY`-required gate.** But just editing the inline array invites the next stray action to slip in. So I extracted the per-action auth level into a separate module that doesn't depend on the Deno runtime — meaning it's unit-testable as-is.

```typescript
// action_auth.ts — auth levels consolidated into three tiers
export type ActionAuthLevel = "public" | "service_role" | "user";

// No auth (reads or intentional public endpoints only)
export const PUBLIC_ACTIONS: readonly string[] = [
  "health.check",
  "blog.recent_posted",
  "maintenance.list_active",
];

// Requires SERVICE_ROLE_KEY Bearer. Anything that posts with owner
// credentials or writes as "system" lives here.
export const SERVICE_ROLE_ONLY_ACTIONS: readonly string[] = [
  "blog.auto_publish",
  "blog.create",
  "blog.backfill_from_apis",
  "x.post_with_media",
];

export function requiredAuthLevel(action: string): ActionAuthLevel {
  if (SERVICE_ROLE_ONLY_ACTIONS.includes(action)) return "service_role";
  if (PUBLIC_ACTIONS.includes(action)) return "public";
  return "user"; // in neither list => logged-in user JWT required (deny by default)
}
```

The gate at the entrance becomes:

```typescript
const authLevel = requiredAuthLevel(action);
const serviceRoleRequest = isServiceRoleRequest(req);
let userId: string | null = null;

if (authLevel === "service_role" && !serviceRoleRequest) {
  return json({ error: "Unauthorized" }, 401);
}
if (authLevel === "user" && !serviceRoleRequest) {
  userId = await getUserId(req);
  if (!userId) return json({ error: "Unauthorized" }, 401);
}
```

The key is that `requiredAuthLevel` **defaults to `"user"`**. Unless an action is explicitly declared public/service_role, it requires auth — deny by default. This makes "accidentally exposed by forgetting to gate it" structurally unlikely.

Tests are trivial because the decision is a pure function:

```typescript
Deno.test("write actions require service_role", () => {
  for (const a of ["blog.auto_publish", "blog.create", "x.post_with_media"]) {
    assertEquals(requiredAuthLevel(a), "service_role");
  }
});

Deno.test("unknown action requires user JWT (deny by default)", () => {
  assertEquals(requiredAuthLevel("nonexistent.action"), "user");
});
```

## Guaranteeing nothing breaks — auditing every caller

The scariest part of a security fix is plugging the hole but also stopping legitimate traffic. So I **enumerated every real caller** of these four actions.

| Action | Caller | Key sent |
|---|---|---|
| `blog.auto_publish` | `blog-publish.yml` / `batch_publish.py` | `SERVICE_ROLE_KEY` |
| `blog.create` | `blog-publish.yml` | `SERVICE_ROLE_KEY` |
| `blog.backfill_from_apis` | `blog-backfill-from-apis.yml` | `SERVICE_ROLE_KEY` |
| `x.post_with_media` | `post-x-with-media.yml` | `SERVICE_ROLE_KEY` |

Every one is a GitHub Actions workflow, and all send `Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}`. So requiring service-role breaks **zero** legitimate paths. The handlers also null-fallback (`userId ?? "system"`), so responses and DB writes over the service-role path are byte-identical to before.

## Verifying in production with zero side effects

After deploying, I wanted to confirm the hole was really closed — in production. But actually calling `x.post_with_media` **fires a real tweet.** I can't produce side effects just to test. Two techniques solved this.

### 1. Confirm the anon key gets rejected

Using the attacker's exact condition — the anon key baked into the web app — call the write actions and confirm **they return 401.** A 401 means the request never reaches the handler, so no side effects.

```bash
ANON="<anon key that ships in the web app>"
URL="https://<project>.supabase.co/functions/v1/schedule-hub"

for a in blog.create x.post_with_media blog.auto_publish blog.backfill_from_apis; do
  printf "%s -> " "$a"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "$URL" \
    -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
    -d "{\"action\":\"$a\"}"
done
# => all HTTP 401

curl -s -o /dev/null -w "health.check -> HTTP %{http_code}\n" -X POST "$URL" \
  -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"action":"health.check"}'
# => HTTP 200 (public read untouched)
```

### 2. Prove the legit path is alive via a green cron

How do you confirm the service-role path still works? Manually running a workflow would, again, fire a real post.

The trick: **a different, non-public, side-effect-free action that already passes the same gate and succeeds on a daily cron.** This EF has an aggregation action that's also called with `SERVICE_ROLE_KEY` every day and keeps succeeding. If the EF's `SERVICE_ROLE_KEY` env didn't match the GitHub Secret, that cron would fail. It isn't failing → the keys match → the four newly gated actions pass through the same code path. That indirectly guarantees the legit path is healthy — **without emitting any side effects.**

## Lessons

- **The anon key is not a secret.** The moment it ships in a web app, it's effectively public. Never use it as an authorization signal. Only `SERVICE_ROLE_KEY` protects anything.
- **Make allowlists deny-by-default.** "Public only if it's in the array" is weaker than "authenticated unless explicitly declared." The latter resists forget-to-gate accidents.
- **Extract authorization decisions into a pure function.** Decouple from the Deno runtime and you can pin behavior with unit tests.
- **A security fix can be verified with two side-effect-free signals: "it's rejected (401)" and "the legit path is proven alive via a separate green path."**

I rolled this out over three sessions (unify Qiita/dev.to error behavior → lock down the four write actions → final lockdown including Notion-sync and WBS-update actions). In the end, `schedule-hub`'s public surface is just three read-only actions plus one intentionally public, no-login funnel.

As a solo dev it's tempting to defer authorization because "only I call this." But **once the anon key is public, "only I call this" simply isn't true.** If you're writing a hub-style EF, go re-read your `publicActions`-equivalent array.
