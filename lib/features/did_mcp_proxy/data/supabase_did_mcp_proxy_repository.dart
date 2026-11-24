import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/did_mcp_proxy_models.dart';

/// D-ID MCP プロキシ通信および監査ログ操作のリポジトリ抽象 (#2662).
abstract class DidMcpProxyRepository {
  Future<DidMcpDashboardSnapshot> fetchDashboard();

  Future<String> executeToolCall(final DidMcpExecutionInput input);

  Future<DidMcpAlert> acknowledgeAlert(final String alertId);
}

/// Edge Function `did-mcp-proxy` を介して D-ID MCP と監視ログを操作する実装 (#2662).
class SupabaseDidMcpProxyRepository implements DidMcpProxyRepository {
  SupabaseDidMcpProxyRepository({final SupabaseClient? client})
      : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Map<String, Object?> _normalizeMap(final Map<Object?, Object?> raw) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in raw.entries)
        if (entry.key != null) entry.key.toString(): entry.value,
    };
  }

  Map<String, Object?> _extractResponseMap(final FunctionResponse response) {
    if (response.data is Map<Object?, Object?>) {
      return _normalizeMap(response.data as Map<Object?, Object?>);
    }
    return const <String, Object?>{};
  }

  @override
  Future<DidMcpDashboardSnapshot> fetchDashboard() async {
    final FunctionResponse response = await _client.functions.invoke(
      'did-mcp-proxy',
      body: const <String, Object?>{'action': 'list_events'},
    );
    final Map<String, Object?> payload = _extractResponseMap(response);

    final List<DidMcpProxyEvent> events = <DidMcpProxyEvent>[];
    if (payload['events'] is List<Object?>) {
      for (final Map<Object?, Object?> raw
          in (payload['events'] as List<Object?>)
              .whereType<Map<Object?, Object?>>()) {
        events.add(DidMcpProxyEvent.fromMap(_normalizeMap(raw)));
      }
    }

    final List<DidMcpAlert> alerts = <DidMcpAlert>[];
    if (payload['alerts'] is List<Object?>) {
      for (final Map<Object?, Object?> raw
          in (payload['alerts'] as List<Object?>)
              .whereType<Map<Object?, Object?>>()) {
        alerts.add(DidMcpAlert.fromMap(_normalizeMap(raw)));
      }
    }

    return DidMcpDashboardSnapshot(events: events, alerts: alerts);
  }

  @override
  Future<String> executeToolCall(final DidMcpExecutionInput input) async {
    final String? validationError = input.validate();
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final FunctionResponse response = await _client.functions.invoke(
      'did-mcp-proxy',
      body: input.toJsonRpcBody(),
    );
    final Map<String, Object?> payload = _extractResponseMap(response);
    if (payload.isEmpty) {
      return 'プロキシ応答を受信しました (HTTP ${response.status})。';
    }
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  @override
  Future<DidMcpAlert> acknowledgeAlert(final String alertId) async {
    final String trimmed = alertId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('alertId が空です。');
    }

    final FunctionResponse response = await _client.functions.invoke(
      'did-mcp-proxy',
      body: <String, Object?>{
        'action': 'acknowledge_alert',
        'alert_id': trimmed,
      },
    );
    final Map<String, Object?> payload = _extractResponseMap(response);
    if (payload['alert'] is Map<Object?, Object?>) {
      return DidMcpAlert.fromMap(
        _normalizeMap(payload['alert'] as Map<Object?, Object?>),
      );
    }
    throw StateError('アラート確認結果の取得に失敗しました。');
  }
}
