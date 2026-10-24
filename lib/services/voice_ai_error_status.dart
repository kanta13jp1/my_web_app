import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps trusted structured function error codes, not arbitrary error text.
String voiceAiErrorStatus(Object error) {
  final details = error is FunctionException ? error.details : null;
  final code = details is Map ? details['error'] : null;
  switch (code) {
    case 'voice_usage_limit_exceeded':
      return 'blocked';
    case 'voice_training_consent_or_provider_zdr_required':
      return 'privacy_blocked';
    default:
      return 'error';
  }
}
