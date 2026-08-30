import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/spreadsheet_repository.dart';
import 'package:my_web_app/data/services/spreadsheet_file_gateway.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/ui/features/spreadsheet/spreadsheet_feature.dart';

void main() {
  testWidgets('wide layout edits cells and displays a calculated result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spreadsheet-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-sheet-tab')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('spreadsheet-formula-input')),
      '2',
    );
    await tester.tap(find.byKey(const Key('spreadsheet-cell-B1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('spreadsheet-formula-input')),
      '3',
    );
    await tester.tap(find.byKey(const Key('spreadsheet-cell-C1')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('spreadsheet-formula-input')),
      '=SUM(A1:B1)',
    );
    await tester.pump();

    final selectedAddress = tester.widget<Text>(
      find.byKey(const Key('spreadsheet-selected-address')),
    );
    expect(selectedAddress.data, 'C1');
    final formulaField = tester.widget<TextField>(
      find.byKey(const Key('spreadsheet-formula-input')),
    );
    expect(formulaField.controller?.text, '=SUM(A1:B1)');
    final c1Text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('spreadsheet-cell-C1')),
        matching: find.byType(Text),
      ),
    );
    expect(c1Text.data, '5');
    expect(find.text('未保存'), findsOneWidget);
  });

  testWidgets('compact layout keeps the editor toolbar and grid accessible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('spreadsheet-compact-layout')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-title')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-formula-input')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-grid')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-add-row')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-import-csv')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-export-csv')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-sheet-tabs')), findsOneWidget);
  });

  testWidgets('adds and renames a sheet from the desktop tab bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('spreadsheet-add-sheet')));
    await tester.pump();
    expect(find.byKey(const Key('spreadsheet-sheet-sheet-2')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('spreadsheet-tab-rename-sheet-2')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('spreadsheet-sheet-name-input')),
      '予算',
    );
    await tester.tap(
      find.byKey(const Key('spreadsheet-sheet-rename-confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('spreadsheet-sheet-sheet-2')),
        matching: find.text('予算'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('imports and exports CSV through toolbar actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _MemorySpreadsheetFileGateway(
      picked: SpreadsheetPickedCsv(
        name: '売上.csv',
        bytes: Uint8List.fromList(utf8.encode('商品,金額\r\nりんご,120')),
      ),
    );

    await tester.pumpWidget(_app(fileGateway: gateway));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('spreadsheet-import-csv')));
    await tester.pumpAndSettle();

    final a1Text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('spreadsheet-cell-A1')),
        matching: find.byType(Text),
      ),
    );
    expect(a1Text.data, '商品');
    expect(find.textContaining('新しいシート'), findsOneWidget);

    await tester.tap(find.byKey(const Key('spreadsheet-export-csv')));
    await tester.pumpAndSettle();

    expect(gateway.savedName, '無題のブック-売上.csv');
    expect(gateway.savedBytes!.take(3), <int>[0xEF, 0xBB, 0xBF]);
    expect(
      utf8.decode(gateway.savedBytes!.sublist(3)),
      startsWith('商品,金額'),
    );
  });
}

Widget _app({SpreadsheetFileGateway? fileGateway}) {
  return MaterialApp(
    home: SpreadsheetFeature(
      repository: _MemorySpreadsheetRepository(),
      fileGateway: fileGateway ?? _MemorySpreadsheetFileGateway(),
    ),
  );
}

class _MemorySpreadsheetRepository implements SpreadsheetRepository {
  SpreadsheetDocument? document;

  @override
  Future<SpreadsheetDocument?> load() async => document;

  @override
  Future<void> save(SpreadsheetDocument next) async {
    document = next;
  }
}

class _MemorySpreadsheetFileGateway implements SpreadsheetFileGateway {
  _MemorySpreadsheetFileGateway({this.picked});

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
