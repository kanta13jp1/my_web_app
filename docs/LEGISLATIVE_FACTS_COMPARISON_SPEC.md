# 立法事実（事実認識）共有・並列比較データベース仕様 (#2806)

## 1. 概要

論点ごとに各会派の「立法事実（前提となる事実認識）」を中立的に記録し、並列比較 UI で一覧表示するためのデータモデル・出典検証・ウィジェット仕様を定義する。

## 2. 必須出典 URL バリデーション

- `LegislativeFactsService.validateSourceUrl` および `validateSourceUrl` (Edge Function 共有モジュール) は、すべての立法事実登録時に `http://` または `https://` スキームかつホスト名を含む有効な URL を必須とする。
- 空文字・不正フォーマット・他スキームは拒否する。

## 3. 並列比較マトリクス UI (`LegislativeFactsMatrixCard`)

- `Wrap` レイアウトと `maxWidth: 320` 制約により、360×800 の狭幅画面かつ `2.0x` textScale 環境でも横方向オーバーフローを発生させない。
- 出典ボタンは `minimumSize: Size(64, 48)`・短縮ラベル（`出典`、7文字以下）を遵守する。

## 4. 実装ファイル

- Flutter サービス / ウィジェット / テスト:
  - `lib/services/legislative_facts_service.dart`
  - `lib/widgets/legislative_facts_matrix_card.dart`
  - `test/widgets/legislative_facts_matrix_card_test.dart`
- Edge Function 共有モジュール:
  - `supabase/functions/_shared/legislative_facts.ts`
  - `supabase/functions/_shared/legislative_facts_test.ts`
