import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_subscription_statement_scan.dart';
import 'package:my_web_app/services/asset_subscription_statement_scan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  AssetSubscriptionStatementImage image({
    String mimeType = 'image/png',
    int byteCount = 4,
  }) {
    return AssetSubscriptionStatementImage(
      fileName: 'statement.png',
      mimeType: mimeType,
      bytes: Uint8List(byteCount),
    );
  }

  test('sends an ephemeral image and maps sanitized candidates', () async {
    Map<String, dynamic>? request;
    final service = AssetSubscriptionStatementScanService(
      invoker: (body) async {
        request = body;
        return <String, dynamic>{
          'success': true,
          'candidates': <Map<String, dynamic>>[
            <String, dynamic>{
              'service_name': 'Netflix',
              'amount_jpy': 1980,
              'charged_at': '2026-08-10',
              'billing_cycle': 'monthly',
              'gateway': 'direct',
              'confidence': 0.92,
              'evidence': '毎月同額の動画サービス請求',
            },
            <String, dynamic>{'service_name': '', 'amount_jpy': 0},
          ],
        };
      },
    );

    final result = await service.analyze(image());

    expect(request?['action'], 'asset_subscription.analyze_statement');
    expect(request?['imageBase64'], isNotEmpty);
    expect(request?.containsKey('persist'), isFalse);
    expect(result, hasLength(1));
    expect(result.single.serviceName, 'Netflix');
    expect(result.single.monthlyEquivalentJpy, 1980);
    expect(result.single.annualEquivalentJpy, 23760);
  });

  test('annual charge is converted deterministically on the client', () async {
    final service = AssetSubscriptionStatementScanService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'candidates': <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': 'Cloud storage',
            'amount_jpy': 12000,
            'billing_cycle': 'annual',
            'confidence': 0.8,
          },
        ],
      },
    );

    final candidate = (await service.analyze(image())).single;
    expect(candidate.monthlyEquivalentJpy, 1000);
    expect(candidate.annualEquivalentJpy, 12000);
  });

  test('rejects unsupported and oversized images before invoking AI', () async {
    var calls = 0;
    final service = AssetSubscriptionStatementScanService(
      invoker: (_) async {
        calls++;
        return <String, dynamic>{'success': true, 'candidates': <dynamic>[]};
      },
    );

    await expectLater(
      service.analyze(image(mimeType: 'application/pdf')),
      throwsA(isA<AssetSubscriptionStatementScanException>()),
    );
    await expectLater(
      service.analyze(
        image(
          byteCount: AssetSubscriptionStatementScanService.maxImageBytes + 1,
        ),
      ),
      throwsA(isA<AssetSubscriptionStatementScanException>()),
    );
    expect(calls, 0);
  });

  test('removes long card-like numbers from returned text', () async {
    final service = AssetSubscriptionStatementScanService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'candidates': <Map<String, dynamic>>[
          <String, dynamic>{
            'service_name': 'Notion 4111 1111 1111 1111',
            'amount_jpy': 1650,
            'billing_cycle': 'monthly',
            'evidence': 'account 1234567890123456',
          },
        ],
      },
    );

    final candidate = (await service.analyze(image())).single;
    expect(candidate.serviceName, contains('[番号を除外]'));
    expect(candidate.evidence, contains('[番号を除外]'));
    expect(candidate.serviceName, isNot(contains('4111 1111')));
  });
}
