# バックエンド移行ロードマップ（詳細版）

**作成日**: 2025年11月14日
**最終更新**: 2025年11月14日
**目的**: フロントエンドロジックをSupabase Edge Functionsへ段階的に移行

---

## 📊 移行の必要性

### 現在の問題
1. **セキュリティリスク**: ビジネスロジックがクライアント側に露出
2. **不正防止**: ポイントやアチーブメントの改ざんが可能
3. **パフォーマンス**: 複雑な計算をクライアント側で実行
4. **データ整合性**: 同時アクセス時の競合状態
5. **保守性**: ロジックの重複（Web、iOS、Android）

### 移行後のメリット
✅ セキュリティ強化（不正防止）
✅ パフォーマンス向上（サーバー側で高速処理）
✅ データ整合性の保証
✅ コード重複の削減
✅ テストの容易性

---

## 🎯 移行優先順位

### 🔴 Critical（最優先）

#### 1. ゲーミフィケーション計算
**理由**: 不正なポイント獲得を防ぐため必須
**現在の場所**: `lib/services/gamification_service.dart`
**影響**: セキュリティ、データ整合性

#### 2. リーダーボード集計
**理由**: パフォーマンス向上、リアルタイム性
**現在の場所**: `lib/services/gamification_service.dart`
**影響**: パフォーマンス、ユーザー体験

#### 3. アクティビティフィード
**理由**: リアルタイムデータが必要
**現在の場所**: `lib/pages/activity_feed_page.dart`
**影響**: 機能の正常動作

### 🟡 High（高優先）

#### 4. 互換性スコア計算
**理由**: データ整合性、アルゴリズムの保護
**現在の場所**: `lib/services/compatibility_service.dart`
**影響**: データ整合性

#### 5. デイリーチャレンジ判定
**理由**: 不正なクリア防止
**現在の場所**: `lib/services/daily_challenge_service.dart`
**影響**: セキュリティ

### 🟢 Medium（中優先）

#### 6. メモカード画像生成
**理由**: サーバー側で高品質レンダリング
**現在の場所**: `lib/widgets/share_note_card_dialog.dart`
**影響**: 画質、パフォーマンス

#### 7. Import処理
**理由**: 大量データ処理の効率化
**現在の場所**: `lib/services/import_service.dart`
**影響**: パフォーマンス

---

## 📅 段階的移行計画

### フェーズ1: ゲーミフィケーション移行（週1-2）

#### 1.1 ポイント付与のバックエンド化

**目標**: クライアント側のポイント計算を廃止

**データベース関数**:
```sql
-- supabase/migrations/20251114120000_gamification_backend.sql

-- ポイント付与関数
CREATE OR REPLACE FUNCTION record_activity(
    p_user_id UUID,
    p_activity_type TEXT,
    p_metadata JSONB DEFAULT '{}'::JSONB
) RETURNS JSON AS $$
DECLARE
    v_points INT;
    v_old_level INT;
    v_new_level INT;
    v_level_up BOOLEAN := FALSE;
    v_achievements JSON[];
BEGIN
    -- ユーザー統計を取得
    SELECT level INTO v_old_level
    FROM user_stats
    WHERE user_id = p_user_id;

    -- アクティビティタイプからポイントを決定
    v_points := CASE p_activity_type
        WHEN 'note_created' THEN 10
        WHEN 'note_updated' THEN 5
        WHEN 'note_deleted' THEN -5
        WHEN 'category_created' THEN 15
        WHEN 'achievement_unlocked' THEN 50
        WHEN 'daily_challenge_completed' THEN 100
        WHEN 'personality_test_completed' THEN 200
        WHEN 'share_note' THEN 20
        WHEN 'invite_friend' THEN 500
        ELSE 0
    END;

    -- ユーザー統計を更新
    UPDATE user_stats
    SET
        total_points = total_points + v_points,
        level = FLOOR((total_points + v_points) / 100.0) + 1,
        updated_at = NOW()
    WHERE user_id = p_user_id
    RETURNING level INTO v_new_level;

    -- レベルアップチェック
    IF v_new_level > v_old_level THEN
        v_level_up := TRUE;

        -- レベルアップボーナス
        UPDATE user_stats
        SET total_points = total_points + (v_new_level * 50)
        WHERE user_id = p_user_id;
    END IF;

    -- アクティビティを記録
    INSERT INTO activities (user_id, activity_type, points, metadata)
    VALUES (p_user_id, p_activity_type, v_points, p_metadata);

    -- アチーブメントチェック
    v_achievements := check_achievements(p_user_id, p_activity_type, p_metadata);

    -- 結果を返す
    RETURN json_build_object(
        'points', v_points,
        'total_points', (SELECT total_points FROM user_stats WHERE user_id = p_user_id),
        'old_level', v_old_level,
        'new_level', v_new_level,
        'level_up', v_level_up,
        'achievements', v_achievements
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Edge Function**:
```typescript
// supabase/functions/record-activity/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from '@supabase/supabase-js'

interface ActivityRequest {
  activityType: string
  metadata?: Record<string, any>
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')!
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    // ユーザー認証チェック
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    }

    const { activityType, metadata = {} }: ActivityRequest = await req.json()

    // データベース関数を呼び出し
    const { data, error } = await supabaseClient.rpc('record_activity', {
      p_user_id: user.id,
      p_activity_type: activityType,
      p_metadata: metadata
    })

    if (error) throw error

    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

**フロントエンド更新**:
```dart
// lib/services/gamification_service.dart（簡略化版）
class GamificationService {
  final SupabaseClient _supabase;

  GamificationService(this._supabase);

  /// アクティビティを記録（バックエンド呼び出し）
  Future<GamificationResult> recordActivity(
    String activityType, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.functions.invoke('record-activity',
        body: {
          'activityType': activityType,
          'metadata': metadata ?? {},
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to record activity: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      return GamificationResult(
        points: data['points'] as int,
        totalPoints: data['total_points'] as int,
        oldLevel: data['old_level'] as int,
        newLevel: data['new_level'] as int,
        levelUp: data['level_up'] as bool,
        achievements: (data['achievements'] as List<dynamic>?)
            ?.map((a) => Achievement.fromJson(a))
            .toList() ?? [],
      );
    } catch (e) {
      print('Error recording activity: $e');
      rethrow;
    }
  }
}
```

**推定時間**: 4-6時間
**テスト時間**: 2-3時間

---

#### 1.2 アチーブメントチェックのバックエンド化

**データベース関数**:
```sql
-- アチーブメントチェック関数
CREATE OR REPLACE FUNCTION check_achievements(
    p_user_id UUID,
    p_activity_type TEXT,
    p_metadata JSONB
) RETURNS JSON[] AS $$
DECLARE
    v_unlocked_achievements JSON[] := ARRAY[]::JSON[];
    v_achievement RECORD;
    v_user_stats RECORD;
BEGIN
    -- ユーザー統計を取得
    SELECT * INTO v_user_stats
    FROM user_stats
    WHERE user_id = p_user_id;

    -- 各アチーブメントの条件をチェック
    FOR v_achievement IN
        SELECT id, code, type, requirement, requirement_value
        FROM achievements
        WHERE NOT EXISTS (
            SELECT 1 FROM user_achievements
            WHERE user_id = p_user_id AND achievement_id = achievements.id
        )
    LOOP
        -- アチーブメントの条件を評価
        IF evaluate_achievement_condition(
            v_achievement,
            v_user_stats,
            p_activity_type,
            p_metadata
        ) THEN
            -- アチーブメントを解除
            INSERT INTO user_achievements (user_id, achievement_id, unlocked_at)
            VALUES (p_user_id, v_achievement.id, NOW());

            -- 配列に追加
            v_unlocked_achievements := array_append(
                v_unlocked_achievements,
                row_to_json(v_achievement)
            );

            -- ボーナスポイント付与
            UPDATE user_stats
            SET total_points = total_points + 50
            WHERE user_id = p_user_id;
        END IF;
    END LOOP;

    RETURN v_unlocked_achievements;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- アチーブメント条件評価関数
CREATE OR REPLACE FUNCTION evaluate_achievement_condition(
    p_achievement RECORD,
    p_user_stats RECORD,
    p_activity_type TEXT,
    p_metadata JSONB
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN CASE p_achievement.type
        WHEN 'note_count' THEN
            p_user_stats.total_notes >= p_achievement.requirement_value
        WHEN 'points_total' THEN
            p_user_stats.total_points >= p_achievement.requirement_value
        WHEN 'level_reached' THEN
            p_user_stats.level >= p_achievement.requirement_value
        WHEN 'daily_streak' THEN
            p_user_stats.current_streak >= p_achievement.requirement_value
        WHEN 'specific_activity' THEN
            p_activity_type = p_achievement.requirement
        ELSE FALSE
    END;
END;
$$ LANGUAGE plpgsql;
```

**推定時間**: 3-4時間

---

### フェーズ2: リーダーボード移行（週2）

#### 2.1 Materialized Viewの作成

**目的**: リーダーボード取得のパフォーマンス向上

```sql
-- supabase/migrations/20251114130000_leaderboard_view.sql

-- リーダーボードView
CREATE MATERIALIZED VIEW leaderboard AS
SELECT
    us.user_id,
    p.display_name,
    p.avatar_url,
    us.level,
    us.total_points,
    us.total_notes,
    us.current_streak,
    us.best_streak,
    ROW_NUMBER() OVER (ORDER BY us.total_points DESC, us.level DESC) AS rank
FROM user_stats us
JOIN profiles p ON us.user_id = p.user_id
ORDER BY us.total_points DESC
LIMIT 100;

-- インデックス作成
CREATE UNIQUE INDEX leaderboard_user_id_idx ON leaderboard(user_id);
CREATE INDEX leaderboard_rank_idx ON leaderboard(rank);

-- 定期更新（1時間ごと）
CREATE OR REPLACE FUNCTION refresh_leaderboard()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard;
END;
$$ LANGUAGE plpgsql;

-- Cron Jobの設定（pg_cronが有効な場合）
-- SELECT cron.schedule('refresh-leaderboard', '0 * * * *', 'SELECT refresh_leaderboard()');
```

**Edge Function**:
```typescript
// supabase/functions/leaderboard/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from '@supabase/supabase-js'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // URLパラメータ
    const url = new URL(req.url)
    const limit = parseInt(url.searchParams.get('limit') || '50')
    const offset = parseInt(url.searchParams.get('offset') || '0')

    // リーダーボード取得
    const { data, error } = await supabaseClient
      .from('leaderboard')
      .select('*')
      .range(offset, offset + limit - 1)

    if (error) throw error

    return new Response(JSON.stringify(data), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

**推定時間**: 2-3時間

---

### フェーズ3: アクティビティフィード移行（週3）

#### 3.1 Realtime対応

```sql
-- supabase/migrations/20251114140000_activity_feed.sql

-- アクティビティテーブル
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    points INT DEFAULT 0,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス
CREATE INDEX activities_user_id_idx ON activities(user_id);
CREATE INDEX activities_created_at_idx ON activities(created_at DESC);
CREATE INDEX activities_type_idx ON activities(activity_type);

-- RLSポリシー
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- 全員が閲覧可能（公開フィード）
CREATE POLICY "Anyone can view activities"
ON activities FOR SELECT
USING (true);

-- 自分のアクティビティのみ作成可能（実際はEdge Functionから）
CREATE POLICY "Users can create their own activities"
ON activities FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- アクティビティフィードView（最新50件）
CREATE VIEW recent_activities AS
SELECT
    a.id,
    a.activity_type,
    a.points,
    a.metadata,
    a.created_at,
    p.display_name AS user_name,
    p.avatar_url AS user_avatar,
    us.level AS user_level
FROM activities a
JOIN profiles p ON a.user_id = p.user_id
JOIN user_stats us ON a.user_id = us.user_id
ORDER BY a.created_at DESC
LIMIT 50;

-- Realtime有効化
ALTER publication supabase_realtime ADD TABLE activities;
```

**フロントエンド更新**:
```dart
// lib/services/activity_feed_service.dart
class ActivityFeedService {
  final SupabaseClient _supabase;
  RealtimeChannel? _subscription;

  ActivityFeedService(this._supabase);

  /// アクティビティフィードをリアルタイム購読
  Stream<List<Activity>> subscribeToActivities() {
    final controller = StreamController<List<Activity>>();

    // 初回ロード
    _loadActivities().then((activities) {
      controller.add(activities);
    });

    // Realtime購読
    _subscription = _supabase
        .channel('public:activities')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'activities',
          callback: (payload) async {
            // 新しいアクティビティを先頭に追加
            final activities = await _loadActivities();
            controller.add(activities);
          },
        )
        .subscribe();

    return controller.stream;
  }

  Future<List<Activity>> _loadActivities() async {
    final response = await _supabase
        .from('recent_activities')
        .select()
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((json) => Activity.fromJson(json))
        .toList();
  }

  void dispose() {
    _subscription?.unsubscribe();
  }
}
```

**推定時間**: 3-4時間

---

## 📊 移行進捗トラッキング

| フェーズ | 機能 | 推定時間 | 優先度 | ステータス | 完了予定 |
|---------|------|---------|--------|----------|---------|
| 1.1 | ポイント付与 | 4-6h | 🔴 Critical | ⏳ 未着手 | Week 1 |
| 1.2 | アチーブメント | 3-4h | 🔴 Critical | ⏳ 未着手 | Week 1 |
| 2.1 | リーダーボード | 2-3h | 🔴 Critical | ⏳ 未着手 | Week 2 |
| 3.1 | アクティビティフィード | 3-4h | 🔴 Critical | ⏳ 未着手 | Week 3 |
| 4.1 | 互換性スコア | 2-3h | 🟡 High | ⏳ 未着手 | Week 4 |
| 5.1 | デイリーチャレンジ | 2-3h | 🟡 High | ⏳ 未着手 | Week 5 |
| 6.1 | 画像生成 | 4-5h | 🟢 Medium | ⏳ 未着手 | Week 6 |

**総推定時間**: 20-28時間

---

## ✅ 成功基準

### セキュリティ
- [ ] ビジネスロジックがサーバーサイドに移行
- [ ] クライアント側からのポイント改ざんが不可能
- [ ] 全APIエンドポイントに認証チェック

### パフォーマンス
- [ ] リーダーボード取得が0.5秒以下
- [ ] アクティビティフィードがリアルタイム更新
- [ ] ポイント付与の応答時間が1秒以下

### データ整合性
- [ ] 同時アクセス時の競合状態が発生しない
- [ ] トランザクションが保証される
- [ ] データの不整合が発生しない

---

**作成者**: Claude Code
**承認**: プロジェクトオーナー
**次回レビュー**: フェーズ1完了後
