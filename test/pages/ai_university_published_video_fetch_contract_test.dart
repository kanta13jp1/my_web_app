import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'published videos are fetched separately and the catalog query paginates',
    () {
      final source = File(
        'lib/pages/gemini_university_v2_page.dart',
      ).readAsStringSync();

      expect(source, contains(".like('category', 'video_%')"));
      expect(source, contains('mergeContentRowsByProviderCategory'));
      expect(source, contains('for (var offset = 0;; offset += pageSize)'));
      expect(source, contains('.range(offset, offset + pageSize - 1)'));
    },
  );
}
