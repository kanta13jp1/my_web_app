---
title: "Building Forest + Grammarly Competitors in Flutter Web: Pomodoro Timer & AI Writing Assistant"
tags: Flutter,Supabase,AI,buildinpublic,productivity
published: true
---

# Building Forest + Grammarly Competitors in Flutter Web: Pomodoro Timer & AI Writing Assistant

## What We Shipped

Three features in one session for [自分株式会社](https://my-web-app-b67f4.web.app/):

1. **Focus Timer** (`focus_timer_page.dart`) — Pomodoro-style timer competing with Forest/Focusmate
2. **AI Writing Assistant** (`ai_writing_assistant_page.dart`) — competing with Grammarly/Notion AI
3. **Abstinence Training Card** — integrated into the home screen dashboard

Plus 5 new Edge Functions added to CI/CD.

---

## Focus Timer: Edge Function + `Timer.periodic`

### The Backend

`focus-timer` Edge Function manages `focus_sessions` records:

```typescript
// GET ?action=stats&days=7
const { data: sessions } = await userClient
  .from("focus_sessions")
  .select("*")
  .eq("user_id", user.id)
  .gte("started_at", since)
  .order("started_at", { ascending: false });

const streak = _calculateStreak(sessions ?? []);
```

Streak calculation: deduplicate dates with a `Set`, count consecutive days from today backward.

### The Flutter Timer

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (_) {
  if (!mounted) return;
  setState(() {
    if (_remainingSeconds > 0) {
      _remainingSeconds--;
    } else {
      _completeSession();
    }
  });
});
```

The session lifecycle:
1. `start` → create DB record, store `_activeSessionId`
2. Tick every second, decrement `_remainingSeconds`
3. On `complete` or `cancel` → UPDATE the record with actual duration

Keeping `_activeSessionId` means the session is correctly marked even if the user navigates away mid-timer.

### `Colors.white08` Doesn't Exist

Quick gotcha: Flutter has no `Colors.white08` shorthand. `flutter analyze` catches it as `undefined_getter`.

```dart
// WRONG — undefined
color: Colors.white08

// CORRECT
color: Colors.white.withValues(alpha: 0.08)
```

---

## AI Writing Assistant: Dart 3 Record Syntax for Actions

### The Edge Function

`ai-writing-assistant` routes text to Gemini based on `action`:

```typescript
case "improve":
  prompt = `Improve the following text for clarity and naturalness:\n\n${text}`;
  break;
case "titles":
  prompt = `Suggest 5 title options for the following content. Each under 20 words:\n\n${text}`;
  break;
case "summarize":
  prompt = `Summarize the following in 3 bullet points:\n\n${text}`;
  break;
```

When `GEMINI_API_KEY` is unset, it returns a fallback message — no error thrown. Local development works without credentials.

### Dart 3 Records for Action Definitions

Instead of enums + models, use Dart 3 record syntax:

```dart
static const _actions = {
  'improve':   ('Improve text',    Icons.auto_fix_high, Color(0xFF6366F1)),
  'summarize': ('Summarize',       Icons.compress,      Color(0xFF10B981)),
  'translate': ('Translate',       Icons.translate,     Color(0xFF8B5CF6)),
  'titles':    ('Title ideas',     Icons.title,         Color(0xFFF97316)),
  'minutes':   ('Meeting minutes', Icons.assignment,    Color(0xFF0EA5E9)),
};
```

Access with `e.value.$1` (label), `e.value.$2` (icon), `e.value.$3` (color). No separate class needed for a simple (label, icon, color) tuple.

---

## Abstinence Training: Home Dashboard Integration

The abstinence training feature tracks "impulse purchases resisted." Five metrics from `AbstinenceDisciplineSnapshot` were added to the home screen:

- `repCount` — total resistance events
- `moneySaved` — estimated money saved (¥)
- `timeSavedMinutes` — time not spent browsing
- `streakDays` — consecutive days with no impulsive spending
- `stageLabel` — current discipline level

One gotcha: `_formatYen(int)` expected `double`, not `int`:

```dart
// WRONG: argument_type_not_assignable
_formatYen(moneySaved)

// CORRECT
_formatYen(moneySaved.toDouble())
```

`flutter analyze` catches this as `argument_type_not_assignable`.

---

## 6 Lint Errors Fixed

| Error | Fix |
|-------|-----|
| `Colors.white08` undefined | → `Colors.white.withValues(alpha: 0.08)` |
| `prefer_const_declarations` | Add `const` to static definitions |
| `require_trailing_commas` | Add trailing commas to all widget arguments |
| `argument_type_not_assignable` | `.toDouble()` before passing int to double param |
| `unnecessary_brace_in_string_interps` | `'$streak'` instead of `'${streak}'` |
| `avoid_dynamic_calls` | Cast EF response to `Map<String, dynamic>?` first |

All caught and fixed before commit. `flutter analyze 0 errors` maintained.

---

## Summary

| Feature | Competing With | Key Tech |
|---------|---------------|----------|
| Focus Timer | Forest, Focusmate | `Timer.periodic` + `focus_sessions` EF |
| AI Writing | Grammarly, Notion AI | Gemini + action-based EF routing |
| Abstinence Card | — | Dashboard integration via `HomeSnapshot` |

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #productivity #AI
