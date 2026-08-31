import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/ai_provider_registry.dart';

void main() {
  group('kAiProviderRegistry data integrity', () {
    test('provider ids are unique', () {
      final ids = kAiProviderRegistry.map((entry) => entry.id).toList();
      final duplicates = <String>{};
      final seen = <String>{};

      for (final id in ids) {
        if (!seen.add(id)) {
          duplicates.add(id);
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: 'Duplicate provider ids found: $duplicates',
      );
      expect(ids.toSet().length, ids.length);
    });

    test('every entry has a non-empty id and display name', () {
      for (final entry in kAiProviderRegistry) {
        expect(entry.id.trim(), isNotEmpty);
        expect(
          entry.displayName.trim(),
          isNotEmpty,
          reason: 'Empty display name for provider id: ${entry.id}',
        );
      }
    });
  });
}
