import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SemanticsHandle? qaSemantics;

// No delegate/socket. Guest page + existing debug/repository DI, no real auth.
class QaHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    debugPrint('REPAYMENT_QA_HTTP ${jsonEncode({
      'method': request.method,
      'denied': request.method != 'GET',
    })}');
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('[]')),
      request.method == 'GET' ? 200 : 403,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class QaRepository extends SharedPreferencesAssetLiabilityRepository {
  final String scenario;
  const QaRepository(this.scenario);

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async =>
      AssetLiabilityMonthlyState(
        paymentOverrides: {'mobit': scenario == 'zero' ? 0 : 1000},
        annualRateOverrides: const {'mobit': 0},
      );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final scenario = Uri.base.queryParameters['scenario'] ?? 'mixed';
  SharedPreferences.setMockInitialValues({
    'asset_management_display_mode_v1': 'full',
    'asset_management_section_overrides_v1': jsonEncode({
      for (final section in AssetManagementSectionId.values)
        section.name: section == AssetManagementSectionId.workbookBoard
            ? 'pinned'
            : 'hidden',
    }),
  });
  final client = QaHttp();
  await http.runWithClient(() async {
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-publishable-key-only',
      httpClient: client,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
    );
    qaSemantics = SemanticsBinding.instance.ensureSemantics();
    runApp(MaterialApp(
      theme: ThemeData(
        fontFamily: 'NotoSansJP',
        fontFamilyFallback: const ['NotoSansJP', 'NotoSans', 'NotoColorEmoji'],
      ),
      home: AssetManagementPage(
        assetLiabilityRepository: QaRepository(scenario),
        debugNow: DateTime(2026, 6, 20),
        debugCalendarNow: DateTime(2026, 6, 20),
        debugInitialAssetData: {
          '2026-06-20': {'現金': 10000, if (scenario != 'recurring') 'mobit': -5000,},
        },
        debugInitialRecurringFixedCosts: const [
          AssetRecurringFixedCost(
            id: 'synthetic-recurring',
            name: '合成定期支出・継続契約は返済元本へ含めない長い名称',
            amount: 1000,
            paymentDay: 20,
            category: AssetRecurringFixedCostCategory.subscription,
          ),
        ],
      ),
    ),);
  }, () => client,);
}
