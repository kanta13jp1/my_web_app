import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/integration_registry.dart';

void main() {
  group('IntegrationCodeMappingCsvParser', () {
    const parser = IntegrationCodeMappingCsvParser();

    test('parses quoted rows and removes duplicate pairs', () {
      final entries = parser.parse('''
old_code,new_code,description
100,A100,"Revenue, domestic"
200,A200,Expense
100,A100,Duplicate
''');

      expect(entries, hasLength(2));
      expect(entries.first.oldCode, '100');
      expect(entries.first.newCode, 'A100');
      expect(entries.first.description, 'Revenue, domestic');
    });

    test('accepts source and target header aliases', () {
      final entries = parser.parse('''
source_code,target_code,note
OLD-1,NEW-1,Migrated
''');

      expect(entries.single.oldCode, 'OLD-1');
      expect(entries.single.newCode, 'NEW-1');
      expect(entries.single.description, 'Migrated');
    });

    test('rejects incomplete data rows', () {
      expect(
        () => parser.parse('old_code,new_code\n100,'),
        throwsFormatException,
      );
    });
  });

  test('snapshot parses latest records and version history', () {
    final snapshot = IntegrationRegistrySnapshot.fromJson(<String, dynamic>{
      'systems': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'system-2',
          'system_key': 'billing',
          'name': 'Billing',
          'version': 2,
        },
      ],
      'system_versions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'system-2',
          'system_key': 'billing',
          'name': 'Billing',
          'version': 2,
        },
        <String, dynamic>{
          'id': 'system-1',
          'system_key': 'billing',
          'name': 'Billing old',
          'version': 1,
        },
      ],
      'interfaces': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'if-1',
          'interface_key': 'billing-ledger',
          'name': 'Journal export',
          'source_system_key': 'billing',
          'target_system_key': 'ledger',
          'version': 1,
          'fields': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'journal_code',
              'data_type': 'string',
              'required': true,
            },
          ],
        },
      ],
    });

    expect(snapshot.systems.single.version, 2);
    expect(snapshot.systemVersions, hasLength(2));
    expect(snapshot.interfaces.single.fields.single.required, isTrue);
  });
}
