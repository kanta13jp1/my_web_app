import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_provider_registry.dart';

void main() {
  group('kAiProviderRegistry data integrity', () {
    test('provider ids are unique (regression guard for duplicate entries)', () {
      final ids = kAiProviderRegistry.map((e) => e.id).toList();
      final seen = <String>{};
      final duplicates = <String>{};
      for (final id in ids) {
        if (!seen.add(id)) {
          duplicates.add(id);
        }
      }
      expect(
        duplicates,
        isEmpty,
        reason: '重複した provider id が存在します: $duplicates。'
            'AI大学 レジストリは 1 プロバイダー 1 エントリを前提とします。',
      );
      expect(ids.toSet().length, ids.length);
    });

    test('every entry has a non-empty id and displayName', () {
      for (final entry in kAiProviderRegistry) {
        expect(entry.id.trim(), isNotEmpty, reason: 'id が空のエントリがあります');
        expect(
          entry.displayName.trim(),
          isNotEmpty,
          reason: 'displayName が空です: id=${entry.id}',
        );
      }
    });
  });
}
