---
title: "How I Deploy 36 Supabase Edge Functions via GitHub Actions with 4 Parallel Claude Code Instances"
tags: Supabase,GitHubActions,Flutter,buildinpublic,ClaudeCode
published: true
---

# How I Deploy 36 Supabase Edge Functions via GitHub Actions with 4 Parallel Claude Code Instances

## The Setup

I'm building [自分株式会社](https://my-web-app-b67f4.web.app/) — an AI-integrated life management app — solo. To maximize output, I run **4 Claude Code instances in parallel**:

```
VSCode instance     → lib/ (Flutter frontend)
Web instance        → supabase/functions/ (Edge Functions)
Windows App         → docs/ (migrations, documentation)
PowerShell instance → CI/CD oversight, global coordination
```

Each instance owns its directory and always starts with `git pull --rebase origin main` to prevent merge conflicts.

---

## The Problem: 7 Edge Functions Outside CI/CD

After auditing `deploy-prod.yml`, I found 7 Edge Functions missing from the deploy list — they required **manual deployment**:

- `check-competitor-updates` — checks availability of 21 competitor websites
- `health-check` — DB connection + table availability check
- `analyze-reality` — AI-powered reality check feature
- `trigger-analysis` — election analysis trigger
- `local-election-intelligence` — local election data
- `agent-runtime-cycle` — AI agent periodic cycle
- `get-competitor-monitoring` (new — didn't exist yet)

Manual deployment = forgotten deployments = production/staging drift.

---

## The Fix: Add Everything to `deploy-prod.yml`

```yaml
- name: Deploy Supabase Edge Functions
  run: |
    # Existing functions
    supabase functions deploy reply-support-request --no-verify-jwt
    supabase functions deploy post-x-update --no-verify-jwt
    supabase functions deploy schedule-daily-digest --no-verify-jwt
    # ... (all existing functions)
    
    # Newly added to CI/CD
    supabase functions deploy check-competitor-updates --no-verify-jwt
    supabase functions deploy get-competitor-monitoring --no-verify-jwt
    supabase functions deploy health-check --no-verify-jwt
    supabase functions deploy analyze-reality --no-verify-jwt
    supabase functions deploy trigger-analysis --no-verify-jwt
    supabase functions deploy local-election-intelligence --no-verify-jwt
    supabase functions deploy agent-runtime-cycle --no-verify-jwt
```

Simple fix, but it requires knowing which functions existed. The audit step is the hard part.

---

## The New Function: `get-competitor-monitoring`

I had `check-competitor-updates` (POST: scrapes competitor sites and writes to DB) but no corresponding read endpoint. So I created a companion GET function:

```typescript
// GET /functions/v1/get-competitor-monitoring?days=7&limit=50
serve(async (req) => {
  const url = new URL(req.url);
  const days = parseInt(url.searchParams.get("days") ?? "7", 10);
  const limit = Math.min(
    parseInt(url.searchParams.get("limit") ?? "50", 10),
    100
  );

  const since = new Date(
    Date.now() - days * 24 * 60 * 60 * 1000
  ).toISOString();

  const { data } = await supabase
    .from("competitor_monitoring")
    .select("*")
    .gte("checked_at", since)
    .order("checked_at", { ascending: false })
    .limit(limit);

  // Deduplicate: keep only the latest result per competitor
  const latestByCompetitor: Record<string, CompetitorResult> = {};
  for (const row of data ?? []) {
    if (!latestByCompetitor[row.competitor_key]) {
      latestByCompetitor[row.competitor_key] = {
        key: row.competitor_key,
        name: row.competitor_name,
        available: row.available,
        latency_ms: row.latency_ms,
        checked_at: row.checked_at,
      };
    }
  }

  const competitors = Object.values(latestByCompetitor);
  const available = competitors.filter((c) => c.available).length;

  return new Response(
    JSON.stringify({
      competitors,
      summary: {
        total: competitors.length,
        available,
        availabilityPct: Math.round((available / competitors.length) * 100),
      },
    }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

**Pattern**: write function (POST) + read function (GET) as a pair. Never mix read and write in the same endpoint.

---

## UI Coverage Tracking: `EdgeFunctionSummaryCard`

With 36 Edge Functions, I needed a way to see which ones had UI connections. `edge_function_summary_card.dart` shows a live audit:

```
Edge Functions Status
Total: 36 | With UI: 31 | Without UI: 5 (86%)
```

Functions without UI connections get a warning icon. Clicking "Details" opens `/edge-functions` where you can manually trigger any function and see the response.

This widget runs the `edge-function-audit.yml` GitHub Actions workflow daily, which creates an Issue if any function is orphaned (deployed but no UI path).

---

## The 4-Instance Coordination Rules

Running 4 Claude Code instances in parallel on the same repo requires discipline:

| Rule | Why |
|------|-----|
| Each instance owns one directory | Prevents merge conflicts |
| `git pull --rebase` before every session | Picks up changes from other instances |
| Web instance never touches `lib/` | `flutter analyze` errors should only come from the VSCode instance |
| All instances use the same `COMPRESSED_PROMPT_V3.md` | Shared state across instances without real-time communication |

The `COMPRESSED_PROMPT_V3.md` file is our shared memory: it records which features are implemented, which instance is responsible for what, and what the current counts are (EF count, page count, etc.).

---

## `flutter analyze 0 errors` — Always

With 4 instances modifying code, `flutter analyze` errors can accumulate fast. Our rule: **no instance commits with analyze errors**. The CI pipeline enforces this:

```yaml
- name: Analyze code
  run: flutter analyze --no-pub
  # Fails the entire deploy if there are any errors
```

---

## Results

| Before | After |
|--------|-------|
| 29/36 Edge Functions in CI/CD | 36/36 Edge Functions in CI/CD |
| Manual deploy for 7 functions | Zero manual deployments |
| Production/staging drift possible | `supabase db push` catches migrations on every push |

The takeaway: **an Edge Function that's not in CI/CD is a liability**. It will drift from main, miss migrations, and eventually fail in ways that are hard to debug.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Supabase #GitHubActions #Flutter #ClaudeCode
