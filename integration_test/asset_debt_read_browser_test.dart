// Executed only after preparing the isolated synthetic factory.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/asset_debt_read_contract.dart';
import 'support/asset_debt_read_factory.dart';

const _owner = 'synthetic-owner';
const _debtName = 'Synthetic Loan';

Future<void> _wait(
  WidgetTester tester,
  Future<void> future,
  String phase,
) async {
  bool done = false;
  Object? failure;
  StackTrace? stack;
  future.then<void>(
    (_) {
      done = true;
    },
    onError: (Object e, StackTrace s) {
      failure = e;
      stack = s;
      done = true;
    },
  );
  for (var i = 0; i < 150 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) {
    throw TestFailure('fixture phase timed out: $phase');
  }
  if (failure != null) {
    Error.throwWithStackTrace(failure!, stack!);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final scenario in DebtReadScenario.values) {
    testWidgets('browser debt display and synthetic read: ${scenario.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        await tester.binding.setSurfaceSize(null);
      });
      AssetSyncDirtyKeysStore.resetWriteLockForTest();
      final harness = makeDebtReadHarness(scenario);
      final id = harness.id;
      await tester.pumpWidget(harness.root());
      await _wait(tester, harness.readStarted, 'automatic boot read');
      harness.respond();
      await _wait(tester, harness.waitRestore(), 'automatic restore');
      await _wait(tester, harness.waitBackfills(), 'backfill');
      await _wait(tester, harness.waitSaves(), 'local save');
      await _wait(tester, harness.waitWrites(), 'mirror write');
      await tester.pump(const Duration(milliseconds: 500));

      expect(harness.owners, <String>[_owner]);
      expect(
        harness.errorsEmitted,
        scenario == DebtReadScenario.failed ? 1 : 0,
      );
      final expectedDay = scenario == DebtReadScenario.existing ? 17 : 10;
      if (scenario == DebtReadScenario.failed) {
        expect(harness.writes, isEmpty);
        expect(harness.saves, isEmpty);
      } else {
        // Existing-row restore saves locally then mirrors; empty-row backfills.
        expect(harness.writes, <Map<String, int>>[
          <String, int>{id: expectedDay},
        ]);
      }
      if (scenario == DebtReadScenario.existing) {
        expect(harness.saves, <Map<String, int>>[
          <String, int>{id: 17},
        ]);
      }

      final name = find.text(_debtName);
      expect(name, findsWidgets);
      // This fixture has exactly one synthetic debt and suppresses built-in
      // fixed-payment rows; an ambiguous visible day is a failure.
      final day = find.text('${expectedDay}日支払');
      expect(day, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(day), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 500));
      expect(day.hitTestable(), findsOneWidget);
      expect(name.hitTestable(), findsWidgets);
      final selectedDay = find.text('${expectedDay}日').hitTestable();
      expect(selectedDay, findsOneWidget);
      await binding.takeScreenshot(
        'synthetic-debt-read-${scenario.name}',
        <String, Object?>{
          'width': 1440,
          'height': 1000,
          'devicePixelRatio': 1.0,
        },
      );
      await tester.tap(selectedDay);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('${expectedDay}日').last.hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        harness.writes.length,
        scenario == DebtReadScenario.failed ? 0 : 1,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
