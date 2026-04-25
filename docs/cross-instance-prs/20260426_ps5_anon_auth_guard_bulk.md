# Cross-Instance PR: Bulk anon auth guard for 120 remaining pages

**From**: PS#5  
**To**: VSCode版  
**Priority**: Medium (ongoing 401 flood reduction)  
**Date**: 2026-04-26

## 背景

PS#5 S58 で発見: 130 ページが `initState` で auth-required EF を呼んでいるが anon guard なし。
`currentUser == null` の場合 401 → catch で silent fail または raw エラーが表示される。

### 修正済み (PS#5 S56-S58)

- `home_page.dart` — `_analyzeFeatureRequestAttachment`, `_submitHomeFeatureRequest`, `_fetchNotifUnreadCount`
- `gemini_university_v2_page.dart` — FSRS `getNextCards`, `getStats`  
- `notifications_page.dart` — `_fetchNotifications`
- `daily_judgment_page.dart` — `_fetchJudgment`
- `growth_weekly_digest_page.dart` — `_load`
- `ai_assistant_chat_page.dart` — `_loadHistory`
- `ai_university_badges_page.dart` — `_fetch`
- `ai_university_content_page.dart` — `_fetch`
- `ai_university_streaks_page.dart` — `_fetch`
- `support_tickets_page.dart` — `_loadTickets`
- `knowledge_base_page.dart` — `_load`
- `goal_tracker_page.dart` — `_fetchGoals`
- `habit_tracker_page.dart` — `_fetchHabits`
- `time_tracker_page.dart` — `_fetchEntries`
- `reading_list_page.dart` — `_fetchBooks`
- `calendar_events_page.dart` — `_fetchMonth`

### 残り ~120 ページ (VSCode版でバッチ修正お願い)

**修正パターン** (各ページの最初の `_fetch`/`_load` メソッド先頭に追加):

```dart
// Pattern A: _isLoading がある場合
if (_supabase.auth.currentUser == null) {
  setState(() => _isLoading = false);
  return;
}

// Pattern B: _loading がある場合
if (_supabase.auth.currentUser == null) {
  setState(() => _loading = false);
  return;
}

// Pattern C: ローディング変数がない場合
if (_supabase.auth.currentUser == null) return;
```

**検出コマンド**:
```bash
for f in lib/pages/*.dart; do
  has_init=$(grep -c "void initState" "$f")
  has_invoke=$(grep -c "functions.invoke" "$f")
  has_guard=$(grep -c "currentUser == null\|currentUser?\.id" "$f")
  if [ "$has_init" -gt 0 ] && [ "$has_invoke" -gt 0 ] && [ "$has_guard" -eq 0 ]; then
    echo "$f"
  fi
done
```

**長期対策**: main.dart のルーターに auth guard middleware を追加して、
auth-required ルートに anon user がアクセスした場合にログインページへ redirect する。
これにより各ページ個別の guard が不要になる (Rule 5: EF-FIRST に準じて共通ロジックを集約)。

## 影響

- anon ユーザーの 401 コンソールエラーが ~120 ページ分 解消
- EF への不要な呼び出しが削減され rate limit のリスク低下
