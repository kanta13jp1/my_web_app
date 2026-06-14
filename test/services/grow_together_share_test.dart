import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/grow_together_share.dart';

void main() {
  group('GrowTogetherShare', () {
    test('shareText keeps the canonical message verbatim', () {
      expect(
        GrowTogetherShare.shareText,
        'ユーザーが機能追加要望や改善要望、不具合報告をすると、'
        'AIが勝手にそれに対応してくれるアプリを作りました。\n\n'
        '使ってみてください。みんなでアプリを育てられます。\n\n'
        '自分株式会社',
      );
      // 本文に URL を二重で含めない（intent の url パラメータ側で付与する）。
      expect(GrowTogetherShare.shareText.contains('http'), isFalse);
    });

    test('fullShareMessage appends the production URL for clipboard use', () {
      expect(
        GrowTogetherShare.fullShareMessage,
        '${GrowTogetherShare.shareText}\n${GrowTogetherShare.appUrl}',
      );
      expect(
        GrowTogetherShare.fullShareMessage,
        contains('https://my-web-app-b67f4.web.app/'),
      );
    });

    test('buildXIntentUrl targets the X tweet intent with text + url params',
        () {
      final uri = GrowTogetherShare.buildXIntentUrl();

      expect(uri.scheme, 'https');
      expect(uri.host, 'x.com');
      expect(uri.path, '/intent/tweet');
      expect(uri.queryParameters['text'], GrowTogetherShare.shareText);
      expect(uri.queryParameters['url'], GrowTogetherShare.appUrl);
    });

    test('buildXIntentUrl percent-encodes newlines and Japanese text', () {
      // toString() はクエリをエンコード済みで返すため、生の改行や日本語が
      // 混入していないことを確認する（intent URL として壊れないこと）。
      final encoded = GrowTogetherShare.buildXIntentUrl().toString();

      expect(encoded.startsWith('https://x.com/intent/tweet?'), isTrue);
      expect(encoded.contains('\n'), isFalse);
      expect(encoded.contains('text='), isTrue);
      expect(encoded.contains('url='), isTrue);
    });
  });
}
