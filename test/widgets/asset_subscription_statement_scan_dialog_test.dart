import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/asset_subscription_statement_scan.dart';
import 'package:my_web_app/services/asset_subscription_statement_scan_service.dart';
import 'package:my_web_app/view_models/asset_subscription_statement_scan_view_model.dart';
import 'package:my_web_app/widgets/asset_subscription_statement_scan_dialog.dart';

void main() {
  testWidgets('imports reviewed candidates and shows deterministic totals', (
    tester,
  ) async {
    List<AssetRecurringFixedCost>? imported;
    final viewModel = _viewModel();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetSubscriptionStatementScanDialog(
            viewModel: viewModel,
            sourceAccountNames: const <String, String>{
              'paypay_card': 'PayPayカード',
            },
            onImport: (costs) => imported = costs,
          ),
        ),
      ),
    );

    expect(find.text('支払い明細のキャプチャーを1枚選ぶだけ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('subscription_statement_pick')));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.textContaining('月額換算 ¥1,980'), findsOneWidget);
    expect(find.text('月額換算'), findsOneWidget);
    expect(find.text('¥1,980'), findsOneWidget);
    expect(find.text('年間合計'), findsOneWidget);
    expect(find.text('¥23,760'), findsOneWidget);

    await tester.tap(find.byKey(const Key('subscription_statement_import')));
    await tester.pumpAndSettle();
    expect(imported, hasLength(1));
    expect(
      imported!.single.subscriptionReviewDecision,
      AssetSubscriptionReviewDecision.hold,
    );
  });

  testWidgets('fits a narrow viewport without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetSubscriptionStatementScanDialog(
            viewModel: _viewModel(),
            sourceAccountNames: const <String, String>{},
            onImport: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('subscription_statement_pick')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Netflix'), findsOneWidget);
    expect(
      find.byKey(const Key('subscription_statement_import')),
      findsOneWidget,
    );
  });
}

AssetSubscriptionStatementScanViewModel _viewModel() {
  return AssetSubscriptionStatementScanViewModel(
    imagePicker: const _FakePicker(),
    analyzer: const _FakeAnalyzer(),
    existingSubscriptions: const <AssetRecurringFixedCost>[],
    now: () => DateTime.fromMicrosecondsSinceEpoch(42),
  );
}

class _FakePicker implements AssetSubscriptionStatementImagePicker {
  const _FakePicker();

  @override
  Future<AssetSubscriptionStatementImage?> pickImage() async {
    return AssetSubscriptionStatementImage(
      fileName: 'statement.png',
      mimeType: 'image/png',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );
  }
}

class _FakeAnalyzer implements AssetSubscriptionStatementAnalyzer {
  const _FakeAnalyzer();

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async {
    return <AssetSubscriptionStatementCandidate>[
      AssetSubscriptionStatementCandidate(
        id: 'netflix',
        serviceName: 'Netflix',
        chargedAmountJpy: 1980,
        chargedAt: DateTime(2026, 8, 10),
        billingCycle: AssetSubscriptionBillingCycle.monthly,
        billingGateway: AssetSubscriptionBillingGateway.direct,
        confidence: 0.9,
        evidence: '同額の定期請求',
      ),
    ];
  }
}
