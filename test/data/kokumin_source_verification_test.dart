import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/kokumin_source_verification.dart';

void main() {
  const url = 'https://new-kokumin.jp/local-election-list';
  const sourceDate = '2026-11-11';
  const digest =
      '8132d6c24659aa340c846d12b97114e092e32d5ecde295f2236b9b44f93ead25';
  const post = 'https://x.com/tamakiyuichiro/status/2119639251365294529';

  test('PDF確認日は原本基準日と異なる固定日で全sourceキーに束縛する', () {
    expect(
      kokuminSourceVerifiedOn(
        sourceUrl: url,
        sourceDate: sourceDate,
        sourceDocumentSha256: digest,
      ),
      '2026-11-12',
    );
    expect(
      kokuminSourceVerificationLabel(
        sourceUrl: url,
        sourceDate: sourceDate,
        sourceDocumentSha256: digest,
      ),
      '出典確認日: 2026/11/12',
    );
  });

  test('最新mainと照合した別PDFも正確な出典キーで確認日を表示する', () {
    const currentDigest =
        '25e432b06b4f1ba860db772dae5de4d647a82a20a7eaae4050460526d00f3af5';
    expect(
      kokuminSourceVerificationLabel(
        sourceUrl: url,
        sourceDate: sourceDate,
        sourceDocumentSha256: currentDigest,
      ),
      '出典確認日: 2026/11/12',
    );
    for (final key in [
      ('https://example.com/other', sourceDate, currentDigest),
      (url, '2026-11-12', currentDigest),
      (url, sourceDate, '${currentDigest}0'),
    ]) {
      expect(
        kokuminSourceVerificationLabel(
          sourceUrl: key.$1,
          sourceDate: key.$2,
          sourceDocumentSha256: key.$3,
        ),
        '出典確認日: 未記録',
      );
    }
  });

  test('PDFのURL・基準日・hashの一つでも異なれば未記録', () {
    for (final key in [
      ('https://example.com/other', sourceDate, digest),
      (url, '2026-11-12', digest),
      (url, sourceDate, 'unknown'),
      (url, sourceDate, ''),
      (url, '', digest),
      ('', sourceDate, digest),
      (url, '2026-11-31', digest),
      (url, '2026-11-11T00:00:00Z', digest),
    ]) {
      expect(
        kokuminSourceVerifiedOn(
          sourceUrl: key.$1,
          sourceDate: key.$2,
          sourceDocumentSha256: key.$3,
        ),
        isNull,
      );
      expect(
        kokuminSourceVerificationLabel(
          sourceUrl: key.$1,
          sourceDate: key.$2,
          sourceDocumentSha256: key.$3,
        ),
        '出典確認日: 未記録',
      );
    }
  });

  test('代表元投稿の確認日は発表日と分けて記録する', () {
    expect(
      kokuminSourceVerifiedOn(sourceUrl: post, sourceDate: '2026-11-09'),
      '2026-11-12',
    );
    expect(
      kokuminSourceVerificationLabel(
        sourceUrl: post,
        sourceDate: '2026-11-09',
      ),
      '出典確認日: 2026/11/12',
    );
  });

  test('代表元投稿もURL・発表日・source種別が変われば未記録', () {
    for (final key in [
      ('https://tamakinet.jp/', '2026-11-09', ''),
      ('https://x.com/tamakiyuichiro/status/unknown', '2026-11-09', ''),
      (post, '2026-11-12', ''),
      (post, '', ''),
      (post, '2026-11-09', digest),
    ]) {
      expect(
        kokuminSourceVerificationLabel(
          sourceUrl: key.$1,
          sourceDate: key.$2,
          sourceDocumentSha256: key.$3,
        ),
        '出典確認日: 未記録',
      );
    }
  });
}
