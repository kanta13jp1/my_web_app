/// Build-time injected application version information.
///
/// `APP_VERSION` is defined via `--dart-define=APP_VERSION=...` in
/// `.github/workflows/deploy-prod.yml` (see `steps.version.outputs.version`).
/// `BUILD_NUMBER` is reserved for the same workflow; the default `0` is
/// returned when the define is absent (local `flutter run`, dev builds).
class AppVersion {
  const AppVersion._();

  static const String value = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  static const String buildNumber = String.fromEnvironment(
    'BUILD_NUMBER',
    defaultValue: '0',
  );

  static bool get isDev => value == 'dev';

  static String get display =>
      buildNumber == '0' ? 'v$value' : 'v$value (build $buildNumber)';
}
