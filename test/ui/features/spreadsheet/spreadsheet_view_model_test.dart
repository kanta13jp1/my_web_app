import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/spreadsheet_repository.dart';
import 'package:my_web_app/data/services/spreadsheet_file_gateway.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/domain/use_cases/evaluate_spreadsheet_formula_use_case.dart';
import 'package:my_web_app/domain/use_cases/spreadsheet_csv_codec.dart';
import 'package:my_web_app/services/auto_save_service.dart';
import 'package:my_web_app/ui/features/spreadsheet/view_models/spreadsheet_view_model.dart';

void main() {
  late _MemorySpreadsheetRepository repository;
  late _MemorySpreadsheetFileGateway fileGateway;
  late SpreadsheetViewModel viewModel;

  setUp(() {
    repository = _MemorySpreadsheetRepository();
    fileGateway = _MemorySpreadsheetFileGateway();
    viewModel = SpreadsheetViewModel(
      repository: repository,
      evaluateFormula: const EvaluateSpreadsheetFormulaUseCase(),
      csvCodec: const SpreadsheetCsvCodec(),
      fileGateway: fileGateway,
      autoSaveService: AutoSaveService(),
      clock: () => DateTime.utc(2026, 8, 22),
    );
  });

  tearDown(() => viewModel.dispose());

  test('creates a blank workbook and calculates edited cells', () async {
    await viewModel.load();

    expect(viewModel.status, SpreadsheetLoadStatus.ready);
    expect(viewModel.document?.rowCount, 30);

    viewModel.updateSelectedCell('12');
    viewModel.selectCell(const CellAddress(row: 0, column: 1));
    viewModel.updateSelectedCell('=A1*2');

    expect(
      viewModel.evaluationAt(const CellAddress(row: 0, column: 1)).displayValue,
      '24',
    );
    expect(viewModel.saveState, SaveState.modified);
  });

  test('supports undo, redo, row and column growth', () async {
    await viewModel.load();
    final initialRows = viewModel.document!.rowCount;
    final initialColumns = viewModel.document!.columnCount;

    viewModel.updateSelectedCell('first');
    viewModel.updateSelectedCell('second');
    viewModel.undo();

    expect(viewModel.selectedCellInput, 'first');
    expect(viewModel.canRedo, isTrue);

    viewModel.redo();
    expect(viewModel.selectedCellInput, 'second');

    viewModel.addRow();
    viewModel.addColumn();
    expect(viewModel.document!.rowCount, initialRows + 1);
    expect(viewModel.document!.columnCount, initialColumns + 1);
  });

  test('manual save persists the latest workbook', () async {
    await viewModel.load();
    viewModel.updateSelectedCell('保存対象');

    expect(await viewModel.save(), isTrue);

    expect(
      repository.saved?.inputAt(const CellAddress(row: 0, column: 0)),
      '保存対象',
    );
    expect(viewModel.saveState, SaveState.saved);
  });

  test('adds, switches and renames independent sheets', () async {
    await viewModel.load();
    viewModel.updateSelectedCell('最初のシート');

    viewModel.addSheet();
    viewModel.updateSelectedCell('2枚目');

    expect(viewModel.sheets, hasLength(2));
    expect(viewModel.document?.activeSheet.name, 'シート2');
    viewModel.renameSheet('sheet-2', '予算');
    expect(viewModel.document?.activeSheet.name, '予算');

    viewModel.selectSheet('sheet-1');
    expect(viewModel.selectedCellInput, '最初のシート');
    viewModel.selectSheet('sheet-2');
    expect(viewModel.selectedCellInput, '2枚目');
  });

  test('imports CSV into a new sheet and keeps the original sheet', () async {
    await viewModel.load();
    fileGateway.picked = SpreadsheetPickedCsv(
      name: '売上.csv',
      bytes: Uint8List.fromList(utf8.encode('商品,金額\r\nりんご,120')),
    );

    expect(await viewModel.importCsv(), isTrue);

    expect(viewModel.sheets, hasLength(2));
    expect(viewModel.document?.activeSheet.name, '売上');
    expect(viewModel.selectedCellInput, '商品');
    expect(
      viewModel.document?.inputAt(const CellAddress(row: 1, column: 1)),
      '120',
    );
    expect(viewModel.noticeMessage, contains('新しいシート'));
  });

  test('exports the active sheet as UTF-8 CSV with formulas preserved',
      () async {
    await viewModel.load();
    viewModel.updateSelectedCell('10');
    viewModel.selectCell(const CellAddress(row: 0, column: 1));
    viewModel.updateSelectedCell('=A1*2');

    expect(await viewModel.exportCsv(), isTrue);

    expect(fileGateway.savedName, '無題のブック-シート1.csv');
    expect(fileGateway.savedBytes!.take(3), <int>[0xEF, 0xBB, 0xBF]);
    expect(utf8.decode(fileGateway.savedBytes!.sublist(3)), '10,=A1*2');
    expect(viewModel.noticeMessage, 'CSVを書き出しました。');
  });
}

class _MemorySpreadsheetRepository implements SpreadsheetRepository {
  SpreadsheetDocument? saved;

  @override
  Future<SpreadsheetDocument?> load() async => saved;

  @override
  Future<void> save(SpreadsheetDocument document) async {
    saved = document;
  }
}

class _MemorySpreadsheetFileGateway implements SpreadsheetFileGateway {
  SpreadsheetPickedCsv? picked;
  String? savedName;
  Uint8List? savedBytes;

  @override
  Future<SpreadsheetPickedCsv?> pickCsv() async => picked;

  @override
  Future<bool> saveCsv({
    required String suggestedName,
    required Uint8List bytes,
  }) async {
    savedName = suggestedName;
    savedBytes = bytes;
    return true;
  }
}
