# 機能単位ディレクトリ構成 & Container/Presentation 分離標準 (#2603)

## 1. 背景と目的
本リポジトリでは、コンポーネント種別（旧 Atomic Design 型の階層分けや巨大 `pages/` へのロジック集中）による責務の曖昧化・影響範囲の肥大化を防ぐため、**機能（Feature）単位のディレクトリ構成** と **Container（状態/ロジック） / Presentation（純粋UI）分離パターン** を標準として採用する。

## 2. 現行リポジトリ構成との整合ポリシー（段階的適用・既存画面非改変）
既存の稼働中ページや動作実績のある画面へ一括で破壊的リファクタリング（大規模 churn）は行わない。新設機能および段階的リファクタリング対象は以下の位置づけで統一管理する。

| ディレクトリ | 位置づけ | ルール |
| --- | --- | --- |
| `lib/features/<feature>/` | **新設機能の標準配置先** | `application/`・`presentation/`・`<feature>_container.dart` を基本構成とする（`lib/features/horse_racing/` は既存先行モジュールとして維持し、改修時に順次移行）。 |
| `lib/ui/features/<feature>/` | **既存 Feature Slice 資産**（21 モジュール） | `views/`・`widgets/`・`view_models/`・`<feature>_feature.dart` 構成を既に採用済み。`views/` は Presentation、`view_models/` は Application 相当として扱い、新規大規模追加は `lib/features/<feature>/` へ集約する。 |
| `lib/widgets/` | **複数機能横断の共通 UI のみ** | ドメイン非依存・複数機能（2 機能以上）で再利用される UI コンポーネントのみ配置する。特定機能専用のウィジェットは配置禁止。 |
| `lib/services/` | **横断インフラ・共通クライアント層** | Supabase / HTTP / ローカル永続化など機能横断のリポジトリ・クライアントを提供し、Presentation 層からの直接インポートを禁止する。 |
| `lib/pages/` | **ルーティング起点シェル** | ルート定義・画面外枠を担当し、新規ロジックは可能な限り Feature Container へ委譲する。 |

## 3. 標準 Feature ディレクトリ構造
新設パッケージを追加せず（`pubspec.yaml` の `provider` または Flutter 標準の `ChangeNotifier` / `ValueNotifier` / `ListenableBuilder` を使用）、以下を標準構成とする。

```text
lib/features/<feature_name>/
  <feature_name>_container.dart        # Container: Controller 生成・DI・dispose 管理・View 接続
  application/
    <feature_name>_controller.dart     # Application/Logic: 状態保持・副作用・検証・Immutable State 公開
  presentation/
    <feature_name>_view.dart           # Presentation: 純粋描画 Widget（副作用/DB/HTTP インポート禁止）
```

必要に応じてデータアクセスが肥大化する場合は `data/<feature_name>_repository.dart` を同ディレクトリ内に追加し、`application/` の Controller へ遅延 DI（Constructor / Resolver 注入）で渡す。

## 4. 責務境界と禁止事項（Static Check 強制対象）
1. **Presentation 層 (`lib/features/<name>/presentation/`)**
   - 引数として渡された `@immutable` State とユーザーイベントコールバックのみに依存する。
   - `package:supabase_flutter`、`package:supabase`、`package:http`、`package:dio`、`dart:io`、`dart:html` を直接インポートしてはならない。
   - `scripts/check_feature_architecture.py` により静的検証される。
2. **Application 層 (`lib/features/<name>/application/`)**
   - `ChangeNotifier` / `ValueNotifier` で状態遷移・エラーハンドリング・ドメイン規則を実行する。
   - `BuildContext` や Material ウィジェットの構築コードを持たない。
   - `dispose()` 後の `notifyListeners()` を防止し、リソース解放を保証する。
3. **Container (`lib/features/<name>/<name>_container.dart`)**
   - `StatefulWidget` として Controller や `TextEditingController` 等のライフサイクル（`initState` / `dispose`）を完結させ、単体テスト時はモック/差し替え Controller を DI 可能にする。
   - State に変更がない純粋表示では `ListenableBuilder` / `AnimatedBuilder` で再描画境界を最小化する。

## 5. リファレンス実装
- Controller: `lib/features/feature_architecture_guide/application/feature_architecture_controller.dart`
- Presentational View: `lib/features/feature_architecture_guide/presentation/feature_architecture_view.dart`
- Container: `lib/features/feature_architecture_guide/feature_architecture_container.dart`
- Tests: `test/features/feature_architecture_guide_test.dart`
- Static Check: `python scripts/check_feature_architecture.py`
