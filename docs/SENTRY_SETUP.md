# Sentry Error Monitoring Setup

`lib/utils/error_reporter.dart` は `SENTRY_DSN` が渡されたビルドだけ Sentry を有効化します。未設定時は従来通り Supabase `core-hub` の `feedback.submit` だけに送信します。

## Dart Defines

```powershell
flutter build web --release `
  --dart-define=SENTRY_DSN="https://examplePublicKey@o0.ingest.sentry.io/0" `
  --dart-define=SENTRY_ENVIRONMENT="production" `
  --dart-define=SENTRY_RELEASE="my_web_app@1.0.0+1"
```

任意:

- `SENTRY_DEBUG=true`: SDK診断ログを有効化
- `SENTRY_TRACES_SAMPLE_RATE_PERCENT=5`: performance trace を 5% sampling

## CI / Firebase Hosting

本番deploy workflowで `SENTRY_DSN` を repository secret として渡します。DSNは公開クライアントキーですが、環境ごとの切り替えと誤送信防止のため secret 管理に寄せます。

Sentryは以下を自動記録します。

- Flutter framework error
- uncaught Dart runtime error
- `AppLogger.error(...)` からの caught error
- Supabase auth user id/email (ログイン済みの場合)
- route navigation breadcrumb (`SentryNavigatorObserver`)
