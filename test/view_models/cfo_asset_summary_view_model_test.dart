import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/department_finance_summary.dart';
import 'package:my_web_app/services/department_finance_summary_repository.dart';
import 'package:my_web_app/view_models/cfo_asset_summary_view_model.dart';

void main() {
  test('loads the current month summary', () async {
    final repository = _FakeRepository(_summary());
    final viewModel = CfoAssetSummaryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(repository.calls, 1);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.summary?.monthKey, '2026-09');
    expect(viewModel.errorMessage, isNull);
  });

  test('exposes a safe retryable error and recovers', () async {
    final repository = _FakeRepository(_summary())..failuresRemaining = 1;
    final viewModel = CfoAssetSummaryViewModel(repository: repository);
    addTearDown(viewModel.dispose);

    await viewModel.load();
    expect(viewModel.errorMessage, contains('もう一度お試しください'));
    expect(viewModel.summary, isNull);

    await viewModel.load();
    expect(repository.calls, 2);
    expect(viewModel.summary, isNotNull);
    expect(viewModel.errorMessage, isNull);
  });
}

class _FakeRepository implements DepartmentFinanceSummaryRepository {
  _FakeRepository(this.value);

  final DepartmentFinanceSummary value;
  int calls = 0;
  int failuresRemaining = 0;

  @override
  Future<DepartmentFinanceSummary> loadCurrentMonth() async {
    calls += 1;
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('private backend detail');
    }
    return value;
  }
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
