import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:my_web_app/services/asset_liability_monthly_state_store.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'asset_calendar_probe_toolbar_stub.dart'
    if (dart.library.js_interop) 'asset_calendar_probe_toolbar_web.dart'
    as toolbar;

const probeOwner = '00000000-0000-4000-8000-000000000001';
const probeOrigin = 'http://127.0.0.1:9999';

/// Has no delegate or socket client. Every request terminates in memory.
class ProbeMemoryHttp extends http.BaseClient {
  Completer<void>? historyGate;
  final requests = <String>[];
  int deniedWrites = 0;
  int deniedExternal = 0;
  int deliveredHistory = 0;

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
      body = {
        'code': 'PGRST202',
        'message': 'fixture rejects all writes and RPC POST',
      };
    } else if (request.url.path == '/rest/v1/cfo_assets') {
      await historyGate?.future;
      deliveredHistory++;
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
      request: request,
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
    Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'synthetic-local-token-not-valid-on-any-server',
        'token_type': 'bearer',
        'user': {
          'id': probeOwner,
          'aud': 'authenticated',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
          'created_at': '2026-06-20T00:00:00Z',
        },
      }),
    );

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
  return http.runWithClient(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      GoogleFonts.config.allowRuntimeFetching = false;
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
      runApp(
        AuthenticatedProbe(
          repository: ProbeDelayedRepository(gate),
          client: client,
          browserToolbar: true,
          earlySemantics: Uri.base.queryParameters['semantics'] == 'early',
        ),
      );
    },
    () => client,
  );
}

class AuthenticatedProbe extends StatefulWidget {
  const AuthenticatedProbe({
    super.key,
    required this.repository,
    this.client,
    this.browserToolbar = false,
    this.earlySemantics = false,
  });
  final ProbeDelayedRepository repository;
  final ProbeMemoryHttp? client;
  final bool browserToolbar;
  final bool earlySemantics;

  @override
  State<AuthenticatedProbe> createState() => _AuthenticatedProbeState();
}

class _AuthenticatedProbeState extends State<AuthenticatedProbe> {
  SemanticsHandle? semantics;
  final counter = _AuthenticatedPopupCounter();
  bool dataFramesSettled = false;

  @override
  void initState() {
    super.initState();
    if (widget.earlySemantics) {
      semantics = SemanticsBinding.instance.ensureSemantics();
    }
    if (widget.browserToolbar) {
      toolbar.installProbeToolbar(
        enable: () {
          semantics ??= SemanticsBinding.instance.ensureSemantics();
          auditTransport();
        },
        release: () => unawaited(releaseBrowserData()),
        audit: auditTransport,
      );
      auditTransport();
    }
  }

  void auditTransport() {
    final client = widget.client;
    toolbar.setProbeToolbarStatus(
      'probe-status:owner=synthetic;'
      'semantics=${semantics == null ? 'disabled' : 'enabled'};'
      'dataFrames=${dataFramesSettled ? 'settled' : 'waiting'};'
      'history=${client?.deliveredHistory ?? 0};'
      'loads=${widget.repository.completedLoads};'
      'writes-denied=${client?.deniedWrites ?? 0};'
      'external-denied=${client?.deniedExternal ?? 0};forwarded=0',
    );
  }

  Future<void> releaseBrowserData() async {
    if (!widget.repository.gate.isCompleted) widget.repository.gate.complete();
    for (var attempt = 0; attempt < 250; attempt++) {
      if ((widget.client?.deliveredHistory ?? 0) > 0 &&
          widget.repository.completedLoads > 0) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    dataFramesSettled = (widget.client?.deliveredHistory ?? 0) > 0 &&
        widget.repository.completedLoads > 0;
    auditTransport();
  }

  @override
  void dispose() {
    semantics?.dispose();
    counter.pushes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorObservers: [counter],
        // Match the production ThemeService bundled fonts without changing product code.
        theme: ThemeData(
          fontFamily: 'NotoSansJP',
          fontFamilyFallback: const ['NotoSansJP', 'NotoSans', 'NotoColorEmoji'],
        ),
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.only(top: widget.browserToolbar ? 80 : 0),
            child: Column(
              children: [
                Wrap(
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: counter.pushes,
                      builder: (_, value, child) => Semantics(
                        container: true,
                        label: 'fixture-popup-pushes:$value',
                        excludeSemantics: true,
                        child: SizedBox(
                          width: 220,
                          height: 32,
                          child: Text('fixture-popup-pushes:$value'),
                        ),
                      ),
                    ),
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
                        semantics ??=
                            SemanticsBinding.instance.ensureSemantics();
                      },
                      child: const Text('Probe: enable semantics'),
                    ),
                  ],
                ),
                Expanded(child: authenticatedProbePage(widget.repository)),
              ],
            ),
          ),
        ),
      );
}

class _AuthenticatedPopupCounter extends NavigatorObserver {
  final pushes = ValueNotifier<int>(0);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pushes.value++);
    }
  }
}
