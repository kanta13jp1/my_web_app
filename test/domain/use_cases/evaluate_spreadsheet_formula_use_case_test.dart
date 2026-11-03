import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/domain/use_cases/evaluate_spreadsheet_formula_use_case.dart';

void main() {
  const evaluate = EvaluateSpreadsheetFormulaUseCase();

  test('evaluates arithmetic with referenced cells', () {
    final document = _document(<String, String>{
      '0:0': '10',
      '0:1': '5',
      '0:2': '=A1+B1*2',
    });

    final result = evaluate(document, const CellAddress(row: 0, column: 2));

    expect(result.displayValue, '20');
    expect(result.numericValue, 20);
    expect(result.isError, isFalse);
  });

  test('evaluates aggregate functions and ignores text inside ranges', () {
    final document = _document(<String, String>{
      '0:0': '10',
      '1:0': '20',
      '2:0': '見出し',
      '0:1': '=SUM(A1:A3)',
      '1:1': '=AVERAGE(A1:A3)',
      '2:1': '=MIN(A1:A3)',
      '3:1': '=MAX(A1:A3)',
    });

    expect(
      evaluate(document, const CellAddress(row: 0, column: 1)).displayValue,
      '30',
    );
    expect(
      evaluate(document, const CellAddress(row: 1, column: 1)).displayValue,
      '15',
    );
    expect(
      evaluate(document, const CellAddress(row: 2, column: 1)).displayValue,
      '10',
    );
    expect(
      evaluate(document, const CellAddress(row: 3, column: 1)).displayValue,
      '20',
    );
  });

  test('reports circular references and division by zero', () {
    final document = _document(<String, String>{
      '0:0': '=B1',
      '0:1': '=A1',
      '0:2': '=10/0',
    });

    expect(
      evaluate(document, const CellAddress(row: 0, column: 0)).displayValue,
      '#CYCLE!',
    );
    expect(
      evaluate(document, const CellAddress(row: 0, column: 2)).displayValue,
      '#DIV/0!',
    );
  });

  test('round-trips a document through JSON', () {
    final original = _document(<String, String>{'0:0': '=1+2'});

    final restored = SpreadsheetDocument.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.cells, original.cells);
    expect(restored.rowCount, original.rowCount);
    expect(restored.columnCount, original.columnCount);
  });
}

SpreadsheetDocument _document(Map<String, String> cells) {
  return SpreadsheetDocument(
    id: 'test',
    title: 'Test',
    sheets: <SpreadsheetSheet>[
      SpreadsheetSheet(
        id: 'sheet-1',
        name: 'シート1',
        rowCount: 10,
        columnCount: 5,
        cells: cells,
      ),
    ],
    activeSheetId: 'sheet-1',
    updatedAt: DateTime.utc(2026, 8, 22),
  );
}
