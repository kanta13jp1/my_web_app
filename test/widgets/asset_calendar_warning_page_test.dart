import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:my_web_app/widgets/asset_calendar_shortfall_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> pumpWarningPage(WidgetTester tester, {required bool paid}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    AssetSalaryResetMarkerStore.prefsKey: '2026-05',
  });
  await const AssetLiabilityMonthlyStateStore().saveMonth(
    month: DateTime(2026, 5),
    state: AssetLiabilityMonthlyState(
      paidAccountNames: paid ? {'Synthetic cycle cost'} : const <String>{},
    ),
  );
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: AssetManagementPage(
        debugNow: DateTime(2026, 6, 20),
        debugCalendarNow: DateTime(2026, 6, 20),
        debugInitialAssetData: const {
          '2026-06-20': {'Synthetic bank': 1000},
        },
        debugInitialRecurringFixedCosts: const [
          AssetRecurringFixedCost(
            id: 'synthetic-cycle-cost',
            name: 'Synthetic cycle cost',
            amount: 5000,
            paymentDay: 22,
          ),
        ],
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets('calendar warning explains aggregate forecast and unknown time',
      (tester) async {
    await pumpWarningPage(tester, paid: false);
    expect(find.text('現金・預金合計の資金繰り見込み'), findsOneWidget);
    expect(find.text('残高の記録日時: 未確認'), findsOneWidget);
    expect(find.textContaining('口座別の引落可否'), findsOneWidget);
    expect(find.textContaining('入金を含めない保守的試算'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('same loaded cycle paid state prevents future double subtraction',
      (tester) async {
    await pumpWarningPage(tester, paid: true);
    for (final details in tester.widgetList<AssetCalendarShortfallDetails>(
      find.byType(AssetCalendarShortfallDetails),
    )) {
      debugPrint(
        'A11_EVENTS ${details.calendar.days.expand((day) => day.events).map((event) => '${event.label}:${event.amount}').join('|')}',
      );
    }
    expect(
      find.byKey(const Key('asset_calendar_shortfall_warning')),
      findsNothing,
    );
    final saved = await const AssetLiabilityMonthlyStateStore().loadMonth(
      DateTime(2026, 5),
    );
    expect(saved.paidAccountNames, contains('Synthetic cycle cost'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
