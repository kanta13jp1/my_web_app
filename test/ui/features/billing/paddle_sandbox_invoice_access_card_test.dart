import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/paddle_invoice_access.dart';
import 'package:my_web_app/ui/features/billing/views/paddle_sandbox_invoice_access_card.dart';

void main() {
  testWidgets('explains the issuer and opens the generic customer portal', (
    tester,
  ) async {
    Uri? launchedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaddleSandboxInvoiceAccessCard(
            config: _validConfig,
            launchPortal: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.textContaining('発行元は'), findsOneWidget);
    expect(find.textContaining('Merchant of Record'), findsOneWidget);
    expect(find.textContaining('マジックリンク'), findsOneWidget);
    expect(find.textContaining('Download invoice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('paddle_sandbox_invoice_button')));
    await tester.pumpAndSettle();

    expect(launchedUri, _validConfig.portalUri);
  });

  testWidgets('shows a public error without exposing launcher details', (
    tester,
  ) async {
    const sensitiveDetail = 'token=do-not-render';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaddleSandboxInvoiceAccessCard(
            config: _validConfig,
            launchPortal: (_) async => throw Exception(sensitiveDetail),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('paddle_sandbox_invoice_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('請求書画面を開けませんでした'), findsOneWidget);
    expect(find.textContaining(sensitiveDetail), findsNothing);
  });

  testWidgets('keeps the help readable on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PaddleSandboxInvoiceAccessCard(
              config: _validConfig,
              launchPortal: (_) async => true,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('VAT / Tax ID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disables access when only a temporary URL is configured', (
    tester,
  ) async {
    const config = PaddleInvoiceAccessConfig(
      enabled: true,
      customerPortalUrl:
          'https://sandbox-customer-portal.paddle.com/cpl_test?token=temporary',
      releaseMode: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaddleSandboxInvoiceAccessCard(
            config: config,
            launchPortal: (_) async => true,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('paddle_sandbox_invoice_button')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('汎用Customer Portal URL'), findsOneWidget);
  });
}

const _validConfig = PaddleInvoiceAccessConfig(
  enabled: true,
  customerPortalUrl:
      'https://sandbox-customer-portal.paddle.com/cpl_sandboxtest123',
  releaseMode: false,
);
