import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/payment_source.dart';

void main() {
  group('PaymentSource Model Tests', () {
    final now = DateTime.now();
    final sampleMap = {
      'id': 'ps_123',
      'name': 'Test Bank',
      'last_audited_at': now.toIso8601String(),
    };

    final nullAuditMap = {
      'id': 'ps_456',
      'name': 'New Card',
      'last_audited_at': null,
    };

    test('PaymentSource can be created from a map', () {
      final paymentSource = PaymentSource.fromMap(sampleMap);

      expect(paymentSource.id, 'ps_123');
      expect(paymentSource.name, 'Test Bank');
      expect(
        paymentSource.lastAuditedAt,
        DateTime.parse(now.toIso8601String()),
      );
    });

    test('PaymentSource handles null last_audited_at from map', () {
      final paymentSource = PaymentSource.fromMap(nullAuditMap);

      expect(paymentSource.id, 'ps_456');
      expect(paymentSource.name, 'New Card');
      expect(paymentSource.lastAuditedAt, isNull);
    });

    test('PaymentSource can be instantiated directly', () {
      final auditDate = DateTime(2023, 10, 26);
      final paymentSource = PaymentSource(
        id: 'ps_789',
        name: 'Manual Entry',
        lastAuditedAt: auditDate,
      );

      expect(paymentSource.id, 'ps_789');
      expect(paymentSource.name, 'Manual Entry');
      expect(paymentSource.lastAuditedAt, auditDate);
    });

    test('PaymentSource can be instantiated without lastAuditedAt', () {
      final paymentSource = PaymentSource(
        id: 'ps_000',
        name: 'Cash',
      );

      expect(paymentSource.id, 'ps_000');
      expect(paymentSource.name, 'Cash');
      expect(paymentSource.lastAuditedAt, isNull);
    });
  });
}
