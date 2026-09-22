import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('content recovery emits allowlisted events at state transitions', () {
    final source = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('AiUniversityContentEvent.contentFetchFailed'),
    );
    expect(source, contains('AiUniversityContentEvent.fallbackShown'));
    expect(source, contains('AiUniversityContentEvent.retryRequested'));
    expect(source, contains('AiUniversityContentEvent.retrySucceeded'));
    expect(source, contains('AiUniversityContentEvent.retryFailed'));
    expect(source, contains('final isRetry = _error != null;'));
    expect(source, isNot(contains('_error = e.toString()')));
  });
}
