# テストカバレッジ & 機能検証レポート

`README.md` に記載されている主要機能と、それに対応する実装ファイルおよびテストケースのマッピングです。
AIエージェントはこのリストを参照し、改修時に既存機能への影響範囲を特定してください。

## ✅ カバレッジマトリクス

| カテゴリ | 機能名 (Feature) | 対象ファイル (File) | テスト確認事項 (Test Case) | 状態 |
| :--- | :--- | :--- | :--- | :--- |
| **CEO** | **経営コックピット** | `lib/pages/home_page.dart` | 各Officeセクションの表示<br>CEOカードのレンダリング |  Implemented |
| **CEO** | **緊急役員会議 (BI版)** | lib/pages/emergency_meeting_page.dart | データ集計ロジック<br>AIプロンプト生成<br>レポート表示UI |  Implemented |
| **CSO** | **断捨離クエスト** |
| **CSO** | **リアル断捨離クエスト** |
| **CFO** | **固定費削減室** |
| **CHO** | **健康管理室** |
| **CMO** | **マーケティング室** | lib/pages/cmo_office_page.dart | ユーザー統計表示(Streak, Points)<br>SNSシェア(Simulation) |  Implemented | lib/pages/health_page.dart | 健康ログ一覧表示<br>ログ追加(Notes連携) |  Implemented | lib/pages/subscription_page.dart | サブスク一覧表示<br>追加削除<br>合計金額計算 |  Implemented | lib/pages/real_world_danshari_page.dart | カメラ/画像選択の起動<br>AI分析結果の表示 | 🚧 Pending | `lib/pages/danshari_page.dart` | カードスワイプUIの表示<br>Supabaseからのデータ取得(Mock) |  Pending (Requires Supabase Mock) |
| **CKO** | **AIアシスタントメニュー** |
| **CKO** | **メモ一覧** | lib/pages/note_list_page.dart | リスト表示<br>新規作成遷移 |  Implemented | `lib/pages/note_editor_page.dart` | メモ作成画面の起動<br>AIメニューの展開 |  Pending |
| **Core** | **テーマ管理** |
| **Core** | **インポート機能** | lib/services/import_service.dart | ポイント付与ロジック<br>ノート数計算 |  Implemented |
| **Model** | **役員会議モデル** | lib/models/board_meeting_model.dart | JSONパース(fromMap) |  Implemented | `lib/services/theme_service.dart` | Dark/Lightモード切替<br>SharedPreferencesへの保存 |  Verified (Manual) |

##  実行コマンド

以下のコマンドでスモークテスト(起動確認)を実行できます。

```bash
flutter test test/readme_features_test.dart
```

##  今後のテスト拡張計画 (TODO)
1. **Supabase Mocking**: `danshari_page.dart` などDB依存のあるページのテストには `mockito` でSupabaseClientをモックする必要があります。
2. **Integration Test**: 実際のDBに接続したE2Eテストは、GitHub Actions上のステージング環境で実施予定。