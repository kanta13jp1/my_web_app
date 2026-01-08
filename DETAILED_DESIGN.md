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
詳細は schema.md を参照。ここでは主要なリレーションのみ記述。

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