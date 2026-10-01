import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/department_finance_summary.dart';
import 'package:my_web_app/services/department_finance_summary_repository.dart';
import 'package:my_web_app/view_models/cfo_asset_summary_view_model.dart';
import 'package:my_web_app/widgets/cfo_asset_summary_card.dart';

void main() {
  testWidgets('renders all four metrics at a narrow width without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final viewModel = CfoAssetSummaryViewModel(
      repository: _FakeRepository(_summary()),
    );
    addTearDown(viewModel.dispose);
    await viewModel.load();
    var detailsOpened = false;

    await tester.pumpWidget(
      _app(
        viewModel,
        onOpenDetails: () => detailsOpened = true,
      ),
    );

    expect(find.text('純資産'), findsOneWidget);
    expect(find.text('当月キャッシュフロー'), findsOneWidget);
    expect(find.text('投資評価額'), findsOneWidget);
    expect(find.text('未確認の異常'), findsOneWidget);
    expect(find.text('一部のみ反映'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('資産管理の詳細を見る'));
    await tester.tap(find.text('資産管理の詳細を見る'));
    expect(detailsOpened, isTrue);
  });

  testWidgets('shows progress while loading', (tester) async {
    final completer = Completer<DepartmentFinanceSummary>();
    final viewModel = CfoAssetSummaryViewModel(
      repository: _CompletingRepository(completer.future),
    );
    addTearDown(viewModel.dispose);

    unawaited(viewModel.load());
    await tester.pumpWidget(_app(viewModel));

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    completer.complete(_summary());
    await tester.pump();
  });

  testWidgets('offers retry after a failed request', (tester) async {
    final repository = _FakeRepository(_summary())..failuresRemaining = 1;
    final viewModel = CfoAssetSummaryViewModel(repository: repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    await tester.pumpWidget(_app(viewModel));
    expect(find.text('再読み込み'), findsOneWidget);

    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('純資産'), findsOneWidget);
  });
}

Widget _app(
  CfoAssetSummaryViewModel viewModel, {
  VoidCallback? onOpenDetails,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: CfoAssetSummaryCard(
          viewModel: viewModel,
          onOpenDetails: onOpenDetails ?? () {},
        ),
      ),
    ),
  );
}

class _FakeRepository implements DepartmentFinanceSummaryRepository {
  _FakeRepository(this.value);

  final DepartmentFinanceSummary value;
  int failuresRemaining = 0;
  int calls = 0;

  @override
  Future<DepartmentFinanceSummary> loadCurrentMonth() async {
    calls += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('offline');
    }
    return value;
  }
}

class _CompletingRepository implements DepartmentFinanceSummaryRepository {
  const _CompletingRepository(this.result);

  final Future<DepartmentFinanceSummary> result;

  @override
  Future<DepartmentFinanceSummary> loadCurrentMonth() => result;
}

DepartmentFinanceSummary _summary() {
  return const DepartmentFinanceSummary(
    monthKey: '2026-09',
    netAssets: 1250000,
    currentMonthCashflow: -25000,
    investmentValuation: 840000,
    anomalyCount: 3,
    netAssetsAvailability: FinanceMetricAvailability.available,
    currentMonthCashflowAvailability: FinanceMetricAvailability.available,
    investmentValuationAvailability: FinanceMetricAvailability.partial,
    anomalyCountAvailability: FinanceMetricAvailability.available,
  );
}
