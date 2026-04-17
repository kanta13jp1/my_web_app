---
title: "From 94 to 15 Supabase Edge Functions: Hub Architecture + CORS Fix Pattern"
tags: Flutter,Supabase,buildinpublic,architecture,devops
published: true
---

# From 94 to 15 Supabase Edge Functions: Hub Architecture + CORS Fix Pattern

## The Problem: Hitting the 99-Function Wall

Supabase caps Edge Functions at 99 per project. After months of adding one function per feature, [自分株式会社](https://my-web-app-b67f4.web.app/) reached 94. The solution: action-based hub integration.

---

## The Action-Based Hub Pattern

Instead of one function per feature, one hub function handles many related features via an `action` field:

```typescript
// growth-hub/index.ts
serve(async (req: Request) => {
  const body = await req.json();
  const action = body.action as string;

  switch (action) {
    case "referral.list":     return handleReferralList(admin, userId);
    case "referral.create":   return handleReferralCreate(admin, userId, body);
    case "acquisition.track": return handleAcquisitionTrack(admin, userId, body);
    case "roadmap.progress":  return handleRoadmapProgress(admin, userId);
    // ... 16 actions total
  }
});
```

Dart side:

```dart
// OLD (deprecated function)
await client.functions.invoke('growth-referral',
  body: {'action': 'get_code'});

// NEW (hub + action name)
await client.functions.invoke('growth-hub',
  body: {'action': 'referral.list'});
```

---

## Final Hub Architecture (15 Functions)

```text
Standalone (4):
  get-home-dashboard
  ai-assistant
  guitar-recording-studio
  local-election-intelligence

Macro-hubs (6):
  core-hub       — notifications, notes, feedback, achievements
  growth-hub     — referrals, acquisition, roadmap progress
  ai-hub         — AI features
  admin-hub      — support, admin, competitor monitoring
  app-hub        — app features
  schedule-hub   — scheduling

Mega-hubs (5):
  tools-hub, media-hub, enterprise-hub,
  social-commerce-hub, lifestyle-hub
```

94 → 15 functions (**84% reduction**).

---

## The CORS Error That Wasn't a CORS Error

When a deleted Edge Function still gets called from Flutter, the browser shows:

```
Access to XMLHttpRequest at
'https://xxx.supabase.co/functions/v1/growth-referral'
has been blocked by CORS policy: Response to preflight request
doesn't pass access control check: No 'Access-Control-Allow-Origin' header
```

**Root cause**: The deleted function returns 404. A 404 response has no CORS headers. The browser interprets "no CORS headers" as a CORS error — not a 404. This is misleading.

**Fix**: Find every call to the old function name and update it to the hub equivalent.

```bash
# Find all references to the deleted function
grep -rn "growth-referral" lib/ --include="*.dart"

# 17 hits → replace with growth-hub + action name
```

### 17 Deprecated Functions Fixed

| Deprecated EF | New Hub | Action |
|---------------|---------|--------|
| `growth-referral` | `growth-hub` | `referral.list/create` |
| `notification-center` | `core-hub` | `notification.list/mark_read` |
| `development-achievements` | `core-hub` | `achievements.list/add` |
| `submit-feedback` | `core-hub` | `feedback.submit` |
| `weather-widget` | `tools-hub` | `get_weather` |
| `wiki-database` | `enterprise-hub` | `wiki.*` |
| `voice-memo-transcriber` | `media-hub` | `transcribe.*` |
| `gantt-timeline-manager` | `enterprise-hub` | `gantt.*` |
| `code-playground` | `enterprise-hub` | `playground.*` |
| `real-estate-tracker` | `lifestyle-hub` | `realestate.*` |
| (and 7 more) | | |

---

## CI Hard Cap: Fail if > 50 Functions

After the reduction, added a CI check to prevent creep back:

```yaml
- name: Check Edge Function deploy count (hard cap 50)
  run: |
    DEPLOYED=$(grep "supabase functions deploy" .github/workflows/deploy-prod.yml \
      | grep -v "^#\|#" | awk '{print $4}' | sort)
    DEPLOY_COUNT=$(echo "$DEPLOYED" | grep -c . || true)
    if [ "$DEPLOY_COUNT" -gt 50 ]; then
      echo "❌ EF hard cap exceeded: ${DEPLOY_COUNT} > 50"
      exit 1
    fi
    echo "✅ EF count OK: ${DEPLOY_COUNT} <= 50"
  continue-on-error: false
```

Any PR that adds a new standalone function fails CI until an existing function is consolidated.

---

## Bonus: `publicActions` for Service-to-Service Auth

GitHub Actions calls the `schedule-hub` EF using `SERVICE_ROLE_KEY`, not a user JWT. The EF's normal auth check (`getUser()`) returns null and rejects with 401.

Fix: a `publicActions` array that skips user auth:

```typescript
// schedule-hub/index.ts
const publicActions = ["digest.run", "health.check", "blog.auto_publish", "blog.create"];

let userId: string | null = null;
if (!publicActions.includes(action)) {
  userId = await getUserId(req);
  if (!userId) return json({ error: "Unauthorized" }, 401);
}
```

Actions in `publicActions` bypass user auth entirely — service callers pass straight through.

---

## Results

| Metric | Before | After |
|--------|--------|-------|
| Deployed functions | 94 | 15 |
| Production CORS errors | 17 functions worth | 0 |
| CI EF guard | None | 50-function hard cap |
| GitHub Actions → EF auth | 401 errors | `publicActions` bypass |

**Rule of thumb**: Every new feature should add an action to an existing hub, not create a new function. The hard cap CI check enforces this automatically.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #architecture #devops
