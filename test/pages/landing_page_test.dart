import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_share_service.dart';
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
      LandingPageViewPoint(
        date: DateTime(2026, 3, 1),
        count: 3,
      ),
      LandingPageViewPoint(
        date: DateTime(2026, 3, 2),
        count: 4,
      ),
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
  }) {
    return Future<AuthResponse>.error(
      UnsupportedError('signInWithPassword is not used in this test'),
    );
  }

  @override
  Future<bool> signInWithGoogle({
    String? redirectTo,
  }) {
    return Future<bool>.value(true);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) {
    return Future<AuthResponse>.error(
      UnsupportedError('signUp is not used in this test'),
    );
  }

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) {
    return Future<void>.value();
  }

  @override
  Future<void> recordInboxOpen() async {}

  @override
  Future<void> recordSaveCta() async {}

  @override
  Future<void> recordTrialRun() async {}
}

void main() {
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
