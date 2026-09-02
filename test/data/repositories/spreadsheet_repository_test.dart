import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/spreadsheet_repository.dart';
import 'package:my_web_app/data/services/spreadsheet_local_storage_service.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists and restores a workbook from local preferences', () async {
    const repository = LocalSpreadsheetRepository(
      storageService: SpreadsheetLocalStorageService(),
    );
    final document = SpreadsheetDocument(
      id: 'local-workbook',
      title: '月次集計',
      sheets: const <SpreadsheetSheet>[
        SpreadsheetSheet(
          id: 'sheet-1',
          name: '売上',
          rowCount: 30,
          columnCount: 12,
          cells: <String, String>{
            '0:0': '120',
            '0:1': '=A1*2',
          },
        ),
      ],
      activeSheetId: 'sheet-1',
      updatedAt: DateTime.utc(2026, 8, 22),
    );

    await repository.save(document);
    final restored = await repository.load();

    expect(restored?.title, '月次集計');
    expect(restored?.cells, document.cells);
    expect(restored?.activeSheet.name, '売上');
    expect(restored?.updatedAt, document.updatedAt);
  });

  test('migrates the previous single-sheet storage format', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'spreadsheet_mvp_document_v1':
          '{"id":"legacy","title":"旧形式","rowCount":40,'
              '"columnCount":14,"cells":{"0:0":"移行済み"},'
              '"updatedAt":"2026-08-22T00:00:00.000Z"}',
    });
    const repository = LocalSpreadsheetRepository(
      storageService: SpreadsheetLocalStorageService(),
    );

    final restored = await repository.load();

    expect(restored?.sheets, hasLength(1));
    expect(restored?.activeSheet.name, 'シート1');
    expect(restored?.rowCount, 40);
    expect(
      restored?.inputAt(const CellAddress(row: 0, column: 0)),
      '移行済み',
    );
  });
}
