---
title: "CRM Pipeline + Horse Racing AI in Flutter Web: Lead Scoring Formula & Kanban with LinearProgressIndicator"
tags: Flutter,Supabase,buildinpublic,Dart,AI
published: true
---

# CRM Pipeline + Horse Racing AI in Flutter Web

## What We Shipped

Two features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **CRM Sales Pipeline** — competing with Salesforce (kanban + AI lead scoring)
2. **Horse Racing Predictor** — competing with netkeiba (~17M users, AI prediction model)

---

## CRM: AI Lead Scoring in the Edge Function

The lead scoring formula runs server-side in Deno:

```typescript
function calculateLeadScore(lead: LeadRecord): number {
  let score = 50;  // base score
  if (lead.email)                score += 10;
  if (lead.company)              score += 15;
  if (lead.phone)                score += 10;
  if (lead.source === 'referral') score += 15;
  // Cap at 100
  return Math.min(score, 100);
}
```

Score interpretation: 0–49 = cold, 50–74 = warm, 75+ = hot. The Flutter UI shows a colored badge based on these buckets — no scoring logic in Dart.

### Pipeline Stages

```
lead → qualified → proposal → negotiation → closed_won / closed_lost
```

### 3-Tab Layout

```
Tab 1: Pipeline (horizontal-scroll kanban)
  └── Column per stage, cards draggable between stages

Tab 2: Leads
  └── List with lead score badge (color by tier)
  └── Filter by stage

Tab 3: Statistics
  └── Win rate (LinearProgressIndicator)
  └── Revenue breakdown per stage
  └── Lost deals analysis
```

### LinearProgressIndicator for Win Rate

```dart
final winRate = totalDeals > 0 ? wonDeals / totalDeals : 0.0;
Row(
  children: [
    Expanded(
      child: LinearProgressIndicator(
        value: winRate.clamp(0.0, 1.0),
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
        minHeight: 8,
      ),
    ),
    const SizedBox(width: 8),
    Text('${(winRate * 100).toStringAsFixed(1)}%'),
  ],
)
```

`LinearProgressIndicator` again as a stats bar — no chart package needed.

---

## Horse Racing: AI Prediction Scoring

```typescript
function calculateRaceScore(horse: HorseRecord): number {
  return (
    horse.recent_form_score  * 3 +   // last 3 races weighted heaviest
    horse.jockey_win_rate    * 2 +   // jockey skill
    horse.trainer_win_rate       +   // trainer skill
    horse.track_affinity             // course specialization bonus
  );
}
```

Higher score = higher predicted chance of winning. The formula is adjustable server-side without a Flutter rebuild.

### Grade Color Chips

```dart
Color _gradeColor(String? grade) => switch (grade) {
  'G1' => Colors.red,
  'G2' => Colors.orange,
  'G3' => Colors.yellow.shade700,
  _    => Colors.grey,
};

Chip(
  label: Text(race['grade'] ?? ''),
  backgroundColor: _gradeColor(race['grade']).withValues(alpha: 0.15),
  side: BorderSide(color: _gradeColor(race['grade'])),
)
```

Grade-colored chips for race classification — visual hierarchy without a design system component.

### Prediction Result Badges

```dart
Widget _predBadge(String? result) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: switch (result) {
      'hit'    => Colors.green.withValues(alpha: 0.15),
      'miss'   => Colors.red.withValues(alpha: 0.15),
      _        => Colors.grey.withValues(alpha: 0.15),
    },
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    switch (result) {
      'hit'  => '✓ Hit',
      'miss' => '✗ Miss',
      _      => 'Pending',
    },
    style: TextStyle(
      fontSize: 11,
      color: switch (result) {
        'hit'  => Colors.green,
        'miss' => Colors.red,
        _      => Colors.grey,
      },
    ),
  ),
);
```

Dart 3 `switch` expressions keep the mapping compact.

---

## `use_build_context_synchronously`: Extract Before `await`

```dart
// WRONG — context.read after async gap
Future<void> _doSomething() async {
  await someAsyncCall();
  final service = context.read<NotificationService>(); // lint error
}

// CORRECT — extract before await
Future<void> _doSomething() async {
  final navigator = Navigator.of(context);   // before await
  final messenger = ScaffoldMessenger.of(context);
  await someAsyncCall();
  navigator.pop();           // safe — no context reference
  messenger.showSnackBar(…);
}
```

Any `context.*` call after an `await` is flagged. Extract what you need before the first `await`.

---

## Why One Session for Two Features

With Edge Function First, each Flutter page is:
1. Invoke EF → get data
2. Render with `FutureBuilder` / `setState`
3. Lint cleanup

The CRM EF and horse racing EF already existed. Both Flutter UIs followed the same 3-tab pattern. The total new Dart code: ~400 lines per feature, ~2h each.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #AI
