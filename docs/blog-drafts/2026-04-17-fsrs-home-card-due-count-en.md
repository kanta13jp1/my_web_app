---
title: "Integrating Spaced Repetition Due Counts into a Flutter Home Dashboard Card"
tags: Flutter,Supabase,buildinpublic,Dart,UX
published: false
---

# Integrating Spaced Repetition Due Counts into a Flutter Home Dashboard Card

## The Problem

You've implemented FSRS spaced repetition for your learning app. Users have review cards due today. But they only see that when they open the learning page — not from the home dashboard.

The fix: surface the due count on the home card so users can't miss it.

---

## Schema: ai_university_fsrs_cards

```sql
CREATE TABLE ai_university_fsrs_cards (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  provider    text        NOT NULL,
  quiz_key    text        NOT NULL,
  due_date    date        NOT NULL DEFAULT current_date,
  stability   real        NOT NULL DEFAULT 1.0,
  difficulty  real        NOT NULL DEFAULT 5.0,
  review_count int        NOT NULL DEFAULT 0,
  last_grade  int,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider, quiz_key)
);

ALTER TABLE ai_university_fsrs_cards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fsrs_own" ON ai_university_fsrs_cards
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

`due_date` is a `date` (not `timestamptz`) — spaced repetition operates at day granularity. Cards due today have `due_date <= current_date`.

---

## Flutter: Home Card with Due Count

The home card widget queries FSRS cards for today's due count:

```dart
class AiUniversityHomeCard extends StatefulWidget {
  const AiUniversityHomeCard({super.key});

  @override
  State<AiUniversityHomeCard> createState() => _AiUniversityHomeCardState();
}

class _AiUniversityHomeCardState extends State<AiUniversityHomeCard> {
  int _dueCardCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDueCount();
  }

  Future<void> _loadDueCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final response = await Supabase.instance.client
          .from('ai_university_fsrs_cards')
          .select('id')
          .eq('user_id', userId)
          .lte('due_date', today);

      setState(() {
        _dueCardCount = (response as List).length;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }
```

Key patterns:
- `.lte('due_date', today)` — cards due today **or earlier** (overdue cards too)
- `.select('id')` — only fetch IDs, not full card data (minimal payload)
- `catch (_)` — FSRS cards table may not exist yet for new users; don't crash the home card

---

## Flutter: Conditional Due Count Badge

Show the badge only when there are cards due:

```dart
@override
Widget build(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  return Card(
    child: InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GeminiUniversityV2Page())),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('AI大学', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                // Due count badge — only when > 0
                if (!_loading && _dueCardCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '復習 $_dueCardCount問',
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            // ... rest of card content
          ],
        ),
      ),
    ),
  );
}
```

`colorScheme.errorContainer` / `colorScheme.onErrorContainer` — the "attention needed" semantic color pair. Red-ish in most Material 3 themes without hardcoding a hex.

---

## Mobile: Review Button

On mobile, add a prominent CTA button when cards are due:

```dart
// In the Column, after the title row:
if (!_loading && _dueCardCount > 0) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GeminiUniversityV2Page())),
      icon: const Icon(Icons.school),
      label: Text('復習する ($_dueCardCount問)'),
    ),
  ),
],
```

`FilledButton` (not `ElevatedButton`) — Material 3 primary action style. The `width: double.infinity` makes it span the full card width on mobile.

---

## Why .select('id') Instead of count()

The Supabase Flutter client doesn't expose `COUNT(*)` directly without a `count` option:

```dart
// Option A: fetch IDs and count client-side (simple)
final response = await supabase
    .from('ai_university_fsrs_cards')
    .select('id')
    .eq('user_id', userId)
    .lte('due_date', today);
final count = (response as List).length;

// Option B: use count option (PostgREST exact count)
final response = await supabase
    .from('ai_university_fsrs_cards')
    .select('*', const FetchOptions(count: CountOption.exact))
    .eq('user_id', userId)
    .lte('due_date', today);
final count = response.count;
```

For small datasets (review cards are per-user, rarely > 100), Option A is simpler. For large tables, use `CountOption.exact`.

---

## Summary

| Pattern | Benefit |
|---------|---------|
| `due_date` as `date` type | Day-granularity SRS, simple `.lte()` filter |
| `.select('id')` | Minimal network payload for count queries |
| `if (_dueCardCount > 0)` conditional badge | No clutter when nothing is due |
| `colorScheme.errorContainer` | Attention color without hardcoded hex |
| `catch (_)` on FSRS query | New users without cards don't crash the home card |

The home card became a retention hook: open the app, see the badge, review the cards.

Try it: [自分株式会社](https://my-web-app-b67f4.web.app/)

#buildinpublic #Flutter #Supabase #Dart #UX
