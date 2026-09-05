import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/models/asset_obsidian_vault_import.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_card_usage_policy_store.dart';
import 'package:my_web_app/services/asset_chat_privacy_settings_service.dart';
import 'package:my_web_app/services/asset_expected_inflow_store.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:my_web_app/services/asset_management_main_account_store.dart';
import 'package:my_web_app/services/asset_recurring_fixed_cost_store.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_revolving_credit_config_store.dart';
import 'package:my_web_app/services/asset_salary_day_store.dart';
import 'package:my_web_app/services/asset_subscription_audit_store.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/services/asset_sync_timestamp_store.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:my_web_app/widgets/asset_recurring_transaction_suggestion_card.dart';
import 'package:my_web_app/widgets/recurring_fixed_cost_card.dart';
import 'package:my_web_app/widgets/subscription_audit_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 支払日上書きだけ差し替え可能なテスト用 repo (#part295 fake repo 足場)。
/// 他のロード/保存は SharedPreferences 実装に委譲(テストでは空)。
class _FakeDebtOverrideRepository
    extends SharedPreferencesAssetLiabilityRepository {
  _FakeDebtOverrideRepository(
    this._seed, {
    this.monthlyState = const AssetLiabilityMonthlyState(),
  });

  final Map<String, int> _seed;
  final AssetLiabilityMonthlyState monthlyState;
  Map<String, int>? savedDebtOverrides;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    return monthlyState;
  }

  @override
  Future<Map<String, int>> loadDebtPaymentDayOverrides() async {
    return Map<String, int>.from(_seed);
  }

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> overrides) async {
    savedDebtOverrides = Map<String, int>.from(overrides);
  }
}

/// ローカル保存 (replaceAll) が必ず失敗するウォッチリストサービス。
/// 復元時の保存失敗が無音にならず (catchError でログ)、かつページを
/// クラッシュさせないことを検証する (review medium / silent save)。
class _ThrowingWatchlistService extends AssetWatchlistService {
  _ThrowingWatchlistService(this._seed);

  final List<AssetWatchlistEntry> _seed;

  @override
  Future<List<AssetWatchlistEntry>> loadEntries({
    SharedPreferences? prefs,
  }) async {
    return List<AssetWatchlistEntry>.from(_seed);
  }

  @override
  Future<List<AssetWatchlistEntry>> replaceAll(
    List<AssetWatchlistEntry> entries, {
    SharedPreferences? prefs,
  }) async {
    throw Exception('simulated disk failure');
  }
}

class _ThrowingRecurringFixedCostStore extends AssetRecurringFixedCostStore {
  const _ThrowingRecurringFixedCostStore();

  @override
  Future<void> save(
    List<AssetRecurringFixedCost> costs, {
    SharedPreferences? prefs,
  }) async {
    throw StateError('simulated recurring fixed cost save failure');
  }
}

/// 資産管理ページの widget スモーク足場 (#3260)。
/// 未ログイン (auth.currentUser == null) では Supabase フェッチ群が
/// 早期 return する性質を利用し、ネットワークなしで UI 契約だけを検証する。
Future<void> _pumpAssetPage(WidgetTester tester) async {
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  AssetRecurringTombstoneSyncService.resetSharedForTest();
  await tester.pumpWidget(
    const MaterialApp(home: AssetManagementPage()),
  );
  await tester.pump(const Duration(milliseconds: 100));
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 各テストを個別の FakeAsync zone で開始するため、前テストが残し得る
    // static write-lock future を現在の zone の完了済み future へ再初期化する
    // (= 将来ログイン状態の編集 smoke が write 経路を踏んでも orphan-hang しない)。
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
  });

  test('Obsidian解約候補は全変更前に現在のサブスクへ再照合する', () {
    const current = <AssetRecurringFixedCost>[
      AssetRecurringFixedCost(
        id: 'sub_xbox',
        name: 'Xbox Game Pass',
        amount: 1550,
        paymentDay: 7,
        category: AssetRecurringFixedCostCategory.subscription,
      ),
    ];
    const valid = AssetObsidianSubscriptionCancellationCandidate(
      sourceSubscriptionName: 'Xbox Game Pass',
      sourceStatus: '解約完了',
      status: AssetObsidianSubscriptionCancellationStatus.matched,
      sourcePaths: <String>['SUBSCRIPTION_LIST.md'],
      matchedSubscriptionId: 'sub_xbox',
      matchedSubscriptionName: 'Xbox Game Pass',
      matchedMonthlyAmount: 1550,
    );

    expect(
      validateObsidianSubscriptionCancellations(
        const <AssetObsidianSubscriptionCancellationCandidate>[valid],
        current,
      ),
      current,
    );
    expect(
      () => validateObsidianSubscriptionCancellations(
        const <AssetObsidianSubscriptionCancellationCandidate>[
          AssetObsidianSubscriptionCancellationCandidate(
            sourceSubscriptionName: 'Xbox Game Pass',
            sourceStatus: '解約完了',
            status: AssetObsidianSubscriptionCancellationStatus.notRegistered,
            sourcePaths: <String>['SUBSCRIPTION_LIST.md'],
            matchedSubscriptionId: 'sub_xbox',
            matchedSubscriptionName: 'Xbox Game Pass',
            matchedMonthlyAmount: 1550,
          ),
        ],
        current,
      ),
      throwsStateError,
    );
    expect(
      () => validateObsidianSubscriptionCancellations(
        const <AssetObsidianSubscriptionCancellationCandidate>[valid, valid],
        current,
      ),
      throwsStateError,
    );
    expect(
      () => validateObsidianSubscriptionCancellations(
        const <AssetObsidianSubscriptionCancellationCandidate>[
          AssetObsidianSubscriptionCancellationCandidate(
            sourceSubscriptionName: 'Xbox Game Pass',
            sourceStatus: '解約完了',
            status: AssetObsidianSubscriptionCancellationStatus.matched,
            sourcePaths: <String>['SUBSCRIPTION_LIST.md'],
            matchedSubscriptionId: 'sub_xbox',
            matchedSubscriptionName: 'Xbox Game Pass',
            matchedMonthlyAmount: 999,
          ),
        ],
        current,
      ),
      throwsStateError,
    );
  });

  group('AssetManagementPage smoke', () {
    testWidgets('sticky asset chat entry opens and closes the panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(find.byKey(const Key('asset_chat_open_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('asset_chat_open_button')));
      await tester.pump();
      expect(find.byKey(const Key('asset_chat_panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('asset_chat_close_button')));
      await tester.pump();
      expect(find.byKey(const Key('asset_chat_panel')), findsNothing);

      await _unmount(tester);
    });

    testWidgets('asset chat money range protection defaults off and persists', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      final customizeButton =
          find.byKey(const Key('asset_section_customize_button'));
      await tester.ensureVisible(customizeButton);
      await tester.tap(customizeButton);
      await tester.pump(const Duration(milliseconds: 200));

      final toggle = find.byKey(const Key('asset_chat_money_range_toggle'));
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 200));

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(
          AssetChatPrivacySettingsService.maskMoneyAmountsKey,
        ),
        isTrue,
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

      await _unmount(tester);
    });

    testWidgets('display mode chips reduce visible sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(find.byKey(const Key('asset_display_mode_minimum')), findsOne);
      final cardsInFull = tester.widgetList(find.byType(Card)).length;

      await tester.tap(find.byKey(const Key('asset_display_mode_minimum')));
      await tester.pump(const Duration(milliseconds: 100));

      final cardsInMinimum = tester.widgetList(find.byType(Card)).length;
      expect(cardsInMinimum, lessThan(cardsInFull));
      expect(find.textContaining('最重要のみ'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('calendar cycle navigation updates the range label', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 「今日」を 2026-07-10 に固定 → 表示サイクルは 6/25〜7/24 (給料日既定25)。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(debugCalendarNow: DateTime(2026, 7, 10)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2026/6/25〜7/24'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_next_month')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_next_month')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2026/7/25〜8/24'), findsOneWidget);
      expect(find.text('2026/6/25〜7/24'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('past cycle shows the actual summary instead of plan chips', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 「今日」= 2026-07-10 → 表示サイクルは 6/25〜7/24。前サイクル(5/25〜6/24)は
      // 全日が過去なので予定チップの代わりに実績サマリが出る。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialRecentFlows: <Map<String, dynamic>>[
              <String, dynamic>{
                'action_type': 'conquer',
                'amount': 300000,
                'description': '給料',
                'occurred_at': DateTime(2026, 5, 25, 12).toIso8601String(),
              },
              <String, dynamic>{
                'action_type': 'expense',
                'amount': 12000,
                'description': '食費',
                'occurred_at': DateTime(2026, 6, 10, 12).toIso8601String(),
              },
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 現在サイクルでは実績サマリは出ず、予定チップが出る。
      expect(
        find.byKey(const Key('asset_calendar_cycle_actual_summary')),
        findsNothing,
      );
      expect(find.text('支払予定合計'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_prev_month')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_prev_month')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('2026/5/25〜6/24'), findsOneWidget);
      final summary = find.byKey(
        const Key('asset_calendar_cycle_actual_summary'),
      );
      expect(summary, findsOneWidget);
      expect(find.text('支払予定合計'), findsNothing);

      // 実績合算: 収入 300,000 / 支出 12,000 / 差引 +288,000 / 記録 2 日。
      expect(
        find.descendant(of: summary, matching: find.text('¥300,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('¥12,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('+¥288,000')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: summary,
          matching: find.textContaining('記録がある日: 2日'),
        ),
        findsOneWidget,
      );

      // さらに前(4/25〜5/24)は記録なし → 空メッセージ。
      await tester.tap(find.byKey(const Key('asset_calendar_prev_month')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining('この期間に記録されたフローはありません'),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets(
      'monthly flow card aggregates over the salary cycle, not the month',
      (tester) async {
        // 暦月だと給料日(25日)受給分が翌月の窓から外れ収入0=赤字になる回帰を防ぐ。
        // 当サイクル [給料日, 翌給料日) の窓で収入/支出を集計することを検証する。
        final now = DateTime.now();
        final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
          now,
          salaryDay: AssetSalaryDayStore.defaultSalaryDay,
        );
        // 当サイクル開始日(=給料日)に受け取った給料。暦月窓では外れるが、
        // サイクル窓では収入として計上される。
        final cycleSalary = DateTime(
          cycleStart.year,
          cycleStart.month,
          cycleStart.day,
          12,
        );
        // 前サイクル(給料日の前日)の収入。当サイクル窓では除外される。
        final previousCycleIncome = cycleSalary.subtract(
          const Duration(days: 1),
        );
        // 当サイクル内(本日)の支出。
        final cycleExpense = DateTime(now.year, now.month, now.day, 12);

        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialRecentFlows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'action_type': 'conquer',
                  'amount': 280000,
                  'description': '給料',
                  'occurred_at': cycleSalary.toIso8601String(),
                },
                <String, dynamic>{
                  'action_type': 'expense',
                  'amount': 50000,
                  'description': '食費',
                  'occurred_at': cycleExpense.toIso8601String(),
                },
                <String, dynamic>{
                  'action_type': 'conquer',
                  'amount': 999999,
                  'description': '前サイクル収入',
                  'occurred_at': previousCycleIncome.toIso8601String(),
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final card = find.byKey(
          const Key('asset_monthly_flow_priority_card'),
        );
        expect(card, findsOneWidget);

        // 当サイクルの給料(280,000)が収入として計上される。
        expect(
          find.descendant(of: card, matching: find.text('¥280,000')),
          findsOneWidget,
        );
        // 当サイクルの支出(50,000)も計上される。
        expect(
          find.descendant(of: card, matching: find.text('¥50,000')),
          findsOneWidget,
        );
        // 前サイクルの収入(999,999)は窓外なので除外される。
        expect(
          find.descendant(of: card, matching: find.textContaining('999,999')),
          findsNothing,
        );
        // 見出しは暦月ラベルではなく給料サイクルの期間ラベルになっている。
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('給料サイクル('),
          ),
          findsOneWidget,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'cycle summary and salary breakdown exclude an unreceived income plan',
      (tester) async {
        final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
          DateTime.now(),
          salaryDay: AssetSalaryDayStore.defaultSalaryDay,
        );
        final payDate = DateFormat('yyyy-MM-dd').format(cycleStart);
        final repo = _FakeDebtOverrideRepository(
          const <String, int>{},
          monthlyState: AssetLiabilityMonthlyState(
            incomePlans: <AssetLiabilityIncomePlan>[
              AssetLiabilityIncomePlan(
                id: 'unreceived_salary',
                date: cycleStart,
                name: '給料予定',
                amount: 450000,
                destinationAccountId: null,
                destinationAccountName: null,
                received: false,
              ),
            ],
          ),
        );
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1': 'full',
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              assetLiabilityRepository: repo,
              debugInitialRecentFlows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'action_type': 'expense',
                  'amount': 175110,
                  'description': '使途不明金（残高差分から自動記録）',
                  'occurred_at': cycleStart.toIso8601String(),
                },
              ],
              debugInitialPayslipSalaryIncomes: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pay_date': payDate,
                  'amount': 421277,
                  'description': '給料',
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        for (final key in <String>[
          'asset_monthly_flow_priority_card',
          'asset_salary_spending_breakdown_card',
        ]) {
          final card = find.byKey(Key(key));
          expect(card, findsOneWidget);
          expect(
            find.descendant(of: card, matching: find.text('¥421,277')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: card, matching: find.textContaining('871,277')),
            findsNothing,
          );
          expect(
            find.descendant(of: card, matching: find.text('+¥246,167')),
            findsOneWidget,
          );
        }
        expect(find.text('期間支出（未照合含む）'), findsOneWidget);
        expect(find.textContaining('全額が消費や浪費とは限りません'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _unmount(tester);
      },
    );

    testWidgets(
      'monthly flow card counts payslip salary income when no conquer flow exists',
      (tester) async {
        // 給料を給与明細(payslips/salary_incomes)でのみ管理しているユーザーは、
        // 収支フロー(conquer)が無いため収入¥0=常に赤字に見える回帰を防ぐ。
        // 当サイクルに受給した給料が収入へ合算されることを検証する。
        final now = DateTime.now();
        final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
          now,
          salaryDay: AssetSalaryDayStore.defaultSalaryDay,
        );
        final payDate = DateFormat('yyyy-MM-dd').format(cycleStart);

        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              // 収支フロー(wealth_struggles)は空。
              debugInitialRecentFlows: const <Map<String, dynamic>>[],
              // 給料は salary_incomes にのみ存在 (給与明細のみ管理)。
              debugInitialPayslipSalaryIncomes: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pay_date': payDate,
                  'amount': 280000,
                  'description': 'Payslip: 自分株式会社',
                  'source': 'payslip_auto',
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final card = find.byKey(
          const Key('asset_monthly_flow_priority_card'),
        );
        expect(card, findsOneWidget);

        // 給与明細の給料(280,000)が収入として計上される。
        expect(
          find.descendant(of: card, matching: find.text('¥280,000')),
          findsOneWidget,
        );
        // 収入があるので「未記録」の空状態文言は出ない。
        expect(
          find.descendant(
            of: card,
            matching: find.textContaining('まだこのサイクルの収支が未記録'),
          ),
          findsNothing,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'monthly flow card shows manual income CTA when no income is recorded',
      (tester) async {
        // 給与明細も収入フロー(conquer)も無く支出だけのユーザーは収入¥0=赤字に
        // 見える。手入力収入への導線(CTA)が出て、ワンタップで収支記録の種別が
        // 「収入」へ切り替わることを検証する。
        final now = DateTime.now();
        final cycleExpense = DateTime(now.year, now.month, now.day, 12);

        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialRecentFlows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'action_type': 'expense',
                  'amount': 50000,
                  'description': '食費',
                  'occurred_at': cycleExpense.toIso8601String(),
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('asset_monthly_flow_income_cta')),
          findsOneWidget,
        );

        final dropdownFinder = find.byKey(
          const Key('asset_flow_type_dropdown'),
        );
        // タップ前は既定の支出。
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(dropdownFinder)
              .initialValue,
          '支出',
        );

        final ctaButton = find.byKey(
          const Key('asset_monthly_flow_income_cta_button'),
        );
        await tester.ensureVisible(ctaButton);
        await tester.pump();
        await tester.tap(ctaButton);
        await tester.pump(const Duration(milliseconds: 400));

        // CTA で収支記録の種別が「収入」へ切り替わる(記録時に conquer になる)。
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(dropdownFinder)
              .initialValue,
          '収入',
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'monthly flow card hides manual income CTA when income exists',
      (tester) async {
        // 当サイクルに収入フロー(conquer)があれば収入¥0ではないので CTA は出ない。
        final now = DateTime.now();
        final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
          now,
          salaryDay: AssetSalaryDayStore.defaultSalaryDay,
        );
        final cycleSalary = DateTime(
          cycleStart.year,
          cycleStart.month,
          cycleStart.day,
          12,
        );

        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialRecentFlows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'action_type': 'conquer',
                  'amount': 280000,
                  'description': '給料',
                  'occurred_at': cycleSalary.toIso8601String(),
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('asset_monthly_flow_income_cta')),
          findsNothing,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'payslip row and salary_income with same pay date/amount are counted once',
      (tester) async {
        // 1枚の給与明細は payslips と salary_incomes の両方に同日同額で入る。
        // 二重計上(560,000)せず1件(280,000)に畳むことを検証する。
        final now = DateTime.now();
        final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
          now,
          salaryDay: AssetSalaryDayStore.defaultSalaryDay,
        );
        final payDate = DateFormat('yyyy-MM-dd').format(cycleStart);

        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialRecentFlows: const <Map<String, dynamic>>[],
              debugInitialPayslipSalaryIncomes: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pay_date': payDate,
                  'amount': 280000,
                  'description': 'Payslip: 自分株式会社',
                  'source': 'payslip_auto',
                },
              ],
              debugInitialPayslipRows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pay_date': payDate,
                  'net_amount': 280000,
                  'company_name': '自分株式会社',
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));

        final card = find.byKey(
          const Key('asset_monthly_flow_priority_card'),
        );
        expect(card, findsOneWidget);

        // 二重計上されず1件分(280,000)だけ計上される。
        expect(
          find.descendant(of: card, matching: find.text('¥280,000')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: card, matching: find.textContaining('560,000')),
          findsNothing,
        );

        await _unmount(tester);
      },
    );

    testWidgets('tapping a day reveals the prefill action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_day_15')),
      );
      await tester.tap(find.byKey(const Key('asset_calendar_day_15')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byKey(const Key('asset_calendar_prefill_flow_button')),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('starts in stored minimum mode', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'minimum',
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('最重要のみ'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('seeded inflows surface as chips and managed rules', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflows_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_one',
            'date': DateTime(2026, 7, 10).toUtc().toIso8601String(),
            'amount': 5000,
            'label': '臨時収入',
          },
        ]),
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // サイクル窓 6/25〜7/24: 単発 7/10 と毎月25日ルールの 6/25 分が窓内。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(debugCalendarNow: DateTime(2026, 7, 10)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_chip_seeded_one')),
      );
      expect(
        find.byKey(const Key('asset_inflow_chip_seeded_one')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('asset_inflow_chip_rule_seeded_rule_202606')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('毎月25日 給料'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('tombstone GC settings dialog edits and saves the config', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugTombstoneGcConfig: AssetTombstoneGcConfig(
              maxCount: 1000,
              maxAgeDays: 365,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));

      // 現在値が保持設定ボタンに出ている。
      expect(find.textContaining('保持設定 (1000件/365日)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(
        find.byKey(const Key('asset_tombstone_gc_maxcount')),
        '50',
      );
      await tester.enterText(
        find.byKey(const Key('asset_tombstone_gc_maxage')),
        '90',
      );
      await tester.tap(find.byKey(const Key('asset_tombstone_gc_save')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // SnackBar で更新を通知し、ボタンラベルも新値へ更新される。
      expect(find.textContaining('最大50件 / 90日'), findsOneWidget);
      expect(find.textContaining('保持設定 (50件/90日)'), findsOneWidget);

      // ローカルにも保存される。
      expect(
        (await AssetExpectedInflowStore.loadGcConfig()).maxCount,
        50,
      );

      await _unmount(tester);
    });

    testWidgets('manual prune button cleans expired tombstones', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'seeded_rule',
            'day_of_month': 25,
            'amount': 280000,
            'label': '給料',
          },
        ]),
        // 2020 年の古い削除記録 → inflow は maxAgeDays:10、override は既定365日で
        // どちらも期限切れ → 一括掃除で 2 件 (#part292)。
        'asset_expected_inflow_deleted_ids_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'old1', 'at': '2020-01-01T00:00:00.000Z'},
        ]),
        'asset_management_section_override_deleted_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'chart', 'at': '2020-01-01T00:00:00.000Z'},
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugTombstoneGcConfig: AssetTombstoneGcConfig(
              maxCount: 1000,
              maxAgeDays: 10,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_rules_button')),
      );
      await tester.tap(find.byKey(const Key('asset_inflow_rules_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('asset_tombstone_gc_edit')));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('asset_tombstone_gc_prune')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // ボタン→prune→SnackBar の配線を検証 (件数は boot 自動 prune が先に
      // 期限切れを掃除するため非依存にする / #part296)。実際の物理削除は
      // 「boot auto-prune」テストと store 単体テストで担保。
      expect(find.textContaining('件 掃除しました'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('boot auto-prune physically drops expired tombstones', (
      tester,
    ) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues(<String, Object>{
        // 期限切れ(2020) + 期限内(現在) を混在させる。
        'asset_expected_inflow_deleted_ids_v1':
            jsonEncode(<Map<String, String>>[
          <String, String>{'id': 'old1', 'at': '2020-01-01T00:00:00.000Z'},
          <String, String>{
            'id': 'recent',
            'at': now.toUtc().toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // boot 自動 prune が期限切れ(old1)を物理削除し、期限内(recent)は残す。
      final raw = (await SharedPreferences.getInstance())
          .getString('asset_expected_inflow_deleted_ids_v1');
      expect(raw, isNotNull);
      expect(raw!.contains('old1'), isFalse);
      expect(raw.contains('recent'), isTrue);

      await _unmount(tester);
    });

    testWidgets('remote section-override tombstone removes local override', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_section_overrides_v1': jsonEncode(
          <String, String>{'chart': 'hidden'},
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で chart の上書きを削除した状態をミラー注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugSectionOverrideDeletedMirror: <String, dynamic>{
              'ids': <String>['chart'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // カスタマイズダイアログを開き、chart の上書きが「自動」に戻ったことを確認。
      await tester.ensureVisible(
        find.byKey(const Key('asset_section_customize_button')),
      );
      await tester.tap(find.byKey(const Key('asset_section_customize_button')));
      await tester.pump(const Duration(milliseconds: 200));

      final dropdown = tester
          .widget<DropdownButton<AssetManagementSectionVisibilityOverride>>(
        find.byKey(const Key('asset_section_override_chart')),
      );
      expect(dropdown.value, AssetManagementSectionVisibilityOverride.auto);

      await _unmount(tester);
    });

    testWidgets('remote debt-override tombstone removes it via fake repo', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // fake repo が debt_1/debt_2 の支払日上書きを返す。他端末が debt_1 を削除した
      // 状態をミラー注入 → boot pull + ロード除外で debt_1 が消え、repo へ保存される。
      final repo = _FakeDebtOverrideRepository(<String, int>{
        'debt_1': 27,
        'debt_2': 5,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repo,
            debugDebtOverrideDeletedMirror: const <String, dynamic>{
              'ids': <String>['debt_1'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除伝播の結果が repo へ保存される(debt_1 除外 / debt_2 維持)。
      expect(repo.savedDebtOverrides, isNotNull);
      expect(repo.savedDebtOverrides!.containsKey('debt_1'), isFalse);
      expect(repo.savedDebtOverrides!['debt_2'], 5);

      await _unmount(tester);
    });

    testWidgets('revolving config syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末A が保存したリボ設定を集約ミラー値へエンコードする(端末A の upload 相当)。
      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            creditLimit: 500000,
          ),
        },
      );

      // 端末B はローカル空(別ブラウザ/別ログイン)で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror: mirrorValue,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 起動時にミラーから復元され、端末B のローカルにも書き戻される。
      final synced = await const AssetRevolvingCreditConfigStore().load();
      expect(synced.keys, contains('aupay'));
      expect(synced['aupay']!.monthlyAmount, 10000);
      expect(synced['aupay']!.creditLimit, 500000);

      await _unmount(tester);
    });

    testWidgets('local revolving config is not clobbered by the mirror', (
      tester,
    ) async {
      // 端末B が既にローカル設定を持つ場合、ミラーは上書きしない(安全側)。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'aupay': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror:
                AssetRevolvingCreditConfigStore.encodeMirrorValue(
              <String, AssetLiabilityRevolvingCreditConfig>{
                'aupay': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 99999,
                  creditLimit: 999999,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // ローカル値(3000)が維持され、ミラー値(99999)では上書きされない。
      final local = await const AssetRevolvingCreditConfigStore().load();
      expect(local['aupay']!.monthlyAmount, 3000);

      await _unmount(tester);
    });

    testWidgets('main account syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末B はローカル空(別ブラウザ/別ログイン)で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugMainAccountMirror: <String, dynamic>{'id': 'smbc_otsuka'},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 端末A のメイン口座IDが起動時に復元され、ローカルへも書き戻される。
      expect(
        await const AssetManagementMainAccountStore().load(),
        'smbc_otsuka',
      );

      await _unmount(tester);
    });

    testWidgets('watchlist syncs from server mirror on a fresh device', (
      tester,
    ) async {
      // 端末A が保存したウォッチリストを集約ミラー値へエンコードする。
      final mirrorValue = AssetWatchlistService.encodeMirrorValue(
        <AssetWatchlistEntry>[
          AssetWatchlistEntry(
            assetType: 'gold',
            group: 'invest',
            memo: 'hedge',
            addedAt: DateTime.utc(2026, 6, 14),
          ),
        ],
      );

      // 端末B はローカル空で起動する。
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugWatchlistMirror: mirrorValue,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 起動時にミラーから復元され、端末B のローカルにも書き戻される。
      final synced = await const AssetWatchlistService().loadEntries();
      expect(synced.map((e) => e.assetType), contains('gold'));

      await _unmount(tester);
    });

    testWidgets('remote inflow tombstone removes the matching local chip', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflows_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'keep_me',
            'date': DateTime(2026, 7, 10).toUtc().toIso8601String(),
            'amount': 5000,
            'label': '残す入金',
          },
          <String, dynamic>{
            'id': 'delete_me',
            'date': DateTime(2026, 7, 12).toUtc().toIso8601String(),
            'amount': 8000,
            'label': '他端末で削除',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末が delete_me を削除した状態をミラー経由で注入。
      // サイクル窓 6/25〜7/24 に seed 日付が入るよう「今日」を固定する。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInflowDeletedIdsMirror: const <String, dynamic>{
              'ids': <String>['delete_me'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_inflow_chip_keep_me')),
      );
      expect(
        find.byKey(const Key('asset_inflow_chip_keep_me')),
        findsOneWidget,
      );
      // 削除トゥームストーンが伝播し、該当チップは消えている。
      expect(
        find.byKey(const Key('asset_inflow_chip_delete_me')),
        findsNothing,
      );

      await _unmount(tester);
    });

    testWidgets('hidden override removes an essential section', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_section_overrides_v1': jsonEncode(
          <String, String>{'calendar': 'hidden'},
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('asset_calendar_prev_month')), findsNothing);

      await _unmount(tester);
    });

    testWidgets('bulk payment-source assign clears all missing sources', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      await tester.binding.setSurfaceSize(const Size(1200, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 預金1口座 + 原資未設定の負債2件 → 一括設定ボタンが出る。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '三井住友銀行大塚支店': 500000,
                'モビット': -300000,
                'アコムカードローン': -200000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final bulkButton = find.byKey(
        const Key('asset_payment_source_bulk_assign'),
      );
      expect(bulkButton, findsOneWidget);

      await tester.ensureVisible(bulkButton);
      await tester.tap(bulkButton);
      // モーダルボトムシートの表示アニメーション (有限) を確実に完了させる。
      // ページに常駐アニメーションがあり pumpAndSettle はタイムアウトするため固定 pump。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // プレビューシート → 「今月だけ設定」で確定。
      final applyMonthly = find.byKey(
        const Key('asset_payment_source_bulk_apply_monthly'),
      );
      expect(applyMonthly, findsOneWidget);
      await tester.tap(applyMonthly);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 適用が実行されたことを SnackBar で確認。
      expect(find.textContaining('原資口座を設定しました'), findsOneWidget);
      // 適用後は全件原資が設定され、一括設定ボタンが消える。
      expect(
        find.byKey(const Key('asset_payment_source_bulk_assign')),
        findsNothing,
      );

      // SnackBar の自動消滅タイマー (既定4秒) を drain してから unmount しないと、
      // 保留タイマーが後続テストの FakeAsync zone へ漏れて "did not complete" になる。
      await tester.pump(const Duration(seconds: 5));
      await _unmount(tester);
    });

    testWidgets('zero-yen payment is shown only in the gray review section', (
      tester,
    ) async {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final repo = _FakeDebtOverrideRepository(
        const <String, int>{},
        monthlyState: const AssetLiabilityMonthlyState(
          paymentOverrides: <String, double>{
            AssetLiabilityPlanningService.jibunBankCardLoanAccountId: 0,
            'paypay_card': 5000,
          },
        ),
      );
      await tester.binding.setSurfaceSize(const Size(1200, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repo,
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 50000,
                'じぶん銀行カードローン': -100000,
                'PayPayカード': -10000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final actionSection =
          find.byKey(const Key('asset_payment_risk_action_section'));
      final reviewSection =
          find.byKey(const Key('asset_payment_risk_review_only_section'));
      expect(actionSection, findsOneWidget);
      expect(reviewSection, findsOneWidget);
      expect(
        find.descendant(
          of: actionSection,
          matching: find.text('PayPayカード'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: actionSection,
          matching: find.text('じぶん銀行カードローン'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: reviewSection,
          matching: find.text('じぶん銀行カードローン'),
        ),
        findsOneWidget,
      );

      final reviewBadge = find.byKey(
        const Key('asset_payment_risk_status_review_27'),
      );
      expect(reviewBadge, findsOneWidget);
      final reviewBadgeText = tester.widget<Text>(
        find.descendant(
          of: reviewBadge,
          matching: find.text('確認のみ'),
        ),
      );
      expect(reviewBadgeText.style?.color, const Color(0xFF64748B));

      await _unmount(tester);
    });

    testWidgets('shortfall warning appears and clears via expected inflow', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // サイクル窓 6/25〜7/24 / 今日=7/10: モビット既定支払日15日(7/15)の
      // 予定額が現金1万を超え、ショート警告が出る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      expect(find.textContaining('回避ライン'), findsOneWidget);
      expect(
        find.byKey(const Key('asset_shift_payment_mobit')),
        findsOneWidget,
      );

      // 回避ライン額がプリフィルされた入金予定を登録すると警告が消える。
      await tester.tap(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('追加'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
        findsNothing,
      );
      expect(find.textContaining('回避ライン'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('recurring inflow before payday prevents the shortfall', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_cover',
            'day_of_month': 14,
            'amount': 100000,
            'label': '給料前入金',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 14日(7/14)の繰り返し入金が15日(7/15)のモビット返済を覆い、警告は出ない。
      expect(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
        findsNothing,
      );
      expect(find.textContaining('回避ライン'), findsNothing);

      await _unmount(tester);
    });

    testWidgets(
        'account shortfall banner links a transfer task and clears on create',
        (tester) async {
      // 全体では黒字(三井住友 500000)でも、モビットの支払原資に割り当てた
      // 現金だけが不足する。先読みバナー→移動タスク作成→見込み残高へ即時
      // 反映されてバナーが解消するまでを検証する。
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetLiabilityMonthlyStateStore.defaultPaymentSourcePrefsKey:
            jsonEncode(<String, String>{'mobit': 'wallet_cash'}),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 1000,
                '三井住友銀行大塚支店': 500000,
                'モビット': -45000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_account_shortfall_banner')),
        findsOneWidget,
      );

      // 三井住友→現金の移動提案がタスク化ボタン付きで表示される。
      final createButton = find.byKey(
        const Key('asset_account_shortfall_create_task_wallet_cash'),
      );
      expect(createButton, findsOneWidget);

      await tester.tap(createButton);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Transfer task created.'), findsOneWidget);
      // 保留中の口座移動が見込み残高に反映され、バナーが解消される。
      expect(
        find.byKey(const Key('asset_account_shortfall_banner')),
        findsNothing,
      );

      await _unmount(tester);
    });

    testWidgets('revolving payoff chip and payday rule appear on debt cards', (
      tester,
    ) async {
      // auPayカードに返済ルール設定 → 概算期間と25日返済の内訳が出る。
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'aupay_card': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 10000,
            newUsageAmount: 20000,
            creditLimit: 500000,
          ),
        },
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugRevolvingConfigsMirror: mirrorValue,
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 50000,
                'auPayカード': -100000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('asset_revolving_payoff_chip_aupay_card')),
        findsOneWidget,
      );
      expect(find.textContaining('リボ: 概算残り'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('revolving:aupay_card:新規利用額')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('revolving:aupay_card:利用限度額')),
        findsOneWidget,
      );
      expect(find.textContaining('返済日: 毎月25日'), findsOneWidget);
      expect(find.textContaining('25日返済'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('safety balance setting persists and updates availability', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{'財布(現金)': 50000},
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final field = find.byKey(const Key('asset_safety_balance_field'));
      await tester.ensureVisible(field);
      await tester.enterText(field, '30000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 200));

      final store = await SharedPreferences.getInstance();
      expect(store.getDouble('asset_minimum_safety_balance_v1'), 30000);
      // 使用可能額カードの安全余裕表示にも反映される。
      expect(find.textContaining('安全余裕 ¥30,000'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets('living expense priority toggle immediately reorders actions', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 3200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: _FakeDebtOverrideRepository(
              <String, int>{'mobit': now.day},
            ),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 1000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final toggle = find.byKey(
        const Key('asset_living_expense_priority_toggle'),
      );
      final livingExpense = find.text('本日の生活費が不足しています');
      final overdue = find.text('モビットが期限超過です');
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(livingExpense, findsOneWidget);
      expect(overdue, findsOneWidget);
      expect(
        tester.getTopLeft(overdue).dy,
        lessThan(tester.getTopLeft(livingExpense).dy),
      );

      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      expect(livingExpense, findsOneWidget);
      expect(overdue, findsNothing);

      await tester.tap(toggle);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      expect(overdue, findsOneWidget);
      expect(
        tester.getTopLeft(overdue).dy,
        lessThan(tester.getTopLeft(livingExpense).dy),
      );

      await _unmount(tester);
    });

    testWidgets('repayment shortfall shows a discipline violation', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final monthKey =
          AssetLiabilityMonthlyStateStore.formatSalaryCycleMonthKey(now);
      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 30000,
          ),
        },
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetLiabilityMonthlyStateStore.actualPaymentPrefsKey: jsonEncode(
          <String, Map<String, double>>{
            monthKey: <String, double>{'famipay_card': 5000},
          },
        ),
        AssetLiabilityMonthlyStateStore.paidPrefsKey: jsonEncode(
          <String, List<String>>{
            monthKey: <String>['famipay_card'],
          },
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugRevolvingConfigsMirror: mirrorValue,
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 50000,
                'ファミペイ': -100000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_discipline_violation_badge')),
        findsOneWidget,
      );
      expect(find.textContaining('不足30,000円'), findsWidgets);
      expect(
        find.byKey(const Key('asset_discipline_apply_escape_famipay_card')),
        findsNothing,
      );

      await _unmount(tester);
    });

    testWidgets('triage guide card shows staged first steps in crisis', (
      tester,
    ) async {
      // 現金1,000円 + 負債 → 「まず、これだけ」カードが生活費確保を最優先で出す。
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 1000,
                '三井住友銀行大塚支店': 500000,
                'モビット': -3200000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_triage_guide_card')),
        findsOneWidget,
      );
      expect(find.textContaining('まず、これだけ'), findsWidgets);
      expect(find.textContaining('食費・移動費を確保する'), findsOneWidget);
      // 負債 320万 ≥ 300万 → 専門窓口の案内も出る。
      expect(find.textContaining('一人で抱えないでください'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('payment source missing banner lists unset payment sources', (
      tester,
    ) async {
      // PayPay の支払原資口座が未設定 → 最上部バナーで件数・金額と、残高付きの
      // 設定候補口座 + 原資未設定一覧へのジャンプ導線を出す。
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 1000,
                '三井住友銀行大塚支店': 500000,
                'PayPay': -20000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_payment_source_missing_banner')),
        findsOneWidget,
      );
      expect(
        find.textContaining('支払原資口座が未設定の支払い'),
        findsOneWidget,
      );
      // 残高最大の三井住友大塚支店が候補として提示される (現在残高付き)。
      // 本番経路ではデフォルト固定費 (家賃等) も原資未設定になるため複数行出る。
      expect(
        find.textContaining('候補: 三井住友銀行大塚支店（現在 ¥500,000'),
        findsWidgets,
      );
      expect(
        find.byKey(const Key('asset_payment_source_missing_jump')),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('card reconciliation shows fix actions for mismatches', (
      tester,
    ) async {
      // KDDI(5764) を PayPay カード請求に含めるが、PayPay の請求額は 20000 →
      // 設定内訳の不一致と明細未取込の両方の解消アクションが出る。
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetLiabilityMonthlyStateStore.defaultCardBillingPrefsKey: jsonEncode(
          <String, String>{'kddi_provider': 'paypay_card'},
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 50000,
                'KDDI': -5764,
                'PayPay': -20000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      final breakdownFix = find.byKey(
        const Key(
          'asset_card_recon_fix_adjustConfiguredBreakdown_paypay_card',
        ),
      );
      await tester.ensureVisible(breakdownFix);
      expect(breakdownFix, findsOneWidget);

      final importFix = find.byKey(
        const Key('asset_card_recon_fix_importStatement_paypay_card'),
      );
      expect(importFix, findsOneWidget);

      // 設定内訳合計(KDDI 5,764)のセルは不一致ハイライト(琥珀色)になる。
      final configuredCells = tester.widgetList<Text>(find.text('¥5,764'));
      expect(
        configuredCells.any(
          (text) => text.style?.color == const Color(0xFFD97706),
        ),
        isTrue,
      );

      // 取り込みアクションのタップで初めて選択案内メッセージが出る
      // (説明文の常時表示と区別するため、タップ前は無いことを先に確認)。
      expect(find.textContaining('を選択しました'), findsNothing);
      await tester.ensureVisible(importFix);
      await tester.tap(importFix);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('を選択しました'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('salary inflow suggestion registers a monthly rule in one tap',
        (tester) async {
      // 給与明細/salary_incomes でのみ給料を管理していると入金予定ルールが
      // 未登録になり、asOf 起点カレンダーでは次サイクル頭の見込み残高が細く
      // 見える (#3799)。最新給与額のワンタップ登録導線を検証する。
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialPayslipSalaryIncomes: const <Map<String, dynamic>>[
              <String, dynamic>{'pay_date': '2026-05-25', 'amount': 400000},
              <String, dynamic>{'pay_date': '2026-06-25', 'amount': 452815},
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_salary_inflow_suggestion')),
      );
      // 最新 (6/25) の手取りが提示される。
      expect(
        find.textContaining('給料 ¥452,815 を毎月25日に登録'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('asset_salary_inflow_register')));
      await tester.pump(const Duration(milliseconds: 200));

      // 登録後は導線が消え、サイクル窓内 (6/25) の給料チップとして反映される。
      expect(
        find.byKey(const Key('asset_salary_inflow_suggestion')),
        findsNothing,
      );
      expect(find.textContaining('6/25 給料 ¥452,815'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('salary suggestion stays hidden when a salary rule exists',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_salary',
            'day_of_month': 25,
            'amount': 450000,
            'label': '給料',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialPayslipSalaryIncomes: const <Map<String, dynamic>>[
              <String, dynamic>{'pay_date': '2026-06-25', 'amount': 452815},
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_salary_inflow_suggestion')),
        findsNothing,
      );

      await _unmount(tester);
    });

    testWidgets('dismissing the salary suggestion persists to prefs',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialPayslipSalaryIncomes: const <Map<String, dynamic>>[
              <String, dynamic>{'pay_date': '2026-06-25', 'amount': 452815},
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.ensureVisible(
        find.byKey(const Key('asset_salary_inflow_dismiss')),
      );
      await tester.tap(find.byKey(const Key('asset_salary_inflow_dismiss')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('asset_salary_inflow_suggestion')),
        findsNothing,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('asset_salary_inflow_prompt_dismissed_v1'),
        isTrue,
      );

      await _unmount(tester);
    });

    testWidgets('post-payday inflow keeps warning but shift previews clear', (
      tester,
    ) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_expected_inflow_rules_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'r_late',
            'day_of_month': 20,
            'amount': 100000,
            'label': '後半入金',
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugCalendarNow: DateTime(2026, 7, 10),
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 10000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 入金(7/20)が返済日(7/15)より後ろなので警告は残る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_calendar_add_inflow_button')),
      );
      expect(find.textContaining('回避ライン'), findsOneWidget);
      // ただし26日へ移せば次回支払は 7/26 = 次サイクル(給料日後)扱いになり、
      // 当サイクルの支払が消えるため事前判定が「回避できます」。
      expect(find.textContaining('を26日へ(回避できます)'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('revolving balance growth surfaces the monthly debt trend card',
        (tester) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      final priorMonth = DateTime(now.year, now.month - 1, 1);
      final priorKey = '${priorMonth.year.toString().padLeft(4, '0')}-'
          '${priorMonth.month.toString().padLeft(2, '0')}';
      // 前月末のモビット残高 3 万円を履歴に仕込み、今月 30 万へ増加させる。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_account_balance_history_v1': jsonEncode(<String, dynamic>{
          priorKey: <String, dynamic>{'mobit': 30000},
        }),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 500000,
                'モビット': -300000,
              },
            },
          ),
        ),
      );
      // 履歴の非同期ロード → setState → 再描画を待つ。
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('家計トラッカー（給料日サイクル / 負債トレンド）'),
        findsOneWidget,
      );
      expect(find.textContaining('残高が先月より増加'), findsWidgets);

      await _unmount(tester);
    });

    testWidgets(
        'an existing revolving balance complies when the payday rule is scheduled',
        (tester) async {
      final now = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(now);
      // 既存残高は一括返済を求めず、新規利用分を25日に全額上乗せする。
      final mirrorValue = AssetRevolvingCreditConfigStore.encodeMirrorValue(
        <String, AssetLiabilityRevolvingCreditConfig>{
          'famipay_card': const AssetLiabilityRevolvingCreditConfig(
            monthlyAmount: 5000,
            newUsageAmount: 30000,
          ),
        },
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror: mirrorValue,
            debugInitialAssetData: <String, Map<String, double>>{
              dateKey: const <String, double>{
                '財布(現金)': 500000,
                'ファミペイ': -100000,
              },
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('借金しない宣言モニター'), findsOneWidget);
      expect(find.textContaining('新規利用分は25日に全額返済: 達成'), findsWidgets);
      expect(find.textContaining('カードは全額一括'), findsNothing);

      await _unmount(tester);
    });
    testWidgets(
      'completed one-shot policy restores its memo and suppresses setup advice',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetCardUsagePolicyStore.prefsKey: jsonEncode(<String, dynamic>{
            'famipay_card': <String, dynamic>{
              'enforce_one_shot': true,
              'changed_at': '2026-08-29T06:18:55.608Z',
              'memo': '受付 ABC123 / 8月29日 電話',
            },
          }),
        });
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await tester.binding.setSurfaceSize(const Size(1200, 3600));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '財布(現金)': 500000,
                  'ファミペイ': -100000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 250));

        final checkbox = tester.widget<CheckboxListTile>(
          find.byKey(const Key('asset_card_one_shot_completed_famipay_card')),
        );
        expect(checkbox.value, isTrue);
        expect(find.text('受付 ABC123 / 8月29日 電話'), findsOneWidget);
        expect(find.textContaining('リボ/分割の設定解除を電話する'), findsNothing);
        expect(find.textContaining('設定を解除し'), findsNothing);

        await _unmount(tester);
      },
    );

    testWidgets('mirror update notice offers and applies remote prefs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_management_display_mode_v1': 'minimum',
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugMirrorPrefsRows: <Map<String, dynamic>>[
              <String, dynamic>{
                'pref_key': 'display_mode',
                'value': const <String, dynamic>{'mode': 'standard'},
                'updated_at': DateTime.now()
                    .add(const Duration(hours: 1))
                    .toUtc()
                    .toIso8601String(),
              },
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('他端末で表示設定が更新されています'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('asset_display_mode_minimum')),
            )
            .selected,
        isTrue,
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('取り込む'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // 取り込み前に「旧 → 新」差分プレビューで確認させる。
      expect(find.text('表示設定の取り込みプレビュー'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('表示モード: ミニマム → 標準'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('asset_mirror_diff_apply')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('asset_display_mode_standard')),
            )
            .selected,
        isTrue,
      );

      await _unmount(tester);
    });

    testWidgets(
      'display-prefs restore does not re-propose a deleted section override',
      (tester) async {
        // ローカルは表示設定なし (= restore 経路: !hadStored && overrides.isEmpty)
        // だが、'chart' セクション上書きを過去に削除した削除トゥームストーンを持つ。
        // サーバには 'chart' の上書きがまだ残っている状態を注入する。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_section_override_deleted_v1': jsonEncode(
            <String>['chart'],
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugMirrorPrefsRows: <Map<String, dynamic>>[
                <String, dynamic>{
                  'pref_key': 'section_overrides',
                  'value': <String, dynamic>{'chart': 'hidden'},
                },
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 削除済みの上書きしか無いので、復元提案ダイアログは出ない
        // (修正前はトゥームストーンを参照せず復活提案していた)。
        expect(find.text('表示設定のバックアップ'), findsNothing);

        await _unmount(tester);
      },
    );

    testWidgets('sync status banner shows logged-out state', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));

      // 未ログイン (スモークは未認証) → 全体バナーが「この端末のみ」を明示。
      await tester.ensureVisible(
        find.byKey(const Key('asset_sync_status_chip')),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('asset_sync_status_chip')),
          matching: find.textContaining('この端末にのみ保存'),
        ),
        findsOneWidget,
      );

      await _unmount(tester);
    });

    testWidgets('unsynced badge appears for local-only watchlist', (
      tester,
    ) async {
      // ローカルにのみウォッチリストがある (未認証 = サーバ未同期) 状態。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'invest',
            'memo': 'hedge',
            'addedAt': DateTime.utc(2026, 6, 14).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAssetPage(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // ウォッチリストが localOnly → 未同期バッジが出る。
      await tester.ensureVisible(
        find.byKey(const Key('asset_unsynced_badge_row')),
      );
      expect(
        find.byKey(const Key('asset_unsynced_badge_watchlist')),
        findsOneWidget,
      );
      expect(find.textContaining('ウォッチリスト 未同期'), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('Phase B flag on: same-key conflict adopts server (LWW)', (
      tester,
    ) async {
      // ローカルに gold(group=old / タイムスタンプ未記録) があり、サーバに同じ
      // gold(group=new) がある衝突状態。union マージでは衝突キーの採否のみフラグで変わる。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'old',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugMirrorReadsAuthoritative: true,
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'gold',
                  group: 'new',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // フラグ ON: 衝突キー gold はサーバ値 (group=new) が採用される。
      final synced = await const AssetWatchlistService().loadEntries();
      final gold = synced.firstWhere((e) => e.assetType == 'gold');
      expect(gold.group, 'new');

      await _unmount(tester);
    });

    testWidgets(
      'Phase B flag on: dirty watchlist key keeps local, clean key adopts '
      'server (#3415 per-key guard)',
      (tester) async {
        // gold はローカル編集済み(dirty) / silver は未編集。サーバは両方別値。
        // フラグ ON でも dirty な gold は巻き添え上書きされず、silver のみ採用。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'assetType': 'gold',
              'group': 'local_gold',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
            <String, dynamic>{
              'assetType': 'silver',
              'group': 'local_silver',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ]),
          'asset_sync_dirty_keys_v1': jsonEncode(<String, dynamic>{
            'watchlist_entries': <String>['gold'],
          }),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugMirrorReadsAuthoritative: true,
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'gold',
                    group: 'server_gold',
                    memo: '',
                    addedAt: DateTime.utc(2026, 6, 14),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'silver',
                    group: 'server_silver',
                    memo: '',
                    addedAt: DateTime.utc(2026, 6, 14),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final synced = await const AssetWatchlistService().loadEntries();
        final gold = synced.firstWhere((e) => e.assetType == 'gold');
        final silver = synced.firstWhere((e) => e.assetType == 'silver');
        expect(gold.group, 'local_gold'); // dirty → 保護
        expect(silver.group, 'server_silver'); // clean → サーバ採用

        await _unmount(tester);
      },
    );

    testWidgets(
      'Phase B flag on: dirty revolving key keeps local, clean key adopts '
      'server (#3415 per-key guard)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
            AssetRevolvingCreditConfigStore.encodeMirrorValue(
              <String, AssetLiabilityRevolvingCreditConfig>{
                'dirty_card': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 1000,
                  creditLimit: 500000,
                ),
                'clean_card': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 2000,
                  creditLimit: 500000,
                ),
              },
            ),
          ),
          'asset_sync_dirty_keys_v1': jsonEncode(<String, dynamic>{
            'revolving_credit_configs': <String>['dirty_card'],
          }),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugMirrorReadsAuthoritative: true,
              debugRevolvingConfigsMirror:
                  AssetRevolvingCreditConfigStore.encodeMirrorValue(
                <String, AssetLiabilityRevolvingCreditConfig>{
                  'dirty_card': const AssetLiabilityRevolvingCreditConfig(
                    monthlyAmount: 9000,
                    creditLimit: 500000,
                  ),
                  'clean_card': const AssetLiabilityRevolvingCreditConfig(
                    monthlyAmount: 8000,
                    creditLimit: 500000,
                  ),
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetRevolvingCreditConfigStore().load();
        expect(local['dirty_card']!.monthlyAmount, 1000); // dirty → 保護
        expect(local['clean_card']!.monthlyAmount, 8000); // clean → サーバ採用

        await _unmount(tester);
      },
    );

    testWidgets(
      'Phase B flag on: dirty debt-override key keeps local, clean key adopts '
      'server (#3415 per-key guard)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_sync_dirty_keys_v1': jsonEncode(<String, dynamic>{
            'debt_payment_day_overrides': <String>['dirty_debt'],
          }),
        });
        final repo = _FakeDebtOverrideRepository(<String, int>{
          'dirty_debt': 10,
          'clean_debt': 11,
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              assetLiabilityRepository: repo,
              debugMirrorReadsAuthoritative: true,
              debugDebtOverridesMirror: const <String, dynamic>{
                'dirty_debt': 20,
                'clean_debt': 21,
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(repo.savedDebtOverrides, isNotNull);
        expect(repo.savedDebtOverrides!['dirty_debt'], 10); // dirty → 保護
        expect(repo.savedDebtOverrides!['clean_debt'], 21); // clean → サーバ採用

        await _unmount(tester);
      },
    );

    testWidgets('Phase B flag off (default): same-key conflict keeps local', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': 'old',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            // debugMirrorReadsAuthoritative 未指定 = 既定 OFF。
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'gold',
                  group: 'new',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // フラグ OFF: 衝突キー gold はローカル値 (group=old) を維持。
      final local = await const AssetWatchlistService().loadEntries();
      final gold = local.firstWhere((e) => e.assetType == 'gold');
      expect(gold.group, 'old');

      await _unmount(tester);
    });

    testWidgets('revolving union-merge: server card fills in, local card kept',
        (
      tester,
    ) async {
      // 端末B はローカルに別カードのリボ設定だけ持つ (auPAY は未設定)。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'other_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 端末A が auPAY のリボ設定をサーバへ保存済みの状態をミラー注入。
      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugRevolvingConfigsMirror:
                AssetRevolvingCreditConfigStore.encodeMirrorValue(
              <String, AssetLiabilityRevolvingCreditConfig>{
                'aupay_card': const AssetLiabilityRevolvingCreditConfig(
                  monthlyAmount: 10000,
                  creditLimit: 500000,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // union マージ: サーバの auPAY が反映され、かつローカルの別カードも維持。
      final merged = await const AssetRevolvingCreditConfigStore().load();
      expect(merged.keys, containsAll(<String>['other_card', 'aupay_card']));
      expect(merged['aupay_card']!.monthlyAmount, 10000);
      expect(merged['aupay_card']!.creditLimit, 500000);
      expect(merged['other_card']!.monthlyAmount, 3000);

      await _unmount(tester);
    });

    testWidgets('watchlist union-merge: server entry fills in, local kept', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'local_only',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
              <AssetWatchlistEntry>[
                AssetWatchlistEntry(
                  assetType: 'server_only',
                  group: 'invest',
                  memo: '',
                  addedAt: DateTime.utc(2026, 6, 14),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final merged = await const AssetWatchlistService().loadEntries();
      expect(
        merged.map((e) => e.assetType),
        containsAll(<String>['local_only', 'server_only']),
      );

      await _unmount(tester);
    });

    testWidgets('debt-override union-merge: server day fills in, local kept', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // ローカルは debt_a の支払日上書きを持ち、サーバは debt_b を持つ状態。
      final repo = _FakeDebtOverrideRepository(<String, int>{'debt_a': 27});

      await tester.pumpWidget(
        MaterialApp(
          home: AssetManagementPage(
            assetLiabilityRepository: repo,
            debugDebtOverridesMirror: const <String, dynamic>{'debt_b': 5},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // union マージ: ローカルの debt_a を維持しつつサーバの debt_b を取り込み、repo へ保存。
      expect(repo.savedDebtOverrides, isNotNull);
      expect(repo.savedDebtOverrides!['debt_a'], 27);
      expect(repo.savedDebtOverrides!['debt_b'], 5);

      await _unmount(tester);
    });

    testWidgets('revolving deletion tombstone removes local config', (
      tester,
    ) async {
      // ローカルに aupay_card / keep_card のリボ設定がある。
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetRevolvingCreditConfigStore.prefsKey: jsonEncode(
          AssetRevolvingCreditConfigStore.encodeMirrorValue(
            <String, AssetLiabilityRevolvingCreditConfig>{
              'aupay_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 10000,
                creditLimit: 500000,
              ),
              'keep_card': const AssetLiabilityRevolvingCreditConfig(
                monthlyAmount: 3000,
                creditLimit: 100000,
              ),
            },
          ),
        ),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で aupay_card を削除した状態を削除トゥームストーンで注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugRevolvingDeletedMirror: <String, dynamic>{
              'ids': <String>['aupay_card'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除が伝播し aupay_card はローカルから消え、keep_card は残る。
      final local = await const AssetRevolvingCreditConfigStore().load();
      expect(local.keys, isNot(contains('aupay_card')));
      expect(local.keys, contains('keep_card'));

      await _unmount(tester);
    });

    testWidgets(
      'recurring fixed cost deletion tombstone removes local cost',
      (tester) async {
        // ローカルに電気代 / Netflix の定期固定費がある。
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'fc_denki',
                  name: '電気代',
                  amount: 8000,
                  paymentDay: 27,
                ),
                AssetRecurringFixedCost(
                  id: 'fc_netflix',
                  name: 'Netflix',
                  amount: 1980,
                  paymentDay: 5,
                ),
              ],
            ),
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // 他端末で fc_denki を削除した状態を削除トゥームストーンで注入。
        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugRecurringFixedCostsDeletedMirror: <String, dynamic>{
                'ids': <String>['fc_denki'],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 削除が伝播し fc_denki はローカルから消え、fc_netflix は残る。
        final local = await const AssetRecurringFixedCostStore().load();
        expect(local.map((c) => c.id), isNot(contains('fc_denki')));
        expect(local.map((c) => c.id), contains('fc_netflix'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'subscription delete confirms history retention and records tombstone',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_xbox',
                  name: 'Xbox Game Pass',
                  amount: 1550,
                  paymentDay: 7,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
            ),
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpAssetPage(tester);
        final deleteButton = find.byTooltip('Xbox Game Pass を削除');
        expect(deleteButton, findsOneWidget);
        await tester.ensureVisible(deleteButton);
        await tester.tap(deleteButton);
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('サブスクを削除'), findsOneWidget);
        expect(find.textContaining('月額 ¥1,550'), findsOneWidget);
        expect(find.textContaining('過去の月次履歴・取引履歴は残ります'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'キャンセル'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('サブスクを削除'), findsNothing);
        final afterCancel = await const AssetRecurringFixedCostStore().load();
        expect(
          afterCancel.map((cost) => cost.id),
          contains('sub_xbox'),
        );

        await tester.ensureVisible(deleteButton);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(deleteButton.hitTestable());
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('サブスクを削除'), findsOneWidget);
        final confirmDelete = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '削除'),
        );
        confirmDelete.onPressed!();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('サブスクを削除'), findsNothing);
        for (var attempt = 0; attempt < 50; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          final persisted = await const AssetRecurringFixedCostStore().load();
          if (persisted.every((cost) => cost.id != 'sub_xbox')) break;
        }

        final afterDelete = await const AssetRecurringFixedCostStore().load();
        final preferences = await SharedPreferences.getInstance();
        const tombstones = MirrorTombstoneStore(
          storageKey: 'recurring_fixed_costs_deleted_v1',
        );
        final activeTombstones = tombstones.activeIds(preferences);
        final pendingSync = await const AssetSyncDirtyKeysStore().loadDirty(
          'recurring_fixed_costs_deleted',
          prefs: preferences,
        );
        expect(
          afterDelete.map((cost) => cost.id),
          isNot(contains('sub_xbox')),
          reason: 'tombstones=$activeTombstones pending=$pendingSync',
        );
        expect(activeTombstones, contains('sub_xbox'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'failed subscription re-add save restores pending and tombstone state',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_xbox',
                  name: 'Xbox Game Pass',
                  amount: 1550,
                  paymentDay: 7,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
            ),
          ),
        });
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        await tester.binding.setSurfaceSize(const Size(1200, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugRecurringFixedCostStore: _ThrowingRecurringFixedCostStore(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        final preferences = await SharedPreferences.getInstance();
        const tombstones = MirrorTombstoneStore(
          storageKey: 'recurring_fixed_costs_deleted_v1',
        );
        await tombstones.addId(preferences, 'sub_xbox');
        await const AssetSyncDirtyKeysStore().updateDirty(
          'recurring_fixed_costs_deleted',
          addKeys: <String>['add:sub_xbox'],
          prefs: preferences,
        );

        final reviewMenu = find.byKey(
          const Key('subscription_review_sub_xbox'),
        );
        await tester.ensureVisible(reviewMenu);
        await tester.tap(reviewMenu);
        await tester.pump(const Duration(milliseconds: 500));
        final keepLabel = find.text('残す').last;
        expect(keepLabel, findsOneWidget);
        Navigator.of(tester.element(keepLabel)).pop(
          AssetSubscriptionReviewDecision.keep,
        );
        await tester.pump(const Duration(milliseconds: 500));

        final persisted = await const AssetRecurringFixedCostStore().load(
          prefs: preferences,
        );
        expect(
          persisted.single.subscriptionReviewDecision,
          AssetSubscriptionReviewDecision.unreviewed,
        );
        expect(tombstones.activeIds(preferences), contains('sub_xbox'));
        expect(
          await const AssetSyncDirtyKeysStore().loadDirty(
            'recurring_fixed_costs_deleted',
            prefs: preferences,
          ),
          contains('add:sub_xbox'),
        );
        expect(find.textContaining('元の状態を保持'), findsOneWidget);

        await _unmount(tester);
      },
    );

    testWidgets(
      'tombstoned recurring fixed cost is not resurfaced when the server '
      'mirror still contains it',
      (tester) async {
        // ローカルに電気代 / Netflix。サーバ集約ミラーは依然 fc_denki を含む状態でも、
        // 削除トゥームストーンを先に取込む (pull→restore 直列化) ので、union マージが
        // fc_denki を復活させない。
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'fc_denki',
                  name: '電気代',
                  amount: 8000,
                  paymentDay: 27,
                ),
                AssetRecurringFixedCost(
                  id: 'fc_netflix',
                  name: 'Netflix',
                  amount: 1980,
                  paymentDay: 5,
                ),
              ],
            ),
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              // サーバミラーはまだ fc_denki を持つ (復活ベクタ)。
              debugRecurringFixedCostsMirror:
                  AssetRecurringFixedCostStore.encodeMirrorValue(
                const <AssetRecurringFixedCost>[
                  AssetRecurringFixedCost(
                    id: 'fc_denki',
                    name: '電気代',
                    amount: 8000,
                    paymentDay: 27,
                  ),
                  AssetRecurringFixedCost(
                    id: 'fc_netflix',
                    name: 'Netflix',
                    amount: 1980,
                    paymentDay: 5,
                  ),
                ],
              ),
              // 同時に fc_denki の削除トゥームストーンが届く。
              debugRecurringFixedCostsDeletedMirror: const <String, dynamic>{
                'ids': <String>['fc_denki'],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetRecurringFixedCostStore().load();
        expect(local.map((c) => c.id), isNot(contains('fc_denki')));
        expect(local.map((c) => c.id), contains('fc_netflix'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'pending tombstone removal preserves a deliberately re-added subscription',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_xbox',
                  name: 'Xbox Game Pass',
                  amount: 1550,
                  paymentDay: 7,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
            ),
          ),
          'recurring_fixed_costs_deleted_v1': jsonEncode(
            const <Map<String, String>>[
              <String, String>{
                'id': 'sub_xbox',
                'at': '2026-08-27T00:00:00.000Z',
              },
            ],
          ),
          AssetSyncDirtyKeysStore.prefsKey: jsonEncode(
            const <String, List<String>>{
              'recurring_fixed_costs_deleted': <String>['remove:sub_xbox'],
            },
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugRecurringFixedCostsDeletedMirror: <String, dynamic>{
                'ids': <String>[],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetRecurringFixedCostStore().load();
        expect(local.map((cost) => cost.id), contains('sub_xbox'));
        final preferences = await SharedPreferences.getInstance();
        const tombstones = MirrorTombstoneStore(
          storageKey: 'recurring_fixed_costs_deleted_v1',
        );
        expect(tombstones.activeIds(preferences), isNot(contains('sub_xbox')));

        await _unmount(tester);
      },
    );

    testWidgets(
      'legacy local tombstone is journaled before remote-authoritative boot',
      (tester) async {
        AssetSyncDirtyKeysStore.resetWriteLockForTest();
        AssetRecurringTombstoneSyncService.resetSharedForTest();
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'sub_legacy_deleted',
                  name: 'Legacy deleted subscription',
                  amount: 980,
                  paymentDay: 8,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
            ),
          ),
          'recurring_fixed_costs_deleted_v1': jsonEncode(
            const <String>['sub_legacy_deleted'],
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugRecurringFixedCostsDeletedMirror: <String, dynamic>{
                'ids': <String>[],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        for (var attempt = 0; attempt < 30; attempt++) {
          final preferences = await SharedPreferences.getInstance();
          if (preferences.getBool(
                'recurring_fixed_cost_tombstone_pending_v2_migrated',
              ) ==
              true) {
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }

        final preferences = await SharedPreferences.getInstance();
        const tombstones = MirrorTombstoneStore(
          storageKey: 'recurring_fixed_costs_deleted_v1',
        );
        final activeTombstones = tombstones.activeIds(preferences);
        final pendingSync = await const AssetSyncDirtyKeysStore().loadDirty(
          'recurring_fixed_costs_deleted',
          prefs: preferences,
        );
        final local = await const AssetRecurringFixedCostStore().load();
        expect(
          local.map((cost) => cost.id),
          isNot(contains('sub_legacy_deleted')),
          reason: 'tombstones=$activeTombstones pending=$pendingSync',
        );
        expect(
          pendingSync,
          contains('add:sub_legacy_deleted'),
        );
        expect(
          preferences.getBool(
            'recurring_fixed_cost_tombstone_pending_v2_migrated',
          ),
          isTrue,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'recurring fixed cost merges additively from the server mirror',
      (tester) async {
        // ローカルは fc_denki のみ。サーバは fc_denki + fc_gym を持つので、
        // additive union で fc_gym が反映され fc_denki も維持される (フラグ OFF)。
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetRecurringFixedCostStore.prefsKey: jsonEncode(
            AssetRecurringFixedCostStore.encodeMirrorValue(
              const <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'fc_denki',
                  name: '電気代',
                  amount: 8000,
                  paymentDay: 27,
                ),
              ],
            ),
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugRecurringFixedCostsMirror:
                  AssetRecurringFixedCostStore.encodeMirrorValue(
                const <AssetRecurringFixedCost>[
                  AssetRecurringFixedCost(
                    id: 'fc_denki',
                    name: '電気代',
                    amount: 8000,
                    paymentDay: 27,
                  ),
                  AssetRecurringFixedCost(
                    id: 'fc_gym',
                    name: 'ジム',
                    amount: 7000,
                    paymentDay: 1,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetRecurringFixedCostStore().load();
        expect(
          local.map((c) => c.id),
          containsAll(<String>['fc_denki', 'fc_gym']),
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'subscription audit syncs check state from the server mirror',
      (tester) async {
        // ローカルは空。新端末がサーバミラーから確認状況を取り込む。
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugSubscriptionAuditMirror:
                  AssetSubscriptionAuditStore.encodeMirrorValue(
                <String, DateTime>{'apple_id': DateTime.utc(2026, 6, 1)},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final state = await const AssetSubscriptionAuditStore().load();
        expect(state['apple_id'], DateTime.utc(2026, 6, 1));

        await _unmount(tester);
      },
    );

    testWidgets(
      'subscription audit MAX-merges and never clobbers a newer check',
      (tester) async {
        // apple_id: local 古 + mirror 新 → 新。au_kantan: local 新 + mirror 古 → 新。
        SharedPreferences.setMockInitialValues(<String, Object>{
          AssetSubscriptionAuditStore.prefsKey: jsonEncode(
            AssetSubscriptionAuditStore.encodeMirrorValue(
              <String, DateTime>{
                'apple_id': DateTime.utc(2026, 6, 1),
                'au_kantan': DateTime.utc(2026, 6, 10),
              },
            ),
          ),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugSubscriptionAuditMirror:
                  AssetSubscriptionAuditStore.encodeMirrorValue(
                <String, DateTime>{
                  'apple_id': DateTime.utc(2026, 6, 10),
                  'au_kantan': DateTime.utc(2026, 6, 1),
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final state = await const AssetSubscriptionAuditStore().load();
        // どちらの方向でも新しい確認が残る (MAX マージ)。
        expect(state['apple_id'], DateTime.utc(2026, 6, 10));
        expect(state['au_kantan'], DateTime.utc(2026, 6, 10));

        await _unmount(tester);
      },
    );

    testWidgets(
      'recurring fixed cost card survives hiding the salary-breakdown section',
      (tester) async {
        // 給与内訳セクションを hidden にしても、固定費カードは専用セクションとして
        // 残る (salaryBreakdown 相乗りの解消 = 候補#5)。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1':
              AssetManagementDisplayMode.standard.storageId,
          'asset_management_section_overrides_v1': jsonEncode(<String, String>{
            AssetManagementSectionId.salaryBreakdown.storageId:
                AssetManagementSectionVisibilityOverride.hidden.storageId,
          }),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(home: AssetManagementPage()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(RecurringFixedCostCard), findsOneWidget);

        await _unmount(tester);
      },
    );

    testWidgets(
      'proposal cards survive hiding the salary-breakdown section',
      (tester) async {
        // 給与内訳セクションを hidden にしても、定期取引/定期収入の自動検出
        // (提案カード) は専用 proposals セクションとして残る (相乗り解消 = 候補#2)。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1':
              AssetManagementDisplayMode.standard.storageId,
          'asset_management_section_overrides_v1': jsonEncode(<String, String>{
            AssetManagementSectionId.salaryBreakdown.storageId:
                AssetManagementSectionVisibilityOverride.hidden.storageId,
          }),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(home: AssetManagementPage()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 検出データが無くてもカード widget 自体は構築される (内部で shrink)。
        expect(
          find.byType(AssetRecurringTransactionSuggestionCard),
          findsWidgets,
        );

        await _unmount(tester);
      },
    );

    testWidgets('watchlist deletion tombstone removes local entry', (
      tester,
    ) async {
      // ローカルに gold / btc のウォッチリスト項目がある。
      SharedPreferences.setMockInitialValues(<String, Object>{
        'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'assetType': 'gold',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
          <String, dynamic>{
            'assetType': 'btc',
            'group': '',
            'memo': '',
            'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
          },
        ]),
      });
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 他端末で gold を削除した状態を削除トゥームストーンで注入。
      await tester.pumpWidget(
        const MaterialApp(
          home: AssetManagementPage(
            debugWatchlistDeletedMirror: <String, dynamic>{
              'ids': <String>['gold'],
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 削除が伝播し gold はローカルから消え、btc は残る。
      final local = await const AssetWatchlistService().loadEntries();
      expect(local.map((e) => e.assetType), isNot(contains('gold')));
      expect(local.map((e) => e.assetType), contains('btc'));

      await _unmount(tester);
    });

    testWidgets(
      'tombstoned entry is not resurfaced when the server mirror still '
      'contains it (review #1)',
      (tester) async {
        // ローカルに gold / btc。サーバ集約ミラーは依然 gold を含む状態でも、
        // 削除トゥームストーンを先に取込む (pull→restore 直列化) ので、union
        // マージが gold を復活させないことを保証する。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'assetType': 'gold',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
            <String, dynamic>{
              'assetType': 'btc',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ]),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              // サーバミラーはまだ gold を持つ (復活ベクタ)。
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'gold',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'btc',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                ],
              ),
              // 同時に gold の削除トゥームストーンが届く。
              debugWatchlistDeletedMirror: const <String, dynamic>{
                'ids': <String>['gold'],
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        final local = await const AssetWatchlistService().loadEntries();
        expect(local.map((e) => e.assetType), isNot(contains('gold')));
        expect(local.map((e) => e.assetType), contains('btc'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'additive merge realigns the local LWW timestamp even with flag off '
      '(review #2)',
      (tester) async {
        // ローカルは 'shared' のみ。サーバは 'shared' + 'extra' を持つので、
        // additive 追加のみ (localHasExtra=false → バックフィル無し) になる。
        // この経路は旧実装だと adoptConflicts=false で markChanged されず、
        // ローカル更新時刻が null のまま据え置かれていた。
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_watchlist_entries_v1': jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'assetType': 'shared',
              'group': '',
              'memo': '',
              'addedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          ]),
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'shared',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'extra',
                    group: 'invest',
                    memo: '',
                    addedAt: DateTime.utc(2026, 6, 14),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // additive マージでもローカル更新時刻が整合される。
        final ts = await const AssetSyncTimestampStore().loadTimestamp(
          'watchlist_entries',
        );
        expect(ts, isNotNull);

        await _unmount(tester);
      },
    );

    testWidgets(
      'restore tolerates a failing local save without crashing (review medium)',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // ローカルは 'gold' のみ。サーバは 'gold' + 'extra' なので additive
        // マージ → replaceAll 保存が走るが、その保存を必ず失敗させる。
        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              watchlistService: _ThrowingWatchlistService(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'gold',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                ],
              ),
              debugWatchlistMirror: AssetWatchlistService.encodeMirrorValue(
                <AssetWatchlistEntry>[
                  AssetWatchlistEntry(
                    assetType: 'gold',
                    group: '',
                    memo: '',
                    addedAt: DateTime.utc(2026, 1, 1),
                  ),
                  AssetWatchlistEntry(
                    assetType: 'extra',
                    group: 'invest',
                    memo: '',
                    addedAt: DateTime.utc(2026, 6, 14),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // 保存 future の失敗は catchError でログのみ → 未捕捉例外でクラッシュしない。
        expect(tester.takeException(), isNull);

        await _unmount(tester);
      },
    );

    testWidgets(
      'three-month overview includes current recurring subscription costs',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1':
              AssetManagementDisplayMode.standard.storageId,
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(
            home: AssetManagementPage(
              debugInitialRecurringFixedCosts: <AssetRecurringFixedCost>[
                AssetRecurringFixedCost(
                  id: 'subscription_total_regression',
                  name: 'AI・クラウドサブスク',
                  amount: 104648,
                  paymentDay: 15,
                  category: AssetRecurringFixedCostCategory.subscription,
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('3ヶ月俯瞰（先月・今月・来月）'), findsOneWidget);
        expect(find.text('固定費: ¥104,648'), findsNWidgets(3));

        await _unmount(tester);
      },
    );

    testWidgets(
      'missing asset data does not claim debt release or payoff',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1':
              AssetManagementDisplayMode.minimum.storageId,
        });
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const MaterialApp(home: AssetManagementPage()),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('判定不可'), findsNWidgets(2));
        expect(
          find.text('資産・負債が未登録のため、完済状態を判定できません。まず残高を登録してください。'),
          findsNWidgets(2),
        );
        expect(find.text('釈放'), findsNothing);
        expect(
          find.text('借金は完済済みです。収監モードは解除されました。'),
          findsNothing,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'registered zero-debt snapshot still shows the paid-off state',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'asset_management_display_mode_v1':
              AssetManagementDisplayMode.minimum.storageId,
        });
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await tester.binding.setSurfaceSize(const Size(1200, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{'財布(現金)': 10000},
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('判定不可'), findsNothing);
        expect(find.text('釈放'), findsNWidgets(2));
        expect(
          find.text('借金は完済済みです。収監モードは解除されました。'),
          findsOneWidget,
        );

        await _unmount(tester);
      },
    );

    testWidgets(
      'subscription audit lists アコムショッピング枠 (shoppingDebt) as a source',
      (tester) async {
        final now = DateTime.now();
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        await tester.binding.setSurfaceSize(const Size(1200, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '財布(現金)': 10000,
                  // 名前に「アコム」「ショッピング」を含むと shoppingDebt に分類される。
                  'アコムショッピング枠': -50000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // サブスク棚卸しカードが描画され、ショッピング枠が請求先候補として
        // 棚卸し対象に含まれる (クレジットカードに加え shoppingDebt も対象)。
        final auditCard = find.byType(SubscriptionAuditCard);
        expect(auditCard, findsOneWidget);
        final card = tester.widget<SubscriptionAuditCard>(auditCard);
        final sourceNames = card.sources.map((s) => s.name).toList();
        expect(sourceNames, contains('アコムショッピング枠'));

        await _unmount(tester);
      },
    );

    testWidgets(
      'Issue #5187: card reconciliation table renders without RenderBox layout exception',
      (tester) async {
        final now = DateTime.now();
        final dateKey = DateFormat('yyyy-MM-dd').format(now);
        await tester.binding.setSurfaceSize(const Size(1200, 4000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              debugInitialAssetData: <String, Map<String, double>>{
                dateKey: const <String, double>{
                  '財布(現金)': 50000,
                  '三井住友カード': -120000,
                  'PayPayカード': -45000,
                },
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // カード請求内訳レビュー / 管理ボードおよび資産負債全容把握カードが正常に描画される
        expect(
          find.byKey(const Key('asset_liability_workbook_board')),
          findsOneWidget,
        );
        expect(find.text('資産/負債 管理ボード'), findsOneWidget);
        expect(find.text('①資産・②負債の全容把握'), findsOneWidget);

        await _unmount(tester);
      },
    );
  });
}
