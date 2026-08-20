import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'published videos are fetched separately from the capped catalog query',
    () {
      final source = File(
        'lib/pages/gemini_university_v2_page.dart',
      ).readAsStringSync();

      expect(source, contains(".like('category', 'video_%')"));
      expect(source, contains('mergeContentRowsByProviderCategory'));
    },
  );
}
