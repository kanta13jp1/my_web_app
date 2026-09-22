import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/paddle_invoice_access.dart';

void main() {
  group('PaddleInvoiceAccessConfig', () {
    test('accepts a stable generic sandbox customer portal URL', () {
      const config = PaddleInvoiceAccessConfig(
        enabled: true,
        customerPortalUrl:
            'https://sandbox-customer-portal.paddle.com/cpl_sandboxtest123',
        releaseMode: false,
      );

      expect(config.shouldExpose, isTrue);
      expect(config.canOpen, isTrue);
      expect(config.portalUri?.host, 'sandbox-customer-portal.paddle.com');
      expect(config.validationMessage, isNull);
    });

    test('rejects production, insecure, and temporary authenticated URLs', () {
      const rejected = [
        'https://customer-portal.paddle.com/cpl_live',
        'http://sandbox-customer-portal.paddle.com/cpl_sandbox',
        'https://sandbox-customer-portal.paddle.com/cpl_sandbox?token=secret',
        'https://sandbox-customer-portal.paddle.com/cpl_sandbox/transactions',
      ];

      for (final url in rejected) {
        final config = PaddleInvoiceAccessConfig(
          enabled: true,
          customerPortalUrl: url,
          releaseMode: false,
        );
        expect(config.canOpen, isFalse, reason: url);
        expect(config.portalUri, isNull, reason: url);
      }
    });

    test('never exposes the sandbox portal in a release build', () {
      const config = PaddleInvoiceAccessConfig(
        enabled: true,
        customerPortalUrl:
            'https://sandbox-customer-portal.paddle.com/cpl_sandboxtest123',
        releaseMode: true,
      );

      expect(config.shouldExpose, isFalse);
      expect(config.canOpen, isFalse);
      expect(config.validationMessage, contains('本番ビルド'));
    });
  });
}
