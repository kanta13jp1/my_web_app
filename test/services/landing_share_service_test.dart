import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_share_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeLandingPageAdapter implements LandingPageAdapter {
  int loadShareSnapshotCallCount = 0;
  int loadLpViewStatsCallCount = 0;
  final List<String> sharedChannels = <String>[];

  LandingShareSnapshot shareSnapshot = const LandingShareSnapshot(
    todayCount: 2,
    totalCount: 5,
    channelCounts: <String, int>{
      LandingShareService.channelX: 2,
      LandingShareService.channelCopy: 1,
    },
    lastChannel: LandingShareService.channelX,
  );

  LandingPageViewStats lpViewStats = LandingPageViewStats(
    todayViews: 3,
    monthViews: 7,
    totalViews: 11,
    series: <LandingPageViewPoint>[
      LandingPageViewPoint(date: DateTime(2026, 3, 1), count: 3),
      LandingPageViewPoint(date: DateTime(2026, 3, 2), count: 4),
    ],
  );

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<LandingShareSnapshot> loadShareSnapshot() async {
    loadShareSnapshotCallCount += 1;
    return shareSnapshot;
  }

  @override
  Future<LandingPageViewStats> loadLpViewStats() async {
    loadLpViewStatsCallCount += 1;
    return lpViewStats;
  }

  @override
  Future<String> improveTrialPrompt({
    required String prompt,
  }) async {
    return 'ACTION: Test action\nREASON: Test reason';
  }

  @override
  Future<LandingShareSnapshot> shareLandingPage({
    required String channel,
  }) async {
    sharedChannels.add(channel);
    shareSnapshot = LandingShareSnapshot(
      todayCount: shareSnapshot.todayCount + 1,
      totalCount: shareSnapshot.totalCount + 1,
      channelCounts: <String, int>{
        ...shareSnapshot.channelCounts,
        channel: shareSnapshot.countFor(channel) + 1,
      },
      lastChannel: channel,
    );
    return shareSnapshot;
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) => Future<AuthResponse>.error(
        UnsupportedError('signInWithPassword is not used in this test'),
      );

  @override
  Future<bool> signInWithGoogle({
    String? redirectTo,
  }) => Future<bool>.value(true);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) => Future<AuthResponse>.error(
        UnsupportedError('signUp is not used in this test'),
      );

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) => Future<void>.value();

  @override
  Future<void> recordInboxOpen() async {}

  @override
  Future<void> recordSaveCta() async {}

  @override
  Future<void> recordTrialRun() async {}
}

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
        <String, String>{'src': 'facebook'},
      ),
      'facebook',
    );
    expect(
      LandingShareService.resolveIncomingSource(
        <String, String>{'src': 'copy'},
      ),
      'copy_link',
    );
    expect(
      LandingShareService.resolveIncomingSource(
        <String, String>{'src': 'unknown'},
      ),
      isNull,
    );
  });

  testWidgets('LandingPage uses injected adapter for initial load and sharing',
      (WidgetTester tester) async {
    final adapter = _FakeLandingPageAdapter();

    await tester.pumpWidget(
      MaterialApp(
        home: LandingPage(adapter: adapter),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('landing_page_scaffold')), findsOneWidget);
    expect(find.byKey(const Key('landing_hero_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_trial_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_auth_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_share_section')), findsOneWidget);
    expect(find.byKey(const Key('landing_pv_section')), findsOneWidget);
    expect(adapter.loadShareSnapshotCallCount, 1);
    expect(adapter.loadLpViewStatsCallCount, 1);

    final shareButton = find.byKey(const Key('landing_share_button_x'));
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(adapter.sharedChannels, <String>[LandingShareService.channelX]);
  });
}
