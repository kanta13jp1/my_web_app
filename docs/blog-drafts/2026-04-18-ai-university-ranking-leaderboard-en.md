---
title: "Building a Leaderboard with Flutter + Supabase (AI University #3)"
tags: Flutter,Supabase,buildinpublic,webdev,Gamification
published: false
---

# Building a Leaderboard with Flutter + Supabase (AI University #3)

Third post in the AI University gamification series (streak → badges → leaderboard). Users are ranked by quiz correct count; top 10 show with public badges.

## The PostgreSQL View

All ranking logic lives in a view — no sorting in Flutter:

```sql
CREATE VIEW ai_university_leaderboard AS
SELECT
  ROW_NUMBER() OVER (ORDER BY total_correct DESC, providers_studied DESC) AS rank,
  user_id,
  total_correct,
  providers_studied
FROM (
  SELECT
    user_id,
    COUNT(*) FILTER (WHERE quiz_correct = true) AS total_correct,
    COUNT(DISTINCT provider_id)                 AS providers_studied
  FROM ai_university_scores
  GROUP BY user_id
) sub;
```

`ROW_NUMBER()` assigns ranks. Tiebreaker: `providers_studied` after `total_correct`.

## Flutter — Fetch Top 10

```dart
final rows = await _supabase
    .from('ai_university_leaderboard')
    .select()
    .order('rank')
    .limit(10)
    .timeout(const Duration(seconds: 10));

final entries = (rows as List)
    .cast<Map<String, dynamic>>()
    .map(_LeaderboardEntry.fromMap)
    .where((e) => e.totalCorrect > 0 || e.providersStudied > 0)
    .toList();
```

Filter out zero-score users with `.where()`.

## Parallel Queries: Badges + My Snapshot

```dart
// Start both futures before awaiting either
final badgesFuture     = _loadPublicBadges(leaderboardUserIds);
final mySnapshotFuture = _loadMySnapshot(_myUserId!);

// Await both — parallel DB calls
final badgesByUser = await badgesFuture;
final mySnapshot   = await mySnapshotFuture;
```

Two DB calls run concurrently instead of sequentially.

## Public Badges

```dart
Future<Map<String, List<_BadgeEntry>>> _loadPublicBadges(List<String> userIds) async {
  final rows = await _supabase
      .from('ai_university_badges')
      .select('user_id, badge_id, badge_name, icon_emoji')
      .in_('user_id', userIds)
      .eq('is_public', true);  // users can hide badges

  final result = <String, List<_BadgeEntry>>{};
  for (final row in rows as List) {
    result
      .putIfAbsent(row['user_id'] as String, () => [])
      .add(_BadgeEntry.fromMap(row));
  }
  return result;
}
```

One query fetches badges for all leaderboard users.

## Rank Colors + Medals

```dart
static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

Color get _rankColor => switch (rank) {
  1 => const Color(0xFFFFD700), // gold
  2 => const Color(0xFFC0C0C0), // silver
  3 => const Color(0xFFCD7F32), // bronze
  _ => const Color(0xFF6366F1), // indigo
};
```

## My Rank (Outside Top 10)

```dart
// Shows "You are currently ranked #42" even if not in top 10
final myRow = await _supabase
    .from('ai_university_leaderboard')
    .select()
    .eq('user_id', userId)
    .maybeSingle();

if (myRow != null) summaryTitle = 'You are currently ranked #${myRow['rank']}';
```

## Design Summary

| Concern | Approach |
|---------|----------|
| Rank calculation | PostgreSQL `ROW_NUMBER()` — not Flutter |
| Parallel data | Fire futures before awaiting |
| Privacy | `is_public` column on badges |
| Zero-score filter | `.where()` on client |

The full gamification loop: **study daily (streak) → earn achievements (badges) → climb the leaderboard (ranking)**.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Gamification
