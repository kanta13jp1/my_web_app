import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_alert_dismissal_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/asset_alert_center_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DismissalProbe extends AssetAlertDismissalStore {
  Set<String> ids = <String>{};
  String? failingOperation;
  int dismissAttempts = 0;
  int restoreAttempts = 0;

  @override
  Future<Set<String>> load({SharedPreferences? prefs}) async =>
      Set<String>.from(ids);

  @override
  Future<Set<String>> dismiss(String id, {SharedPreferences? prefs}) async {
    dismissAttempts++;
    if (failingOperation == 'dismiss') {
      throw StateError('synthetic failure with private payload');
    }
    ids = <String>{...ids, id};
    return Set<String>.from(ids);
  }

  @override
  Future<void> restoreAll({SharedPreferences? prefs}) async {
    restoreAttempts++;
    if (failingOperation == 'restoreAll') {
      throw StateError('synthetic failure with private payload');
    }
    ids = <String>{};
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-only',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });

  Future<void> pumpPage(WidgetTester tester, _DismissalProbe probe) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 5, 15);
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          alertDismissalStore: probe,
          debugCalendarNow: now,
          debugInitialAssetData: <String, Map<String, double>>{
            DateFormat('yyyy-MM-dd').format(now): const <String, double>{
              'PayPayカード': -1000,
            },
          },
          debugInitialRecentFlows: const [],
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  AssetAlertCenterCard card(WidgetTester tester) =>
      tester.widget<AssetAlertCenterCard>(find.byType(AssetAlertCenterCard));

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('alert dismissal failure is visible and does not hide the alert',
      (tester) async {
    final probe = _DismissalProbe()..failingOperation = 'dismiss';
    await pumpPage(tester, probe);
    final before = card(tester).center.alerts.map((a) => a.id).toList();
    expect(before, isNotEmpty);
    card(tester).onDismiss!(before.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.dismissAttempts, 1);
    expect(card(tester).center.alerts.map((a) => a.id), before);
    expect(find.text('非表示の保存結果を確認できませんでした。再読込して状態を確認してください。'), findsOneWidget);
    expect(find.textContaining('private payload'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('alert restoration failure retains the dismissed view',
      (tester) async {
    final probe = _DismissalProbe();
    await pumpPage(tester, probe);
    final id = card(tester).center.alerts.first.id;
    card(tester).onDismiss!(id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.dismissAttempts, 1);
    expect(probe.ids, contains(id));
    expect(card(tester).center.dismissedCount, 1);
    probe.failingOperation = 'restoreAll';
    card(tester).onRestoreDismissed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.restoreAttempts, 1);
    expect(card(tester).center.dismissedCount, 1);
    expect(card(tester).center.alerts.any((a) => a.id == id), isFalse);
    expect(find.text('再表示の保存結果を確認できませんでした。再読込して状態を確認してください。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('confirmed alert dismissal can be restored', (tester) async {
    final probe = _DismissalProbe();
    await pumpPage(tester, probe);
    final id = card(tester).center.alerts.first.id;
    card(tester).onDismiss!(id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.dismissAttempts, 1);
    expect(probe.ids, contains(id));
    expect(card(tester).center.dismissedCount, 1);
    card(tester).onRestoreDismissed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(probe.dismissAttempts, 1);
    expect(probe.restoreAttempts, 1);
    expect(card(tester).center.dismissedCount, 0);
    expect(card(tester).center.alerts.any((a) => a.id == id), isTrue);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
