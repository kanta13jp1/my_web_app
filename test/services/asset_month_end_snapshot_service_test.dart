import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_month_end_snapshot_service.dart';
import 'package:my_web_app/widgets/asset_month_end_snapshot_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AssetMonthEndSnapshot checkpoint() => AssetMonthEndSnapshot.fromJson({
      'month_key': '2026-08-01',
      'cutoff_at': '2026-08-31T15:00:00Z',
      'captured_at': '2026-08-31T15:05:00Z',
      'total_assets': 1200,
      'total_liabilities': -4000,
      'net_worth': -2800,
      'accounts': [
        {
          'title': 'sample account',
          'observed_at': '2026-07-31T14:00:00Z',
          'stale': true,
        }
      ],
      'stale_account_count': 1,
    });

class MemoryService extends AssetMonthEndSnapshotService {
  MemoryService() : super(SupabaseClient('https://example.invalid', 'test'));
  bool enabled = false;
  bool fail = false;
  int loads = 0;
  @override
  Future<bool> isEnabled() async => enabled;
  @override
  Future<List<AssetMonthEndSnapshot>> load() async {
    loads++;
    if (fail) throw StateError('unavailable');
    return [checkpoint()];
  }

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }
}

void main() {
  test('preserves observed timestamps and separates missing months from zero',
      () {
    final snapshot = checkpoint();
    final comparison = monthEndComparison(
      monthKeys: ['2026-08', '2026-09', '2026-10'],
      snapshots: [snapshot],
    );
    expect(comparison[0]?.totalAssets, 1200);
    expect(comparison[1], isNull);
    expect(comparison[2], isNull);
    expect(snapshot.cutoffAt, DateTime.utc(2026, 8, 31, 15));
    expect(snapshot.accounts.single['observed_at'], '2026-07-31T14:00:00Z');
    expect(snapshot.staleAccountCount, 1);
  });

  testWidgets('narrow view preserves gaps and opt-in is explicit',
      (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = MemoryService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AssetMonthEndSnapshotCard(
              service: service,
              monthKeys: const ['2026-08', '2026-09', '2026-10'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('未取得'), findsNWidgets(2));
    expect(service.enabled, isFalse);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(service.enabled, isTrue);
    await tester.tap(find.byTooltip('月末記録だけ更新'));
    await tester.pumpAndSettle();
    expect(service.loads, 3);
  });

  testWidgets('load failure is visible and retry recovers', (tester) async {
    final service = MemoryService()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetMonthEndSnapshotCard(
            service: service,
            monthKeys: const ['2026-08'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('取得できませんでした'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.byTooltip('月末記録だけ更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('取得できませんでした'), findsNothing);
    expect(find.text('2026-08'), findsOneWidget);
  });
}
