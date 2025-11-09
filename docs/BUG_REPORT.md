# バグレポート - 2025年11月9日

**作成日**: 2025年11月9日
**最終更新**: 2025年11月9日
**ステータス**: 調査完了、修正待ち

---

## 📋 概要

本ドキュメントは、プロジェクトの現在の既知の問題と、その調査結果をまとめたものです。

---

## 🔴 緊急度: 高

### 1. AI機能がエラー（400 Bad Request）

**ステータス**: ⏳ デプロイ待ち

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

### 2. 添付ファイル機能が動作しない

**ステータス**: ⏳ デプロイ待ち

**問題**:
- ファイルのアップロード機能が使用不可
- 既存の添付ファイルが表示されない
- データベースエラーが発生

**根本原因**:
1. `attachments`テーブルが存在しない
2. Storageバケット（`attachments`）が作成されていない
3. RLS（Row Level Security）ポリシーが未設定

**解決策**:
1. マイグレーションファイル（`supabase/migrations/20251108_attachments_complete_setup.sql`）をデプロイ
   ```bash
   supabase db push
   ```
2. 動作確認
   - attachmentsテーブルの存在確認
   - attachmentsバケットの存在確認
   - ファイルアップロードテスト

**詳細**: `docs/technical/FILE_ATTACHMENT_FIX.md`
**関連セッション**: `docs/session-summaries/SESSION_SUMMARY_2025-11-08_FILE_ATTACHMENT_FIX.md`

**推定修正時間**: 15分

---

## 🟡 緊急度: 中

### 3. ドキュメント表示機能のエラー

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

### 4. Linterエラー

**ステータス**: ✅ 一部修正完了、継続監視

**修正済み**:
- `lib/pages/archive_page.dart:507` - trailing comma追加 ✅

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

### 5. 大きなファイルのリファクタリング

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

### 6. フロントエンド処理の複雑化

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

### 最優先（今すぐ）
1. **AI機能のエラー** - ユーザー体験に直接影響
2. **添付ファイル機能** - 基本機能が使えない

### 短期（今週〜来週）
3. **ドキュメント表示エラー** - 調査が必要
4. **Linterエラーの完全修正** - コード品質の向上

### 中期（今月）
5. **大きなファイルのリファクタリング** - 保守性向上
6. **バックエンド移行フェーズ1** - パフォーマンス向上

---

## 📈 修正進捗

| 問題 | ステータス | 進捗 |
|:-----|:----------|-----:|
| AI機能エラー | ⏳ デプロイ待ち | 90% |
| 添付ファイル機能 | ⏳ デプロイ待ち | 90% |
| ドキュメント表示エラー | 🔍 調査中 | 50% |
| Linterエラー | ✅ 一部完了 | 70% |
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

**2025年11月9日のリクエスト**:
1. ✅ メモを書きながら設定できるタイマー機能（フェーズ1完了）
2. ⏳ NOTIONのように自動保存にする（中期計画）
3. ✅ 画面遷移しないで保存できる保存ボタン（実装完了）
4. ⏳ 添付ファイル機能がエラー（デプロイ待ち）
5. 🔍 ドキュメントが見れない（調査中）
6. ⬜ Twitterシェア用の文面を考えて（未着手）

### 次回セッションでの対応

1. **最優先**: AI機能と添付ファイル機能のデプロイ
2. **短期**: ドキュメント表示エラーの調査と修正
3. **中期**: Linterエラーの完全修正
4. **長期**: リファクタリングとバックエンド移行

---

**最終更新**: 2025年11月9日
**次回レビュー**: 修正完了後
**作成者**: Claude Code
