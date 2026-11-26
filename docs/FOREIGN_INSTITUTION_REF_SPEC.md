# 諸外国の制度比較リファレンス仕様 (#2808)

## 1. 概要

諸外国（ドイツ、イギリス等）の緊急事態関連制度・議会統制ルールを中立的に記録し、国別フィルタリング、議事録・発言 ID による逆引き検索、および公的データベースへの参照リンク検証を提供する。

## 2. データモデルと検索機能

- **制度カテゴリ (`InstitutionCategory`)**: `emergency_decree`（緊急政令）、`term_extension`（任期延長）、`oversight`（議会統制）
- **必須出典 URL 検証 (`validateOfficialUrl`)**: `http://` または `https://` スキームと有効なホスト名を必須とする。
- **逆引き検索 (`findBySpeechId`)**: `citedSpeechIds` 配列に基づき、対象の発言・議事録 ID で引用された海外事例を抽出する。

## 3. UI・アクセシビリティ基準 (`ForeignInstitutionRefCard`)

- `Wrap` レイアウトと `maxWidth: 320` 制約により、360×800・`2.0x` textScale 環境でも横方向オーバーフローを防止する。
- 参照ボタンは `minimumSize: Size(64, 48)`・短縮ラベル（`参照`、7文字以下）を採用する。

## 4. 実装ファイル

- Flutter サービス / ウィジェット / テスト:
  - `lib/services/foreign_institution_ref_service.dart`
  - `lib/widgets/foreign_institution_ref_card.dart`
  - `test/widgets/foreign_institution_ref_card_test.dart`
- Edge Function 共有モジュール:
  - `supabase/functions/_shared/foreign_institution_ref.ts`
  - `supabase/functions/_shared/foreign_institution_ref_test.ts`
