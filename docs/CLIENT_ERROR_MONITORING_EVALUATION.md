# Flutter Web クライアントエラー監視・テスト自動化 評価レポート

Status: 評価完了・現行構成採用 (Issue #2768)

Last verified against primary vendor sources: 2026-11-26

## 1. 評価目的と結論

Issue #2768 に基づき、Supabase をメインバックエンドとしつつ Flutter Web クライアントの実行時エラー収集・テスト自動化を実現する構成を、一次情報と既存リポジトリ実装の両面から評価しました。

**結論**:
1. **クライアントエラー監視**: 既存統合済みの **Sentry (`sentry_flutter: ^9.30.0`) + Supabase (`core-hub` `feedback.submit` / `source: 'auto_error_report'`)** を継続採用します。**Firebase Crashlytics は Flutter Web をサポートしていない**ため、Flutter Web のクラッシュ収集には使用しません。
2. **マルチ環境テスト自動化**: GitHub Actions 上の **Flutter `VM tests` + Playwright Web E2E (`ci.yml` / `e2e-smoke.yml` / `visual-regression.yml`)** を継続・強化します。**Firebase Test Lab は Android / iOS 向け**（かつ公式ドキュメント上で deprecated 表記）であり、Flutter Web テストには適用できません。

## 2. ソリューション比較評価 (一次情報ベース)

| 項目 | Sentry (`sentry_flutter`) | Firebase Crashlytics (`firebase_crashlytics`) | Supabase Telemetry (`core-hub` -> `hub_data`) |
| --- | --- | --- | --- |
| **Flutter Web 対応** | **対応** (`sentry_flutter: ^9.30.0`, `pubspec.yaml:63` 統合済) | **非対応** ([`firebase_crashlytics` v6.1.0](https://pub.dev/api/packages/firebase_crashlytics) の `platforms` は `android`, `ios`, `macos` のみ) | **対応** (Flutter Web から Edge Function `core-hub` 経由で記録) |
| **無料枠・料金 (2026-11-26 確認)** | Developer プラン `$0` (1 ユーザー、月 `5,000` errors、`5GB` logs、`5M` spans、`50` replays)。Team プラン `$80/mo` (`50k` errors/月) ([Sentry Pricing](https://sentry.io/pricing/)) | Spark 無料枠あり ([Crashlytics Docs](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter)) | 既存 Supabase プロジェクト (`hub_data`) を共用し追加ベンダー課金なし |
| **ソースマップ / スタックトレース** | Dart/JS スタックトレース、リリース識別 (`SENTRY_RELEASE`)・環境分離 (`SENTRY_ENVIRONMENT`) | モバイルネイティブ/dSYM/ProGuard 主体 | 先頭 6 行のスタック要約・120 文字フィンガープリントを記録 |
| **セキュリティ / PII 制御** | `sendDefaultPii = false`、`SentryUser(id: userId)` のみ送信、送信前メール/Bearer/JWT マスク | Google Analytics 連携設定依存 | ログイン済みユーザー限定 (`auth.currentUser != null`)、`source: 'auto_error_report'` で公開 GitHub Issue 化を抑止 |
| **採用判定** | **主系 (採用)** | **不採用 (Web 非対応)** | **副系・監査フォールバック (採用)** |

### Firebase Spark マルチクラウド構成の運用コストとセキュリティ評価

- **Firebase Test Lab の扱い**: [Firebase Test Lab](https://firebase.google.com/docs/test-lab) は Android / iOS の実機・仮想端末向けであり、公式ナビゲーション上で `Test Lab (deprecated)` と表示されています。Flutter Web ターゲットの自動テストには適さないため導入しません。
- **マルチクラウド運用コスト**: Supabase + Firebase Hosting（静的ホスティング）に監視目的で Crashlytics/Test Lab を追加しても、Flutter Web 側のカバレッジは増えず、Firebase SDK 初期化・設定ファイル管理の保守負債だけが増えます。Sentry Developer プラン（無料枠 5,000 errors/月）と Supabase `hub_data` の併用が最小コストです。
- **セキュリティ要件**:
  - `SENTRY_DSN` はリポジトリへハードコードせず、`--dart-define=SENTRY_DSN=...` と `ErrorReporter.isValidSentryDsn` による検証のみで有効化します。
  - `sendDefaultPii = false` を強制し、メールアドレス・氏名等を Sentry へ自動送信しません。
  - クライアントから送信するメッセージは `ErrorReporter.sanitizeMessage` によりメールアドレス・Bearer トークン・JWT 形式文字列をマスクします。
  - セッションあたり同一エラー（先頭 120 文字）の重複抑止および最大 10 件/セッションの上限により、障害時のログフラッドや無料枠枯渇を防ぎます。

## 3. PoC（概念実証）実装 (`lib/utils/error_reporter.dart`)

既存の `ErrorReporter`（`lib/main.dart:415-422, 2129-2130` で `FlutterError.onError` / `PlatformDispatcher.onError` / `AppLogger.error` と接続済み）を拡張し、以下を検証可能にしました（DB マイグレーション `0` 件）:

- `ErrorReporter.sanitizeMessage`: メールアドレス・`Bearer` トークン・`eyJ...` JWT を `[REDACTED_*]` へマスク
- `ErrorReporter.buildTelemetryPayload`: `core-hub` (`action: 'feedback.submit'`, `category: 'bug'`, `source: 'auto_error_report'`) 向けの構造化非 PII ペイロード生成（スタック先頭 6 行・最大 2000 文字）
- `ErrorReporter.diagnosticSnapshot()`: `sentryEnabled`・`handlersInstalled`・送信件数・重複/上限抑止件数・プラットフォーム（`web` / `vm`）の診断スナップショット取得
- `@visibleForTesting` テストシンク (`setTestSinks` / `resetForTesting`): Sentry / Supabase 双方への PoC ディスパッチ・重複排除・10 件スロットリングの単体検証 (`test/utils/error_reporter_test.dart`)

## 4. CI/CD 主要ユーザーシナリオ自動テスト監査

既存 GitHub Actions ワークフロー（`.github/workflows/`）を棚卸しした結果、主要シナリオの自動テストは以下に組み込まれています:

| シナリオ領域 | ワークフロー | 実行コマンド / 対象 |
| --- | --- | --- |
| Flutter 単体・ウィジェット・ErrorReporter | `.github/workflows/ci.yml` (`VM tests (0)/(1)`) | `flutter test` (`test/utils/error_reporter_test.dart` ほか全 feature テスト) |
| ビジネス実行 E2E (フィクスチャサーバ) | `.github/workflows/ci.yml` (`business_execution_e2e`) | `npm run e2e:business-execution -- --forbid-only` (`test/e2e/business_execution.spec.ts`) |
| 公開ルート・ノーサインアップ体験スモーク | `.github/workflows/e2e-smoke.yml` (`schedule` + `workflow_dispatch`) | `npm run e2e:smoke` (`test/e2e/public_smoke.spec.ts`, `public_no_signup_trial.spec.ts`) |
| レスポンシブ視覚エビデンス・入力検証 | `.github/workflows/e2e-smoke.yml`, `.github/workflows/visual-regression.yml` | `npm run e2e:visual`, `test/e2e/jwenv_lab.spec.ts`, `npm run e2e:visual:regression` |

`test/scripts/test_client_error_monitoring_ci.py` により、上記 `sentry_flutter` 依存・`main.dart` 配線・`ci.yml` / `e2e-smoke.yml` の主要テストステップが維持されていることをオフラインで継続検証します。
