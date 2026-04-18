---
title: "Flutter × Supabase でバッジ・実績システムを作った — AI大学の裏側"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: true
---

# Flutter × Supabase でバッジ・実績システムを作った — AI大学の裏側

## はじめに

自分株式会社の AI大学に「バッジ・実績システム」を実装しました。

- 🔥 3日連続学習 → `streak_3d` バッジ付与
- 🏆 7日連続学習 → `streak_7d` バッジ付与
- 🎓 3社クイズ正解 → `quiz_master_3` バッジ付与
- 🌟 全社クイズ正解 → `quiz_master_all` バッジ付与
- 📣 学習シェア → `social_sharer` バッジ付与 (クライアント駆動)

バッジ数はホームカードに「バッジ 3個」と表示されます。

## アーキテクチャ

`ai-university-badges` Edge Function が中心。7つのアクションを1本のEFに統合:

| action | 用途 |
|--------|------|
| `award` | 手動でバッジ付与 (シェアイベント等) |
| `list` | バッジ一覧取得 |
| `check_streaks` | ストリーク条件を評価してバッジ自動付与 |
| `check_quiz_master` | クイズ正解数を評価してバッジ自動付与 |
| `record_score` | クイズ結果記録 + バッジ自動チェック |
| `leaderboard` | バッジ保有数ランキング |
| `score_leaderboard` | クイズ正解数ランキング |

## バッジ定義 (TypeScript)

```typescript
const STREAK_BADGES = [
  { badge_id: "streak_3d",  badge_name: "3日連続学習",  icon_emoji: "🔥", condition: "3日以上連続学習" },
  { badge_id: "streak_7d",  badge_name: "1週間連続学習", icon_emoji: "🏆", condition: "7日以上連続学習" },
  { badge_id: "streak_30d", badge_name: "1ヶ月連続学習", icon_emoji: "💎", condition: "30日以上連続学習" },
];
const QUIZ_MASTER_3   = { badge_id: "quiz_master_3",   badge_name: "クイズマスター(3社)",   icon_emoji: "🎓", condition: "3社以上正解" };
const QUIZ_MASTER_ALL = { badge_id: "quiz_master_all",  badge_name: "AI大学卒業",           icon_emoji: "🌟", condition: "全社正解" };
```

## ストリーク → バッジ自動付与 (check_streaks)

```typescript
// POST { action: "check_streaks" }
// ストリーク日数を取得し、条件を満たすバッジを自動付与
const { data: streakData } = await supabase
  .from("ai_university_streaks")
  .select("current_streak")
  .eq("user_id", user.id)
  .maybeSingle();

const currentStreak = streakData?.current_streak ?? 0;
const awarded: string[] = [];

for (const badge of STREAK_BADGES) {
  const threshold = badge.badge_id === "streak_3d" ? 3 : badge.badge_id === "streak_7d" ? 7 : 30;
  if (currentStreak >= threshold) {
    const { data: r } = await supabase.rpc("award_ai_university_badge", {
      p_user_id: user.id,
      p_badge_id: badge.badge_id,
      p_badge_name: badge.badge_name,
      p_icon_emoji: badge.icon_emoji,
      p_condition: badge.condition,
    });
    if (r === true) awarded.push(badge.badge_id); // newly_awarded のみ追加
  }
}

return json({ success: true, current_streak: currentStreak, awarded });
```

`award_ai_university_badge` RPC は「既に持っているバッジは重複付与しない」設計なので、毎日呼んでも安全です。

## クイズ正解 → バッジ付与 (record_score)

```typescript
// POST { action: "record_score", provider_id, quiz_correct }
// クイズ結果を記録し、初めて正解したタイミングでクイズマスターバッジを評価

const upsertResult = await supabase
  .from("ai_university_scores")
  .upsert({ user_id: user.id, provider_id, quiz_correct, studied_at: new Date().toISOString() },
           { onConflict: "user_id,provider_id" })
  .select()
  .single();

// 初めて quiz_correct=true になった場合のみバッジ評価
if (quiz_correct && isNewlyCorrect) {
  // check_quiz_master を内部呼び出し
  const awardedBadges = await checkQuizMaster(supabase, user.id);
  return json({ success: true, awarded_badges: awardedBadges });
}
```

クイズに正解するたびに全プロバイダー数と比較し、3社達成・全社達成のタイミングでバッジを付与します。

## PostgreSQL RPC — award_ai_university_badge

重複付与防止はDB側で保証:

```sql
CREATE OR REPLACE FUNCTION award_ai_university_badge(
  p_user_id UUID, p_badge_id TEXT, p_badge_name TEXT,
  p_icon_emoji TEXT DEFAULT NULL, p_condition TEXT DEFAULT NULL
)
RETURNS BOOLEAN  -- TRUE = 新規付与, FALSE = 既存
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO ai_university_badges (user_id, badge_id, badge_name, icon_emoji, condition)
  VALUES (p_user_id, p_badge_id, p_badge_name, p_icon_emoji, p_condition)
  ON CONFLICT (user_id, badge_id) DO NOTHING;

  RETURN FOUND;  -- INSERT が実行されたか (= 新規付与か)
END;
$$;
```

`FOUND` 擬似変数は `ON CONFLICT DO NOTHING` のとき `FALSE` を返すので、「新規付与かどうか」を1行で判定できます。

## Flutter — バッジ数をホームカードに表示

```dart
// ai_university_home_card.dart
int _badgeCount = 0;

Future<void> _loadData() async {
  final badgeRow = await _supabase
      .from('ai_university_badges')
      .select('id')
      .eq('user_id', user.id)
      .count(CountOption.exact);

  setState(() {
    _badgeCount = badgeRow.count;
  });
}
```

`.count(CountOption.exact)` で件数だけ取得。実際のバッジ内容は詳細ページで表示します。

## Flutter — クライアント駆動バッジ (social_sharer)

シェアボタン押下時に `award` アクションを呼ぶ:

```dart
// シェア完了後
await _supabase.functions.invoke('ai-university-badges', body: {
  'action': 'award',
  'badge_id': 'social_sharer',
  'badge_name': '学習シェアマスター',
  'icon_emoji': '📣',
  'condition': '学習進捗をシェア',
});
```

## まとめ

バッジシステムの設計ポイント:
1. **DB側で重複排除** — `ON CONFLICT DO NOTHING` + `FOUND` で冪等に
2. **条件評価はEF内で** — ストリーク/クイズ両方を1本のEFに集約
3. **クライアント駆動とサーバー駆動を混在** — シェアは即時付与、連続学習は定期チェック

これで「学習 → バッジ → シェア → 新ユーザー獲得」のバイラルループが完成します。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #Gamification
