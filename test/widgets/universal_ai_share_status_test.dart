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
}
