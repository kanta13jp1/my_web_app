import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/asset_subscription_statement_scan.dart';
import 'package:my_web_app/services/asset_subscription_statement_scan_service.dart';
import 'package:my_web_app/view_models/asset_subscription_statement_scan_view_model.dart';

void main() {
  final image = AssetSubscriptionStatementImage(
    fileName: 'statement.png',
    mimeType: 'image/png',
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
  );

  test(
    'analyzes, removes existing duplicates, and totals monthly amounts',
    () async {
      final viewModel = AssetSubscriptionStatementScanViewModel(
        imagePicker: _FakePicker(image),
        analyzer: _FakeAnalyzer(<AssetSubscriptionStatementCandidate>[
          _candidate('netflix', 'Netflix', 1980),
          _candidate(
            'icloud',
            'iCloud+',
            12000,
            cycle: AssetSubscriptionBillingCycle.annual,
          ),
        ]),
        existingSubscriptions: const <AssetRecurringFixedCost>[
          AssetRecurringFixedCost(
            id: 'existing_netflix',
            name: 'Netflix',
            amount: 1980,
            paymentDay: 10,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
        now: () => DateTime(2026, 8, 22),
      );

      await viewModel.pickAndAnalyze();

      expect(viewModel.reviews, hasLength(2));
      expect(viewModel.duplicateCount, 1);
      expect(viewModel.selectedCount, 1);
      expect(viewModel.selectedMonthlyTotal, 1000);
      expect(viewModel.selectedAnnualTotal, 12000);
      expect(
        viewModel.reviews.last.decision,
        AssetSubscriptionReviewDecision.hold,
      );
    },
  );

  test(
    'builds selected recurring costs with user decisions and source',
    () async {
      final viewModel = AssetSubscriptionStatementScanViewModel(
        imagePicker: _FakePicker(image),
        analyzer: _FakeAnalyzer(<AssetSubscriptionStatementCandidate>[
          _candidate('netflix', 'Netflix', 1980),
        ]),
        existingSubscriptions: const <AssetRecurringFixedCost>[],
        now: () => DateTime.fromMicrosecondsSinceEpoch(42),
      );
      await viewModel.pickAndAnalyze();
      viewModel.setSourceAccountId('paypay_card');
      viewModel.setDecision(
        'netflix',
        AssetSubscriptionReviewDecision.cancelCandidate,
      );

      final cost = viewModel.buildSelectedCosts().single;
      expect(cost.id, 'sub_statement_42_0');
      expect(cost.sourceAccountId, 'paypay_card');
      expect(cost.amount, 1980);
      expect(
        cost.subscriptionReviewDecision,
        AssetSubscriptionReviewDecision.cancelCandidate,
      );
      expect(viewModel.cancelCandidateMonthlySavings, 1980);
    },
  );

  test('reports a clear empty-result error', () async {
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: _FakePicker(image),
      analyzer: const _FakeAnalyzer(<AssetSubscriptionStatementCandidate>[]),
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );

    await viewModel.pickAndAnalyze();

    expect(viewModel.hasResults, isFalse);
    expect(viewModel.errorMessage, contains('候補を特定できませんでした'));
  });
}

AssetSubscriptionStatementCandidate _candidate(
  String id,
  String name,
  double amount, {
  AssetSubscriptionBillingCycle cycle = AssetSubscriptionBillingCycle.monthly,
}) {
  return AssetSubscriptionStatementCandidate(
    id: id,
    serviceName: name,
    chargedAmountJpy: amount,
    chargedAt: DateTime(2026, 8, 10),
    billingCycle: cycle,
    billingGateway: AssetSubscriptionBillingGateway.direct,
    confidence: 0.9,
    evidence: '定期請求の可能性',
  );
}

class _FakePicker implements AssetSubscriptionStatementImagePicker {
  final AssetSubscriptionStatementImage? image;

  const _FakePicker(this.image);

  @override
  Future<AssetSubscriptionStatementImage?> pickImage() async => image;
}

class _FakeAnalyzer implements AssetSubscriptionStatementAnalyzer {
  final List<AssetSubscriptionStatementCandidate> candidates;

  const _FakeAnalyzer(this.candidates);

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async =>
      candidates;
}
