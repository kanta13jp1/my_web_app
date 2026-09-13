import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/business_csv_import_service.dart';

void main() {
  group('BusinessCsvImportService', () {
    const service = BusinessCsvImportService();

    test('parses quoted CSV rows into note import rows', () {
      final rows = service.parseCsvText(
        [
          'external_id,title,content,tags',
          'A-1,"Revenue memo","Line 1, with comma","finance,import"',
        ].join('\n'),
      );

      expect(rows, hasLength(1));
      expect(rows.single.rowNumber, 2);
      expect(rows.single.externalId, 'A-1');
      expect(rows.single.title, 'Revenue memo');
      expect(rows.single.content, 'Line 1, with comma');
      expect(rows.single.tags, <String>['finance', 'import']);
    });

    test('dry-run separates valid rows and error rows', () {
      final rows = service.parseCsvText(
        [
          'external_id,title,content,tags',
          'A-1,Valid memo,Ready,ops',
          'A-2,,Missing title,ops',
          'A-1,Duplicate external,Ready,ops',
        ].join('\n'),
      );

      final result = service.dryRunRows(fileName: 'business.csv', rows: rows);

      expect(result.totalRows, 3);
      expect(result.validRows, hasLength(1));
      expect(result.errorRows, hasLength(2));
      expect(result.errorRows.first.reasonText, contains('required title'));
      expect(
        result.errorRows.last.reasonText,
        contains('duplicate external_id'),
      );
      expect(result.validNotes.single.source, 'business_csv');
    });

    test('exports only rejected rows as CSV', () {
      final result = service.dryRunRows(
        fileName: 'business.csv',
        rows: service.parseCsvText(
          ['title,content', ',No title', '"Bad, title",'].join('\n'),
        ),
      );

      final lines = const LineSplitter().convert(result.errorCsv);

      expect(lines.first, 'row_number,title,error_reason,raw_text');
      expect(lines, hasLength(3));
      expect(lines[1], contains('required title missing'));
      expect(lines[2], contains('required content missing'));
      expect(lines[2], contains('Bad, title'));
    });

    test('neutralizes spreadsheet formulas in exported error CSV', () {
      final result = service.dryRunRows(
        fileName: 'business.csv',
        rows: service.parseCsvText(
          ['title,content', '=IMPORTXML("https://example.com"),'].join('\n'),
        ),
      );

      final lines = const LineSplitter().convert(result.errorCsv);

      expect(lines, hasLength(2));
      expect(lines[1], contains("'=IMPORTXML"));
    });

    test('reads server commit response shape', () {
      final result = BusinessCsvCommitResult.fromJson(<String, dynamic>{
        'insertedCount': 0,
        'rolledBack': true,
        'commitMode': 'all_or_rollback',
        'dryRun': <String, dynamic>{
          'fileName': 'business.csv',
          'totalRows': 1,
          'validRows': const <Map<String, dynamic>>[],
          'errorRows': <Map<String, dynamic>>[
            <String, dynamic>{
              'rowNumber': 2,
              'title': '',
              'rawText': ',body',
              'reasons': <String>['required title missing'],
            },
          ],
          'checkedBy': 'postgres-rpc',
        },
      });

      expect(result.rolledBack, isTrue);
      expect(result.commitMode, BusinessCsvCommitMode.allOrRollback);
      expect(result.dryRun.usedServerDryRun, isTrue);
      expect(result.dryRun.errorRows.single.rowNumber, 2);
    });
  });
}
