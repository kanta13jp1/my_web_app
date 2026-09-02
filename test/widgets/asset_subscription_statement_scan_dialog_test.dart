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

    expect(find.text('支払い明細のキャプチャーを最大5枚まとめて選択'), findsOneWidget);
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

  testWidgets('opens inline login after an authentication failure', (
    tester,
  ) async {
    var loginCalls = 0;
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: const _FakePicker(),
      analyzer: const _AuthenticationRequiredAnalyzer(),
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetSubscriptionStatementScanDialog(
            viewModel: viewModel,
            sourceAccountNames: const <String, String>{},
            onImport: (_) {},
            onLogin: () async {
              loginCalls++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('subscription_statement_pick')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('subscription_statement_login')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('subscription_statement_login')));
    await tester.pumpAndSettle();

    expect(loginCalls, 1);
    expect(find.textContaining('ログインしました'), findsOneWidget);
    expect(viewModel.loginRequired, isFalse);
  });

  testWidgets('shows merged results and image count for a multi-image batch', (
    tester,
  ) async {
    final viewModel = AssetSubscriptionStatementScanViewModel(
      imagePicker: const _MultiImagePicker(),
      analyzer: const _MultiImageAnalyzer(),
      existingSubscriptions: const <AssetRecurringFixedCost>[],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetSubscriptionStatementScanDialog(
            viewModel: viewModel,
            sourceAccountNames: const <String, String>{},
            onImport: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('subscription_statement_pick')));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Notion'), findsOneWidget);
    expect(find.text('2 / 2枚'), findsOneWidget);
    expect(find.textContaining('画像間の重複 1件'), findsOneWidget);
    expect(find.text('画像を追加解析'), findsOneWidget);
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
  Future<List<AssetSubscriptionStatementImage>> pickImages() async =>
      <AssetSubscriptionStatementImage>[
        AssetSubscriptionStatementImage(
          fileName: 'statement.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ];
}

class _MultiImagePicker implements AssetSubscriptionStatementImagePicker {
  const _MultiImagePicker();

  @override
  Future<List<AssetSubscriptionStatementImage>> pickImages() async =>
      <AssetSubscriptionStatementImage>[
        AssetSubscriptionStatementImage(
          fileName: 'statement-1.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        AssetSubscriptionStatementImage(
          fileName: 'statement-2.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(<int>[2]),
        ),
      ];
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

class _AuthenticationRequiredAnalyzer
    implements AssetSubscriptionStatementAnalyzer {
  const _AuthenticationRequiredAnalyzer();

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) {
    throw const AssetSubscriptionStatementScanException(
      '明細のAI解析にはログインが必要です。',
      failure: AssetSubscriptionStatementScanFailure.authenticationRequired,
    );
  }
}

class _MultiImageAnalyzer implements AssetSubscriptionStatementAnalyzer {
  const _MultiImageAnalyzer();

  @override
  Future<List<AssetSubscriptionStatementCandidate>> analyze(
    AssetSubscriptionStatementImage image,
  ) async {
    if (image.fileName == 'statement-1.png') {
      return <AssetSubscriptionStatementCandidate>[
        _candidate('netflix', 'Netflix', 1980),
        _candidate('notion', 'Notion', 1650),
      ];
    }
    return <AssetSubscriptionStatementCandidate>[
      _candidate('notion-again', 'NOTION', 1650),
    ];
  }

  AssetSubscriptionStatementCandidate _candidate(
    String id,
    String name,
    double amount,
  ) {
    return AssetSubscriptionStatementCandidate(
      id: id,
      serviceName: name,
      chargedAmountJpy: amount,
      chargedAt: DateTime(2026, 8, 10),
      billingCycle: AssetSubscriptionBillingCycle.monthly,
      billingGateway: AssetSubscriptionBillingGateway.direct,
      confidence: 0.9,
      evidence: '同額の定期請求',
    );
  }
}
