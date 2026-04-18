---
title: "Spaced Repetition in Flutter + Supabase — AI University Memory System"
tags: Flutter,Supabase,buildinpublic,webdev,FlutterTips
published: true
---

# Spaced Repetition in Flutter + Supabase — AI University Memory System

I added a spaced repetition (FSRS-inspired) system to my AI University feature. Users tap one of four grade buttons after each quiz answer — the system calculates when to show that card again.

**Core idea**: `stability` is the only state variable. Grade it → multiply stability → set `due_date = now + stability days`.

## Schema

```sql
CREATE TABLE ai_university_fsrs_cards (
  user_id     uuid REFERENCES auth.users NOT NULL,
  provider    text NOT NULL,
  question_id text NOT NULL,
  due_date    timestamptz NOT NULL DEFAULT now(),
  stability   float8 NOT NULL DEFAULT 1.0,  -- memory strength
  reps        int  NOT NULL DEFAULT 0,
  lapses      int  NOT NULL DEFAULT 0,
  last_review timestamptz,
  state       text NOT NULL DEFAULT 'new',  -- new/learning/review/relearning
  PRIMARY KEY (user_id, provider, question_id)
);
```

## Grading Algorithm (Edge Function)

```typescript
// supabase/functions/ai-hub — quiz.fsrs_grade
const currentStability = existing?.stability ?? 1.0;

let newStability  = currentStability;
let daysUntilNext = 1;

if      (grade === 1) { newStability = Math.max(currentStability * 0.5, 0.5); daysUntilNext = 1;                           } // Again
else if (grade === 2) { newStability = currentStability * 0.8;                daysUntilNext = Math.max(newStability, 1);   } // Hard
else if (grade === 3) {                                                         daysUntilNext = Math.max(currentStability, 1); } // Good  
else                  { newStability = currentStability * 1.3;                daysUntilNext = Math.max(newStability * 1.3, 1); } // Easy

const nextDue = new Date();
nextDue.setDate(nextDue.getDate() + Math.round(daysUntilNext));
```

| Grade | Stability change | Next review |
|-------|-----------------|-------------|
| 1: Again | × 0.5 (min 0.5) | Tomorrow |
| 2: Hard | × 0.8 | stability days |
| 3: Good | unchanged | stability days |
| 4: Easy | × 1.3 | stability × 1.3 days |

Starting at `stability = 1.0`: "Good" → next day. "Easy" → next day. After a few "Easy" reviews the interval grows exponentially.

## Fetching Today's Due Cards

```typescript
// quiz.fsrs_next — cards where due_date <= now
const { data: cards } = await admin
  .from("ai_university_fsrs_cards")
  .select("question_id, provider, due_date, stability, state")
  .eq("user_id", userId)
  .lte("due_date", new Date().toISOString())
  .order("due_date", { ascending: true })
  .limit(limit);
```

`due_date <= now` is all you need — no extra scheduling logic.

## Flutter Service

```dart
// lib/services/ai_fsrs_service.dart
Future<({DateTime nextDue, double stability})> gradeCard({
  required String provider,
  required String questionId,
  required int grade,      // 1=Again  2=Hard  3=Good  4=Easy
}) async {
  final response = await _supabase.functions.invoke(
    'ai-hub',
    body: {'action': 'quiz.fsrs_grade', 'provider': provider,
           'question_id': questionId, 'grade': grade},
  );
  final data = response.data as Map<String, dynamic>;
  return (
    nextDue:   DateTime.parse(data['next_due'] as String),
    stability: (data['stability'] as num).toDouble(),
  );
}

static String nextDueLabel(DateTime d) {
  final days = d.difference(DateTime.now()).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return 'in $days days';
}
```

## UI — 4-Button Grading

```dart
Row(
  children: [
    for (final grade in [1, 2, 3, 4])
      ElevatedButton(
        onPressed: () async {
          final result = await _fsrsService.gradeCard(
            provider: providerId, questionId: questionId, grade: grade,
          );
          setState(() => _fsrsNextDue[providerId] = result.nextDue);
        },
        child: Text(['Again', 'Hard', 'Good', 'Easy'][grade - 1]),
      ),
  ],
)
```

## Key Design Decisions

1. **Single state variable** — `stability` only. No complex SM-2 formula.
2. **`due_date <= now` filter** — "today's review list" with zero extra logic.
3. **UPSERT idempotency** — `onConflict: "user_id,provider,question_id"` → safe to call multiple times.
4. **Algorithm lives in the EF** — Flutter just sends a grade number. Swap algorithms without touching Dart.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #SpacedRepetition #FlutterTips
