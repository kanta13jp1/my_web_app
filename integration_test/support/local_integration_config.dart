/// Validates disposable local integration configuration before client startup.
void validateLocalIntegrationConfig({
  required bool enabled,
  required String url,
  required String publishableKey,
  required String email,
  required String password,
}) {
  final uri = Uri.tryParse(url);
  if (!enabled ||
      uri == null ||
      uri.scheme != 'http' ||
      !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      publishableKey.isEmpty ||
      !publishableKey.startsWith('sb_publishable_') ||
      email.trim().isEmpty ||
      password.isEmpty) {
    throw StateError(
      'Explicit local-only integration configuration is required.',
    );
  }
}
