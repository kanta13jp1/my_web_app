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

  test('analyzes multiple images sequentially and merges duplicates', () async {
    final secondImage = AssetSubscriptionStatementImage(
      fileName: 'statement-2.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[4, 5, 6]),
    );
    final analyzer = _PerImageAnalyzer(
      <String, List<AssetSubscriptionStatementCandidate>>{
        'statement.png': <AssetSubscriptionStatementCandidate>[
          _candidate('notion', 'Notion', 1650),
          _candidate('netflix', 'Netflix', 1980),
        ],
        'statement-2.png': <AssetSubscriptionStatementCandidate>[
          _candidate('notion-again', 'NOTION', 1650),
          _candidate('github', 'GitHub', 600),
        ],
      },
    );
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: _FakePicker(<AssetSubscriptionStatementImage>[
        image,
        secondImage,
      ]),
      analyzer: analyzer,
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );

    await viewModel.pickAndAnalyze();

    expect(analyzer.analyzedFileNames, <String>[
      'statement.png',
      'statement-2.png',
    ]);
    expect(
      viewModel.reviews.map((review) => review.candidate.serviceName),
      <String>['Notion', 'Netflix', 'GitHub'],
    );
    expect(viewModel.selectedImageCount, 2);
    expect(viewModel.analyzedImageCount, 2);
    expect(viewModel.mergedDuplicateCount, 1);
    expect(viewModel.fileFailures, isEmpty);
  });

  test('keeps successful results when one image fails', () async {
    final failedImage = AssetSubscriptionStatementImage(
      fileName: 'blurred.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[7, 8, 9]),
    );
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: _FakePicker(<AssetSubscriptionStatementImage>[
        image,
        failedImage,
      ]),
      analyzer: _PartiallyFailingAnalyzer(),
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );

    await viewModel.pickAndAnalyze();

    expect(viewModel.reviews, hasLength(1));
    expect(viewModel.reviews.single.candidate.serviceName, 'Netflix');
    expect(viewModel.analyzedImageCount, 1);
    expect(viewModel.fileFailures, hasLength(1));
    expect(viewModel.fileFailures.single.fileName, 'blurred.png');
    expect(viewModel.infoMessage, contains('解析結果を保持'));
  });

  test('rejects more than five selected images before analysis', () async {
    final images = <AssetSubscriptionStatementImage>[
      for (var index = 0; index < 6; index++)
        AssetSubscriptionStatementImage(
          fileName: 'statement-$index.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(<int>[index]),
        ),
    ];
    final analyzer = _PerImageAnalyzer(const {});
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: _FakePicker(images),
      analyzer: analyzer,
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );

    await viewModel.pickAndAnalyze();

    expect(viewModel.errorMessage, contains('5枚まで'));
    expect(analyzer.analyzedFileNames, isEmpty);
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
  final List<AssetSubscriptionStatementImage> images;

  _FakePicker(Object? value)
      : images = value is AssetSubscriptionStatementImage
            ? <AssetSubscriptionStatementImage>[value]
            : List<AssetSubscriptionStatementImage>.of(
                value as List<AssetSubscriptionStatementImage>? ?? const [],
              );

  @override
  Future<List<AssetSubscriptionStatementImage>> pickImages() async => images;
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

class _PerImageAnalyzer implements AssetSubscriptionStatementAnalyzer {
  final Map<String, List<AssetSubscriptionStatementCandidate>> candidatesByFile;
  final List<String> analyzedFileNames = <String>[];

  _PerImageAnalyzer(this.candidatesByFile);

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async {
    analyzedFileNames.add(image.fileName);
    return candidatesByFile[image.fileName] ?? const [];
  }
}

class _PartiallyFailingAnalyzer implements AssetSubscriptionStatementAnalyzer {
  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async {
    if (image.fileName == 'blurred.png') {
      throw const AssetSubscriptionStatementScanException('画像が不鮮明です。');
    }
    return <AssetSubscriptionStatementCandidate>[
      _candidate('netflix', 'Netflix', 1980),
    ];
  }
}
