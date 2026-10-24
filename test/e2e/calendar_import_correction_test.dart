import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_calendar_reflection_repository.dart';
import 'package:my_web_app/widgets/asset_calendar_reflection_panel.dart';

class _Store implements AssetCalendarReflectionStore {
  int imports = 0;
  @override
  Future<void> import(List<AssetCalendarReflection> events) async {
    imports++;
  }

  @override
  Future<List<AssetCalendarReflection>> load(
    DateTime start,
    DateTime end,
  ) async {
    return [];
  }
}

void main() {
  for (final width in [1200.0, 390.0]) {
    testWidgets(
      'Japanese import correction retains input without saving $width',
      (tester) async {
        final store = _Store();
        await tester.binding.setSurfaceSize(Size(width, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AssetCalendarReflectionPanel(
                  repository: store,
                  start: DateTime(2026, 10),
                  end: DateTime(2026, 11),
                  selectedDate: null,
                  onLoaded: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('日記・読書データを取り込む'));
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        await tester.enterText(field, '[');
        await tester.tap(find.text('内容を確認'));
        await tester.pumpAndSettle();
        expect(find.textContaining('JSONの構文'), findsOneWidget);
        expect(tester.widget<TextField>(field).controller!.text, '[');
        final row = <String, dynamic>{
          'source_key': 'synthetic:no-save',
          'occurred_on': '2026-10-21',
          'kinds': ['reading'],
          'title': '日本語の書名',
          'source_label': '保存なし検査',
          'memo': List.filled(2001, 'あ').join(),
        };
        await tester.enterText(field, jsonEncode([row]));
        await tester.tap(find.text('内容を確認'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1件目: メモが長すぎます'), findsOneWidget);
        row['memo'] = List.filled(2000, 'あ').join();
        final corrected = jsonEncode([row]);
        await tester.enterText(field, corrected);
        await tester.tap(find.text('内容を確認'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, corrected);
        expect(find.textContaining('確認: 1件'), findsOneWidget);
        expect(find.textContaining('日本語の書名（出典: 保存なし検査）'), findsOneWidget);
        expect(store.imports, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('閉じる'));
        await tester.pumpAndSettle();
        expect(store.imports, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
