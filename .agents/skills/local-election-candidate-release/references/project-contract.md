# Project Contract

## 公式ソースと生成経路

- 公式候補者一覧: `https://new-kokumin.jp/local-election-list`
- 依存定義: `scripts/requirements-election-intelligence.txt`
- 唯一のジェネレーター: `scripts/update_kokumin_local_endorsements.py`
- 正規JSON asset: `assets/data/kokumin_local_endorsements.json`
- 生成Dart fallback: `lib/data/dpj_official_endorsements.dart`
- asset登録: `pubspec.yaml` の `assets/data/`

次の順で実行する。

```powershell
python -m pip install -r scripts/requirements-election-intelligence.txt
python scripts/update_kokumin_local_endorsements.py
```

ローカルPDFでparserを調べる場合は `--input-pdf <path>` を使う。通常更新で `--source-url` を差し替えない。

## データ安全契約

ジェネレーターは次を満たさない出力を拒否する。

- 公認30件以上
- 10都道府県以上
- 現職・新人・元職の合計と公認総数が一致
- 都道府県別内訳と各総数が一致
- 前回から25%を超える減少がない

`--allow-large-drop` は安全契約の解除である。公式資料上の理由を確認し、PR本文へ記録してから使う。

## Flutterの消費経路

- Data: `lib/data/repositories/official_endorsement_repository.dart`
- Logic: `lib/ui/features/election_victory/view_models/official_endorsement_view_model.dart`
- UI: `lib/pages/election_victory_page.dart`
- Share: `lib/services/local_election_share_service.dart`

live Edge Function snapshotが有効ならrepositoryが優先し、利用不能なら生成Dart fallbackを返す。表示側で別の公認件数を持たない。

## 対象検証

まず限定テストを実行する。

```powershell
python test/scripts/update_kokumin_local_endorsements_test.py
flutter test test/data/dpj_official_endorsements_test.dart test/data/repositories/official_endorsement_repository_test.dart test/ui/features/election_victory/view_models/official_endorsement_view_model_test.dart test/pages/election_victory_page_test.dart test/services/local_election_share_service_test.dart test/services/local_election_share_payload_test.dart
dart format --output=none --set-exit-if-changed lib/data/dpj_official_endorsements.dart lib/data/repositories/official_endorsement_repository.dart lib/ui/features/election_victory/view_models/official_endorsement_view_model.dart
flutter analyze
```

変更内容が固まった後、リポジトリのpre-push hookまたは公式full gateを1回通す。カバレッジ生成で `coverage/lcov.info` だけが変わった場合は、今回の生成物ではないことを確認してworktree側の変更だけを戻す。

## 想定差分

公式PDFの通常更新なら、主差分は次の2ファイルに限定する。

- `assets/data/kokumin_local_endorsements.json`
- `lib/data/dpj_official_endorsements.dart`

parser、schema、repository、ViewModel、UIの差分が出た場合は、公式形式変更または新要件の根拠をPRで説明する。
