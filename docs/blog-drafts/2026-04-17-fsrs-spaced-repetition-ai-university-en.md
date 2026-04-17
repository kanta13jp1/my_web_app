---
title: "Implementing FSRS Spaced Repetition in Flutter + Supabase — Adding Memory Science to an AI Learning App"
tags: Flutter,Supabase,buildinpublic,webdev,machinelearning
published: false
---

# Implementing FSRS Spaced Repetition in Flutter + Supabase

## The Problem

My app "AI University" lets users learn about 66+ AI providers through quizzes and news. The problem: **how do you make learning stick?**

The answer: **FSRS (Free Spaced Repetition Scheduler)** — the algorithm powering next-gen flashcard systems like the latest Anki. Here's how I integrated it into a Flutter + Supabase stack.

## What is FSRS?

FSRS models memory using two parameters:
- **Stability (S)**: How well the memory is consolidated. Higher S = longer interval before next review.
- **Difficulty (D)**: Subjective difficulty of the card.

After each review, the algorithm calculates a new interval based on a target retrievability (e.g., 90% recall probability).

## Database Schema

```sql
CREATE TABLE ai_university_fsrs_cards (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES auth.users NOT NULL,
  provider     text NOT NULL,    -- 'google', 'openai', etc.
  question_id  text NOT NULL,
  due_date     timestamptz NOT NULL DEFAULT now(),
  stability    float NOT NULL DEFAULT 1.0,
  difficulty   float NOT NULL DEFAULT 0.3,
  state        text NOT NULL DEFAULT 'new',  -- new/learning/review/relearning
  reps         int NOT NULL DEFAULT 0,
  lapses       int NOT NULL DEFAULT 0,
  last_review  timestamptz,
  UNIQUE(user_id, provider, question_id)
);

-- Each user only sees their own cards
ALTER TABLE ai_university_fsrs_cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_fsrs_cards" ON ai_university_fsrs_cards
  FOR ALL USING (user_id = auth.uid());
```

## Edge Function: Two Actions

I added two actions to the existing `ai-hub` Edge Function:

### `quiz.fsrs_next` — Get today's due cards

```typescript
case "quiz.fsrs_next": {
  const { provider, limit = 10 } = body;
  const { data: cards } = await supabase
    .from("ai_university_fsrs_cards")
    .select("*")
    .eq("user_id", user.id)
    .eq("provider", provider)
    .lte("due_date", new Date().toISOString())
    .order("due_date")
    .limit(limit);
  return new Response(JSON.stringify({ success: true, cards }));
}
```

### `quiz.fsrs_grade` — Record answer and schedule next review

```typescript
case "quiz.fsrs_grade": {
  const { provider, question_id, grade } = body; // grade 1-4
  const newStability = calculateFsrsStability(currentCard, grade);
  const intervalDays = Math.round(newStability * retrievabilityFactor);
  const nextDue = new Date(Date.now() + intervalDays * 86400000);

  await supabase.from("ai_university_fsrs_cards").upsert({
    user_id: user.id, provider, question_id,
    stability: newStability,
    due_date: nextDue.toISOString(),
    state: grade === 1 ? "relearning" : "review",
    reps: currentCard.reps + 1,
    last_review: new Date().toISOString()
  });
  return new Response(JSON.stringify({ success: true, next_due: nextDue }));
}
```

## Flutter Service Layer

```dart
class AiFsrsService {
  final _supabase = Supabase.instance.client;

  // grade: 1=Again, 2=Hard, 3=Good, 4=Easy
  Future<({DateTime nextDue, double stability})> gradeCard({
    required String provider,
    required String questionId,
    required int grade,
  }) async {
    final response = await _supabase.functions.invoke('ai-hub', body: {
      'action': 'quiz.fsrs_grade',
      'provider': provider,
      'question_id': questionId,
      'grade': grade,
    });
    final nextDue = DateTime.parse(response.data?['next_due'] ?? '');
    final stability = (response.data?['stability'] as num?)?.toDouble() ?? 1.0;
    return (nextDue: nextDue, stability: stability);
  }

  static String nextDueLabel(DateTime nextDue) {
    final diff = nextDue.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return 'In $diff days';
  }
}
```

## Home Card: Due Card Counter

After grading cards, I display a review reminder on the home screen:

```dart
// Query due cards directly from Supabase (RLS handles auth)
final dueCardRow = await _supabase
    .from('ai_university_fsrs_cards')
    .select('id')
    .eq('user_id', user.id)
    .lte('due_date', DateTime.now().toIso8601String())
    .count(CountOption.exact);

setState(() => _dueCardCount = dueCardRow.count);
```

When `_dueCardCount > 0`, a "Review X cards" badge and button appear on the home card — a subtle but effective re-engagement hook.

## Bug Caught Along the Way

When writing admin RLS policies on `user_profiles`, I initially used:

```sql
-- WRONG: 'id' is not the auth-mapped column
EXISTS (SELECT 1 FROM user_profiles WHERE id = auth.uid() AND is_admin = true)

-- RIGHT: user_profiles uses 'user_id' to reference auth.users
EXISTS (SELECT 1 FROM user_profiles up WHERE up.user_id = auth.uid() AND up.is_admin = true)
```

This kind of mistake silently passes schema validation but blocks admin access entirely.

## What's Next

- **Voice + FSRS**: Answer cards by speaking — Web Speech API grades the answer and FSRS schedules the next review.
- **Adaptive difficulty**: Use the `learner_profiles` table to route hard cards through a more capable LLM.
- **Cross-provider review sessions**: A single session that surfaces due cards across multiple AI providers.

---

Building in public: https://my-web-app-b67f4.web.app/#/gemini-university  
#FlutterWeb #Supabase #SpacedRepetition #FSRS #buildinpublic
