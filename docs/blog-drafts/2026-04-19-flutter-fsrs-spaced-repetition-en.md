---
title: "Implementing FSRS Spaced Repetition in Flutter — The Algorithm Behind AI University"
tags: Flutter,Supabase,AI,buildinpublic,webdev
published: false
---

# Implementing FSRS Spaced Repetition in Flutter

## What is FSRS?

**FSRS (Free Spaced Repetition Scheduler)** is the modern replacement for the SM-2 algorithm used in Anki. It models memory using three parameters that track how well you've learned something and when you're likely to forget it.

I added it to "AI University" — a feature that teaches 93 AI provider overviews with quizzes, badges, and streaks.

## The Memory Model

```dart
class FsrsCard {
  final double stability;      // How many days before 90% forgetting
  final double difficulty;     // 1-10, how hard is this material
  final double retrievability; // Probability of correct recall right now
  final DateTime dueDate;      // When to review next
}
```

## The Interval Calculation

```dart
enum Rating { again, hard, good, easy }

double calcInterval(FsrsCard card, Rating rating) {
  switch (rating) {
    case Rating.again: return 1.0;  // tomorrow
    case Rating.hard:  return card.stability * 0.8;
    case Rating.good:  return card.stability * _growthFactor(card.difficulty);
    case Rating.easy:  return card.stability * _growthFactor(card.difficulty) * 1.3;
  }
}

// Stability grows slower for harder material
double _growthFactor(double difficulty) {
  return 2.5 * (11 - difficulty) / 10;
}
```

A card with stability = 7 and difficulty = 5 rated "good" will next appear in ~8.75 days. Rated "easy": ~11.4 days. Rated "hard": ~5.6 days.

## Database Schema

```sql
CREATE TABLE ai_university_fsrs_cards (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users NOT NULL,
  provider text NOT NULL,
  category text NOT NULL,     -- "overview" | "models" | "api"
  stability float DEFAULT 1.0,
  difficulty float DEFAULT 5.0,
  due_date timestamptz DEFAULT now(),
  last_review timestamptz,
  review_count int DEFAULT 0
);
```

## Flutter Review UI

```dart
class FsrsReviewWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildQuestion(),
        if (_showAnswer)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: Rating.values.map(_buildRatingButton).toList(),
          )
        else
          ElevatedButton(
            onPressed: () => setState(() => _showAnswer = true),
            child: const Text('Show answer'),
          ),
      ],
    );
  }

  Widget _buildRatingButton(Rating rating) {
    final label = switch (rating) {
      Rating.again => 'Again\n<1 day',
      Rating.hard  => 'Hard\n~3 days',
      Rating.good  => 'Good\n~7 days',
      Rating.easy  => 'Easy\n~14 days',
    };
    return ElevatedButton(
      onPressed: () => _submitReview(rating),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  Future<void> _submitReview(Rating rating) async {
    await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'fsrs.review', 'provider': provider, 'rating': rating.name},
    );
  }
}
```

## Edge Function: Next Date Calculation

```typescript
// ai-hub: action "fsrs.review"
case "fsrs.review": {
  const { provider, rating } = params;

  const { data: card } = await supabase
    .from('ai_university_fsrs_cards')
    .select('stability, difficulty, review_count')
    .eq('user_id', user.id)
    .eq('provider', provider)
    .single();

  const interval = calcFsrsInterval(
    card?.stability ?? 1.0,
    card?.difficulty ?? 5.0,
    rating
  );

  const nextDue = new Date();
  nextDue.setDate(nextDue.getDate() + Math.round(interval));

  await supabase.from('ai_university_fsrs_cards').upsert({
    user_id: user.id,
    provider,
    stability: updateStability(card?.stability, rating),
    difficulty: updateDifficulty(card?.difficulty, rating),
    due_date: nextDue.toISOString(),
    last_review: new Date().toISOString(),
    review_count: (card?.review_count ?? 0) + 1,
  });

  return { next_due: nextDue, interval_days: Math.round(interval) };
}
```

## Fetching Today's Review Queue

```dart
final dueCards = await Supabase.instance.client
    .from('ai_university_fsrs_cards')
    .select('provider, stability')
    .eq('user_id', userId)
    .lte('due_date', DateTime.now().toIso8601String())
    .order('due_date')
    .limit(20);
```

Only cards where `due_date <= now()` show up. Users only see what FSRS says they're about to forget.

## Comparison with SM-2

| | SM-2 (classic Anki) | FSRS |
|--|---------------------|------|
| Parameters | EF (ease factor) | stability + difficulty + retrievability |
| Accuracy | Good | Better at predicting forgetting curves |
| Adaptation | Per-card | Per-user + per-card |
| Implementation complexity | ~50 lines | ~100 lines |

For a solo app, both work. FSRS is worth the extra lines — the forgetting curve model is more accurate and the algorithm is actively maintained.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Supabase #AI #buildinpublic #webdev
