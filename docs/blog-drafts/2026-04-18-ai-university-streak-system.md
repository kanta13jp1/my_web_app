---
title: "Flutter × Supabase で連続学習ストリークシステムを作った — AI大学の裏側"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# Flutter × Supabase で連続学習ストリークシステムを作った — AI大学の裏側

## はじめに

自分株式会社の AI大学に「連続学習ストリーク」を実装しました。毎日学習すると日数がカウントアップし、ホームカードに「7日連続」などと表示されます。Duolingo や Wordle のあの仕組みです。

バックエンド: Supabase Edge Function + PostgreSQL RPC
フロントエンド: Flutter + `ai_university_home_card.dart`

## アーキテクチャ

```
[学習完了ボタン押下]
      ↓
ai-university-streaks EF
      ↓
update_ai_university_streak RPC (PostgreSQL関数)
      ↓
ai_university_streaks テーブル更新
      ↓
Flutter ホームカードに current_streak 表示
```

## Supabase Edge Function — ai-university-streaks

3つのアクション:

| action | 用途 | 認証 |
|--------|------|------|
| `update` | 学習完了時にストリーク更新 | JWT必須 |
| `get` | 現在のストリーク状態取得 | JWT必須 |
| `leaderboard` | ストリークランキング TOP N | JWT必須 |

```typescript
// POST { action: "update" }
// 返り値: { success, current_streak, longest_streak, is_new_streak_day }
serve(async (req) => {
  // ...認証・CORS処理...

  if (action === "update") {
    const { data } = await supabase.rpc("update_ai_university_streak", {
      p_user_id: user.id,
    });
    return json({
      success: true,
      current_streak: data.current_streak,
      longest_streak: data.longest_streak,
      is_new_streak_day: data.is_new_streak_day,
    });
  }
  // ...
});
```

## PostgreSQL RPC — update_ai_university_streak

ストリーク計算ロジックはすべてDB側に集約:

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

  -- 当日既に学習済み → スキップ
  IF v_last_date = v_today THEN
    RETURN QUERY SELECT v_current, v_longest, FALSE;
    RETURN;
  END IF;

  -- 昨日学習 → streak+1 / 2日以上空き → streak=1 リセット
  IF v_last_date = v_today - 1 THEN
    v_current := v_current + 1;
  ELSE
    v_current := 1;
  END IF;

  v_longest := GREATEST(v_longest, v_current);

  INSERT INTO ai_university_streaks (user_id, current_streak, longest_streak, last_studied_date)
  VALUES (p_user_id, v_current, v_longest, v_today)
  ON CONFLICT (user_id) DO UPDATE SET
    current_streak   = EXCLUDED.current_streak,
    longest_streak   = EXCLUDED.longest_streak,
    last_studied_date = EXCLUDED.last_studied_date;

  RETURN QUERY SELECT v_current, v_longest, TRUE;
END;
$$;
```

設計のポイント:
1. **当日既学習はスキップ** — 何度も学習しても1カウントのみ
2. **昨日学習かどうかで分岐** — `v_last_date = v_today - 1` の1行で判定
3. **UPSERT** — 初回学習でも既存レコードがあってもどちらも動く

## Flutter — ホームカードへの表示

```dart
// ai_university_home_card.dart
int _currentStreak = 0;

Future<void> _loadData() async {
  final streakRow = await _supabase
      .from('ai_university_streaks')
      .select('current_streak')
      .eq('user_id', user.id)
      .maybeSingle();

  setState(() {
    _currentStreak = (streakRow?['current_streak'] as num?)?.toInt() ?? 0;
  });
}

// 表示テキスト
final streakText = _currentStreak > 0 ? ' / $_currentStreak日連続' : '';
// → "12社学習済み / 7日連続"
```

## 学習完了時のストリーク更新

```dart
// gemini_university_v2_page.dart — クイズ正解時
await _supabase.rpc('update_ai_university_streak', params: {
  'p_user_id': user.id,
});
```

RPCを直接呼ぶ or EFのどちらでもOK。EF経由は `is_new_streak_day` フラグで「今日初の学習！」トーストを出せる利点がある。

## RLS (Row Level Security)

```sql
-- 自分のストリークのみ参照・更新可
CREATE POLICY "users_own_streaks"
ON ai_university_streaks
FOR ALL
USING (auth.uid() = user_id);
```

leaderboard は service_role で読み出すため、ユーザーの個人情報を除外しつつ公開ランキングを実現できます。

## まとめ

ストリークの「3行の核心」:

```sql
IF v_last_date = v_today     THEN -- 今日学習済み → スキップ
IF v_last_date = v_today - 1 THEN v_current := v_current + 1;  -- 連続
ELSE                               v_current := 1;              -- リセット
```

これだけでDuolingo的な学習継続システムが完成します。FlutterからはRPC1行で呼べるので、クライアント側のロジックはほぼゼロです。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #AILearning
