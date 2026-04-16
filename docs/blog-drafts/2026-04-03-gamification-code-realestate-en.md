---
title: "3 Features in One Day: Gamification, Code Playground & Real Estate Tracker (Flutter + Supabase)"
tags: Flutter,Supabase,buildinpublic,Dart,productivity
published: true
---

# 3 Features in One Day: Gamification, Code Playground & Real Estate Tracker

## What We Shipped

Three features in a single session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Habit Gamification** — competing with Duolingo, Habitica, Forest
2. **Code Playground** — competing with GitHub Gist, CodePen
3. **Real Estate Tracker** — competing with MoneyForward's asset management

All three use the same Edge Function First architecture.

---

## Habit Gamification

### XP + Level System (UI)

The XP and level logic lives in the Edge Function. Flutter just renders the result:

```dart
final level      = _profile['level']       as int?    ?? 1;
final currentXp  = _profile['currentXp']   as int?    ?? 0;
final nextLevelXp = _profile['nextLevelXp'] as int?   ?? 100;
final progress   = nextLevelXp > 0 ? currentXp / nextLevelXp : 0.0;

LinearProgressIndicator(
  value: progress.clamp(0.0, 1.0),
  backgroundColor: Colors.white24,
  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
)
```

The XP formula, level thresholds, and badge conditions are all in Deno — not in Dart. This means you can adjust the game balance without a Flutter rebuild.

### Daily Challenge Completion

```dart
Future<void> _completeChallenge(String type) async {
  final res = await _supabase.functions.invoke(
    'habit-gamification',
    body: {'action': 'complete_challenge', 'type': type},
  );
  final data = res.data as Map<String, dynamic>?;
  if (data?['success'] == true) {
    final xp        = data?['xpEarned']  as int?  ?? 0;
    final newBadges = data?['newBadges'] as List? ?? [];
    // Show badge notification if newBadges is non-empty
  }
}
```

Always cast `res.data` to `Map<String, dynamic>?` before property access — `avoid_dynamic_calls` lint rule enforced.

### Badge Storage Pattern

12 badge types (first-step, 3-day-streak, 7-day, 30-day, 100-day, etc.) stored as a JSON array in `app_analytics.metadata`:

```typescript
// In habit-gamification Edge Function
await supabase.from('app_analytics').upsert({
  user_id: userId,
  source: 'gamification',
  metadata: {
    badges: ['first-step', '3-day-streak'],
    xp: 450,
    level: 5,
  },
}, { onConflict: 'user_id,source' });
```

No separate `badges` table needed — JSONB metadata handles the array with a single UPSERT.

---

## Code Playground: 20-Language Snippet Manager

### Language Color Map

```dart
Widget _langIcon(String lang) {
  const langColors = {
    'javascript': Color(0xFFF7DF1E),
    'typescript': Color(0xFF3178C6),
    'python':     Color(0xFF3776AB),
    'dart':       Color(0xFF0175C2),
    'rust':       Color(0xFFDEA584),
    'go':         Color(0xFF00ADD8),
    'sql':        Color(0xFF336791),
  };
  final color = langColors[lang] ?? Colors.grey;
  return CircleAvatar(
    backgroundColor: color.withValues(alpha: 0.15),
    child: Text(lang.substring(0, 1).toUpperCase()),
  );
}
```

Note `withValues(alpha: 0.15)` — `withOpacity` is deprecated in Flutter 3.33+.

### `DropdownButtonFormField` — `value` is Deprecated

Flutter 3.33 deprecated the `value` property on `DropdownButtonFormField`:

```dart
// DEPRECATED
DropdownButtonFormField<String>(
  value: _selectedLanguage,
  ...
)

// CORRECT
DropdownButtonFormField<String>(
  initialValue: _selectedLanguage,
  ...
)
```

### One-Tap Copy

```dart
TextButton.icon(
  onPressed: () {
    Clipboard.setData(ClipboardData(text: snippet.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  },
  icon: const Icon(Icons.copy, size: 16),
  label: const Text('Copy'),
),
```

---

## Real Estate Tracker: ROI Calculated Server-Side

### Edge Function ROI Calculation

```typescript
// real-estate-tracker Edge Function
const roi = totalValue > 0
  ? Math.round((totalIncome - totalExpense) / totalValue * 10000) / 100
  : 0;

return { properties, totals: { roi, totalValue, totalIncome, totalExpense } };
```

`Math.round(... * 10000) / 100` gives a percentage with 2 decimal places without floating-point drift.

### Japanese Number Formatting

Large monetary values displayed in 億/万 units:

```dart
String _fmt(double v) {
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}億';
  if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}万';
  return v.toStringAsFixed(0);
}
```

¥123,456,789 → "1.2億". ¥45,000 → "4.5万". Keeps property values readable in a compact UI.

---

## Flutter 3.33 Lint Fixes Summary

All four lint issues caught by `flutter analyze`:

| Rule | What it caught | Fix |
|------|---------------|-----|
| `deprecated_member_use` | `withOpacity()` | → `withValues(alpha: x)` |
| `deprecated_member_use` | `DropdownButtonFormField.value` | → `initialValue` |
| `unnecessary_brace_in_string_interps` | `'${streak}'` | → `'$streak'` |
| `curly_braces_in_flow_control_structures` | `if (x) doThing()` | → add braces |

The rule: run `flutter analyze` after every significant change, not just before commit. Catching these early prevents cascading errors.

---

## Competing With 3 SaaS in One Day

| Feature | Competing With | Edge Function |
|---------|---------------|---------------|
| Habit Gamification | Habitica, Duolingo | `habit-gamification` |
| Code Playground | GitHub Gist, CodePen | `code-playground` |
| Real Estate Tracker | MoneyForward, Suumo | `real-estate-tracker` |

The pattern that makes this possible: Edge Function First means the Flutter implementation is always thin. Once the EF is working, the UI is mostly `FutureBuilder` + `ListView` + formatting helpers.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #productivity
