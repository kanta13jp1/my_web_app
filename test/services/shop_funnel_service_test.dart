import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';

/// 流入元の正規化を固定する (2026-07-29 追加)。
///
/// 検証の主眼は**計測が黙って欠測しないこと**。EF 側は source を
/// `^[a-z0-9_.-]{1,64}$` に制限しており、弾かれた段は記録されない。
/// 記録されないことはエラーにならないので、**気づけないまま母数が欠ける**。
/// クライアント側で必ず通る形へ整えておく、という契約をここで固定する。
void main() {
  group('ShopFunnelService.sourceFromUri', () {
    test('utm_source が無ければ direct として数える', () {
      // 捨てると母数が合わなくなる。直接流入も1つの流入元として扱う。
      expect(
        ShopFunnelService.sourceFromUri(
            Uri.parse('https://x.test/shop/hexciv')),
        'direct',
      );
    });

    test('utm_source をそのまま流入元にする', () {
      expect(
        ShopFunnelService.sourceFromUri(
          Uri.parse('https://x.test/shop/hexciv?utm_source=itch_io'),
        ),
        'itch_io',
      );
    });

    test('大文字は小文字に揃える (itch.io と Itch.io を別チャネルにしない)', () {
      expect(
        ShopFunnelService.sourceFromUri(
          Uri.parse('https://x.test/shop/hexciv?utm_source=Itch_IO'),
        ),
        'itch_io',
      );
    });

    test('EF が弾く文字は置換する — 弾かれるとその段が丸ごと欠測するため', () {
      // 空白や日本語がそのまま行くと EF の 400 で記録されない。
      final source = ShopFunnelService.sourceFromUri(
        Uri.parse(
            'https://x.test/shop/hexciv?utm_source=X%20%E6%8A%95%E7%A8%BF'),
      );
      expect(
        RegExp(r'^[a-z0-9_.-]{1,64}$').hasMatch(source),
        isTrue,
        reason: 'EF の制限を満たさない値は記録されず、母数が欠ける',
      );
    });

    test('64文字を超える値は切り詰める', () {
      final long = 'a' * 200;
      final source = ShopFunnelService.sourceFromUri(
        Uri.parse('https://x.test/shop/hexciv?utm_source=$long'),
      );
      expect(source.length, 64);
    });

    test('空の utm_source は direct に倒す', () {
      expect(
        ShopFunnelService.sourceFromUri(
          Uri.parse('https://x.test/shop/hexciv?utm_source='),
        ),
        'direct',
      );
    });
  });

  group('ShopFunnelService.campaignFromUri', () {
    test('utm_campaign が無ければ空文字', () {
      // campaign は補助軸なので、無いことが正常。source と違い direct へ倒さない。
      expect(
        ShopFunnelService.campaignFromUri(
          Uri.parse('https://x.test/shop/hexciv'),
        ),
        '',
      );
    });

    test('utm_campaign を正規化して返す', () {
      expect(
        ShopFunnelService.campaignFromUri(
          Uri.parse('https://x.test/shop/hexciv?utm_campaign=Launch-2026'),
        ),
        'launch-2026',
      );
    });
  });
}
