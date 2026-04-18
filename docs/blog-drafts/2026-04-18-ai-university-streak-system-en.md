---
title: "Building a Learning Streak System with Flutter + Supabase (Like Duolingo)"
tags: Flutter,Supabase,buildinpublic,webdev,AI
published: true
---

# Building a Learning Streak System with Flutter + Supabase (Like Duolingo)

I added a daily learning streak to my AI University feature — the same mechanic Duolingo and Wordle use. Study every day and your streak grows; miss a day and it resets to 1.

**Stack**: Supabase Edge Function + PostgreSQL RPC + Flutter home card widget

## The Architecture

```
[Quiz completed]
      ↓
ai-university-streaks Edge Function
      ↓
update_ai_university_streak RPC (PostgreSQL function)
      ↓
ai_university_streaks table updated
      ↓
Flutter home card shows "7-day streak 🔥"
```

## The Core Logic — 3 Lines of SQL

The entire streak calculation lives in a PostgreSQL function:

```sql
-- Today already studied → skip (idempotent)
IF v_last_date = v_today THEN
  RETURN QUERY SELECT v_current, v_longest, FALSE; RETURN;
END IF;

-- Yesterday → increment / gap of 2+ days → reset to 1
IF v_last_date = v_today - 1 THEN
  v_current := v_current + 1;
ELSE
  v_current := 1;
END IF;

v_longest := GREATEST(v_longest, v_current);
```

That's the full streak logic. Three decisions:
1. **Idempotent** — multiple completions in one day = one count
2. **Consecutive** — `v_today - 1` catches yesterday exactly
3. **Reset** — any gap resets to 1

Full function:

```sql
CREATE OR REPLACE FUNCTION update_ai_university_streak(p_user_id UUID)
RETURNS TABLE(current_streak INT, longest_streak INT, is_new_streak_day BOOL)
LANGUAGE plpgsql AS $$
DECLARE
  v_today DATE := CURRENT_DATE;
  v_last_date DATE;
  v_current INT := 0;
  v_longest INT := 0;
BEGIN
  SELECT last_studied_date, current_streak, longest_streak
  INTO v_last_date, v_current, v_longest
  FROM ai_university_streaks
  WHERE user_id = p_user_id;

  IF v_last_date = v_today THEN
    RETURN QUERY SELECT v_current, v_longest, FALSE; RETURN;
  END IF;

  IF v_last_date = v_today - 1 THEN v_current := v_current + 1;
  ELSE v_current := 1;
  END IF;

  v_longest := GREATEST(v_longest, v_current);

  INSERT INTO ai_university_streaks
    (user_id, current_streak, longest_streak, last_studied_date)
  VALUES (p_user_id, v_current, v_longest, v_today)
  ON CONFLICT (user_id) DO UPDATE SET
    current_streak    = EXCLUDED.current_streak,
    longest_streak    = EXCLUDED.longest_streak,
    last_studied_date = EXCLUDED.last_studied_date;

  RETURN QUERY SELECT v_current, v_longest, TRUE;
END;
$$;
```

## Edge Function Wrapper

Three actions, all JWT-authenticated:

```typescript
// POST { action: "update" } → update streak after study session
// POST { action: "get" }    → fetch current state
// GET  ?action=leaderboard  → top N by current_streak (service_role read)

if (action === "update") {
  const { data } = await supabase.rpc("update_ai_university_streak", {
    p_user_id: user.id,
  });
  return json({
    success: true,
    current_streak:    data.current_streak,
    longest_streak:    data.longest_streak,
    is_new_streak_day: data.is_new_streak_day,  // show toast if true
  });
}
```

The `is_new_streak_day` flag is useful: show a "🔥 First study today! Streak extended!" toast only when it's `true`.

## Flutter — Home Card Display

```dart
int _currentStreak = 0;

Future<void> _loadData() async {
  final row = await _supabase
      .from('ai_university_streaks')
      .select('current_streak')
      .eq('user_id', user.id)
      .maybeSingle();

  setState(() {
    _currentStreak = (row?['current_streak'] as num?)?.toInt() ?? 0;
  });
}

// Display: "12 providers learned / 7-day streak"
final streakText = _currentStreak > 0 ? ' / ${_currentStreak}d streak' : '';
```

## Calling the RPC from Flutter

```dart
// On quiz completion
await _supabase.rpc('update_ai_university_streak', params: {
  'p_user_id': user.id,
});
```

Or call the EF if you want the `is_new_streak_day` flag for the toast.

## Row Level Security

```sql
CREATE POLICY "users_own_streaks" ON ai_university_streaks
FOR ALL USING (auth.uid() = user_id);
```

Leaderboard uses `service_role` to read across all users — no personal data exposed since email is excluded.

## Why Put Logic in PostgreSQL?

The alternative is computing streak logic in the Edge Function (TypeScript). The DB approach wins because:
- **Single source of truth** — no client-side date arithmetic that drifts
- **Atomic UPSERT** — no race conditions from concurrent requests
- **Timezone-safe** — `CURRENT_DATE` uses DB timezone consistently

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #AILearning
