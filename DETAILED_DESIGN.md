# 自分株式会社 (Me Inc.) 詳細設計書

**Version:** 1.0.0
**Last Updated:** 2026-01-08

## 1. システムアーキテクチャ

本プロジェクトは、**Flutter (Web)** をフロントエンド、**Supabase** をBaaS (Backend as a Service) として採用したサーバーレス構成である。

### 1.1 技術スタック

* **Frontend**: Flutter Web (Channel: stable)
* **Auth**: Supabase Auth (Email/Password)
* **Database**: PostgreSQL (Supabase DB)
* **Backend Logic**: Supabase Edge Functions (Deno/TypeScript)
    * i-assistant: Gemini APIを用いたAI推論分析
* **State Management**: provider パッケージ (ChangeNotifier)

### 1.2 データフロー
```mermaid
graph LR
    User[ユーザー (CEO)] -->|操作| UI[Flutter Pages]
    UI -->|状態参照| Service[Provider Services]
    Service -->|CRUD/RPC| SupabaseSDK
    SupabaseSDK -->|Query| DB[(PostgreSQL)]
    SupabaseSDK -->|Invoke| Edge[Edge Functions]
    Edge -->|API Call| Gemini[Google Gemini API]
    Edge -->|Result| SupabaseSDK
    SupabaseSDK -->|Update| Service
    Service -->|Notify| UI
```

```mermaid
graph LR
    Root[自分株式会社]
    
    %% --- 役員定義 ---
    CEO[<b>CEO 最高執行責任者</b><br/>ユーザー本人]
    CSO[<b>CSO 最高戦略責任者</b><br/>戦略・監視]
    CFO[<b>CFO 最高財務責任者</b><br/>財務・コスト]
    CKO[<b>CKO 最高知識責任者</b><br/>知識・記録]
    CHO[<b>CHO 最高健康責任者</b><br/>健康管理]
    CMO[<b>CMO 広報・マーケティング</b><br/>分析・UI/UX]
    CHRO[<b>CHRO 人事・厚生局</b><br/>メンタル・福利厚生]
    MA[<b>M&A 合併・買収</b><br/>外部連携]

    Root --- CEO
    Root --- CSO
    Root --- CFO
    Root --- CKO
    Root --- CHO
    Root --- CMO
    Root --- CHRO
    Root --- MA

    %% --- CEOの機能 ---
    CEO --> CEO_1[緊急役員会議]
    CEO --> CEO_2[モーニングブリーフィング]

    %% --- CSOの機能 ---
    CSO --> CSO_1[AI秘書サービス]
    CSO --> CSO_2[断捨離クエスト]
    CSO --> CSO_3[リアル断捨離クエスト]
    CSO --> CSO_4[AI稼働モニター]

    %% --- CFOの機能 ---
    CFO --> CFO_1[固定費削減室]
    CFO --> CFO_2[決済チャネル台帳]
    CFO --> CFO_3[監査進捗モニター]
    CFO --> CFO_4[未監査アラート]
    CFO --> CFO_5[月次決算]

    %% --- CKOの機能 ---
    CKO --> CKO_1[Gemini大学]
    CKO --> CKO_2[メモ機能]
    CKO_2 -.- CKO_2a[文書校正]
    CKO_2 -.- CKO_2b[要約]
    CKO_2 -.- CKO_2c[アイデア拡張]
    CKO_2 -.- CKO_2d[タイトル案]

    %% --- CHOの機能 ---
    CHO --> CHO_1[健康管理室]

    %% --- CMOの機能 ---
    CMO --> CMO_1[アプリ分析]
    CMO --> CMO_2[シェア機能]
    CMO --> CMO_3[UI/UX 経営コックピット]
    CMO_3 -.- CMO_3a[ランディングページ]

    %% --- CHROの機能 ---
    CHRO --> CHRO_1[福利厚生 & メンタル機能]

    %% --- M&Aの機能 ---
    MA --> MA_1[インポート機能]
```

---

## 2. ディレクトリ構成と責務
MVVMライクな構成を採用し、ビジネスロジックを services に分離している。

* **lib/models/**: データモデル。romMap/	oMap を実装し、JSONシリアライズを担当。
    * oard_meeting_model.dart: 役員会議のログメッセージ構造定義。
    * user_stats.dart: ポイント、レベル等のユーザー統計。
* **lib/pages/**: 画面UI。Scaffold を持ち、画面遷移の単位となる。
    * home_page.dart: 経営コックピット。各機能へのハブ。
    * emergency_meeting_page.dart: BIレポート形式の会議画面。
    * 
ote_editor_page.dart: メモ作成編集AI支援。
* **lib/services/**: アプリケーションロジック状態管理。
    * gamification_service.dart: ポイント付与、レベル計算、実績解除ロジック。
    * import_service.dart: 外部データ取り込みとポイント換算。
    * 	heme_service.dart: ダークモード管理。
* **lib/widgets/**: 再利用可能なUIコンポーネント。

---

## 3. 主要機能の内部ロジック

### 3.1 緊急役員会議 (BI Report System)
チャットボットではなく、データドリブンなレポート生成システム。

1.  **Trigger**: ユーザーが EmergencyMeetingPage で「招集」ボタンを押下。
2.  **Data Collection**:
    * 並列処理 (Future.wait) で 
otes (CKO), subscriptions (CFO), user_stats (CHRO) 等の件数をCount。
3.  **Prompt Engineering**:
    * 収集した数字をコンテキストとして埋め込み、AIに「各役員のロールプレイ」と「戦略提案」を指示。
4.  **Generation**: Edge Function (i-assistant) がGeminiを呼び出し、JSON形式でレポートを生成。
5.  **Persistence**:
    * 会議本体 (oard_meetings) と発言ログ (oard_messages) をDBに保存。

### 3.2 ゲーミフィケーション (Gamification)
ユーザーの行動を即座に報酬へ結びつける。

* **Logic**: GamificationService.awardPoints(points, reason)
* **Flow**:
    1.  アクション検知 (例: メモ保存)。
    2.  wardPoints 呼び出し。
    3.  user_stats テーブルの 	otal_points を加算 (Atomic update推奨だが現在はService層で処理)。
    4.  
otifyListeners() でUI更新 (CHROオフィス等の表示反映)。

### 3.3 ナレッジ管理 (Note Management)
* **Sync**: 基本的にSupabaseを「正」とする。
* **Listing**: NoteListPage で created_at, is_pinned に基づきソートして取得。
* **AI Support**: NoteEditorPage から選択範囲または全文をAIに送信し、校正要約を行う。

---

## 4. データベース設計 (Schema Abstract)
詳細は データベース設計書 を参照。ここでは主要なリレーションのみ記述。

* users (Auth)
    * 1 : 1 -> user_stats (Gamification)
    * 1 : N -> 
otes (Knowledge)
    * 1 : N -> oard_meetings (Strategy)
        * 1 : N -> oard_messages

## 5. セキュリティ方針
* **RLS (Row Level Security)**: 全テーブルで有効化。
    * 基本ポリシー: uth.uid() == user_id のデータのみ SELECT/INSERT/UPDATE/DELETE 可能。
* **Env Vars**: APIキー (Supabase Anon Key) は lutter-dotenv またはビルド時注入で管理 (Web公開時はドメイン制限で保護)。

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