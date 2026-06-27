@TestOn('browser')

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_service.dart';

void main() {
  test('maps 402 free_limit_reached payload to upgrade metadata', () {
    final error = AIServiceException.fromFunctionPayload({
      'status': 402,
      'code': 'free_limit_reached',
      'message': '無料AI質問枠を使い切りました。',
      'upgrade_url': '/billing',
    });

    expect(error.isFreeLimitReached, isTrue);
    expect(error.statusCode, 402);
    expect(error.code, 'free_limit_reached');
    expect(error.message, '無料AI質問枠を使い切りました。');
    expect(error.upgradeUrl, '/billing');
  });

  test('keeps non-402 payloads as regular AIServiceException errors', () {
    final error = AIServiceException.fromFunctionPayload({
      'status': 500,
      'code': 'provider_down',
      'error': 'provider unavailable',
    });

    expect(error.isFreeLimitReached, isFalse);
    expect(error.statusCode, 500);
    expect(error.code, 'provider_down');
    expect(error.message, 'provider unavailable');
  });
}
