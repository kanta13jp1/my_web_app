import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/csv_bulk_upsert_planner.dart';

void main() {
  const schema = <CsvColumnSpec>[
    CsvColumnSpec('code', isKey: true, required: true, requiredValue: true),
    CsvColumnSpec('name', required: true, requiredValue: true),
    CsvColumnSpec('price', type: CsvColumnType.integer),
    CsvColumnSpec('active', type: CsvColumnType.boolean),
    CsvColumnSpec('due', type: CsvColumnType.date),
  ];

  group('planCsvBulkUpsert', () {
    test('splits rows into insert and update by existing keys', () {
      const csv = 'code,name,price,active,due\n'
          'A1,Apple,120,true,2026-07-16\n'
          'B2,Banana,80,false,2026-07-20\n';

      final plan = planCsvBulkUpsert(
        csvText: csv,
        schema: schema,
        existingKeys: <String>{'A1'},
      );

      expect(plan.hasHeaderErrors, isFalse);
      expect(plan.errorCount, 0);
      expect(plan.successCount, 2);
      expect(plan.updateCount, 1); // A1 exists
      expect(plan.insertCount, 1); // B2 is new
      final a1 = plan.rows.firstWhere((r) => r.key == 'A1');
      expect(a1.operation, CsvRowOperation.update);
      expect(a1.values['price'], 120);
      expect(a1.values['active'], true);
      expect(a1.values['due'], '2026-07-16');
    });

    test('reports a type error with the row number and column', () {
      const csv = 'code,name,price,active,due\n'
          'A1,Apple,NOT_A_NUMBER,true,2026-07-16\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: schema);

      expect(plan.successCount, 0);
      expect(plan.errorCount, 1);
      expect(plan.errors.first.rowNumber, 1);
      expect(plan.errors.first.column, 'price');
    });

    test('rejects an empty required value', () {
      const csv = 'code,name,price\n'
          'A1,,120\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: schema);

      expect(plan.errorCount, 1);
      expect(plan.errors.first.column, 'name');
    });

    test('flags an empty key and a duplicate key within the file', () {
      const csv = 'code,name\n'
          ',NoKey\n'
          'A1,First\n'
          'A1,DuplicateKey\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: schema);

      expect(plan.successCount, 1); // only the first A1
      expect(plan.errorCount, 2); // empty key + duplicate
      expect(plan.errors.any((e) => e.rowNumber == 1), isTrue);
      expect(plan.errors.any((e) => e.rowNumber == 3), isTrue);
    });

    test('rejects the whole file when a required column is missing', () {
      const csv = 'code,price\n'
          'A1,120\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: schema);

      expect(plan.hasHeaderErrors, isTrue);
      expect(plan.rows, isEmpty);
      expect(plan.headerErrors.first.contains('name'), isTrue);
    });

    test('ignores unknown extra columns but records a warning', () {
      const csv = 'code,name,extra\n'
          'A1,Apple,junk\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: schema);

      expect(plan.successCount, 1);
      expect(plan.headerWarnings.any((w) => w.contains('extra')), isTrue);
      expect(plan.rows.first.values.containsKey('extra'), isFalse);
    });

    test('handles quoted fields with commas, newlines and a BOM', () {
      const csv = '\uFEFFcode,name\n'
          'A1,"Doe, John"\n'
          '"B2","line1\nline2"\n';

      final plan = planCsvBulkUpsert(csvText: csv, schema: <CsvColumnSpec>[
        CsvColumnSpec('code', isKey: true, required: true, requiredValue: true),
        CsvColumnSpec('name'),
      ]);

      expect(plan.successCount, 2);
      expect(plan.rows[0].values['name'], 'Doe, John');
      expect(plan.rows[1].values['name'], 'line1\nline2');
    });

    test('summaryLabel reflects the counts', () {
      const csv = 'code,name\n'
          'A1,Apple\n'
          'B2,Banana\n';

      final plan = planCsvBulkUpsert(
        csvText: csv,
        schema: <CsvColumnSpec>[
          CsvColumnSpec('code', isKey: true, required: true),
          CsvColumnSpec('name'),
        ],
        existingKeys: <String>{'A1'},
      );

      expect(plan.summaryLabel, '成功 2 件 (新規 1 / 更新 1) / エラー 0 件');
    });

    test('throws for a schema without exactly one key column', () {
      expect(
        () => planCsvBulkUpsert(
          csvText: 'a\n1\n',
          schema: const <CsvColumnSpec>[CsvColumnSpec('a')],
        ),
        throwsArgumentError,
      );
    });
  });
}
