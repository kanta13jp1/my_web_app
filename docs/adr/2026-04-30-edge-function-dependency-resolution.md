# ADR: Supabase Edge Function Dependency Resolution

Date: 2026-04-30
Status: Accepted

## Context

Production deploys failed repeatedly while bundling Edge Functions because Deno
resolved `https://esm.sh/@supabase/supabase-js@2` through esm.sh and received
HTTP 522. The application code was not the failing surface; the deploy pipeline
was relying on a remote CDN resolution path that had already failed in earlier
incidents.

## Decision

Supabase Edge Functions must import Supabase JS with:

```ts
import { createClient } from "npm:@supabase/supabase-js@2";
```

Do not add new Edge Function imports from
`https://esm.sh/@supabase/supabase-js@2`. CI runs
`scripts/check_edge_function_imports.py` to block regressions.

The production deploy workflow also retries `supabase functions deploy` up to
three times. Retry is a safety net for transient platform/network failures, not
the primary dependency strategy.

Dependency maps live in `supabase/functions/deno.json` via `imports`. Do not
reintroduce the legacy root `import_map.json` fallback, because recent Supabase
CLI output warns that import-map flags are deprecated for function deploys.

## Consequences

- Edge Function deploys no longer depend on esm.sh for Supabase JS.
- Deploy logs avoid the deprecated root import-map fallback path.
- CI turns a recurring operational incident into a deterministic failure before
  merge.
- New Edge Functions should be added to existing hubs where possible and should
  reuse the same `npm:` import rule.
