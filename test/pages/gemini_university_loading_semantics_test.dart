import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('AI大学の読み込み状態を支援技術へ通知する', () {
    final source = File(
      'lib/pages/gemini_university_v2_page.dart',
    ).readAsStringSync();
    final loadingState = RegExp(
      r'if \(_loading \|\| tc == null\) \{([\s\S]*?)\n    \}',
    ).firstMatch(source);

    expect(loadingState, isNotNull);
    expect(loadingState!.group(1), contains('Semantics('));
    expect(loadingState.group(1), contains('liveRegion: true'));
    expect(
      loadingState.group(1),
      contains("label: 'AI大学のコンテンツを読み込んでいます'"),
    );
  });
}
