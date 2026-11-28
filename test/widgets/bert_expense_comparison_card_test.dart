import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/bert_expense_comparison_service.dart';
import 'package:my_web_app/widgets/bert_expense_comparison_card.dart';

Map<String, double> _buildTwelveScores({
  String topCategory = 'food',
  double topScore = 0.89,
}) {
  final remaining = (1.0 - topScore) / (BertExpenseCategories.all.length - 1);
  return <String, double>{
    for (final category in BertExpenseCategories.all)
      category: category == topCategory ? topScore : remaining,
  };
}

Widget _wrapAt360x800({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.indigo,
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        textScaler: TextScaler.linear(2.0),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  const validProvenance = BertModelProvenance(
    modelId: 'typed-decision-bert',
    weightRevision: 'rev-2026-11-28',
    pinnedSha: '0123456789abcdef0123456789abcdef01234567',
    runtimeKind: 'cpu_inference',
  );

  final verifiedRecord = BertSyntheticSampleRecord(
    sampleId: 'syn-001',
    syntheticMemo: '合成サンプル: スーパーで野菜と牛乳を購入',
    isSyntheticOnly: true,
    ruleCandidateCategory: 'food',
    status: BertMeasurementStatus.verified,
    provenance: validProvenance,
    modelCandidateCategory: 'food',
    uncalibratedScores: _buildTwelveScores(
      topCategory: 'food',
      topScore: 0.89,
    ),
    cpuInferenceMs: 42.5,
    httpRoundTripMs: 118.0,
    iterations: 3,
  );

  const notMeasuredRecord = BertSyntheticSampleRecord(
    sampleId: 'syn-pending',
    syntheticMemo: '合成サンプル: 未計測ケース',
    isSyntheticOnly: true,
    ruleCandidateCategory: 'convenience',
    status: BertMeasurementStatus.notMeasured,
    provenance: validProvenance,
  );

  const failedRecord = BertSyntheticSampleRecord(
    sampleId: 'syn-fail',
    syntheticMemo: '合成サンプル: 推論タイムアウト',
    isSyntheticOnly: true,
    ruleCandidateCategory: 'cafe_snack',
    status: BertMeasurementStatus.failed,
    provenance: validProvenance,
    errorCode: 'upstream_timeout',
    errorMessage: 'CPU inference timed out',
  );

  testWidgets(
      'renders loaded state with provenance and 12-category uncalibrated scores at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        child: BertExpenseComparisonCard(
          records: <BertSyntheticSampleRecord>[verifiedRecord],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('BERT 支出分類 合成サンプル比較（読み取り専用）'),
      findsOneWidget,
    );
    expect(find.text('合成サンプル専用'), findsOneWidget);
    expect(find.textContaining('typed-decision-bert'), findsOneWidget);
    expect(
      find.textContaining('0123456789abcdef0123456789abcdef01234567'),
      findsOneWidget,
    );
    expect(find.textContaining('食費・食材'), findsWidgets);
    expect(find.textContaining('89.0%（未校正）'), findsOneWidget);
    expect(find.textContaining('42.5 ms'), findsWidgets);
    expect(find.textContaining('118.0 ms'), findsWidgets);

    final expansionFinder = find.text('12カテゴリ未校正スコア内訳 (12件)');
    expect(expansionFinder, findsOneWidget);
    await tester.ensureVisible(expansionFinder);
    await tester.tap(expansionFinder);
    await tester.pumpAndSettle();

    expect(find.text('水道・光熱費'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'shows fetch failure honestly and recovers on retry at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var attempt = 0;
    Future<List<BertSyntheticSampleRecord>> loadRecords() async {
      attempt++;
      if (attempt == 1) {
        throw StateError('upstream_timeout');
      }
      return <BertSyntheticSampleRecord>[verifiedRecord];
    }

    await tester.pumpWidget(
      _wrapAt360x800(
        child: BertExpenseComparisonCard(loadRecords: loadRecords),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('比較結果の取得に失敗しました（成功扱いにはしません）'),
      findsOneWidget,
    );
    expect(find.textContaining('upstream_timeout'), findsOneWidget);
    expect(find.text('syn-001'), findsNothing);

    final retryFinder = find.text('再試行');
    expect(retryFinder, findsOneWidget);
    await tester.ensureVisible(retryFinder);
    await tester.tap(retryFinder);
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.text('syn-001'), findsOneWidget);
    expect(
      find.text('比較結果の取得に失敗しました（成功扱いにはしません）'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'renders empty and not_measured/failed states honestly at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.dark,
        child: const BertExpenseComparisonCard(
          records: <BertSyntheticSampleRecord>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('保存済みの合成サンプル比較結果はまだありません（未計測）'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.dark,
        child: const BertExpenseComparisonCard(
          records: <BertSyntheticSampleRecord>[
            notMeasuredRecord,
            failedRecord,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('syn-pending'), findsOneWidget);
    expect(find.text('syn-fail'), findsOneWidget);
    expect(find.textContaining('平均CPU推論: 未計測'), findsOneWidget);
    expect(
      find.textContaining('失敗詳細: upstream_timeout'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
