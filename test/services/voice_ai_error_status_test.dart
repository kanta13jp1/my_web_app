import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/voice_ai_error_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('quota response is shown as blocked', () {
    expect(
      voiceAiErrorStatus(
        const FunctionException(
        status: 429,
        details: {'error': 'voice_usage_limit_exceeded'},
        ),
      ),
      'blocked',
    );
  });
  test('privacy response requests consent', () {
    expect(
      voiceAiErrorStatus(
        const FunctionException(
        status: 403,
        details: {'error': 'voice_training_consent_or_provider_zdr_required'},
        ),
      ),
      'privacy_blocked',
    );
  });
  test('unstructured or unrelated failures remain generic', () {
    expect(
      voiceAiErrorStatus(StateError('voice_usage_limit_exceeded')),
      'error',
    );
    expect(
      voiceAiErrorStatus(const FunctionException(status: 500, details: 'bad')),
      'error',
    );
  });
}
