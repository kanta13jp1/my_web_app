import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_salary_day_store.dart';
import 'package:my_web_app/services/asset_salary_reset_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '00000000-0000-4000-8000-000000000001';
const origin = 'http://127.0.0.1:9999';

// No delegate, socket, real auth or database. Boot is empty; only the public
// read-only reload receives the case snapshot, so A06 cannot mark a plan received.
class CycleMemoryHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  bool ready = false;
  List<Map<String, dynamic>> flows = [], salaries = [], payslips = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    Object body = <Object>[];
    var status = 200;
    final path = request.url.path;
    if (request.url.origin != origin ||
        request.method != 'GET' ||
        !path.startsWith('/rest/v1/')) {
      status = 404;
      body = {
        'code': 'PGRST202',
        'message': 'memory-only denies transport and writes'
      ,};
    } else if (path.endsWith('/wealth_struggles') ||
        path.endsWith('/salary_incomes') ||
        path.endsWith('/payslips')) {
      // A successful response is available only for the explicit owner filter.
      expect(request.url.queryParameters['user_id'], 'eq.$owner');
      if (ready) {
        final rows = path.endsWith('/wealth_struggles')
            ? flows
            : path.endsWith('/salary_incomes')
                ? salaries
                : payslips;
        body = [
          for (var i = 0; i < rows.length; i++)
            {'id': 'synthetic-${path.split('/').last}-$i', ...rows[i]}
        ,];
      }
    } else if ((request.headers['Accept'] ?? request.headers['accept'] ?? '')
        .contains('vnd.pgrst.object')) {
      status = 406;
      body = {'code': 'PGRST116', 'message': 'synthetic empty result'};
    }
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))), status,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,);
  }
}

class CycleRepository extends SharedPreferencesAssetLiabilityRepository {
  CycleRepository({this.monthlyState = const AssetLiabilityMonthlyState()});
  final AssetLiabilityMonthlyState monthlyState;
  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async =>
      monthlyState;
}

final client = CycleMemoryHttp();

Widget evidencePage({
  AssetLiabilityRepository? assetLiabilityRepository,
  Map<String, Map<String, double>>? debugInitialAssetData,
  List<Map<String, dynamic>>? debugInitialRecentFlows,
  List<Map<String, dynamic>>? debugInitialPayslipSalaryIncomes,
  List<Map<String, dynamic>>? debugInitialPayslipRows,
}) {
  client.flows = debugInitialRecentFlows ?? [];
  client.salaries = debugInitialPayslipSalaryIncomes ?? [];
  client.payslips = debugInitialPayslipRows ?? [];
  return AssetManagementPage(
    assetLiabilityRepository: assetLiabilityRepository ?? CycleRepository(),
    debugInitialAssetData: debugInitialAssetData ?? const {},
  );
}

Future<void> pumpEvidencePage(WidgetTester tester, Widget page) async {
  await http.runWithClient(() async {
    await tester.pumpWidget(page);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final section = find.byKey(const Key('asset_income_reconciliation'));
    await tester.ensureVisible(section);
    await tester.pump();
    await tester.tap(section);
    await tester.pump(const Duration(milliseconds: 300));
    final reload = find.widgetWithText(TextButton, '既存明細を再読込');
    await Scrollable.ensureVisible(tester.element(reload), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 200));
    expect(reload.hitTestable(), findsOneWidget);
    final before = client.requests.length;
    client.ready = true;
    await tester.tap(reload);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.widget<TextButton>(reload).onPressed, isNotNull);
    final reads = client.requests.skip(before).toList();
    expect(reads, isNotEmpty);
    expect(
        reads.every((r) =>
            r.method == 'GET' &&
            r.url.origin == origin &&
            r.url.path.startsWith('/rest/v1/'),),
        isTrue,);
  }, () => client,);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: origin,
        publishableKey: 'synthetic-only',
        httpClient: client,
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            detectSessionInUri: false,
            localStorage: EmptyLocalStorage(),),);
  });
  setUp(() async {
    client.ready = false;
    client.requests.clear();
    client.flows = [];
    client.salaries = [];
    client.payslips = [];
    SharedPreferences.setMockInitialValues({});
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'synthetic-local-token-not-valid-on-any-server',
      'token_type': 'bearer',
      'user': {
        'id': owner,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-06-20T00:00:00Z'
      ,}
    ,}),);
  });
  tearDownAll(() => Supabase.instance.dispose());
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

      await pumpEvidencePage(
        tester,
        MaterialApp(
          home: evidencePage(
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
      final repo = CycleRepository(
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

      await pumpEvidencePage(
        tester,
        MaterialApp(
          home: evidencePage(
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
      final previousCycleKey = AssetLiabilityMonthlyStateStore.formatMonthKey(
        DateTime(cycleStart.year, cycleStart.month - 1),
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        AssetSalaryResetMarkerStore.prefsKey: previousCycleKey,
      });

      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpEvidencePage(
        tester,
        MaterialApp(
          home: evidencePage(
            debugInitialAssetData: <String, Map<String, double>>{
              DateFormat('yyyy-MM-dd').format(now): const <String, double>{
                '現金': 50000,
              },
            },
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
      expect(
        find.descendant(
          of: card,
          matching: find.text('給与会計記録計: JPY 280000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining('現在残高や今後の支払後に使える額とは異なります'),
        ),
        findsOneWidget,
      );
      expect(find.text('給与の口座入金は未確認です'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(AssetSalaryResetMarkerStore.prefsKey),
        previousCycleKey,
        reason: '給与明細だけでは口座入金と判定して支払チェックをリセットしない',
      );
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      await tester.pump();
      expect(find.text('給与の口座入金は未確認です'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      await pumpEvidencePage(
        tester,
        MaterialApp(
          home: evidencePage(
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
    'same date and amount without explicit FK remain unconfirmed',
    (tester) async {
      // 同日同額だけでは別々の出典を同一収入と断定しない。
      // 明示FKがないため合算を保留し、280000/560000とも確定表示しない。
      final now = DateTime.now();
      final cycleStart = AssetLiabilityMonthlyStateStore.salaryCycleStart(
        now,
        salaryDay: AssetSalaryDayStore.defaultSalaryDay,
      );
      final payDate = DateFormat('yyyy-MM-dd').format(cycleStart);

      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpEvidencePage(
        tester,
        MaterialApp(
          home: evidencePage(
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

      expect(find.descendant(of: card, matching: find.text('¥280,000')),
          findsNothing,);
      expect(
          find.descendant(
              of: card, matching: find.textContaining('出典間の対応が未照合'),),
          findsWidgets,);
      expect(
          find.descendant(of: card, matching: find.textContaining('560,000')),
          findsNothing,);

      await _unmount(tester);
    },
  );
  testWidgets(
      'anonymous unconfirmed read never claims empty income or offers empty CTA',
      (tester) async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: AssetManagementPage(
        assetLiabilityRepository: CycleRepository(),
        debugInitialAssetData: const {},
        debugInitialRecentFlows: const [],
      ),),);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      final card = find.byKey(const Key('asset_monthly_flow_priority_card'));
      expect(card, findsOneWidget);
      expect(
          find.byKey(const Key('asset_monthly_flow_income_cta')), findsNothing,);
      expect(
          find.descendant(
              of: card, matching: find.textContaining('収入の読み取りを確認できないため未計算'),),
          findsWidgets,);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    }, () => client,);
  });
}
