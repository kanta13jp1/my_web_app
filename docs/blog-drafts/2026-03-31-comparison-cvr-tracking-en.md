---
title: "Competitor Comparison Page CVR Dashboard: JSONB Signal Aggregation in Flutter + Supabase"
tags: Flutter,Supabase,buildinpublic,Dart,growth
published: true
---

# Competitor Comparison Page CVR Dashboard: JSONB Signal Aggregation in Flutter + Supabase

## The Problem

[自分株式会社](https://my-web-app-b67f4.web.app/) has 21 competitor comparison pages (`/vs-notion`, `/vs-slack`, etc.). Traffic to each page was tracked, but the question was unanswerable: **which comparison page leads to actual signups?**

This post covers the analytics dashboard that makes that question answerable.

---

## Signal Architecture

Two signal types track the funnel:

```dart
static const String touchComparison = 'touch_comparison';
static const String signupSubmitComparison = 'signup_submit_comparison';
```

When a user visits `/vs-notion`, `touch_comparison_notion` is recorded as the latest touchpoint. When they sign up, the touchpoint is resolved:

```dart
static String resolveSignupSubmitSignal(String? latestTouchpoint) {
  switch (latestTouchpoint) {
    case touchComparison:
      return signupSubmitComparison;
    // ... other channels
    default:
      return signupSubmitLanding;
  }
}
```

Result: `signupSubmitComparison` is attributed to the last comparison page visited before signup. Last-touch attribution — simple and deterministic.

---

## Storage: JSONB Over a Normalized Table

Signals are stored in `app_analytics.source_details` as a JSONB object:

```json
{
  "touch_comparison_notion": 42,
  "touch_comparison_slack":  18,
  "touch_comparison_discord": 11,
  "signup_submit_comparison": 3
}
```

Why JSONB instead of a dedicated `signals` table with `(date, signal_name, count)` rows?

| Normalized Table | JSONB |
|-----------------|-------|
| Strong schema enforcement | Dynamic keys without schema changes |
| Easy SQL aggregation | Requires `jsonb_each()` or client-side iteration |
| Extra migration per new competitor | Add competitor → new key appears automatically |

The signal key `touch_comparison_{competitor}` is dynamic — it grows as new competitors are added. JSONB avoids a schema change every time a new comparison page is created.

---

## Flutter: Aggregating JSONB Signals

```dart
Future<void> _loadComparisonCvr() async {
  final rows = await _supabase.from('app_analytics').select('source_details');

  final touches = <String, int>{};
  var signups = 0;

  for (final row in rows) {
    final sd = row['source_details'];
    if (sd is! Map) continue;

    sd.forEach((key, value) {
      final k = key.toString();
      final v = (value is num) ? value.toInt() : 0;

      if (k.startsWith('touch_comparison_')) {
        final competitor = k.replaceFirst('touch_comparison_', '');
        touches.update(competitor, (c) => c + v, ifAbsent: () => v);
      } else if (k == 'signup_submit_comparison') {
        signups += v;
      }
    });
  }

  setState(() {
    _touches  = touches;
    _signups  = signups;
  });
}
```

Key patterns:
- `if (sd is! Map) continue` — guards against null or malformed JSONB rows
- `(value is num) ? value.toInt() : 0` — JSONB numbers come back as `num`, not `int`
- `touches.update(competitor, (c) => c + v, ifAbsent: () => v)` — aggregates across multiple daily rows

---

## Flutter: LinearProgressIndicator as Bar Chart

```dart
Widget _buildCompetitorBar(String competitor, int count, int maxCount) {
  final ratio = maxCount > 0 ? count / maxCount : 0.0;
  return Row(
    children: [
      SizedBox(width: 80, child: Text(competitor)),
      Expanded(
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
        ),
      ),
      SizedBox(width: 40, child: Text('$count', textAlign: TextAlign.right)),
    ],
  );
}
```

`LinearProgressIndicator` renders horizontal bars relative to the max competitor's count. No chart package needed. Output:

```
notion  ████████████████ 42
slack   ████████         18
discord ████             11
...
CVR: 71 touches → 3 signups = 4.2%
```

---

## Known Limitation: Per-Competitor Signup CVR

Current implementation tracks **total comparison signups**, not **which comparison page** each signup came from. Last-touch is comparison-channel, not comparison-competitor.

Example: user visits `/vs-notion`, then `/vs-slack`, then signs up → `signup_submit_comparison` records a comparison signup, but the per-competitor breakdown is lost.

Planned fix: pass `last_comparison` as a hidden field in the signup form → record `signup_submit_comparison_notion` instead of just `signup_submit_comparison`. Same signal pattern, one level more granular.

---

## Summary

- JSONB for dynamic signal keys (no schema change per new competitor)
- `k.startsWith('touch_comparison_')` + `replaceFirst` to extract competitor key
- `(value is num) ? value.toInt() : 0` for safe JSONB numeric extraction
- `LinearProgressIndicator` as a bar chart — no chart dependency

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #growth
