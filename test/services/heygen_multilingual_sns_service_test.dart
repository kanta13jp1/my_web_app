import 'package:my_web_app/services/heygen_multilingual_sns_service.dart';
import 'package:test/test.dart';

void main() {
  test('buildKit creates HeyGen-ready variants for five languages', () {
    final kit = HeyGenMultilingualSnsService.buildKit(
      templateKey: 'dark_war',
      sourceLanguage: 'ja',
      caption: '時間とお金を浪費するツールを見直す広告',
      script: const [
        '複数アプリに奪われた時間を取り戻す。',
        '自分株式会社で生活管理を一つにする。',
      ],
    );

    expect(kit.templateKey, 'dark_war');
    expect(kit.variants.map((variant) => variant.localeCode), [
      'ja',
      'en',
      'ko',
      'zh',
      'es',
    ]);
    expect(kit.variants, hasLength(5));
    for (final variant in kit.variants) {
      expect(variant.videoScript, isNotEmpty);
      expect(variant.heygenBrief, contains('HeyGen'));
      expect(variant.xPost.length, lessThanOrEqualTo(280));
    }
  });

  test('clipboard bundle includes brief, script, and social post', () {
    final kit = HeyGenMultilingualSnsService.buildKit(
      templateKey: 'feature_highlight',
      sourceLanguage: 'en',
      caption: 'Protect time, money, health, and focus.',
      script: const [],
    );

    final english = kit.variants.singleWhere(
      (variant) => variant.localeCode == 'en',
    );

    expect(english.clipboardBundle, contains('HeyGen brief'));
    expect(english.clipboardBundle, contains('Video script'));
    expect(english.clipboardBundle, contains('X post'));
    expect(kit.allPostsForClipboard, contains('English'));
  });
}
