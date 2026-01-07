# データベース設計書 (Database Schema)

全体のテーブル定義を機能ドメインごとに分割して記載しています。

## 1. ユーザー & プロフィール (User Core)
ユーザーの基本情報、認証、プロフィール、統計データ。

```mermaid
erDiagram
    users ||--|| user_profiles : "1:1 profile"
    users ||--|| user_stats : "1:1 stats"
    users ||--|| user_onboarding : "1:1 onboarding"
    users ||--|{ subscriptions : "has"
    users ||--|{ payment_sources : "has"
    user_profiles ||--|{ user_follows : "follows/followers"
    user_profiles ||--|{ user_supporters : "supported by"

    user_profiles { UUID user_id PK "FK -> auth.users" text display_name text role integer trust_score }
    user_stats { UUID id PK integer total_points integer current_level integer current_streak }
    user_onboarding { UUID id PK boolean tutorial_completed boolean first_note_created }
    subscriptions { UUID id PK text service_name numeric price }
    payment_sources { UUID id PK text name timestamp last_audited_at }
    user_follows { UUID id PK UUID follower_id UUID following_id }
    user_supporters { UUID id PK text supporter_name boolean is_active }
```

## 2. 知識 & メモ (Knowledge & Notes)
CKO管轄。メモ、カテゴリ、添付ファイル、共有機能。

```mermaid
erDiagram
    notes }|--|| categories : "categorized by"
    notes ||--|{ attachments : "contains"
    notes ||--o| public_memos : "published as"
    notes ||--o| note_likes : "liked by"
    notes ||--o| note_comments : "commented by"
    notes ||--o| shared_notes : "shared via"
    notes ||--o| timers : "tracked by"

    notes { UUID id PK text title text content boolean is_archived boolean is_pinned }
    categories { UUID id PK text name text color }
    attachments { UUID id PK text file_name text file_path bigint file_size }
    public_memos { UUID id PK integer like_count integer view_count boolean is_public }
    shared_notes { UUID id PK text share_token text permission }
    note_likes { UUID id PK UUID user_id FK }
    note_comments { UUID id PK UUID user_id FK text content }
```

## 3. 戦略 & AI (Strategy & AI Agents)
CEO/CSO管轄。役員会議、AIログ、ベンチマーク。

```mermaid
erDiagram
    board_meetings ||--|{ board_messages : "contains"
    users ||--|{ board_meetings : "holds"
    users ||--|{ ai_usage_log : "generates"
    users ||--|{ ai_request_logs : "debugs"
    users ||--|{ ai_benchmark_results : "tests"

    board_meetings { UUID id PK text topic text conclusion }
    board_messages { UUID id PK text speaker_name text role text content }
    ai_usage_log { UUID id PK text action integer total_tokens numeric cost_estimate }
    ai_request_logs { UUID id PK text provider text model integer duration_ms }
    ai_benchmark_results { UUID id PK text model_name integer vision_score }
```

## 4. ゲーミフィケーション & 厚生 (Gamification & Welfare)
CHO/CHRO管轄。習慣化、実績、アイテム、厚生施設。

```mermaid
erDiagram
    daily_challenges ||--o{ user_daily_challenges : "assigned to"
    daily_challenges ||--o{ user_challenge_progress : "tracked by"
    users ||--|{ user_achievements : "unlocks"
    users ||--|{ user_inventory : "owns"
    user_inventory }|--|| welfare_items : "item detail"
    users ||--|{ daily_login_rewards : "receives"
    users ||--|{ penalty_logs : "penalized"

    daily_challenges { UUID id PK text challenge_title integer reward_points }
    user_daily_challenges { UUID id PK boolean is_completed boolean reward_claimed }
    user_achievements { UUID id PK UUID achievement_id boolean is_unlocked }
    welfare_items { UUID id PK text name integer cost text effect_type }
    user_inventory { UUID id PK boolean is_used }
    daily_login_rewards { UUID id PK integer consecutive_days }
```

## 5. その他ログ & 分析 (Logs & Analytics)
CMO/System管轄。

```mermaid
erDiagram
    site_statistics { UUID id PK integer active_users_today }
    growth_metrics { UUID id PK integer total_users }
    page_views { UUID id PK text page_path }
    app_analytics { date date integer landing_views }
    activity_logs { UUID id PK text action text type }
```

### 修正のポイント
1.  **5つのカテゴリに分割**: 関連するテーブルごとに図を分けたので、1つ1つの図が小さく、プレビューでもはっきり見えるようになります。
2.  **重要なカラムのみ表示**: 全カラムを表示すると長くなるため、主要なカラム（ID, 名前, ステータス等）に絞って表示する記述に簡略化しました（実際のカラム定義はSupabase側にありますが、概念図としてはこれで十分です）。