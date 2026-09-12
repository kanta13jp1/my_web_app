import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_interest_history.dart';
import 'package:my_web_app/services/asset_interest_repository.dart';
import 'package:my_web_app/widgets/asset_interest_history_card.dart';

class MemoryInterestRepository implements AssetInterestRepository {
  List<AssetInterestMonth> rows = [];
  bool fail = false;
  @override
  Future<List<AssetInterestMonth>> load() async => rows;
  @override
  Future<void> save(AssetInterestMonth month) async {
    if (fail) throw StateError('offline');
    rows = [...rows.where((r) => r.month != month.month), month];
  }
}

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('responsive chart and missing months at $width', (tester) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = MemoryInterestRepository()..rows = [
        AssetInterestMonth(month: '2026-07', amounts: {'A': 100}, complete: true, evidence: 'statement'),
        AssetInterestMonth(month: '2026-08', amounts: {'A': 80}, complete: true, evidence: 'statement'),
      ];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: AssetInterestHistoryCard(repository: repository, now: DateTime(2026, 9, 12))))));
      await tester.pumpAndSettle();
      expect(find.textContaining('20円減少'), findsOneWidget);
      expect(find.text('未登録'), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('record persists through reload and failed save keeps input', (tester) async {
    final repository = MemoryInterestRepository();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: AssetInterestHistoryCard(repository: repository, now: DateTime(2026, 9, 12))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('記録・修正').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'A=100');
    await tester.enterText(find.byType(TextField).at(1), '明細照合');
    repository.fail = true;
    await tester.tap(find.text('サーバに保存'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    expect(find.text('A=100'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('サーバに保存'));
    await tester.pumpAndSettle();
    expect(repository.rows.single.total, 100);
    expect(find.textContaining('100円 / 未照合'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
