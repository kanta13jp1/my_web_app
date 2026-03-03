import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/landing_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('buildShareUrl keeps the base params and adds tracking', () {
    final shareUrl =
        LandingShareService.buildShareUrl(LandingShareService.channelX);
    final uri = Uri.parse(shareUrl);

    expect(uri.queryParameters['v'], 'test2025');
    expect(uri.queryParameters['src'], 'x_share');
    expect(uri.queryParameters['utm_source'], 'x_share');
    expect(uri.queryParameters['utm_medium'], 'social');
    expect(uri.queryParameters['utm_campaign'], 'share_boost');
  });

  test('recordShareAction stores local counters and resets daily count',
      () async {
    final first = await LandingShareService.recordShareAction(
      channel: LandingShareService.channelX,
      now: DateTime(2026, 3, 3, 9),
    );
    final second = await LandingShareService.recordShareAction(
      channel: LandingShareService.channelCopy,
      now: DateTime(2026, 3, 3, 10),
    );
    final nextDay = await LandingShareService.loadSnapshot(
      now: DateTime(2026, 3, 4, 8),
    );

    expect(first.todayCount, 1);
    expect(first.totalCount, 1);
    expect(first.countFor(LandingShareService.channelX), 1);

    expect(second.todayCount, 2);
    expect(second.totalCount, 2);
    expect(second.countFor(LandingShareService.channelX), 1);
    expect(second.countFor(LandingShareService.channelCopy), 1);
    expect(second.lastChannel, LandingShareService.channelCopy);

    expect(nextDay.todayCount, 0);
    expect(nextDay.totalCount, 2);
    expect(nextDay.countFor(LandingShareService.channelX), 1);
    expect(nextDay.countFor(LandingShareService.channelCopy), 1);
  });

  test('resolveIncomingSource maps supported share sources', () {
    expect(
      LandingShareService.resolveIncomingSource(<String, String>{'src': 'x'}),
      'x_share',
    );
    expect(
      LandingShareService.resolveIncomingSource(
          <String, String>{'src': 'facebook'}),
      'facebook',
    );
    expect(
      LandingShareService.resolveIncomingSource(
          <String, String>{'src': 'copy'}),
      'copy_link',
    );
    expect(
      LandingShareService.resolveIncomingSource(
          <String, String>{'src': 'unknown'}),
      isNull,
    );
  });
}
