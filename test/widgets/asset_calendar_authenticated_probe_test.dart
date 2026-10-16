import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/widgets/debt_progress_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fixtures/asset_calendar_authenticated_probe.dart' as probe;

void main() {
  final client = probe.ProbeMemoryHttp();
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: probe.probeOrigin,
      publishableKey: 'test-publishable-key',
      httpClient: client,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  test('synthetic owner restoration performs no HTTP or persisted login', () async {
    final before = client.requests.length;
    await probe.restoreProbeOwner();
    expect(Supabase.instance.client.auth.currentUser?.id, probe.probeOwner);
    expect(client.requests.length, before);
    expect(await const EmptyLocalStorage().hasAccessToken(), isFalse);
  });

  test('memory HTTP rejects external destinations and every POST', () async {
    final localPost = await client.post(
      Uri.parse('${probe.probeOrigin}/rest/v1/cfo_assets'),
    );
    expect(localPost.statusCode, 404);
    final external = await http.runWithClient(
      () => http.get(Uri.parse('https://outside.invalid/never-send')),
      () => client,
    );
    expect(external.statusCode, 403);
    expect(client.deniedWrites, 1);
    expect(client.deniedExternal, 1);
    // The stub has no delegate client: neither request has a transport path.
  });

  for (final lateSemantics in [false, true]) {
    testWidgets('real page async card then next with late semantics=$lateSemantics',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await probe.restoreProbeOwner();
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      client.historyGate = gate;
      final repository = probe.ProbeDelayedRepository(gate);
      SemanticsHandle? semantics;
      if (!lateSemantics) semantics = tester.ensureSemantics();
      try {
        await http.runWithClient(() async {
          await tester.pumpWidget(probe.AuthenticatedProbe(repository: repository));
          await tester.pump(const Duration(milliseconds: 600));
          final savings = find.byKey(
            const ValueKey('savings-life-plan:${probe.probeOwner}'),
          );
          expect(savings, findsNothing, reason: 'real page card waits for its snapshot',);
          expect(repository.loadCalls, 1);
          expect(repository.completedLoads, 0);
          await tester.tap(find.text('Probe: release synthetic data'));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(repository.completedLoads, 1);
          expect(savings, findsOneWidget, reason: 'card is inside the real page, not a harness sibling',);
          if (lateSemantics) {
            await tester.tap(find.text('Probe: enable semantics'));
            await tester.pump();
          }
          final next = find.byKey(const Key('asset_calendar_next_month'));
          await tester.ensureVisible(next);
          await tester.pump();
          expect(
            tester.semantics.simulatedAccessibilityTraversal(),
            contains(containsSemantics(label: '次のサイクル')),
          );
          expect(find.text('2026/5/25〜6/24'), findsOneWidget);
          expect(next.hitTestable(), findsOneWidget);
          await tester.tapAt(tester.getCenter(next));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('2026/6/25〜7/24'), findsOneWidget);
          expect(find.byType(DebtProgressShareDialog), findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }, () => client);
      } finally {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics?.dispose();
      }
    });
  }
}
