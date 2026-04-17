---
title: "SM-2 Spaced Repetition in Deno + Flashcard UI in Flutter Web: Building a Duolingo Competitor"
tags: Flutter,Supabase,buildinpublic,Dart,algorithm
published: true
---

# SM-2 Spaced Repetition in Deno + Flashcard UI in Flutter Web

## What We Built

A language learning feature for [自分株式会社](https://my-web-app-b67f4.web.app/) competing with Duolingo and Anki:

- SM-2 spaced repetition algorithm (server-side in Deno)
- Flashcard flip UI with progress indicator
- Vocabulary deck management
- Streak tracking (🔥 consecutive days)
- Statistics tab: accuracy rate, total reviews, streak records

---

## SM-2 Algorithm in the Edge Function

The SM-2 algorithm runs server-side in the `language-learning` Edge Function — not in Dart. This keeps the scheduling logic centralized and testable:

```typescript
// SM-2 implementation in Deno
function calculateNextReview(
  correct: boolean,
  quality: number,  // 0-5 response quality
  interval: number, // current interval in days
  ease: number,     // ease factor (default 2.5)
): { interval: number; ease: number; nextReview: string } {
  if (correct) {
    if (interval === 1) interval = 6;
    else interval = Math.round(interval * ease);
    ease = ease + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ease < 1.3) ease = 1.3;  // minimum ease factor
  } else {
    interval = 1;  // wrong answer → review again in 1 day
  }
  const nextReview = new Date(Date.now() + interval * 86400000).toISOString();
  return { interval, ease, nextReview };
}
```

Key SM-2 mechanics:
- First correct answer → 6 days (not 1)
- Subsequent correct → `interval × ease` (compounding)
- Wrong answer → reset to 1 day, ease unchanged
- Ease floor at 1.3 prevents intervals from collapsing to 1 day permanently

---

## Flutter UI: 3-Tab Structure

```
LanguageLearningPage
├── Tab 1: Decks
│   ├── Streak banner (🔥 N consecutive days)
│   ├── Deck list (source language → target language)
│   └── Card list for selected deck
├── Tab 2: Flashcard Review
│   ├── LinearProgressIndicator (current session progress)
│   ├── Flashcard (front / back with tap-to-flip)
│   └── "Got it!" / "Review again" buttons
└── Tab 3: Statistics
    ├── Streak (current + personal best)
    ├── Stats grid: decks / total cards / total reviews / accuracy %
    └── Study tips card
```

### Flashcard Flip

```dart
GestureDetector(
  onTap: () => setState(() => _showBack = !_showBack),
  child: AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: _showBack
      ? _buildCardBack(_currentCard)
      : _buildCardFront(_currentCard),
  ),
)
```

`AnimatedSwitcher` handles the flip animation. `_showBack` toggles on tap.

---

## `unnecessary_const` Inside const Context

Inside a `const` constructor's argument list, inner `const` keywords are redundant and trigger the `unnecessary_const` lint:

```dart
// WRONG — unnecessary_const lint
const Column(
  children: [
    const Icon(Icons.book),   // redundant const
    const Text('Decks'),       // redundant const
  ],
)

// CORRECT — outer const propagates inward
const Column(
  children: [
    Icon(Icons.book),
    Text('Decks'),
  ],
)
```

When the outer widget is `const`, all children are implicitly `const` — remove the inner `const` keywords.

---

## `require_trailing_commas` Pattern

```dart
// WRONG — missing trailing comma on multi-line
Text('text', textAlign: TextAlign.center,
    style: TextStyle(color: Colors.grey)),

// CORRECT
Text(
  'text',
  textAlign: TextAlign.center,
  style: TextStyle(color: Colors.grey),
),
```

Every multi-line argument list needs a trailing comma on the last argument. `dart format` auto-applies this when run with `--fix`.

---

## Edge Function API Design

```
GET ?action=decks                        → deck list
GET ?action=cards&deck_id=xxx            → cards due for review
GET ?action=stats                        → streak, accuracy, review counts
POST {action: "create_deck", ...}        → create vocabulary deck
POST {action: "create_card", ...}        → add card to deck
POST {action: "review", card_id, quality} → SM-2 update
```

Flutter:

```dart
// Review a card
final res = await _supabase.functions.invoke(
  'language-learning',
  body: {
    'action': 'review',
    'card_id': card['id'],
    'quality': correct ? 4 : 1,  // 4 = good, 1 = again
  },
);
final data = res.data as Map<String, dynamic>?;
final nextReview = data?['nextReview'] as String?;
```

The Edge Function returns the next scheduled review date — the client just shows it. No scheduling logic in Dart.

---

## Why SM-2 Server-Side

If SM-2 runs in Dart:
- Logic can drift across app versions
- Offline edits bypass the scheduling
- Can't batch-recalculate when the algorithm changes

Server-side SM-2: one implementation, one place to fix, no version drift.

---

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #algorithm
