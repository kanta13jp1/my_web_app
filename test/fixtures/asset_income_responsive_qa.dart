import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const qaOwner = '00000000-0000-4000-8000-000000000001';
const qaOrigin = 'http://127.0.0.1:9999';
const qaPayslip =
    'SYNTHETIC-PAYSLIP-REFERENCE-LONG-ID-FOR-NARROW-WRAPPING-ONLY-0001';
SemanticsHandle? incomeQaSemantics;

// No delegate or socket: every request finishes in synthetic memory.
class IncomeQaHttp extends http.BaseClient {
  var sequence = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final denied = request.url.origin != qaOrigin ||
        request.method != 'GET' ||
        !request.url.path.startsWith('/rest/v1/');
    // Fixture evidence logs no query, token or record values.
    debugPrint(
      'INCOME_QA_HTTP ${jsonEncode({
      'sequence': ++sequence,
      'method': request.method,
      'path': request.url.path,
      'denied': denied,
      })}',
    );
    Object body = <Object>[];
    var status = 200;
    if (denied) {
      status = 404;
      body = {
        'code': 'PGRST202',
        'message': 'INCOME_QA_DENIED: memory-only fixture rejects request',
      };
    } else if (request.url.path.endsWith('/salary_incomes')) {
      body = [
        {
          'id': 'SYNTHETIC-SALARY-0001',
          'pay_date': '2026-06-20',
          'amount': 100,
          'source': 'payslip',
          'payslip_id': qaPayslip,
        },
      ];
    } else if (request.url.path.endsWith('/payslips') &&
        request.url.queryParameters.containsKey('id')) {
      body = [
        {
          'id': qaPayslip,
          'pay_date': '2026-06-20',
          'net_amount': 100,
        },
      ];
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

// Existing repository DI. The unowned legacy observation must stay withheld.
class IncomeQaRepository extends SharedPreferencesAssetLiabilityRepository {
  const IncomeQaRepository();

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async =>
      AssetLiabilityMonthlyState(
        incomePlans: [
          AssetLiabilityIncomePlan(
            id: 'SYNTHETIC-LEGACY-OWNER-UNKNOWN',
            date: DateTime(2026, 6, 20),
            name: 'Synthetic other income',
            amount: 31,
            destinationAccountId: null,
            destinationAccountName: null,
            received: true,
          ),
        ],
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final client = IncomeQaHttp();
  await http.runWithClient(
    () async {
      await Supabase.initialize(
        url: qaOrigin,
        publishableKey: 'synthetic-publishable-key-only',
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
            'id': qaOwner,
            'aud': 'authenticated',
            'app_metadata': <String, Object>{},
            'user_metadata': <String, Object>{},
            'created_at': '2026-06-20T00:00:00Z',
          },
        }),
      );
      incomeQaSemantics = SemanticsBinding.instance.ensureSemantics();
      runApp(
        MaterialApp(
          theme: ThemeData(
            fontFamily: 'NotoSansJP',
            fontFamilyFallback: const [
              'NotoSansJP',
              'NotoSans',
              'NotoColorEmoji',
            ],
          ),
          home: AssetManagementPage(
            assetLiabilityRepository: const IncomeQaRepository(),
            debugNow: DateTime(2026, 6, 20),
            debugCalendarNow: DateTime(2026, 6, 20),
            debugInitialAssetData: const <String, Map<String, double>>{},
          ),
        ),
      );
    },
    () => client,
  );
}
