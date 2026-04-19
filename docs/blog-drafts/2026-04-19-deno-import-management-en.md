---
title: "Managing Deno Imports in Supabase Edge Functions — deno.json, Version Pinning, Zero Lint"
tags: Supabase,Deno,TypeScript,buildinpublic,webdev
published: true
---

# Managing Deno Imports in Supabase Edge Functions

## Deno Uses URL-Based Imports

Unlike Node.js, Deno has no `npm install`. Imports are ESM URLs:

```typescript
// Node.js (doesn't work in Deno)
import { createClient } from 'supabase';

// Deno (correct)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
```

## Pin Your Versions

```typescript
// ❌ Unpinned — will break on next major release
import { Hono } from 'https://deno.land/x/hono/mod.ts';

// ✅ Pinned
import { Hono } from 'https://deno.land/x/hono@v4.7.0/mod.ts';
```

The `@latest` alias on `deno.land` resolves dynamically. An unpinned import that works today can silently break tomorrow.

## Centralize with deno.json

Put a `deno.json` in `supabase/functions/` to alias all imports:

```json
{
  "imports": {
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2.49.4",
    "hono": "https://deno.land/x/hono@v4.7.0/mod.ts",
    "hono/cors": "https://deno.land/x/hono@v4.7.0/middleware/cors/index.ts"
  }
}
```

Each Edge Function imports by alias:

```typescript
import { createClient } from '@supabase/supabase-js';
import { Hono } from 'hono';
```

Version upgrades: change one line in `deno.json`, all EFs update.

## Shared Utilities with `_shared/`

Avoid repeating Supabase client initialization in every EF:

```typescript
// supabase/functions/_shared/supabase.ts
import { createClient } from '@supabase/supabase-js';

export function getClient(req: Request) {
  const auth = req.headers.get('Authorization')!;
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: auth } } }
  );
}

export function getAdminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
}
```

## Keep `deno lint` at Zero

`deno lint` runs in CI. Common violations to avoid:

```typescript
// ❌ prefer-const — reassigned never → must be const
let count = 0;

// ✅
const count = 0;

// ❌ no-explicit-any
function process(data: any) {}

// ✅ use unknown and narrow
function process(data: unknown) {
  if (typeof data === 'string') { ... }
}
```

Run after every EF change:

```bash
deno lint supabase/functions/
```

## import_map.json vs deno.json

Older Supabase projects use `import_map.json`. Migrate to `deno.json`:

```bash
mv supabase/functions/import_map.json supabase/functions/deno.json
# Wrap content: { "imports": { ...same content... } }
```

## Summary

| Concern | Solution |
|---------|---------|
| Version drift | Pin with `@x.y.z` in every URL |
| Many EFs same imports | `deno.json` `imports` aliases |
| Repeated client init | `_shared/supabase.ts` utility |
| CI lint failures | `deno lint` after every EF edit |

Good import hygiene means zero "works locally, breaks in CI" surprises.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #Deno #TypeScript #buildinpublic #EdgeFunctions
