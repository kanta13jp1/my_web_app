import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_recorded_change_details.dart';

void main() {
  testWidgets('empty observations offer no false difference', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: AssetRecordedChangeDetails(dates: [], changes: []))));
    expect(find.byType(ExpansionTile), findsNothing);
  });
  for (final width in <double>[1200, 390]) {
    testWidgets('recorded differences explain gaps and first observation at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AssetRecordedChangeDetails(
        dates: ['2025-12-31', '2026-01-09', '2026-01-11'], changes: [0, 200, -50],
      )))));
      await tester.tap(find.text('記録日ごとの差額を一覧で確認'));
      await tester.pumpAndSettle();
      expect(find.text('比較元なし（最初の記録）'), findsOneWidget);
      expect(find.textContaining('比較元 2025-12-31 → 2026-01-09'), findsOneWidget);
      expect(find.textContaining('+¥200'), findsOneWidget);
      expect(find.textContaining('-¥50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

