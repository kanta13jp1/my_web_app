import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/referral_benefit_copy.dart';

void main() {
  group('ReferralBenefitCopy', () {
    test('states the give-get Stripe credit and activation gate honestly', () {
      expect(ReferralBenefitCopy.headline, contains('招待した人も'));
      expect(ReferralBenefitCopy.headline, contains('招待された人も'));
      expect(ReferralBenefitCopy.detail, contains('Stripe請求残高'));
      expect(ReferralBenefitCopy.detail, contains('次回請求に自動充当'));
      expect(ReferralBenefitCopy.detail, contains('登録だけでは付与されません'));
    });

    test('share text includes the invite URL and optional hashtags', () {
      const url = 'https://example.com/?ref=ABC123';
      final plain = ReferralBenefitCopy.buildShareText(url);
      final social = ReferralBenefitCopy.buildShareText(
        url,
        includeHashtags: true,
      );

      expect(plain, contains(url));
      expect(plain, contains('両方にPro月額1か月分のクレジット'));
      expect(plain, isNot(contains('#buildinpublic')));
      expect(social, contains('#buildinpublic'));
    });
  });
}
