import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/spreadsheet_repository.dart';
import 'package:my_web_app/data/services/spreadsheet_file_gateway.dart';
import 'package:my_web_app/domain/models/spreadsheet_document.dart';
import 'package:my_web_app/main_spreadsheet_windows.dart';

void main() {
  testWidgets('Windows entrypoint opens the spreadsheet-only product', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      JibunSpreadsheetApp(
        repository: _MemorySpreadsheetRepository(),
        fileGateway: const _DisabledSpreadsheetFileGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('表計算'), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-wide-layout')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-formula-input')), findsOneWidget);
    expect(find.byKey(const Key('spreadsheet-grid')), findsOneWidget);
  });
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

class _DisabledSpreadsheetFileGateway implements SpreadsheetFileGateway {
  const _DisabledSpreadsheetFileGateway();

  @override
  Future<SpreadsheetPickedCsv?> pickCsv() async => null;

  @override
  Future<bool> saveCsv({
    required String suggestedName,
    required Uint8List bytes,
  }) async =>
      false;
}
