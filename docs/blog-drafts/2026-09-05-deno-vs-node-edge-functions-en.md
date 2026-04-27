---
title: "Deno vs Node.js for Edge Functions: What I Learned Running Supabase in Production"
tags: deno,programming,webdev,saas
published: true
---

# Deno vs Node.js for Edge Functions: What I Learned Running Supabase in Production

## The Real Question Behind "Deno vs Node"

Supabase Edge Functions run on Deno. Vercel and Cloudflare Workers run on V8 isolates with Node.js compatibility. AWS Lambda and Google Cloud Functions use Node.js 20+.

The runtime choice is usually made for you by the platform. But understanding the tradeoffs helps you pick the right platform in the first place — and work with Deno's quirks rather than against them.

---

## Runtime Matrix

| Platform | Runtime | npm compatible |
|----------|---------|----------------|
| Supabase Edge Functions | **Deno** | Partial (npm: scheme) |
| Vercel Edge Functions | V8 isolates (Node-compat) | Nearly complete |
| Cloudflare Workers | V8 isolates (Workerd) | Nearly complete |
| AWS Lambda | Node.js 20/22 | Full |
| Google Cloud Functions | Node.js 20/22 | Full |

---

## Deno: Strengths and Weaknesses

### Strengths

**1. Security by Default**

```bash
deno run --allow-net --allow-env index.ts
# No --allow-read = no file system access
```

Network, file system, and environment access all require explicit permission flags. In Supabase Edge Functions this is handled automatically — giving you meaningful isolation with zero extra config.

**2. TypeScript Without Configuration**

```typescript
// No tsconfig.json, no ts-node, no build step
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req: Request): Promise<Response> => {
  const body = await req.json();
  return new Response(JSON.stringify({ ok: true }));
});
```

**3. URL Imports — No node_modules**

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.39.0";
```

No `npm install`, no lockfile churn, no node_modules bloat. Cold starts are faster when there's nothing to read from disk.

**4. Web Standard APIs**

`fetch`, `Request`, `Response`, `ReadableStream`, `WebSocket` — all built in. Closer to browser APIs than Node's `http` module.

### Weaknesses

**1. Native npm Package Compatibility**

```typescript
import sharp from "npm:sharp";       // native binary — may not work
import puppeteer from "npm:puppeteer"; // browser-dependent — won't work
```

Packages with native binaries often fail. If your use case requires image processing (sharp), PDF generation, or browser automation, you'll need Node.js.

**2. Smaller Ecosystem**

Stack Overflow answers, GitHub Issues, and blog posts are a fraction of what exists for Node.js. You'll spend more time debugging from first principles.

**3. Local Dev Learning Curve**

```bash
# Supabase Deno local dev
supabase functions serve ai-assistant --env-file .env.local
```

URL import caching, permission flags, and Deno-specific module resolution add overhead compared to plain Node development.

---

## Node.js: Strengths and Weaknesses

### Strengths

**1. 2M+ npm Packages**

Whatever you need probably exists. Binary dependencies, specialized formats, legacy integrations — all covered.

**2. Information Density**

Documentation, tutorials, Stack Overflow answers — Node wins on volume by a large margin.

**3. Native Module Support**

`sharp`, `pdfkit`, `better-sqlite3` — all work as expected.

### Weaknesses

**1. TypeScript Needs Setup**

```json
{
  "compilerOptions": { "target": "ES2022", "module": "commonjs" }
}
```

Plus ts-node, esbuild, or tsc in your build pipeline.

**2. Loose Security Defaults**

Full file system and network access by default. Supply-chain attacks via npm packages have real impact.

**3. Cold Start at Scale**

Large `node_modules` directories create slow cold starts on Lambda and Cloud Functions — sometimes measured in seconds, not milliseconds.

---

## Why Jibun Kaisha Chose Deno (via Supabase)

1. **Supabase integration** — deepest native support, not an afterthought
2. **Zero-config TypeScript** — no build step between writing and deploying
3. **No binary dependencies** — AI API calls, DB queries, JSON transforms: URL imports cover all of it
4. **Security posture** — multi-user SaaS benefits from EF-level permission enforcement

---

## Deno × Supabase Patterns

### Basic Handler Structure

```typescript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SERVICE_ROLE_KEY")!,
  );

  const body = await req.json();
  // ... process ...

  return new Response(JSON.stringify({ result: "ok" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
```

### Hub Pattern: Multiple Actions, One Function

```typescript
const action = body.action as string;
switch (action) {
  case "support.list":   return await handleSupportList(supabase);
  case "support.reply":  return await handleSupportReply(supabase, body);
  default:
    return new Response(JSON.stringify({ error: "Unknown action" }), {
      status: 400, headers: corsHeaders,
    });
}
```

Jibun Kaisha consolidated 30+ individual functions into `tools-hub`, staying well within Supabase's 50-function limit.

### Error Handling

```typescript
try {
  const result = await riskyOperation();
  return json({ success: true, data: result });
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  console.error("[EF Error]", message);
  return new Response(JSON.stringify({ error: message }), {
    status: 500, headers: corsHeaders,
  });
}
```

---

## Decision Matrix

| Condition | Pick |
|-----------|------|
| Already using Supabase | **Deno** (obvious) |
| Already using Vercel / Cloudflare | **Node-compat** (obvious) |
| Need native npm binaries (sharp, pdfkit) | **Node.js** on Lambda/Cloud Functions |
| Want zero-config TypeScript | **Deno** |
| Need maximum ecosystem coverage | **Node.js** |
| Security / permission isolation matters | **Deno** |

The real decision is **platform first**, not runtime first. "Supabase or Vercel or Cloudflare?" answers the Deno vs Node question automatically.

---

## Summary

As of 2026:

- **If you're on Supabase, embrace Deno** — fighting it costs more than learning it
- **Deno's weaknesses are narrow** — native binaries and ecosystem depth. For AI/DB/HTTP, it's fine.
- **TypeScript native + URL imports + security defaults** are genuine advantages for EF workloads
- **Node.js wins when** you need a specific npm package that requires native compilation

For AI backends on Supabase Edge Functions, Deno is production-ready and the right tool for the job.

---

## Related Posts

- [Supabase Edge Functions + AI: Real Cost Breakdown](./2026-08-22-supabase-edge-functions-ai-cost-en.md)
- [Flutter Web + AI Integration in 2026](./2026-08-29-flutter-web-ai-integration-2026-en.md)
- [litellm: One Gateway for All AI APIs](./2026-08-01-litellm-unified-ai-gateway-en.md)

---

*Jibun Kaisha — integrating the best of 21 competitors into one life management app*  
*Live: https://my-web-app-b67f4.web.app/*
