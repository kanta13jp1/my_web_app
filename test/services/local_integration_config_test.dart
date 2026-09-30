import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/local_integration_config.dart';

void main() {
  void validate({
    bool enabled = true,
    String url = 'http://127.0.0.1:54321',
    String key = 'sb_publishable_synthetic',
    String email = 'synthetic@example.test',
    String password = 'synthetic-only',
  }) {
    validateLocalIntegrationConfig(
      enabled: enabled,
      url: url,
      publishableKey: key,
      email: email,
      password: password,
    );
  }

  test('requires explicit opt-in and every credential field', () {
    expect(() => validate(enabled: false), throwsStateError);
    expect(() => validate(url: ''), throwsStateError);
    expect(() => validate(key: ''), throwsStateError);
    expect(() => validate(email: '  '), throwsStateError);
    expect(() => validate(password: ''), throwsStateError);
  });

  test('rejects remote, lookalike, user-info, and privileged key inputs', () {
    for (final url in <String>[
      'https://example.test',
      'http://localhost.example.test',
      'http://127.0.0.1.example.test',
      'http://localhost@example.test',
      'http://user@localhost:54321',
      'file:///localhost',
    ]) {
      expect(() => validate(url: url), throwsStateError);
    }
    expect(() => validate(key: 'sb_secret_synthetic'), throwsStateError);
    expect(() => validate(key: 'legacy-token'), throwsStateError);
  });

  test('accepts explicit loopback configuration without networking', () {
    for (final host in <String>['localhost', '127.0.0.1', '[::1]']) {
      expect(() => validate(url: 'http://$host:54321'), returnsNormally);
    }
  });
}
