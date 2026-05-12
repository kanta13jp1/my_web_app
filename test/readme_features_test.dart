@TestOn('browser')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_list_page.dart';
import 'package:my_web_app/services/abstinence_guard_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:my_web_app/pages/home_page.dart';
import 'package:my_web_app/pages/emergency_meeting_page.dart';
import 'package:my_web_app/widgets/global_header_clock_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // 1. テスト実行前にFlutterの機能をバインドする（プラグインエラー防止の鍵）
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 2. Supabaseが動く前に、保存機能のモック（偽物）を用意する
    SharedPreferences.setMockInitialValues({});

    // 3. その後でSupabaseを初期化する
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      anonKey: 'dummy',
      debug: false,
    );
  });

  setUp(() {
    // 各テストの前に設定をリセット
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: MaterialApp(
        builder: (context, child) => GlobalHeaderClockShell(
          child: child ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }

  group('README Features Smoke Test', () {
    testWidgets('Feature: HomePage default uses curated navigation sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const HomePage()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_section_site_guide_ai')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_tier_recent')), findsOneWidget);
      expect(find.byKey(const Key('home_tier_popular')), findsOneWidget);
      expect(find.byKey(const Key('home_tier_system')), findsOneWidget);
      expect(find.byKey(const Key('home_tier_pinned')), findsOneWidget);
      expect(find.byKey(const Key('home_tier_new')), findsOneWidget);
      expect(find.byKey(const Key('home_tier_recommend')), findsOneWidget);
      expect(
        find.byKey(const Key('home_section_feature_request')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_section_ceo_office')), findsNothing);
    });

    testWidgets('Feature: HomePage (Cockpit) renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(const HomePage(showLegacyOperations: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('global_header_clock_bar')), findsOneWidget);
      expect(find.byKey(const Key('global_header_clock_text')), findsOneWidget);
      expect(find.byKey(const Key('home_page_scaffold')), findsOneWidget);
      expect(find.byKey(const Key('home_page_title')), findsOneWidget);
      expect(
        find.byKey(const Key('home_monthly_cashflow_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_completion_goal_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_section_office_kpi_summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_office_kpi_card_cfo')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('home_section_ceo_office')), findsOneWidget);
      expect(
        find.byKey(const Key('home_section_cso_office')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_section_operations_calendar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_task_preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_month_prev')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_month_next')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_month_label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_preview_filter_all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_preview_filter_incompleteOnly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_preview_filter_importantOnly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_calendar_task_preview_empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_abstinence_guard_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_abstinence_discipline_card')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: HomePage prioritizes morning briefing before noon',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_monthly_flow_review_done_2026-02': true,
      });
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 9, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_next_action_morningBriefing')),
        findsOneWidget,
      );
    });

    testWidgets(
        'Feature: HomePage prioritizes monthly cashflow review before briefing',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 9, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_next_action_monthlyFlowReview')),
        findsOneWidget,
      );
    });

    testWidgets(
        'Feature: HomePage prioritizes abstinence guard when slips exist',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await AbstinenceGuardStore.setEnabled(
        itemId: 'alcohol',
        isEnabled: true,
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );
      await AbstinenceGuardStore.incrementSlip(
        itemId: 'alcohol',
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );

      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 9, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_next_action_abstinenceGuard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_next_action_morningBriefing')),
        findsNothing,
      );
    });

    testWidgets('Feature: HomePage prioritizes balance check after briefing',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_monthly_flow_review_done_2026-02': true,
        'home_morning_briefing_done_2026-02-26': true,
      });
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 10, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_next_action_balanceCheck')),
        findsOneWidget,
      );
    });

    testWidgets(
        'Feature: HomePage prioritizes completion goal after core flow is done',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_monthly_flow_review_done_2026-02': true,
        'home_morning_briefing_done_2026-02-26': true,
        'home_balance_check_done_2026-02-26': true,
      });
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_next_action_beatYesterdayGoal')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: HomePage calendar day shows slips and missing items',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'home_morning_briefing_done_2026-02-26': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await AbstinenceGuardStore.setEnabled(
        itemId: 'alcohol',
        isEnabled: true,
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );
      await AbstinenceGuardStore.incrementSlip(
        itemId: 'alcohol',
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );

      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendarDay = find.byKey(const Key('calendar_day_2026-02-26'));
      await tester.ensureVisible(calendarDay);
      await tester.tap(calendarDay);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('calendar_day_detail_2026-02-26')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('calendar_day_detail_open_abstinence_button')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: HomePage calendar summary pills filter highlights',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await AbstinenceGuardStore.setEnabled(
        itemId: 'alcohol',
        isEnabled: true,
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );
      await AbstinenceGuardStore.incrementSlip(
        itemId: 'alcohol',
        prefs: prefs,
        now: DateTime(2026, 2, 26),
      );

      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slipSummaryPill = find.byKey(
        const Key('home_calendar_summary_slip'),
      );
      await tester.ensureVisible(slipSummaryPill);
      await tester.tap(slipSummaryPill);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_calendar_filter_slip')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: HomePage calendar can move between months',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      Text monthLabel = tester.widget(
        find.byKey(const Key('home_calendar_month_label')),
      );
      expect(monthLabel.data, '2026年2月');

      await tester.ensureVisible(
        find.byKey(const Key('home_calendar_month_prev')),
      );
      await tester.tap(find.byKey(const Key('home_calendar_month_prev')));
      await tester.pumpAndSettle();

      monthLabel = tester.widget(
        find.byKey(const Key('home_calendar_month_label')),
      );
      expect(monthLabel.data, '2026年1月');

      await tester.ensureVisible(
        find.byKey(const Key('home_calendar_month_next')),
      );
      await tester.tap(find.byKey(const Key('home_calendar_month_next')));
      await tester.pumpAndSettle();

      monthLabel = tester.widget(
        find.byKey(const Key('home_calendar_month_label')),
      );
      expect(monthLabel.data, '2026年2月');
    });

    testWidgets(
        'Feature: HomePage shows abstinence discipline prompt by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('home_abstinence_guard_panel'));
      await tester.ensureVisible(panel);

      expect(
        find.byKey(const Key('home_abstinence_discipline_summary')),
        findsOneWidget,
      );
      expect(
        find.textContaining('今日はまだ我慢の実績がありません'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('home_abstinence_open_training_button')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: HomePage surfaces abstinence discipline totals',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      await AbstinenceGuardStore.recordDisciplineRep(
        categoryId: 'no_buy',
        moneySaved: 1800,
        timeSavedMinutes: 20,
        note: 'コンビニ回避',
        prefs: prefs,
        now: DateTime(2026, 2, 26, 8, 0),
      );

      await tester.pumpWidget(
        createTestWidget(
          HomePage(
            nowProvider: () => DateTime(2026, 2, 26, 13, 0),
            showLegacyOperations: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(const Key('home_abstinence_guard_panel'));
      await tester.ensureVisible(panel);

      expect(
        find.textContaining('今日の我慢 1回 / 防いだ出費 1,800円 / 取り戻した時間 20分'),
        findsOneWidget,
      );
      expect(find.text('一拍置ける'), findsWidgets);
    });

    testWidgets('Feature: EmergencyMeetingPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: EmergencyMeetingPage()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('emergency_meeting_page_scaffold')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('emergency_meeting_page_title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('emergency_meeting_focus_balanced')),
        findsOneWidget,
      );
    });

    testWidgets('Feature: NoteListPage renders correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: NoteListPage()));
      // データの読み込み待ち（エラーになってもUIが出ればOK）
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('note_list_page_scaffold')), findsOneWidget);
      expect(find.byKey(const Key('note_list_page_title')), findsOneWidget);
      expect(find.byKey(const Key('note_list_page_fab')), findsOneWidget);
    });
  });
}
