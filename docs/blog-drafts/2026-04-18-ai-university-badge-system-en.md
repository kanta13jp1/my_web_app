---
title: "Building a Badge & Achievement System with Flutter + Supabase"
tags: Flutter,Supabase,buildinpublic,webdev,Gamification
published: false
---

# Building a Badge & Achievement System with Flutter + Supabase

I added a badge and achievement system to my AI University feature. Users earn badges as they learn:

- 🔥 3-day streak → `streak_3d`
- 🏆 7-day streak → `streak_7d`
- 🎓 Quiz correct on 3 providers → `quiz_master_3`
- 🌟 Quiz correct on ALL providers → `quiz_master_all`
- 📣 Share progress → `social_sharer` (client-driven)

The badge count shows on the home card: "3 badges earned."

## Architecture: One Edge Function, 7 Actions

All badge logic lives in `ai-university-badges`:

| action | Purpose |
|--------|---------|
| `award` | Manual badge grant (share events, etc.) |
| `list` | Get user's badge list |
| `check_streaks` | Auto-award streak badges |
| `check_quiz_master` | Auto-award quiz badges |
| `record_score` | Record quiz result + trigger badge check |
| `leaderboard` | Badge count leaderboard |
| `score_leaderboard` | Quiz correct count leaderboard |

## Badge Definitions

```typescript
const STREAK_BADGES = [
  { badge_id: "streak_3d",  badge_name: "3-Day Streak",  icon_emoji: "🔥", condition: "3+ consecutive days" },
  { badge_id: "streak_7d",  badge_name: "7-Day Streak",  icon_emoji: "🏆", condition: "7+ consecutive days" },
  { badge_id: "streak_30d", badge_name: "30-Day Streak", icon_emoji: "💎", condition: "30+ consecutive days" },
];
const QUIZ_MASTER_3   = { badge_id: "quiz_master_3",   icon_emoji: "🎓", condition: "Correct on 3+ providers" };
const QUIZ_MASTER_ALL = { badge_id: "quiz_master_all", icon_emoji: "🌟", condition: "Correct on ALL providers" };
```

## Streak Badges — Auto-Award on check_streaks

```typescript
// POST { action: "check_streaks" }
const { data } = await supabase
  .from("ai_university_streaks")
  .select("current_streak")
  .eq("user_id", user.id)
  .maybeSingle();

const streak = data?.current_streak ?? 0;
const awarded: string[] = [];

for (const badge of STREAK_BADGES) {
  const threshold = badge.badge_id === "streak_3d" ? 3 : badge.badge_id === "streak_7d" ? 7 : 30;
  if (streak >= threshold) {
    const { data: isNew } = await supabase.rpc("award_ai_university_badge", {
      p_user_id: user.id,
      p_badge_id: badge.badge_id,
      p_badge_name: badge.badge_name,
      p_icon_emoji: badge.icon_emoji,
      p_condition: badge.condition,
    });
    if (isNew === true) awarded.push(badge.badge_id);
  }
}
return json({ success: true, current_streak: streak, awarded });
```

Calling this every day is safe — the RPC prevents duplicate awards.

## The Core: award_ai_university_badge RPC

Idempotent award using `ON CONFLICT DO NOTHING` + PostgreSQL's `FOUND`:

```sql
CREATE OR REPLACE FUNCTION award_ai_university_badge(
  p_user_id UUID, p_badge_id TEXT, p_badge_name TEXT,
  p_icon_emoji TEXT DEFAULT NULL, p_condition TEXT DEFAULT NULL
)
RETURNS BOOLEAN  -- TRUE = newly awarded, FALSE = already had it
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO ai_university_badges (user_id, badge_id, badge_name, icon_emoji, condition)
  VALUES (p_user_id, p_badge_id, p_badge_name, p_icon_emoji, p_condition)
  ON CONFLICT (user_id, badge_id) DO NOTHING;
  RETURN FOUND;  -- FALSE when DO NOTHING fires
END;
$$;
```

`FOUND` is `FALSE` after `DO NOTHING` — one line to check "was this a new award?"

## Quiz Badge on record_score

```typescript
// POST { action: "record_score", provider_id, quiz_correct }
// Upsert score, then award quiz badges only on first correct answer

await supabase
  .from("ai_university_scores")
  .upsert({ user_id: user.id, provider_id, quiz_correct },
           { onConflict: "user_id,provider_id" });

if (quiz_correct && isNewlyCorrect) {
  // Count total correct providers vs total registered
  const { count: correctCount } = await supabase
    .from("ai_university_scores")
    .select("id", { count: "exact" })
    .eq("user_id", user.id)
    .eq("quiz_correct", true);

  if (correctCount >= 3)            await awardBadge(QUIZ_MASTER_3);
  if (correctCount >= totalProviders) await awardBadge(QUIZ_MASTER_ALL);
}
```

## Client-Driven Badge (social_sharer)

Some badges are triggered by client events — no server-side condition needed:

```dart
// On share button tap
await _supabase.functions.invoke('ai-university-badges', body: {
  'action': 'award',
  'badge_id': 'social_sharer',
  'badge_name': 'Social Sharer',
  'icon_emoji': '📣',
});
```

## Flutter — Badge Count on Home Card

```dart
final badgeRow = await _supabase
    .from('ai_university_badges')
    .select('id')
    .eq('user_id', user.id)
    .count(CountOption.exact);

setState(() => _badgeCount = badgeRow.count);
```

`.count(CountOption.exact)` — fetch only the count, no row data.

## Design Principles

1. **Idempotent at the DB layer** — `ON CONFLICT DO NOTHING` + `FOUND` means calling award 100× = same result as calling it once
2. **All conditions in one EF** — streak badges and quiz badges share the same endpoint, keeping the Flutter client simple
3. **Mix server and client triggers** — automated conditions run server-side; social actions run client-side; both hit the same `award` action

The result is a viral loop: **study → badge → share → new user joins → badges become a retention hook**.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #Gamification
