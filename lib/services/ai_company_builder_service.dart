import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiCompanyBuilderService {
  AiCompanyBuilderService({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;
  RealtimeChannel? _eventsChannel;
  RealtimeChannel? _controlsChannel;
  RealtimeChannel? _masterChannel;
  Timer? _fallbackTimer;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  bool get isSignedIn => _client.auth.currentUser != null;

  Future<List<Map<String, dynamic>>> listCompanies() async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: const {'action': 'company_builder.list'},
    );
    final payload = _asMap(response.data);
    return _asMapList(payload['companies']);
  }

  Future<Map<String, dynamic>> getCompany(String companyId) async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: {'action': 'company_builder.get', 'company_id': companyId},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> bootstrap({
    required String idea,
    required double threshold,
  }) async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'company_builder.bootstrap',
        'idea': idea,
        'threshold': threshold,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> runtimeCommand({
    required String companyId,
    required String command,
  }) async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: {'action': 'company_builder.$command', 'company_id': companyId},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> addResearchSource({
    required String companyId,
    required String sourceUrl,
  }) async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'company_builder.research.add',
        'company_id': companyId,
        'source_url': sourceUrl,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> setGlobalKillSwitch({
    required bool enabled,
  }) async {
    final response = await _client.functions.invoke(
      'ai-hub',
      body: {
        'action': 'company_builder.global_kill_switch',
        'enabled': enabled,
      },
    );
    return _asMap(response.data);
  }

  void subscribe(String companyId, void Function() onChange) {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    unawaited(_removeSubscriptions());
    _fallbackTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => onChange(),
    );

    try {
      _eventsChannel = _client
          .channel('company_agent_events:$companyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'company_agent_events',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId,
            ),
            callback: (_) => onChange(),
          )
          .subscribe();
      _controlsChannel = _client
          .channel('company_agent_runtime_controls:$companyId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'company_agent_runtime_controls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'company_id',
              value: companyId,
            ),
            callback: (_) => onChange(),
          )
          .subscribe();
      _masterChannel = _client
          .channel('company_agent_runtime_master_controls')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'company_agent_runtime_master_controls',
            callback: (_) => onChange(),
          )
          .subscribe();
    } catch (_) {
      _eventsChannel = null;
      _controlsChannel = null;
      _masterChannel = null;
    }
  }

  Future<void> dispose() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _removeSubscriptions();
  }

  Future<void> _removeSubscriptions() async {
    final channels = [
      _eventsChannel,
      _controlsChannel,
      _masterChannel,
    ].whereType<RealtimeChannel>().toList(growable: false);
    _eventsChannel = null;
    _controlsChannel = null;
    _masterChannel = null;
    for (final channel in channels) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {
        // A stale Realtime channel must not prevent page navigation.
      }
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
