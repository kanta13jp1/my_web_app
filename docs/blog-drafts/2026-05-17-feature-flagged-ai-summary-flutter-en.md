---
title: "Shipping AI features safely in Flutter Web with Feature Flag + Deterministic Fallback"
tags: flutter,ai,featureflag,supabase,indiedev
published: true
---

# Shipping AI features safely in Flutter Web with Feature Flag + Deterministic Fallback

## Why you can't just ship AI features

Adding AI to a feature is not like adding a button. The risk surface is wider:

- **Costs are unpredictable**: user count × prompt length × API price = unknown until month-end
- **Quality wobbles**: same input, different output. Edge cases break Japanese rendering
- **Upstream goes down**: DeepInfra, Anthropic, or OpenAI flaking — one of them — paints your UI white
- **You can't A/B with 4 users**: "the AI version is better" is not a claim you can make at indie scale

When I added an AI summary to my asset-management page at *Jibun Inc.*, I looked for a pattern that solved all four. The answer was **`--dart-define` feature flag + deterministic fallback** in combination.

---

## Pattern: a 3-state status enum, no more

The minimal vocabulary you need is *flag off / AI succeeded / AI failed → fallback*.

```dart
enum AssetManagementAiSummaryStatus { disabled, aiGenerated, fallback }

class AssetManagementAiSummaryFeatureFlag {
  static const String dartDefineName = 'ASSET_MANAGEMENT_AI_SUMMARY_ENABLED';

  static const bool enabled = bool.fromEnvironment(
    dartDefineName,
    defaultValue: false,
  );
}
```

Three things matter here:

1. **`bool.fromEnvironment`**: the value is frozen at build time. You can ship one build with flag ON, others with flag OFF
2. **`defaultValue: false`**: forget the flag and you default to OFF — the safe side
3. **A 3-value enum, not a bool**: "AI ran" and "AI failed and we served fallback" need to be distinguishable in logs and in UI

---

## Pattern: build the fallback *before* calling AI

This was the single biggest design call for me.

```dart
Future<AssetManagementAiSummaryResult> generateSummary({
  required AssetManagementInsightReport report,
}) async {
  final payload = buildPayload(report);
  final fallback = buildDeterministicSummary(report);  // ★ built before the AI call

  if (!_aiEnabled) {
    return AssetManagementAiSummaryResult(
      status: AssetManagementAiSummaryStatus.disabled,
      text: fallback,                                    // ★ same fallback served
      ...
    );
  }

  try {
    final response = await _chatService.sendProviderChat(...);
    return /* aiGenerated */;
  } catch (e) {
    return /* fallback with status: fallback, errorMessage: e */;
  }
}
```

The core idea: **the function's type guarantees that a usable summary is always returned**, even if AI explodes.

`text` is non-nullable. The UI doesn't need an `AsyncSnapshot` error branch. The worst case is "deterministic summary served, log line recorded." No empty screen, no error toast.

---

## Pattern: inject the flag in the constructor so you can test it

Writing the flag *only* through `bool.fromEnvironment` makes it untestable. One extra constructor argument fixes that.

```dart
AssetManagementAiSummaryService({
  bool aiEnabled = AssetManagementAiSummaryFeatureFlag.enabled,
  ...
}) : _aiEnabled = aiEnabled, ...;
```

Now tests look like:

```dart
test('flag off → status disabled', () async {
  final svc = AssetManagementAiSummaryService(aiEnabled: false);
  final result = await svc.generateSummary(report: r);
  expect(result.status, AssetManagementAiSummaryStatus.disabled);
});

test('flag on but AI throws → status fallback', () async {
  final svc = AssetManagementAiSummaryService(
    aiEnabled: true,
    chatService: _ThrowingChatService(),
  );
  final result = await svc.generateSummary(report: r);
  expect(result.status, AssetManagementAiSummaryStatus.fallback);
  expect(result.text, isNotEmpty);  // fallback must never be empty
});
```

Because there are only 3 status values, the combinatorial space stays small.

---

## Pattern: prod rollout = "flag OFF for a day, then ON in stages"

Set `--dart-define=ASSET_MANAGEMENT_AI_SUMMARY_ENABLED=false` in the GHA workflow at first.

1. **Day 0**: deploy everywhere with flag OFF. Confirm fallback works in prod
2. **Day 1**: flip flag ON in dev/staging. Watch prompt quality and latency
3. **Day 2**: flip prod ON. Run a cost-watch cron that auto-rolls back if budget is exceeded

Because `bool.fromEnvironment` is build-time, flipping the flag requires a redeploy — and that's the *feature*, not the bug. It's a hard speed-bump that prevents reckless enabling.

---

## Why I didn't use a runtime flag table

I considered the runtime-flag pattern (admin UI toggles a Supabase config row). At my current scale (4 users), it's overkill:

- Emergency stop is a redeploy, ~3 minutes
- Runtime flags add layers: DB lookup → cache → invalidation
- A/B testing at n=4 is not a meaningful statistic

When I hit PMF, I'll switch to `Supabase config table + 1-hour cache`. Not before.

---

## The 4-layer defense, in one table

| Layer | Mechanism | What it protects |
|---|---|---|
| 1. Feature flag | `bool.fromEnvironment` | "oops, prod is ON" accidents |
| 2. Deterministic fallback | Built before the AI call | White-screen UI on API outages |
| 3. Status enum (3 values) | `disabled / aiGenerated / fallback` | Conflating "success" and "fallback" |
| 4. Injectable flag in tests | Constructor argument | Flag-state regressions |

With these four in place, an AI feature ships with the same casualness as any other.

I shipped the *Jibun Inc.* asset-management AI summary as a single 487-line commit using this pattern. Next up: a daily-KPI AI coach using the same scaffolding.

---

## Links

- *Jibun Inc.* (prod): <https://my-web-app-b67f4.web.app/>
- PR: feature-flagged asset management AI summaries (#2459)
- Related: "Notion database limits and workarounds" (2026-05-16)
