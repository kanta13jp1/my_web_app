import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';

void main() {
  test('composePostedStatus keeps the video-failure reason visible', () {
    // 実障害(2026-07-07): Hedraクレジット不足で静止画投稿になったが、理由は
    // 投稿前の一瞬のステータスにしか出ず operator が気づけなかった。投稿完了
    // メッセージに短縮した理由を残す。
    final message = composePostedStatus(
      posted: true,
      account: '@kanta13jp1',
      videoAttached: false,
      videoFailReason:
          'Hedra のクレジットが不足しています（必要 119 / 残り 68 クレジット）。動画生成には Hedra クレジットの追加が必要です。',
    );
    expect(message, contains('画像付きで投稿しました'));
    expect(message, contains('動画なし:'));
    expect(message, contains('クレジットが不足'));
    // 最初の「。」までに短縮され、後続の説明文は落ちる。
    expect(message, isNot(contains('追加が必要')));
    // 🎉 は劣化投稿には付けない。
    expect(message, isNot(contains('🎉')));
  });

  test('composePostedStatus is unchanged for healthy paths', () {
    expect(
      composePostedStatus(
        posted: true,
        account: '@kanta13jp1',
        videoAttached: true,
        videoFailReason: null,
      ),
      '@kanta13jp1 に動画付きで投稿しました 🎉',
    );
    expect(
      composePostedStatus(
        posted: true,
        account: null,
        videoAttached: false,
        videoFailReason: null,
      ),
      '@kanta13jp1 に画像付きで投稿しました 🎉',
    );
    expect(
      composePostedStatus(
        posted: false,
        account: null,
        videoAttached: false,
        videoFailReason: null,
      ),
      contains('投稿できませんでした'),
    );
  });

  test('composePostedStatus discloses reused-video posts without 🎉', () {
    final message = composePostedStatus(
      posted: true,
      account: '@kanta13jp1',
      videoAttached: true,
      videoFailReason:
          'Hedra のクレジットが不足しています（必要 119 / 残り 68 クレジット）。動画生成には追加が必要です。',
      videoReused: true,
      reusedVideoDate: '7/6',
    );
    expect(message, contains('動画付きで投稿しました'));
    expect(message, contains('7/6生成'));
    expect(message, contains('過去動画を再利用'));
    expect(message, contains('動画生成不可:'));
    expect(message, isNot(contains('🎉')));

    // 理由なし(プリフライトスキップ等で理由未設定)でも再利用は開示する。
    final noReason = composePostedStatus(
      posted: true,
      account: '@kanta13jp1',
      videoAttached: true,
      videoFailReason: null,
      videoReused: true,
      reusedVideoDate: '7/6',
    );
    expect(noReason, contains('過去動画を再利用'));
    expect(noReason, isNot(contains('🎉')));
  });

  test('composePostedStatus caps very long reasons at 60 runes', () {
    final message = composePostedStatus(
      posted: true,
      account: '@kanta13jp1',
      videoAttached: false,
      videoFailReason: 'あ' * 200,
    );
    // 60 runes + 省略記号 + 前後の定型文に収まる。
    expect(message.contains('…'), isTrue);
    expect(message.runes.length, lessThan(120));
  });

  test('composePostedTweetUrl builds /i/status/ links and rejects blanks', () {
    // /i/status/ 形式はアカウント名(@付き/表記ゆれ)に依存しない。
    expect(
      composePostedTweetUrl('2074234802048503845'),
      'https://x.com/i/status/2074234802048503845',
    );
    expect(composePostedTweetUrl(null), isNull);
    expect(composePostedTweetUrl('   '), isNull);
  });
}
