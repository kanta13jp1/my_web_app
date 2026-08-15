import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin_x_posted_today.dart';

void main() {
  // R16: /admin アクションカードの状態機械。今日投稿済みなら「X投稿を作る」を出さず、
  // ゴールデンアワー / 計測待ち / spend-cap 上限確認へ切り替える純ロジックを検証する。
  final now = DateTime(2026, 7, 8, 13, 0); // JST 想定のローカル時刻

  test('status 未取得(null) は none = 従来の「X投稿を作る」へフォールバック', () {
    expect(adminXPostedTodayCta(null, now), AdminXPostedTodayCta.none);
  });

  test('今日未投稿(count 0) も none', () {
    expect(
      adminXPostedTodayCta({'postedTodayCount': 0}, now),
      AdminXPostedTodayCta.none,
    );
  });

  test('blocked は最優先(投稿有無に関わらず)', () {
    expect(
      adminXPostedTodayCta(
        {'blocked': true, 'postedTodayCount': 1, 'resetAt': '2026-07-10'},
        now,
      ),
      AdminXPostedTodayCta.blocked,
    );
  });

  test('投稿後60分以内 → goldenHour', () {
    final status = {
      'postedTodayCount': 1,
      'lastPostedAt':
          now.toUtc().subtract(const Duration(minutes: 30)).toIso8601String(),
      'lastTweetId': '123',
    };
    expect(adminXPostedTodayCta(status, now), AdminXPostedTodayCta.goldenHour);
  });

  test('60分ちょうどは goldenHour、61分で measuring(境界)', () {
    Map<String, dynamic> at(int minutes) => {
          'postedTodayCount': 1,
          'lastPostedAt': now
              .toUtc()
              .subtract(Duration(minutes: minutes))
              .toIso8601String(),
        };
    expect(adminXPostedTodayCta(at(60), now), AdminXPostedTodayCta.goldenHour);
    expect(adminXPostedTodayCta(at(61), now), AdminXPostedTodayCta.measuring);
  });

  test('投稿後60分超 → measuring', () {
    final status = {
      'postedTodayCount': 2,
      'lastPostedAt':
          now.toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
    };
    expect(adminXPostedTodayCta(status, now), AdminXPostedTodayCta.measuring);
  });

  test('postedTodayCount が文字列でもパースされる', () {
    final status = {
      'postedTodayCount': '1',
      'lastPostedAt':
          now.toUtc().subtract(const Duration(hours: 2)).toIso8601String(),
    };
    expect(adminXPostedTodayCta(status, now), AdminXPostedTodayCta.measuring);
  });
}
