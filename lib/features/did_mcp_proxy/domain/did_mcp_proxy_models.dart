import 'dart:convert';

import 'package:flutter/foundation.dart';

/// D-ID 公式 Streamable HTTP MCP ドキュメントサーバーのエンドポイント (#2662).
const String didMcpDocsEndpointUrl = 'https://docs.d-id.com/mcp';

/// D-ID MCP プロキシが提供するツール種別 (#2662).
enum DidMcpTool {
  talkVideo('did_generate_talk_video', 'アバター動画生成 (Talks)'),
  agentChat('did_agent_chat', 'エージェント対話 (Agents)'),
  ragQuery('did_rag_query', 'ナレッジ検索 (RAG)'),
  docsLookup('did_mcp_docs_lookup', 'D-ID MCP 公式仕様検索');

  const DidMcpTool(this.wireName, this.labelJa);

  final String wireName;
  final String labelJa;

  static DidMcpTool fromWire(final String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final DidMcpTool tool in DidMcpTool.values) {
      if (tool.wireName == normalized) {
        return tool;
      }
    }
    return DidMcpTool.talkVideo;
  }
}

/// D-ID MCP プロキシ呼出ログの実行状態 (#2662).
enum DidMcpEventStatus {
  queued('queued', 'Dry-Run / キュー済'),
  succeeded('succeeded', '成功'),
  rateLimited('rate_limited', 'レート制限 (429)'),
  failed('failed', '失敗');

  const DidMcpEventStatus(this.wireName, this.labelJa);

  final String wireName;
  final String labelJa;

  static DidMcpEventStatus fromWire(final String raw) {
    final String normalized = raw.trim().toLowerCase();
    for (final DidMcpEventStatus value in DidMcpEventStatus.values) {
      if (value.wireName == normalized) {
        return value;
      }
    }
    return DidMcpEventStatus.failed;
  }
}

/// クライアント向けの公開 Streamable HTTP MCP 接続設定 JSON を生成します (秘密鍵非含有).
String buildDidMcpClientConfigJson() {
  const Map<String, Object?> snippet = <String, Object?>{
    'mcpServers': <String, Object?>{
      'd-id-docs': <String, Object?>{
        'transport': 'streamable-http',
        'url': didMcpDocsEndpointUrl,
      },
    },
  };
  return const JsonEncoder.withIndent('  ').convert(snippet);
}

/// 監査テーブル `did_mcp_proxy_events` に対応する不変モデル (#2662).
@immutable
class DidMcpProxyEvent {
  const DidMcpProxyEvent({
    required this.id,
    required this.toolName,
    required this.rpcMethod,
    required this.promptSummary,
    required this.status,
    required this.httpStatus,
    required this.dryRun,
    required this.alertDispatched,
    required this.latencyMs,
    required this.createdAt,
    this.upstreamHost,
    this.errorMessage,
  });

  factory DidMcpProxyEvent.fromMap(final Map<String, Object?> row) {
    final int httpStatus = (row['http_status'] as num?)?.toInt() ?? 200;
    final int latencyMs = (row['latency_ms'] as num?)?.toInt() ?? 0;
    return DidMcpProxyEvent(
      id: (row['id']?.toString() ?? '').trim(),
      toolName:
          (row['tool_name']?.toString() ?? 'did_generate_talk_video').trim(),
      rpcMethod: (row['rpc_method']?.toString() ?? 'tools/call').trim(),
      promptSummary: (row['prompt_summary']?.toString() ?? '').trim(),
      status: DidMcpEventStatus.fromWire(row['status']?.toString() ?? 'failed'),
      httpStatus: httpStatus,
      dryRun: row['dry_run'] == true,
      alertDispatched: row['alert_dispatched'] == true,
      upstreamHost: row['upstream_host']?.toString(),
      errorMessage: row['error_message']?.toString(),
      latencyMs: latencyMs < 0 ? 0 : latencyMs,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String toolName;
  final String rpcMethod;
  final String promptSummary;
  final DidMcpEventStatus status;
  final int httpStatus;
  final bool dryRun;
  final bool alertDispatched;
  final String? upstreamHost;
  final String? errorMessage;
  final int latencyMs;
  final DateTime createdAt;
}

/// 監査アラートテーブル `did_mcp_alerts` に対応する不変モデル (#2662).
@immutable
class DidMcpAlert {
  const DidMcpAlert({
    required this.id,
    required this.severity,
    required this.alertType,
    required this.message,
    required this.acknowledged,
    required this.createdAt,
    this.eventId,
  });

  factory DidMcpAlert.fromMap(final Map<String, Object?> row) {
    return DidMcpAlert(
      id: (row['id']?.toString() ?? '').trim(),
      eventId: row['event_id']?.toString(),
      severity: (row['severity']?.toString() ?? 'warning').trim(),
      alertType: (row['alert_type']?.toString() ?? 'upstream_error').trim(),
      message: (row['message']?.toString() ?? '').trim(),
      acknowledged: row['acknowledged'] == true,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final String id;
  final String? eventId;
  final String severity;
  final String alertType;
  final String message;
  final bool acknowledged;
  final DateTime createdAt;

  DidMcpAlert copyWith({final bool? acknowledged}) {
    return DidMcpAlert(
      id: id,
      eventId: eventId,
      severity: severity,
      alertType: alertType,
      message: message,
      acknowledged: acknowledged ?? this.acknowledged,
      createdAt: createdAt,
    );
  }
}

/// D-ID MCP プロキシ呼出リクエストの入力バリデーションモデル (#2662).
@immutable
class DidMcpExecutionInput {
  const DidMcpExecutionInput({
    required this.tool,
    required this.prompt,
    this.targetId = '',
    this.dryRun = true,
  });

  final DidMcpTool tool;
  final String prompt;
  final String targetId;
  final bool dryRun;

  String? validate() {
    final String trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return 'プロンプトまたは検索クエリを入力してください。';
    }
    if (trimmed.length > 2000) {
      return 'プロンプトは 2000 文字以内で入力してください。';
    }
    return null;
  }

  Map<String, Object?> toJsonRpcBody() {
    final String cleanedPrompt = prompt.trim();
    final String cleanedTarget = targetId.trim();
    final Map<String, Object?> args;
    switch (tool) {
      case DidMcpTool.talkVideo:
        args = <String, Object?>{
          'script': cleanedPrompt,
          'dry_run': dryRun,
        };
      case DidMcpTool.agentChat:
        args = <String, Object?>{
          'agent_id': cleanedTarget.isEmpty ? 'agent_default' : cleanedTarget,
          'message': cleanedPrompt,
          'dry_run': dryRun,
        };
      case DidMcpTool.ragQuery:
        args = <String, Object?>{
          'knowledge_id': cleanedTarget.isEmpty ? 'default' : cleanedTarget,
          'query': cleanedPrompt,
          'top_k': 5,
          'dry_run': dryRun,
        };
      case DidMcpTool.docsLookup:
        args = <String, Object?>{
          'query': cleanedPrompt,
          'dry_run': dryRun,
        };
    }
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': tool.wireName,
        'arguments': args,
      },
    };
  }
}

/// Edge Function から取得したダッシュボード状態スナップショット (#2662).
@immutable
class DidMcpDashboardSnapshot {
  const DidMcpDashboardSnapshot({
    required this.events,
    required this.alerts,
  });

  final List<DidMcpProxyEvent> events;
  final List<DidMcpAlert> alerts;
}

/// D-ID MCP プロキシ画面のイミュータブル UI ステート (#2662).
@immutable
class DidMcpProxyState {
  const DidMcpProxyState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.lastResponsePreview,
    this.events = const <DidMcpProxyEvent>[],
    this.alerts = const <DidMcpAlert>[],
    this.selectedTool = DidMcpTool.talkVideo,
    this.dryRunOnly = true,
  });

  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? lastResponsePreview;
  final List<DidMcpProxyEvent> events;
  final List<DidMcpAlert> alerts;
  final DidMcpTool selectedTool;
  final bool dryRunOnly;

  int get rateLimitedCount => events
      .where(
        (final DidMcpProxyEvent e) => e.status == DidMcpEventStatus.rateLimited,
      )
      .length;

  int get unacknowledgedAlertCount =>
      alerts.where((final DidMcpAlert a) => !a.acknowledged).length;

  DidMcpProxyState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final String? errorMessage,
    final bool clearError = false,
    final String? lastResponsePreview,
    final List<DidMcpProxyEvent>? events,
    final List<DidMcpAlert>? alerts,
    final DidMcpTool? selectedTool,
    final bool? dryRunOnly,
  }) {
    return DidMcpProxyState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastResponsePreview: lastResponsePreview ?? this.lastResponsePreview,
      events: events ?? this.events,
      alerts: alerts ?? this.alerts,
      selectedTool: selectedTool ?? this.selectedTool,
      dryRunOnly: dryRunOnly ?? this.dryRunOnly,
    );
  }
}
