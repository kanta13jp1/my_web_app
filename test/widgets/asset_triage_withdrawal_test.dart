import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _date = DateTime(2026, 9, 1);

class _RecordingRepository extends SharedPreferencesAssetLiabilityRepository {
  _RecordingRepository() {
    final defaults = const AssetLiabilityPlanningService().buildWorkbook(
      latestSnapshot: const <String, double>{}, baseDate: _date,
    );
    current = AssetLiabilityMonthlyState(
      paidAccountNames: defaults.debtMasterRows.map((row) => row.id).toSet(),
    );
  }
  late AssetLiabilityMonthlyState current;
  bool failSave = false;
  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async => current;
  @override
  Future<void> saveMonth({required DateTime month,
      required AssetLiabilityMonthlyState state}) async {
    if (failSave) throw StateError('synthetic storage failure');
    current = state;
  }
}

Future<void> _pump(WidgetTester tester, _RecordingRepository repository,
    {double bank = 500000}) async {
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  AssetRecurringTombstoneSyncService.resetSharedForTest();
  await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
    debugNow: _date, debugCalendarNow: _date,
    assetLiabilityRepository: repository,
    debugInitialAssetData: <String, Map<String, double>>{
      '2026-09-01': <String, double>{'財布(現金)': 1000, '三井住友銀行': bank},
    },
  )));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _tapAmount(WidgetTester tester, int amount) async {
  final button = find.byKey(Key('triage_withdrawal_template_$amount'));
  expect(button, findsOneWidget);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999', publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('triage amounts save once, recalculate and survive page recreation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final amount in [10000, 20000]) {
      final repository = _RecordingRepository();
      await _pump(tester, repository);
      expect(find.textContaining('生活費は専用財布へ'), findsWidgets);
      await _tapAmount(tester, amount);
      expect(repository.current.transferTasks, hasLength(1));
      final task = repository.current.transferTasks.single;
      expect(task.amount, amount.toDouble());
      expect(task.fromAccountName, '三井住友銀行');
      expect(task.toAccountName, '財布(現金)');
      expect(task.dueDate, _date);
      expect(task.completed, isFalse);
      final projected = amount == 10000 ? '¥490,000' : '¥480,000';
      expect(find.textContaining(projected), findsWidgets);
      await _tapAmount(tester, amount);
      expect(repository.current.transferTasks, hasLength(1));
      await _unmount(tester);
      await _pump(tester, repository);
      expect(find.textContaining(projected), findsWidgets);
      await _tapAmount(tester, amount);
      expect(repository.current.transferTasks, hasLength(1));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    }
  });

  testWidgets('pending withdrawal removes unaffordable templates', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingRepository();
    await _pump(tester, repository, bank: 15000);
    expect(find.byKey(const Key('triage_withdrawal_template_20000')), findsNothing);
    await _tapAmount(tester, 10000);
    expect(repository.current.transferTasks, hasLength(1));
    expect(find.byKey(const Key('triage_withdrawal_template_10000')), findsNothing);
    expect(find.textContaining('¥5,000'), findsWidgets);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('failed storage rolls back and allows retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    repository.failSave = true;
    await _tapAmount(tester, 10000);
    expect(repository.current.transferTasks, isEmpty);
    expect(find.textContaining('出金タスクを保存できませんでした'), findsOneWidget);
    repository.failSave = false;
    await _tapAmount(tester, 10000);
    expect(repository.current.transferTasks, hasLength(1));
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
