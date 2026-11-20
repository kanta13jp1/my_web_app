import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _RecordingRepository extends SharedPreferencesAssetLiabilityRepository {
  final paidMonths = <DateTime>[];

  @override
  Future<void> saveMonth({
    required DateTime month,
    required AssetLiabilityMonthlyState state,
  }) async {
    if (state.paidAccountNames.contains('mobit')) {
      paidMonths.add(month);
    }
    await super.saveMonth(month: month, state: state);
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  testWidgets('使用可能額がマイナスのときは生活費優先ガードダイアログが挟まり、正のときはブロックされない (#4219)', (
    tester,
  ) async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 1. 使用可能額が負の場合: ガードダイアログが表示される
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugCalendarNow: DateTime(2026, 7, 10),
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{'三井住友銀行大塚支店': 5000, 'モビット': -45000},
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final negativeCheckbox = find.byKey(const Key('debt_paid_checkbox_mobit'));
    await tester.ensureVisible(negativeCheckbox);
    await tester.tap(negativeCheckbox);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsOneWidget,
    );

    // キャンセル時は支払済みにならない
    await tester.tap(find.byKey(const Key('living_guard_cancel_button')));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(negativeCheckbox).value, isFalse);

    // 再度タップして「それでも実行」で支払済みになる
    await tester.tap(negativeCheckbox);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('living_guard_force_execute_button')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(negativeCheckbox).value, isTrue);

    await _unmount(tester);

    // 2. 使用可能額が正の場合: ブロックされない
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(
      MaterialApp(
        home: AssetManagementPage(
          debugCalendarNow: DateTime(2026, 7, 10),
          debugInitialAssetData: <String, Map<String, double>>{
            dateKey: const <String, double>{
              '三井住友銀行大塚支店': 200000,
              'モビット': -45000,
            },
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final positiveCheckbox = find.byKey(const Key('debt_paid_checkbox_mobit'));
    await tester.ensureVisible(positiveCheckbox);
    await tester.tap(positiveCheckbox);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('asset_living_expense_guard_dialog')),
      findsNothing,
    );
    expect(tester.widget<Checkbox>(positiveCheckbox).value, isTrue);

    await _unmount(tester);
  });

  testWidgets('確認中に給与サイクルが変わった操作は保存しない', (tester) async {
    final first = DateTime(2026, 7, 10);
    final second = DateTime(2026, 8, 10);
    final clock = ValueNotifier<DateTime>(first);
    final repository = _RecordingRepository();
    final balances = <String, Map<String, double>>{
      for (final day in [first, second])
        DateFormat('yyyy-MM-dd').format(day): const <String, double>{
          '三井住友銀行大塚支店': 5000,
          'モビット': -45000,
        },
    };
    SharedPreferences.setMockInitialValues(<String, Object>{
      'asset_management_section_overrides_v1':
          '{"subscriptionFixedCost":"hidden"}',
    });
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(clock.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<DateTime>(
          valueListenable: clock,
          builder: (context, now, _) => AssetManagementPage(
            debugNow: now,
            debugCalendarNow: first,
            debugInitialAssetData: balances,
            assetLiabilityRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final checkbox = find.byKey(const Key('debt_paid_checkbox_mobit'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('living_guard_force_execute_button'));
    expect(confirm, findsOneWidget);

    clock.value = second;
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(confirm, findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repository.paidMonths, isEmpty);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);
    await _unmount(tester);
  });
}
