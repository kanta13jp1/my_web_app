import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '00000000-0000-4000-8000-000000000001';
const origin = 'http://127.0.0.1:9999';

// No delegate or socket client: all responses terminate in this synthetic fixture.
class MemoryIncomeHttp extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  var failFinance = false;
  var limited = false;
  Completer<void>? financeGate;
  bool financeGateEntered = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    Object body = <Object>[];
    var status = 200;
    if (request.url.origin != origin || request.method != 'GET') {
      status = 404;
      body = {
        'code': 'PGRST202',
        'message': 'memory fixture rejects transport and writes',
      };
    } else if (!request.url.path.startsWith('/rest/v1/')) {
      status = 403;
      body = {'code': 'FIXTURE_PATH_DENIED', 'message': 'no auth or other endpoint transport',};
    } else if (request.url.path.endsWith('/payslips') ||
        request.url.path.endsWith('/salary_incomes')) {
      if (financeGate != null) {
        financeGateEntered = true;
        await financeGate!.future;
      }
      if (failFinance) {
        status = 503;
        body = {
          'code': 'FIXTURE_READ_FAILURE',
          'message': 'synthetic read failed',
        };
      } else if (request.url.path.endsWith('/salary_incomes')) {
        body = List.generate(
          limited ? 12 : 1,
          (i) => {
            'id': 's$i',
            'pay_date': '2026-06-20',
            'amount': 100,
            'source': 'payslip',
            'payslip_id': 'p$i',
          },
        );
      } else if (request.url.queryParameters.containsKey('id')) {
        body = List.generate(
          limited ? 12 : 1,
          (i) => {
            'id': 'p$i',
            'pay_date': '2026-06-20',
            'net_amount': 100,
          },
        );
      }
    } else if ((request.headers['Accept'] ?? request.headers['accept'] ?? '')
        .contains('vnd.pgrst.object')) {
      status = 406;
      body = {'code': 'PGRST116', 'message': 'synthetic empty result'};
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  final client = MemoryIncomeHttp();
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
        localStorage: EmptyLocalStorage(),
      ),
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-local-token-not-valid-on-any-server',
        'token_type': 'bearer',
        'user': {
          'id': owner,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-06-20T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
      'new reconciliation reload is GET only, owner bounded, FK evidence only; failure and limit withhold totals',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            home: AssetManagementPage(
              assetLiabilityRepository:
                  const SharedPreferencesAssetLiabilityRepository(),
              debugNow: DateTime(2026, 6, 20),
              debugCalendarNow: DateTime(2026, 6, 20),
              debugInitialAssetData: const {},
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        final section = find.byKey(const Key('asset_income_reconciliation'));
        await tester.ensureVisible(section);
        await tester.pump();
        await tester.tap(section);
        await tester.pump(const Duration(milliseconds: 500));
        final prefs = await SharedPreferences.getInstance();
        final beforePrefs = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        };
        Future<void> tapReload() async {
          final button = find.widgetWithText(TextButton, '既存明細を再読込');
          expect(tester.widget<TextButton>(button).onPressed, isNotNull);
          await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
          await tester.pump(const Duration(milliseconds: 200));
          expect(button.hitTestable(), findsOneWidget,
            reason: 'synthetic reload control must be visibly hit-testable before pointer input: ${tester.getRect(button)}',);
          await tester.tap(button);
        }
        Future<List<http.BaseRequest>> reload() async {
          final before = client.requests.length;
          await tapReload();
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final added = client.requests.sublist(before);
          expect(added, isNotEmpty);
          expect(
            added.every((r) => r.method == 'GET' && r.url.origin == origin),
            isTrue,
            reason:
                'new read must not reach either finance or flow A06 saving continuation',
          );
          expect(
            {for (final key in prefs.getKeys()) key: prefs.get(key)},
            beforePrefs,
            reason:
                'received/paid/ack and persisted plan states stay unchanged',
          );
          return added;
        }

        final reads = await reload();
        final finance = reads
            .where(
              (r) =>
                  r.url.path.endsWith('/payslips') ||
                  r.url.path.endsWith('/salary_incomes'),
            )
            .toList();
        expect(finance, hasLength(3));
        expect(
          finance.every((r) => r.url.queryParameters['user_id'] == 'eq.$owner'),
          isTrue,
        );
        final fk =
            finance.singleWhere((r) => r.url.queryParameters.containsKey('id'));
        expect(fk.url.queryParameters['id'], 'in.(p0)');
        expect(fk.url.queryParameters['limit'], '1');
        expect(find.textContaining('対応の確認専用・独立加算なし'), findsOneWidget);
        expect(find.text('給与明細記録計: 未計算'), findsOneWidget);
        client.failFinance = true;
        await reload();
        expect(find.textContaining('読み取り未確認のため合算は未計算'), findsOneWidget);
        client.failFinance = false;
        client.limited = true;
        await reload();
        expect(find.textContaining('取得件数の上限に達したため'), findsOneWidget);
        client.limited = false;
        final gate = Completer<void>();
        client.financeGate = gate;
        await tapReload();
        for (var i = 0; i < 12 && !client.financeGateEntered; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(client.financeGateEntered, isTrue);
        const nextOwner = '00000000-0000-4000-8000-000000000002';
        await Supabase.instance.client.auth.setInitialSession(
          jsonEncode({
            'access_token': 'synthetic-second-owner-not-valid-on-any-server',
            'token_type': 'bearer',
            'user': {
              'id': nextOwner,
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-06-20T00:00:00Z',
            },
          }),
        );
        client.financeGate = null;
        gate.complete();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(
          find.text('給与明細データを読み込んでいます...'),
          findsNothing,
          reason:
              'stale owner request ends its own spinner without adopting its data',
        );
        expect(
          find.descendant(of: section, matching: find.textContaining('ID: p0')),
          findsNothing,
          reason:
              'prior owner observations are withheld from the comparison panel',
        );
        final newReads = await reload();
        final newFinance = newReads.where(
          (r) =>
              r.url.path.endsWith('/payslips') ||
              r.url.path.endsWith('/salary_incomes'),
        );
        expect(newFinance, isNotEmpty);
        expect(
          newFinance.every(
            (r) => r.url.queryParameters['user_id'] == 'eq.$nextOwner',
          ),
          isTrue,
        );
        expect(find.text('既存明細IDで照合'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      () => client,
    );
  });
}
