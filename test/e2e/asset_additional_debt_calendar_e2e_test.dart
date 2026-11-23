import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_payment_calendar_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:my_web_app/widgets/asset_additional_debt_calendar_dialog.dart';
import 'package:my_web_app/widgets/asset_borrowing_calendar_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> _unmountPage(WidgetTester tester) async {
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

  testWidgets(
    'Case 1 (happy path): Money Calendar displays borrowing, revolving, and Debt Guard badges and records from violation modal',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 30000,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 7, 10),
            debugCalendarNow: DateTime(2026, 7, 10),
            debugRevolvingConfigsMirror: mirrorValue,
            debugInitialAssetData: const <String, Map<String, double>>{
              '2026-07-10': <String, double>{
                '財布(現金)': 50000,
                'ファミペイ': -100000,
              },
            },
            debugInitialRecentFlows: const <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 101,
                'action_type': 'borrowing',
                'amount': 20000,
                'description': '[モビット] ATMキャッシング',
                'occurred_at': '2026-07-08T12:00:00',
              },
            ],
            debugInitialCardStatementLines: <AssetLiabilityCardStatementLine>[
              AssetLiabilityCardStatementLine(
                id: 'revolving_cal_famipay_card_1',
                billingAccountId: 'famipay_card',
                billingAccountName: 'ファミペイ',
                postedAt: DateTime(2026, 7, 9),
                description: 'コンビニリボ利用',
                amount: 4500,
              ),
            ],
            debugInitialDebtGuardViolations: <AssetCalendarDebtGuardViolationInput>[
              AssetCalendarDebtGuardViolationInput(
                date: DateTime(2026, 7, 9),
                note: 'ファミペイ: コンビニリボ利用',
                sourceId: 'dg_1',
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('asset_calendar_debt_badge_2026_7_8')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_calendar_debt_badge_2026_7_9')),
        findsOneWidget,
      );
      expect(find.text('借入受取（キャッシング・収入集計外）'), findsOneWidget);
      expect(find.text('リボ利用（現金引落なし）'), findsOneWidget);
      expect(find.text('追加借金違反（Debt Guard）'), findsOneWidget);

      final day9 = find.byKey(const Key('asset_calendar_day_9'));
      await tester.ensureVisible(day9);
      await tester.tap(day9);
      await tester.pump();

      expect(
        find.byKey(const Key('asset_calendar_additional_debt_summary')),
        findsOneWidget,
      );
      expect(
        find.text('リボ利用（現金引落なし）: ファミペイ / コンビニリボ利用'),
        findsOneWidget,
      );
      expect(
        find.text('追加借金ルール違反（Debt Guard）: ファミペイ: コンビニリボ利用'),
        findsOneWidget,
      );
      expect(
        find.textContaining('追加借金ルール違反（Debt Guard）の記録あり'),
        findsOneWidget,
      );

      final openModalButton = find.byKey(
        const Key('asset_discipline_banner_open_modal_button'),
      );
      await tester.ensureVisible(openModalButton);
      await tester.tap(openModalButton);
      await tester.pumpAndSettle();

      final recordFromModalButton = find.byKey(
        const Key('asset_discipline_record_calendar_famipay_card'),
      );
      await tester.ensureVisible(recordFromModalButton);
      await tester.tap(recordFromModalButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('asset_additional_debt_calendar_dialog')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('asset_additional_debt_amount_field')),
        '7200',
      );
      await tester.tap(
        find.byKey(const Key('asset_additional_debt_submit_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('asset_discipline_violations_modal')),
          matching: find.text('閉じる'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('asset_calendar_debt_badge_2026_7_10')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _unmountPage(tester);
    },
  );

  testWidgets(
    'Case 2 (error path): invalid zero amount shows inline validation error and adds no calendar badge',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 7, 10),
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: const <String, Map<String, double>>{
              '2026-07-10': <String, double>{'財布(現金)': 50000},
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final day10 = find.byKey(const Key('asset_calendar_day_10'));
      await tester.ensureVisible(day10);
      await tester.tap(day10);
      await tester.pump();

      final recordButton = find.byKey(
        const Key('asset_calendar_record_debt_button'),
      );
      await tester.ensureVisible(recordButton);
      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('asset_additional_debt_amount_field')),
        '0',
      );
      await tester.tap(
        find.byKey(const Key('asset_additional_debt_submit_button')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('asset_additional_debt_error_text')),
        findsOneWidget,
      );
      expect(find.text('1円以上の金額を入力してください'), findsOneWidget);
      expect(
        find.byKey(const Key('asset_additional_debt_calendar_dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_calendar_debt_badge_2026_7_10')),
        findsNothing,
      );

      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _unmountPage(tester);
    },
  );

  testWidgets(
    'Case 3 (empty & recovery state): empty calendar shows no debt badges then updates cleanly after recording cashing with Debt Guard',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      AssetAdditionalDebtCalendarDraft? savedDraft;
      DateTime? savedViolationDate;
      String? savedViolationNote;

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugNow: DateTime(2026, 7, 10),
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: const <String, Map<String, double>>{
              '2026-07-10': <String, double>{'財布(現金)': 50000},
            },
            debugInitialDebtGuardViolations: const <AssetCalendarDebtGuardViolationInput>[],
            debugRecordAdditionalDebtFlow: (draft) async {
              savedDraft = draft;
            },
            debugRecordDebtGuardViolation: (date, note) async {
              savedViolationDate = date;
              savedViolationNote = note;
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AssetBorrowingCalendarBadge), findsNothing);

      final day10 = find.byKey(const Key('asset_calendar_day_10'));
      await tester.ensureVisible(day10);
      await tester.tap(day10);
      await tester.pump();

      final recordButton = find.byKey(
        const Key('asset_calendar_record_debt_button'),
      );
      await tester.ensureVisible(recordButton);
      await tester.tap(recordButton);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('asset_additional_debt_amount_field')),
        '15000',
      );
      await tester.enterText(
        find.byKey(const Key('asset_additional_debt_memo_field')),
        '緊急キャッシング',
      );
      await tester.tap(
        find.byKey(const Key('asset_additional_debt_guard_checkbox')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('asset_additional_debt_submit_button')),
      );
      await tester.pumpAndSettle();

      expect(savedDraft, isNotNull);
      expect(savedDraft!.amount, 15000);
      expect(savedViolationDate, DateTime(2026, 7, 10));
      expect(savedViolationNote, contains('¥15,000'));
      expect(savedViolationNote, contains('キャッシング・借入'));
      expect(
        find.byKey(const Key('asset_calendar_debt_badge_2026_7_10')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_calendar_additional_debt_summary')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _unmountPage(tester);
    },
  );
}
