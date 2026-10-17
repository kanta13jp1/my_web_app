import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:my_web_app/services/debt_progress_card_service.dart';
import 'package:my_web_app/widgets/debt_progress_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  for (final confirmed in [false, true]) {
    testWidgets(
        'share preview preserves principal and rate evidence $confirmed',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetSalaryResetMarkerStore.prefsKey: '2026-05',
      });
      await const AssetLiabilityMonthlyStateStore().saveMonth(
        month: DateTime(2026, 5),
        state: AssetLiabilityMonthlyState(
          paidAccountNames: const {'SyntheticLoan'},
          paymentOverrides: const {'SyntheticLoan': 10000},
          annualRateOverrides:
              confirmed ? const {'SyntheticLoan': 0} : const <String, double>{},
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 6, 20),
            debugCalendarNow: DateTime(2026, 6, 20),
            debugInitialAssetData: const {
              '2026-06-20': {'Synthetic bank': 1000, 'SyntheticLoan': -100000},
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester
          .tap(find.byKey(const Key('debt_progress_share_appbar_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final preview = tester.widget<DebtProgressShareDialog>(
        find.byType(DebtProgressShareDialog),
      );
      expect(preview.data.totalDebt, 100000);
      expect(
        preview.data.projectionStatus,
        confirmed
            ? DebtProgressProjectionStatus.estimated
            : DebtProgressProjectionStatus.unconfirmedTerms,
      );
      expect(preview.data.estimatedInterest, confirmed ? 0 : null);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
