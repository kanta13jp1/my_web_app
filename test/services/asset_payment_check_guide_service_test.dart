import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_payment_check_guide_service.dart';

void main() {
  const service = AssetPaymentCheckGuideService();

  group('AssetPaymentCheckGuideService.buildBaseGuide', () {
    test('embeds account, date and amount from the debt row', () {
      final guide = service.buildBaseGuide(
        debtName: 'ファミマカード',
        paymentSourceAccountName: '三井住友銀行大塚支店',
        paymentDate: DateTime(2026, 6, 8),
        paymentAmount: 22000,
      );
      expect(guide, contains('ファミマカード'));
      expect(guide, contains('三井住友銀行大塚支店'));
      expect(guide, contains('6月8日'));
      expect(guide, contains('22,000円'));
      expect(guide, contains('入出金明細'));
    });

    test('falls back to paymentDay when no exact date', () {
      final guide = service.buildBaseGuide(
        debtName: 'アコムショッピング',
        paymentSourceAccountName: '三井住友銀行',
        paymentDay: 8,
        paymentAmount: 68000,
      );
      expect(guide, contains('毎月8日'));
      expect(guide, contains('68,000円'));
    });

    test('uses generic wording when source account is missing', () {
      final guide = service.buildBaseGuide(
        debtName: 'カードローン',
        paymentDate: DateTime(2026, 6, 27),
        paymentAmount: 30000,
      );
      expect(guide, contains('引き落とし元の口座'));
      expect(guide, contains('6月27日'));
    });

    test('omits amount line gracefully when amount unknown', () {
      final guide = service.buildBaseGuide(
        debtName: 'リボ残高',
        paymentSourceAccountName: 'みずほ銀行',
        paymentDate: DateTime(2026, 6, 10),
        paymentAmount: 0,
      );
      // 金額が無くても支払予定日と負債名で手順が成立する。
      expect(guide, contains('6月10日'));
      expect(guide, contains('リボ残高'));
      expect(guide, isNot(contains('0円')));
    });
  });

  group('AssetPaymentCheckGuideService.buildAiPrompt', () {
    test('asks for institution-specific steps with the key facts', () {
      final prompt = service.buildAiPrompt(
        debtName: 'ファミマカード',
        paymentSourceAccountName: '三井住友銀行大塚支店',
        paymentDate: DateTime(2026, 6, 8),
        paymentAmount: 22000,
      );
      expect(prompt, contains('ファミマカード'));
      expect(prompt, contains('三井住友銀行大塚支店'));
      expect(prompt, contains('6月8日'));
      expect(prompt, contains('22,000円'));
      expect(prompt, contains('入出金明細'));
      expect(prompt, contains('日本語'));
    });

    test('degrades to generic account clause when source missing', () {
      final prompt = service.buildAiPrompt(
        debtName: 'カードローン',
        paymentDay: 27,
        paymentAmount: 30000,
      );
      expect(prompt, contains('引き落とし元の金融機関口座'));
      expect(prompt, contains('毎月27日'));
    });
  });
}
