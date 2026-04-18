---
title: "Flutter × Supabase でランキング・リーダーボードを作った — AI大学の裏側"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: true
---

# Flutter × Supabase でランキング・リーダーボードを作った — AI大学の裏側

## はじめに

自分株式会社 AI大学にランキングページ (`/ai-university-ranking`) を実装しました。クイズ正解数でユーザーをランキング表示し、公開バッジも一覧表示します。ストリーク・バッジに続くゲーミフィケーション3本目です。

## アーキテクチャ

```
ai_university_leaderboard (PostgreSQL ビュー)
  ↓  TOP10 を rank 昇順で取得
AiUniversityRankingPage (Flutter)
  + _LeaderboardEntry モデル
  + _loadPublicBadges (他ユーザーの公開バッジ)
  + _loadMySnapshot (自分のランキング位置)
```

## PostgreSQL ビュー — ai_university_leaderboard

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
) sub
ORDER BY rank;
```

`ROW_NUMBER()` で順位を自動付与。`total_correct` → `providers_studied` の優先順で並べます。

## Flutter — データ取得

```dart
// TOP10 を rank 昇順で取得
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

0スコアのユーザーは `.where()` でフィルタ。

## 並列データ取得 (公開バッジ + 自分のスナップショット)

```dart
// ランキングユーザーの公開バッジ + 自分の位置を並列取得
final leaderboardUserIds = entries.map((e) => e.userId).toList();
final badgesFuture    = _loadPublicBadges(leaderboardUserIds);
final mySnapshotFuture = _myUserId == null
    ? Future.value(null)
    : _loadMySnapshot(_myUserId!);

final badgesByUser = await badgesFuture;
final mySnapshot   = await mySnapshotFuture;
```

`Future` を先に起動してから `await` することで、2つのDBクエリを並列実行します。

## 公開バッジ取得

```dart
Future<Map<String, List<_BadgeEntry>>> _loadPublicBadges(List<String> userIds) async {
  if (userIds.isEmpty) return {};
  final rows = await _supabase
      .from('ai_university_badges')
      .select('user_id, badge_id, badge_name, icon_emoji')
      .in_('user_id', userIds)
      .eq('is_public', true);

  final result = <String, List<_BadgeEntry>>{};
  for (final row in rows as List) {
    final userId = row['user_id'] as String;
    result.putIfAbsent(userId, () => []).add(_BadgeEntry.fromMap(row));
  }
  return result;
}
```

`is_public = true` のバッジのみ表示。ユーザーはバッジを非公開にできます。

## ランキング表示 UI

```dart
// 1位: 🥇 / 2位: 🥈 / 3位: 🥉 / 4位以降: #N
static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};

Color get _rankColor {
  switch (rank) {
    case 1: return const Color(0xFFFFD700); // gold
    case 2: return const Color(0xFFC0C0C0); // silver
    case 3: return const Color(0xFFCD7F32); // bronze
    default: return const Color(0xFF6366F1); // indigo
  }
}
```

## 自分のランキング位置表示

ログイン中ユーザーの位置を TOP10 外でも表示:

```dart
// ai_university_scores から自分のスコアを取得
final myRow = await _supabase
    .from('ai_university_leaderboard')
    .select()
    .eq('user_id', userId)
    .maybeSingle();

// TOP10 外ならフッターに「あなたは現在 X 位です」を表示
if (myEntry != null) {
  summaryTitle = 'あなたは現在 ${myEntry.rank} 位です';
}
```

## まとめ

ランキングの3要素:
1. **ビュー側で順位計算** — `ROW_NUMBER()` でFlutter側のソートロジックなし
2. **並列クエリ** — バッジ + 自分のスナップショットを同時取得
3. **is_public フィルタ** — プライバシー制御を1カラムで実現

ストリーク → バッジ → ランキングの3機能で「学習 → 競争 → 継続」のループが完成しました。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #Gamification
