import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/shop_funnel_service.dart';

/// 流入元の正規化を固定する (2026-07-29 追加)。
///
/// 検証の主眼は**計測が黙って欠測しないこと**。EF 側は source を
/// `^[a-z0-9_.-]{1,64}$` に制限しており、弾かれた段は記録されない。
/// 記録されないことはエラーにならないので、**気づけないまま母数が欠ける**。
/// クライアント側で必ず通る形へ整えておく、という契約をここで固定する。
///
/// 実装メモ: URL は必ずローカル変数へ出す。式を直接引数に埋めると行が長くなり、
/// `ci-auto-fix.yml` の整形が折り返した先に末尾カンマが付かず
/// `require_trailing_commas` で CI が赤くなる (2026-07-29 に実際に踏んだ)。
void main() {
  const base = 'https://x.test/shop/hexciv';

  group('ShopFunnelService.sourceFromUri', () {
    test('utm_source が無ければ direct として数える', () {
      // 捨てると母数が合わなくなる。直接流入も1つの流入元として扱う。
      final uri = Uri.parse(base);
      expect(ShopFunnelService.sourceFromUri(uri), 'direct');
    });

    test('utm_source をそのまま流入元にする', () {
      final uri = Uri.parse('$base?utm_source=itch_io');
      expect(ShopFunnelService.sourceFromUri(uri), 'itch_io');
    });

    test('大文字は小文字に揃える (itch.io と Itch.io を別チャネルにしない)', () {
      final uri = Uri.parse('$base?utm_source=Itch_IO');
      expect(ShopFunnelService.sourceFromUri(uri), 'itch_io');
    });

    test('EF が弾く文字は置換する — 弾かれるとその段が丸ごと欠測するため', () {
      // 空白や日本語がそのまま行くと EF の 400 で記録されない。
      final uri = Uri.parse('$base?utm_source=X%20%E6%8A%95%E7%A8%BF');
      final source = ShopFunnelService.sourceFromUri(uri);
      final allowed = RegExp(r'^[a-z0-9_.-]{1,64}$');
      expect(
        allowed.hasMatch(source),
        isTrue,
        reason: 'EF の制限を満たさない値は記録されず、母数が欠ける',
      );
    });

    test('64文字を超える値は切り詰める', () {
      final long = 'a' * 200;
      final uri = Uri.parse('$base?utm_source=$long');
      expect(ShopFunnelService.sourceFromUri(uri).length, 64);
    });

    test('空の utm_source は direct に倒す', () {
      final uri = Uri.parse('$base?utm_source=');
      expect(ShopFunnelService.sourceFromUri(uri), 'direct');
    });
  });

  group('ShopFunnelService.campaignFromUri', () {
    test('utm_campaign が無ければ空文字', () {
      // campaign は補助軸なので、無いことが正常。source と違い direct へ倒さない。
      final uri = Uri.parse(base);
      expect(ShopFunnelService.campaignFromUri(uri), '');
    });

    test('utm_campaign を正規化して返す', () {
      final uri = Uri.parse('$base?utm_campaign=Launch-2026');
      expect(ShopFunnelService.campaignFromUri(uri), 'launch-2026');
    });
  });
}
