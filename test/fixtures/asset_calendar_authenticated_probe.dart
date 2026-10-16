import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/models/asset_liability_workbook.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const probeOwner = '00000000-0000-4000-8000-000000000001';
const probeOrigin = 'http://127.0.0.1:9999';

/// Has no delegate or socket client. Every request terminates in memory.
class ProbeMemoryHttp extends http.BaseClient {
  Completer<void>? historyGate;
  final requests = <String>[];
  int deniedWrites = 0;
  int deniedExternal = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add('${request.method} ${request.url.path}');
    Object body = <Object>[];
    var status = 200;
    if (request.url.origin != probeOrigin) {
      deniedExternal++;
      status = 403;
      body = {'code': 'PROBE_EXTERNAL_DENIED', 'message': 'fixture only'};
    } else if (request.method != 'GET') {
      deniedWrites++;
      status = 404;
      // The product already falls back from unavailable history RPC to GET.
      body = {'code': 'PGRST202', 'message': 'fixture rejects all writes and RPC POST'};
    } else if (request.url.path == '/rest/v1/cfo_assets') {
      await historyGate?.future;
      body = [
        {
          'id': 1,
          'title': 'Synthetic bank',
          'amount': 1000,
          'created_at': '2026-06-20T00:00:00Z',
        },
        {
          'id': 2,
          'title': 'SyntheticLoan',
          'amount': -10000,
          'created_at': '2026-06-20T00:00:00Z',
        },
      ];
    } else if (!request.url.path.startsWith('/rest/v1/')) {
      status = 403;
      body = {'code': 'PROBE_PATH_DENIED', 'message': 'fixture only'};
    } else if ((request.headers['Accept'] ?? request.headers['accept'] ?? '')
        .contains('vnd.pgrst.object')) {
      status = 406;
      body = {'code': 'PGRST116', 'message': 'synthetic empty result'};
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Existing DI only; the same gate also releases the synthetic GET snapshot.
class ProbeDelayedRepository extends SharedPreferencesAssetLiabilityRepository {
  ProbeDelayedRepository(this.gate);
  final Completer<void> gate;
  int loadCalls = 0;
  int completedLoads = 0;

  @override
  Future<AssetLiabilityMonthlyState> loadMonth(DateTime month) async {
    loadCalls++;
    await gate.future;
    completedLoads++;
    return const AssetLiabilityMonthlyState();
  }
}

Future<void> restoreProbeOwner() =>
    Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'synthetic-local-token-not-valid-on-any-server',
      'token_type': 'bearer',
      'user': {
        'id': probeOwner,
        'aud': 'authenticated',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
        'created_at': '2026-06-20T00:00:00Z',
      },
    }),);

Widget authenticatedProbePage(ProbeDelayedRepository repository) =>
    AssetManagementPage(
      assetLiabilityRepository: repository,
      debugNow: DateTime(2026, 6, 20),
      debugCalendarNow: DateTime(2026, 6, 20),
      debugInitialAssetData: const <String, Map<String, double>>{},
      debugInitialRecentFlows: const <Map<String, dynamic>>[],
      debugInitialPayslipRows: const <Map<String, dynamic>>[],
      debugInitialPayslipSalaryIncomes: const <Map<String, dynamic>>[],
    );

Future<void> main() {
  final client = ProbeMemoryHttp();
  return http.runWithClient(() async {
      WidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final gate = Completer<void>();
      client.historyGate = gate;
      await Supabase.initialize(
        url: probeOrigin,
        publishableKey: 'test-publishable-key',
        httpClient: client,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          detectSessionInUri: false,
          localStorage: EmptyLocalStorage(),
        ),
      );
      await restoreProbeOwner();
      runApp(AuthenticatedProbe(repository: ProbeDelayedRepository(gate)));
    }, () => client);
}

class AuthenticatedProbe extends StatefulWidget {
  const AuthenticatedProbe({super.key, required this.repository});
  final ProbeDelayedRepository repository;

  @override
  State<AuthenticatedProbe> createState() => _AuthenticatedProbeState();
}

class _AuthenticatedProbeState extends State<AuthenticatedProbe> {
  SemanticsHandle? semantics;

  @override
  void dispose() {
    semantics?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Wrap(
                children: [
                  TextButton(
                    onPressed: () {
                      if (!widget.repository.gate.isCompleted) {
                        widget.repository.gate.complete();
                      }
                    },
                    child: const Text('Probe: release synthetic data'),
                  ),
                  TextButton(
                    onPressed: () {
                      semantics ??= SemanticsBinding.instance.ensureSemantics();
                    },
                    child: const Text('Probe: enable semantics'),
                  ),
                ],
              ),
              Expanded(child: authenticatedProbePage(widget.repository)),
            ],
          ),
        ),
      );
