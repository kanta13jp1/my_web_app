import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/video_studio/data/video_studio_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('VideoStudioException.fromFunctionException', () {
    test('preserves the structured Edge Function error code and message', () {
      final mapped = VideoStudioException.fromFunctionException(
        const FunctionException(
          status: 401,
          details: {
            'error': 'authentication_required',
            'message': 'Sign in first',
          },
          reasonPhrase: 'Unauthorized',
        ),
      );

      expect(mapped.code, 'authentication_required');
      expect(mapped.message, 'Sign in first');
    });

    test('falls back to the HTTP status when details are not structured', () {
      final mapped = VideoStudioException.fromFunctionException(
        const FunctionException(
          status: 503,
          details: 'temporarily unavailable',
          reasonPhrase: 'Service Unavailable',
        ),
      );

      expect(mapped.code, 'http_503');
      expect(mapped.message, 'Service Unavailable');
    });
  });
}
