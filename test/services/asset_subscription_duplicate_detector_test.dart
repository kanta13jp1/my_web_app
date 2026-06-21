import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/services/asset_subscription_duplicate_detector.dart';

void main() {
  // 短いラッパー (長い式の折返しを避け、formatter のバージョン差に依存しない形にする)。
  String? keyOf(String name) {
    return AssetSubscriptionDuplicateDetector.providerFor(name)?.key;
  }

  SubscriptionDuplicateMember member(
    String id,
    String name,
    double amount, {
    AssetSubscriptionBillingGateway gateway =
        AssetSubscriptionBillingGateway.direct,
  }) {
    return (id: id, name: name, amount: amount, gateway: gateway);
  }

  group('AssetSubscriptionDuplicateDetector.providerFor', () {
    test('maps known cloud/AI providers; unknown is null', () {
      expect(keyOf('Google One 100GB'), 'google');
      expect(keyOf('Google AI Pro 5TB'), 'google');
      expect(keyOf('iCloud+ 2TB'), 'apple');
      expect(keyOf('ChatGPT Pro 20x'), 'openai');
      // 過度に一般的な語 (X / LINE / マネフォ) は提供元化しない (誤検出回避)。
      expect(keyOf('X Premium'), isNull);
      expect(keyOf('LINEスタンプ プレミアム'), isNull);
      expect(keyOf('マネーフォワードME'), isNull);
    });

    test('short-substring keywords do not false-match (no aws→Lawson)', () {
      // 'aws' のような短い部分一致は「Lawson」に誤当たりするため keyword に入れない。
      expect(keyOf('Lawson'), isNull);
    });

    test('multi-word keywords match after whitespace collapse', () {
      // 正規化で空白を除くため、複数語ブランドも部分一致する契約を pin。
      expect(keyOf('Office 365'), 'microsoft');
      expect(keyOf('Creative Cloud'), 'adobe');
      expect(keyOf('Amazon Prime Video'), 'amazon');
    });
  });

  group('AssetSubscriptionDuplicateDetector.detect', () {
    test('flags the real Google One + Google AI Pro overlap', () {
      final subs = <SubscriptionDuplicateMember>[
        member(
          'a',
          'Google One 100GB',
          290,
          gateway: AssetSubscriptionBillingGateway.apple,
        ),
        member('b', 'Google AI Pro 5TB', 2900),
        member(
          'c',
          'iCloud+ 2TB',
          1500,
          gateway: AssetSubscriptionBillingGateway.apple,
        ),
        member(
          'd',
          'ChatGPT Pro 20x',
          30000,
          gateway: AssetSubscriptionBillingGateway.apple,
        ),
      ];
      final groups = AssetSubscriptionDuplicateDetector.detect(subs);
      // Google だけが 2 件 → 1 グループ。iCloud/ChatGPT は単独なので対象外。
      expect(groups.length, 1);
      expect(groups.single.providerKey, 'google');
      expect(groups.single.providerLabel, 'Google');
      expect(groups.single.members.map((m) => m.id), <String>['a', 'b']);
      expect(groups.single.totalAmount, 3190);
    });

    test('single subscription per provider yields no group', () {
      final subs = <SubscriptionDuplicateMember>[
        member('a', 'Google One 100GB', 290),
        member('b', 'iCloud+ 2TB', 1500),
      ];
      expect(AssetSubscriptionDuplicateDetector.detect(subs), isEmpty);
    });

    test('ignoredProviderKeys suppresses the group', () {
      final subs = <SubscriptionDuplicateMember>[
        member('a', 'Google One 100GB', 290),
        member('b', 'Google AI Pro 5TB', 2900),
      ];
      final groups = AssetSubscriptionDuplicateDetector.detect(
        subs,
        ignoredProviderKeys: const <String>{'google'},
      );
      expect(groups, isEmpty);
    });

    test('groups sort by total amount descending', () {
      final subs = <SubscriptionDuplicateMember>[
        member('a', 'Dropbox Plus', 1500),
        member('b', 'Dropbox Family', 2000), // dropbox 合計 3500
        member('c', 'Google One 100GB', 290),
        member('d', 'Google AI Pro 5TB', 2900), // google 合計 3190
      ];
      final groups = AssetSubscriptionDuplicateDetector.detect(subs);
      // 合計の降順: dropbox (3500) → google (3190)。
      expect(groups.map((g) => g.providerKey), <String>['dropbox', 'google']);
    });
  });
}
