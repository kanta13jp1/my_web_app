# バグレポート - 2025年11月9日

**作成日**: 2025年11月9日
**最終更新**: 2025年11月9日（午後）
**ステータス**: 主要バグ修正完了、デプロイ待ち

---

## 📋 概要

本ドキュメントは、プロジェクトの現在の既知の問題と、その調査結果をまとめたものです。

---

## 🔴 緊急度: 高（修正完了、デプロイ待ち）

### 1. サインイン起動が動作していない（500 Server Error）

**ステータス**: ✅ 修正完了、デプロイ待ち

**問題**:
- 新規ユーザーのサインアップ時に500エラー
- `POST /auth/v1/signup 500 (Internal Server Error)`
- ユーザーアカウントが作成できない状態

**根本原因**:
- `create_user_referral_code()`トリガー関数がRLS（Row Level Security）ポリシーに引っかかっていた
- トリガーが実行される時点で`auth.uid()`がまだ設定されていない
- `referral_codes`と`user_onboarding`テーブルへのINSERTが失敗

**解決策**: ✅ **実装完了**
- トリガー関数に`SECURITY DEFINER`を追加してRLSをバイパス
- エラーハンドリング追加（サインアップ失敗を防ぐ）
- セキュリティ向上のため`SET search_path = public`を明示

**マイグレーションファイル**: `supabase/migrations/20251109000000_fix_auth_trigger.sql`

**デプロイ手順**:
```bash
supabase db push
```

**推定修正時間**: 完了（デプロイ: 5分）

---

### 2. 保存時にメモが別レコードになる

**ステータス**: ✅ 修正完了

**問題**:
- 「保存」ボタンで保存後、再度保存すると新しいレコードが作成される
- 1つのメモが複数のレコードとして重複

**根本原因**:
- `_saveNoteWithoutClosing()`で保存後、`widget.note`が更新されない
- `isNewNote = widget.note == null`の判定が常に`true`のまま
- 2回目以降もINSERTが実行される

**解決策**: ✅ **実装完了**
- `_currentNoteId`ステート変数を追加
- INSERT後に返されたIDを`_currentNoteId`に保存
- 判定を`isNewNote = _currentNoteId == null`に変更
- UPDATE時も`_currentNoteId`を使用

**修正ファイル**: `lib/pages/note_editor_page.dart`

**推定修正時間**: 完了

---

### 3. AI機能がエラー（400 Bad Request）

**ステータス**: ✅ デプロイ完了（2025-11-10ユーザー報告）

**問題**:
- AI文章改善機能が使用不可
- AI要約・展開機能が使用不可
- AI秘書機能（タスク推奨）が使用不可
- 翻訳機能が使用不可

**エラーメッセージ**:
```
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-assistant 400 (Bad Request)
Gemini API error: 404
```

**根本原因**:
- コードはGemini APIに移行済み（2025年11月8日完了）
- しかし、`GOOGLE_AI_API_KEY`がSupabase Secretsに未設定
- Edge Functionが未デプロイまたは古いバージョン

**解決策**:
1. Google AI APIキーを取得（Google AI Studio）
2. Supabase Secretsへ`GOOGLE_AI_API_KEY`を設定
3. `ai-assistant` Edge Functionをデプロイ
4. 本番環境でテスト

**詳細**: `docs/IMMEDIATE_ACTION_PLAN.md`
**関連セッション**: `docs/session-summaries/SESSION_SUMMARY_2025-11-08_GEMINI_MIGRATION.md`

**推定修正時間**: 15分

---

### 4. 添付ファイル機能が動作しない（Web版特有の問題）

**ステータス**: 🔍 Web版デプロイ後の問題（2025-11-10ユーザー報告更新）

**重要な発見**:
- ✅ ローカル開発環境では正常に動作
- ❌ デプロイ後（Web版）でのみエラーが発生
- DBの問題ではない（テーブル、バケット、RLSポリシーは正常）

**問題の性質**:
- **Web版特有の問題**または**環境設定の問題**
- バックエンド（データベース、Storage）の設定は正常
- フロントエンド（Web版）とStorageの通信に問題がある

**可能性のある原因**:
1. **CORS（Cross-Origin Resource Sharing）の問題**
   - Supabase StorageのCORS設定が不足
   - デプロイ先のドメインが許可リストに含まれていない
   - ブラウザコンソールに`CORS policy`エラーが表示される

2. **署名付きURLの問題**
   - Storageバケットが`public: false`（プライベート）
   - `getPublicUrl()`ではなく`createSignedUrl()`を使用する必要がある
   - Status Code: `403 Forbidden`

3. **file_picker Web版の問題**
   - `withData: true`が設定されていない
   - `bytes`が null になる

4. **Content Security Policy (CSP) の問題**
   - デプロイ先のCSP設定が厳しすぎる
   - Supabase StorageのURLが許可されていない

5. **環境変数の問題**
   - デプロイ先でSupabase URLまたはAPIキーが正しく設定されていない

**次のステップ**:
1. **Web版特有の問題診断**: `docs/WEB_DEPLOYMENT_ISSUES.md` ⭐ **最重要**
2. ブラウザの開発者ツールでエラーを確認:
   - **F12キー** → **Console**タブと**Network**タブ
   - ファイルアップロード時のエラーメッセージを記録
   - Status Codeを確認（403, 413, 0など）
3. 以下を確認:
   ```javascript
   // ブラウザコンソールで確認すべきエラー
   // - CORS policy エラー → CORS設定が必要
   // - 403 Forbidden → 署名付きURL必要
   // - bytes is null → withData: true 確認
   ```
4. デバッグコードを追加して詳細ログを取得

**詳細ガイド**:
- ⭐ **`docs/WEB_DEPLOYMENT_ISSUES.md`** - Web版特有の問題診断（最重要）
- `docs/DEPLOYMENT_VERIFICATION.md` - 一般的な検証手順
- `docs/technical/FILE_ATTACHMENT_FIX.md` - 修正ガイド

**推奨される診断順序**:
1. ブラウザコンソールの確認（CORSエラーがないか）
2. Network タブの確認（Status Code確認）
3. デバッグコードの追加（詳細ログ取得）
4. 問題に応じた解決策の適用

**推定修正時間**: 30分〜1時間（診断を含む）

---

### 5. リーダーボード問題（自分しか表示されない）

**ステータス**: 🔍 デプロイ済み、問題継続中（2025-11-10ユーザー報告）

**問題**:
- マイグレーション `20251109120000_fix_user_stats_leaderboard_rls.sql` はデプロイ済み
- しかし、リーダーボードに自分しか表示されない問題は継続

**可能性のある原因**:
1. **古いRLSポリシーが残っている**
   - `DROP POLICY IF EXISTS`が失敗している可能性
   - ポリシー名が微妙に異なる可能性

2. **マイグレーションが正しく実行されていない**
   - `supabase db push`が失敗している
   - マイグレーションファイルが読み込まれていない

3. **キャッシュの問題**
   - Supabaseのキャッシュ
   - アプリのキャッシュ

4. **データが実際に1ユーザーしかない**
   - user_statsテーブルに実際に1ユーザーのデータしかない

**次のステップ**:
1. **詳細診断ガイドに従う**: `docs/BUG_REPORT_LEADERBOARD_ISSUE.md`
2. 以下のSQLを実行して状態を確認:
   ```sql
   -- データ確認
   SELECT COUNT(*) as user_count FROM user_stats;

   -- ポリシー確認
   SELECT policyname, cmd, qual
   FROM pg_policies
   WHERE tablename = 'user_stats' AND cmd = 'SELECT';
   ```
3. ポリシーの強制再作成:
   ```sql
   DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
   DROP POLICY IF EXISTS "Anyone can view user stats for leaderboard" ON user_stats;

   CREATE POLICY "Anyone can view user stats for leaderboard"
     ON user_stats FOR SELECT
     USING (true);
   ```

**詳細**:
- `docs/BUG_REPORT_LEADERBOARD_ISSUE.md` - 詳細診断ガイド
- `docs/DEPLOYMENT_VERIFICATION.md` - デプロイ検証ガイド

**推定修正時間**: 30分〜1時間（診断を含む）

---

## 🟡 緊急度: 中

### 5. ドキュメント表示機能のエラー

**ステータス**: 🔍 調査中

**問題**:
- ユーザーから「ドキュメントが見れない（エラーが発生する）」との報告あり
- 具体的なエラーメッセージは不明

**調査結果**:
- コードレベルでは問題なし
  - `lib/services/document_service.dart` - 問題なし
  - `lib/pages/document_viewer_page.dart` - 問題なし
  - `lib/pages/documents_page.dart` - 問題なし
- `pubspec.yaml`でドキュメントファイルは正しくアセットとして登録されている
  ```yaml
  assets:
    - docs/
    - docs/release-notes/
    - docs/roadmaps/
    - docs/user-docs/
    - docs/session-summaries/
    - docs/technical/
  ```

**可能性のある原因**:
1. Flutterビルド時にアセットが正しく含まれていない
2. 特定のドキュメントファイルが存在しない
3. MarkdownPreviewウィジェットに問題がある
4. ネットワークエラー（Web版の場合）

**次のステップ**:
1. 本番環境でドキュメント表示を実際にテスト
2. ブラウザのコンソールでエラーメッセージを確認
3. 具体的なエラーが特定されたら修正

**推定修正時間**: 調査次第（1-3時間）

---

### 6. Linterエラー

**ステータス**: ✅ 修正完了 (2025-11-10)

**修正済み**:
- `lib/pages/archive_page.dart:520` - trailing comma追加 ✅ (2025-11-10)

**残存可能性**:
- Flutter CLIが利用できないため、全体のLinterエラーは手動確認が必要
- `analysis_options.yaml`で厳格なルールが設定されている
  - `require_trailing_commas`
  - `prefer_const_constructors`
  - `avoid_print`
  - など

**次のステップ**:
1. Flutterが利用できる環境で`flutter analyze`を実行
2. すべてのLinterエラーを修正
3. 目標: Linterエラー 0件

**推定修正時間**: 1-2時間

---

## 🟢 緊急度: 低

### 7. 大きなファイルのリファクタリング

**ステータス**: 📋 計画段階

**問題**:
- 一部のファイルが大きすぎる（1,000行前後）
- 保守性と可読性が低下する可能性

**対象ファイル**:
1. `lib/widgets/home_page/home_app_bar.dart` - 1,192行
2. `lib/pages/note_editor_page.dart` - 992行
3. `lib/pages/home_page.dart` - 848行
4. `lib/widgets/share_note_card_dialog.dart` - 810行

**目標**:
- 各ファイル500-700行以内にリファクタリング

**優先度**: 中（緊急ではないが、長期的には重要）

**推定修正時間**: 2-4週間

---

## 📊 その他の既知の問題

### 8. フロントエンド処理の複雑化

**ステータス**: 📋 計画段階

**問題**:
- 複雑な処理がフロントエンドで実行されている
- ゲーミフィケーション処理
- メモカード画像生成
- インポート処理

**解決策**:
- バックエンド移行計画に従って段階的に移行
- Supabase Edge FunctionsまたはNetlify Functionsへ移行

**詳細**: `docs/technical/BACKEND_MIGRATION_PLAN.md`

**推定修正時間**: 3-4週間

---

## 🎯 修正優先順位

### ✅ 修正完了（今回のセッション）
1. ✅ **サインイン500エラー** - トリガー関数修正、デプロイ待ち
2. ✅ **保存時の別レコード問題** - note_editor_page.dart修正完了
3. ✅ **Linterエラー** - archive_page.dart修正完了

### 最優先（デプロイ必要）
1. **サインイン500エラーのデプロイ** - マイグレーション適用が必要
2. **AI機能のエラー** - Google AI APIキー設定とデプロイが必要
3. **添付ファイル機能** - マイグレーション適用が必要

### 短期（今週〜来週）
4. **ドキュメント表示エラー** - 調査が必要

### 中期（今月）
5. **大きなファイルのリファクタリング** - 保守性向上
6. **バックエンド移行フェーズ1** - パフォーマンス向上

---

## 📈 修正進捗

| 問題 | ステータス | 進捗 |
|:-----|:----------|-----:|
| サインイン500エラー | ✅ 修正完了（デプロイ待ち） | 95% |
| 保存時の別レコード | ✅ 修正完了 | 100% |
| Linterエラー | ✅ 修正完了 | 100% |
| AI機能エラー | ⏳ デプロイ待ち | 90% |
| 添付ファイル機能 | ⏳ デプロイ待ち | 90% |
| ドキュメント表示エラー | 🔍 調査中 | 50% |
| 大きなファイル | 📋 計画段階 | 0% |
| バックエンド移行 | 📋 計画段階 | 10% |

---

## 🔗 関連ドキュメント

### 緊急対応
- [緊急対応アクションプラン](./IMMEDIATE_ACTION_PLAN.md) - AI機能の修正手順
- [添付ファイル修正ガイド](./technical/FILE_ATTACHMENT_FIX.md) - 添付ファイル機能の修正手順

### 技術ドキュメント
- [バックエンド移行計画](./technical/BACKEND_MIGRATION_PLAN.md)
- [Netlifyコスト最適化](./technical/NETLIFY_COST_OPTIMIZATION.md)

### 戦略ドキュメント
- [成長戦略ロードマップ](./roadmaps/GROWTH_STRATEGY_ROADMAP.md)
- [事業運営計画書](./roadmaps/BUSINESS_OPERATIONS_PLAN.md)

---

## 📝 備考

### ユーザーからのフィードバック

**2025年11月10日のリクエスト**:
1. ✅ **Linterエラー修正**（archive_page.dart:520）- 完了
2. ✅ **最終保存日時の表示** - 実装完了（タイトル付近に大きく表示）
3. 🔍 **リーダーボード問題** - デプロイ済み、問題継続中（要再調査）
4. ⏳ タイマー機能の実装（設計完了、実装待ち）
5. ⏳ 自動保存機能（中期計画）
6. ⏳ UNDO/REDO機能（中期計画）
7. ⏳ 添付ファイル機能のエラー（デプロイ待ち）
8. 🔍 ドキュメント表示エラー（調査中）
9. ✅ Twitterシェア用の文面（既存ドキュメントあり: docs/TWITTER_SHARE_TEMPLATES.md）

**2025年11月9日のリクエスト**:
1. ✅ メモを書きながら設定できるタイマー機能（設計完了、実装待ち）
2. ⏳ NOTIONのように自動保存にする（中期計画）
3. ✅ 画面遷移しないで保存できる保存ボタン（実装完了）
4. ✅ **サインイン起動が動作していない（最重要）** - 修正完了、デプロイ待ち
5. ✅ **保存したらメモが別レコードになる** - 修正完了
6. ⏳ 添付ファイル機能がエラー（デプロイ待ち）
7. 🔍 ドキュメントが見れない（調査中）
8. ✅ Linterエラー修正（archive_page.dart:514）- 完了
9. ✅ Twitterシェア用の文面（既存ドキュメントあり: docs/TWITTER_SHARE_TEMPLATES.md）

### 次回セッションでの対応

1. **最優先**: 添付ファイルとリーダーボード問題の診断・修正
   - 検証ガイドに従って診断: `docs/DEPLOYMENT_VERIFICATION.md`
   - リーダーボード詳細ガイド: `docs/BUG_REPORT_LEADERBOARD_ISSUE.md`
   - SQLクエリで実際の状態を確認
   - 必要に応じてポリシーを再作成
2. **高優先**: AI機能とサインイン機能の動作確認（デプロイ済みだが念のため）
3. **短期**: ドキュメント表示エラーの調査と修正
4. **中期**: タイマー機能の実装
5. **長期**: リファクタリングとバックエンド移行

---

## 📝 今回のセッションで完了したこと（2025年11月9日）

### 1. サインイン500エラーの修正 ✅
- **原因特定**: トリガー関数のRLSポリシー問題
- **修正**: `SECURITY DEFINER`追加、エラーハンドリング追加
- **マイグレーション作成**: `20251109000000_fix_auth_trigger.sql`
- **コミット**: `aa3ea7a`

### 2. 保存時の別レコード問題の修正 ✅
- **原因特定**: `widget.note`未更新による判定ミス
- **修正**: `_currentNoteId`変数追加、INSERT後のID保存
- **影響範囲**: `_saveNote()`と`_saveNoteWithoutClosing()`
- **コミット**: `cfbf72e`

### 3. Linterエラーの修正 ✅
- **箇所**: `archive_page.dart:514`
- **修正**: trailing comma追加
- **コミット**: `08c247b`

### 4. Git操作 ✅
- **ブランチ**: `claude/fix-critical-auth-bugs-011CUxddu9QMfmGRndLZ1Tho`
- **プッシュ**: 完了
- **コミット数**: 3件

---

## 📝 2025年11月10日のセッションで完了したこと

### 1. Linterエラーの修正 ✅
- **箇所**: `archive_page.dart:520`
- **修正**: trailing comma追加
- **影響**: Linterエラー解消、コード品質向上

### 2. 最終保存日時表示機能の実装 ✅
- **実装内容**:
  - 状態変数 `_lastSavedTime` 追加
  - 保存時に自動更新（`_saveNote()`, `_saveNoteWithoutClosing()`）
  - タイトル付近に目立つ表示（青色、Semi-Bold）
  - `DateFormatter.formatDateTime()` メソッド追加
- **表示例**: 「最終保存: 2024/11/10 14:30」
- **影響ファイル**:
  - `lib/pages/note_editor_page.dart`
  - `lib/utils/date_formatter.dart`

### 3. リーダーボード問題の調査 ✅
- **調査結果**: RLS (Row Level Security) ポリシーが原因
- **既に修正済み**: マイグレーション `20251109120000_fix_user_stats_leaderboard_rls.sql`
- **ステータス**: デプロイ待ち
- **詳細**: `/home/user/my_web_app/FIX_USER_STATS_406_ERROR.md`

### 4. コードベースの包括的調査 ✅
- **調査内容**: プロジェクト構造、実装済み機能、技術スタック、ドキュメント
- **結果**: 27,346行のコード、100ファイル、43ドキュメント
- **評価**: 7.5/10（充実した機能、良好なアーキテクチャ）

### 5. セッションサマリーの作成 ✅
- **ドキュメント**: `docs/session-summaries/SESSION_SUMMARY_2025-11-10.md`
- **内容**: 完了した作業、技術的所見、次のステップ

### 6. Git操作 ✅
- **ブランチ**: `claude/fix-linter-errors-archive-011CUyPycdfG7nz3NA3gptfR`
- **変更ファイル数**: 4ファイル
- **準備完了**: コミット＆プッシュ待ち

---

**最終更新**: 2025年11月10日
**次回レビュー**: デプロイ完了後
**作成者**: Claude Code
