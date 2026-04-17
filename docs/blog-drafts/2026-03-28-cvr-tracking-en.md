---
title: "CVR Tracking by Competitor Comparison Page: StatelessWidget → StatefulWidget + unawaited() Pattern"
tags: Flutter,Supabase,buildinpublic,Dart,growth
published: true
---

# CVR Tracking by Competitor Comparison Page: StatelessWidget → StatefulWidget + `unawaited()`

## The Problem

[自分株式会社](https://my-web-app-b67f4.web.app/) has 21 competitor comparison pages (`/vs-notion`, `/vs-slack`, `/vs-moneyforward`, etc.). The question we couldn't answer: **which comparison page drives the most signups?**

---

## The Solution: Per-Page Acquisition Signals

Add two signal types per competitor:

```dart
static const String touchComparison = 'touch_comparison';
static const String signupSubmitComparison = 'signup_submit_comparison';

// Per-competitor signal (granular analysis)
Future<void> recordComparisonTouch(String competitorKey) async {
  await _persistLatestTouchpoint(touchComparison);
  await _recordSignal('touch_comparison_$competitorKey');  // e.g. 'touch_comparison_notion'
}
```

`touch_comparison_notion` is recorded when `/vs-notion` is viewed. When that visitor later signs up, `signup_submit_comparison` is attributed to their last-touch competitor. Now you can rank: "Notion visitors convert at 8%, Slack visitors at 3%."

---

## StatelessWidget → StatefulWidget Migration

`ComparisonPage` was a `StatelessWidget` — no lifecycle hooks. Recording on page view requires `initState`. Migration pattern:

```dart
// BEFORE — StatelessWidget, no lifecycle
class _ComparisonShell extends StatelessWidget {
  final _CompetitorInfo info;
  const _ComparisonShell({required this.info});
  
  @override
  Widget build(BuildContext context) { ... }
}

// AFTER — StatefulWidget with initState
class _ComparisonShell extends StatefulWidget {
  final _CompetitorInfo info;
  final String competitorKey;  // added
  const _ComparisonShell({required this.info, required this.competitorKey});

  @override
  State<_ComparisonShell> createState() => _ComparisonShellState();
}

class _ComparisonShellState extends State<_ComparisonShell> {
  static const _acquisitionService = GrowthAcquisitionService();

  @override
  void initState() {
    super.initState();
    unawaited(_acquisitionService.recordComparisonTouch(widget.competitorKey));
  }

  _CompetitorInfo get _info => widget.info;

  @override
  Widget build(BuildContext context) { ... }
}
```

---

## `unawaited()` for Non-Blocking Signals

```dart
unawaited(_acquisitionService.recordComparisonTouch(widget.competitorKey));
```

`unawaited()` explicitly marks a `Future` as intentionally not awaited. Without it, `flutter analyze` raises a `discarded_futures` warning — "you started an async operation but aren't handling the result."

This is the correct pattern for fire-and-forget analytics: don't block the UI render on a network call, and don't care about the result.

Import: `import 'dart:async' show unawaited;`

---

## Migration Gotcha: `_info` References

When a `StatelessWidget` becomes a `StatefulWidget`, direct field references (`info.name`) must become `widget.info.name` or use a getter:

```dart
// Safer: getter in State class
_CompetitorInfo get _info => widget.info;

// Then all widget references work unchanged
_info.name   // not widget.info.name everywhere
```

After migration, run:

```bash
grep -n "info\." lib/pages/comparison_page.dart
```

Any line with `info.` that isn't prefixed by `widget.` or `_` is a potential missed update.

---

## Passing `competitorKey` Down

```dart
class ComparisonPage extends StatelessWidget {
  final String competitorKey;  // 'notion', 'slack', etc.
  
  @override
  Widget build(BuildContext context) {
    final info = _competitorInfo[competitorKey.toLowerCase()] ?? _defaultInfo;
    return _ComparisonShell(
      info: info,
      competitorKey: competitorKey.toLowerCase(),  // added
    );
  }
}
```

`competitorKey.toLowerCase()` normalizes route params (`/vs-Notion` → `notion`).

---

## What This Enables

| Signal | Meaning |
|--------|---------|
| `touch_comparison_notion` | User viewed /vs-notion |
| `touch_comparison_slack` | User viewed /vs-slack |
| `signup_submit_comparison` | User who viewed a comparison page signed up |

Joining these in the Edge Function: `touch_comparison_${key}` count → `signup_submit_comparison` count = CVR per competitor page. Focus LP investment on the high-CVR comparisons.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #growth
