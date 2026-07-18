import 'package:supabase_flutter/supabase_flutter.dart';

class McpFileConnector {
  const McpFileConnector({
    required this.id,
    required this.name,
    required this.canAttachContext,
  });

  final String id;
  final String name;
  final bool canAttachContext;

  factory McpFileConnector.fromJson(Map<String, dynamic> json) {
    return McpFileConnector(
      id: _text(json['id']),
      name: _text(json['name'], fallback: _text(json['id'])),
      canAttachContext: json['can_attach_context'] == true,
    );
  }
}

class McpFileSearchResult {
  const McpFileSearchResult({
    required this.id,
    required this.title,
    required this.uri,
    required this.mimeType,
    required this.snippet,
    required this.connectorId,
    required this.connectorName,
    required this.contextEligible,
    this.modifiedAt,
    this.score,
  });

  final String id;
  final String title;
  final String uri;
  final String mimeType;
  final String snippet;
  final String connectorId;
  final String connectorName;
  final bool contextEligible;
  final DateTime? modifiedAt;
  final double? score;

  factory McpFileSearchResult.fromJson(Map<String, dynamic> json) {
    return McpFileSearchResult(
      id: _text(json['id']),
      title: _text(json['title'], fallback: '無題のファイル'),
      uri: _text(json['uri']),
      mimeType: _text(json['mime_type']),
      snippet: _text(json['snippet']),
      connectorId: _text(json['connector_id']),
      connectorName: _text(json['connector_name']),
      contextEligible: json['context_eligible'] == true,
      modifiedAt: DateTime.tryParse(_text(json['modified_at'])),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class McpFileSearchResponse {
  const McpFileSearchResponse({
    required this.results,
    required this.deniedCount,
    required this.unsafeCount,
  });

  final List<McpFileSearchResult> results;
  final int deniedCount;
  final int unsafeCount;
}

class McpFileContextAttachment {
  const McpFileContextAttachment({
    required this.id,
    required this.title,
    required this.uri,
    required this.connectorId,
    required this.connectorName,
    required this.truncated,
  });

  final String id;
  final String title;
  final String uri;
  final String connectorId;
  final String connectorName;
  final bool truncated;

  factory McpFileContextAttachment.fromJson(Map<String, dynamic> json) {
    return McpFileContextAttachment(
      id: _text(json['id']),
      title: _text(json['title'], fallback: '無題のファイル'),
      uri: _text(json['uri']),
      connectorId: _text(json['connector_id']),
      connectorName: _text(json['connector_name']),
      truncated: json['truncated'] == true,
    );
  }
}

abstract class McpFileSearchGateway {
  Future<List<McpFileConnector>> loadConnectors();

  Future<McpFileSearchResponse> search({
    required String connectorId,
    required String query,
    int limit = 20,
  });

  Future<McpFileContextAttachment> attachContext(McpFileSearchResult result);
}

class McpFileSearchService implements McpFileSearchGateway {
  McpFileSearchService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<McpFileConnector>> loadConnectors() async {
    final data = await _invoke(buildMcpFileConnectorsBody());
    return _maps(data['connectors'])
        .map(McpFileConnector.fromJson)
        .where((connector) => connector.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<McpFileSearchResponse> search({
    required String connectorId,
    required String query,
    int limit = 20,
  }) async {
    final data = await _invoke(
      buildMcpFileSearchBody(
        connectorId: connectorId,
        query: query,
        limit: limit,
      ),
    );
    return McpFileSearchResponse(
      results: _maps(data['results'])
          .map(McpFileSearchResult.fromJson)
          .where((result) => result.id.isNotEmpty && result.uri.isNotEmpty)
          .toList(growable: false),
      deniedCount: _integer(data['denied_count']),
      unsafeCount: _integer(data['unsafe_count']),
    );
  }

  @override
  Future<McpFileContextAttachment> attachContext(
    McpFileSearchResult result,
  ) async {
    final data = await _invoke(buildMcpFileAttachContextBody(result));
    final context = _map(data['context']);
    if (_text(context['id']).isEmpty) {
      throw const McpFileSearchException('コンテキストを保存できませんでした');
    }
    return McpFileContextAttachment.fromJson(context);
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final response = await _client.functions.invoke('tools-hub', body: body);
    final data = _map(response.data);
    final error = _text(data['error']);
    if (response.status < 200 || response.status >= 300 || error.isNotEmpty) {
      throw McpFileSearchException(
        error.isEmpty ? 'HTTP ${response.status}' : error,
        statusCode: response.status,
      );
    }
    return data;
  }
}

class McpFileSearchException implements Exception {
  const McpFileSearchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Map<String, dynamic> buildMcpFileConnectorsBody() {
  return const <String, dynamic>{'action': 'mcp_file.connectors'};
}

Map<String, dynamic> buildMcpFileSearchBody({
  required String connectorId,
  required String query,
  int limit = 20,
}) {
  return <String, dynamic>{
    'action': 'mcp_file.search',
    'connector_id': connectorId.trim(),
    'query': query.trim(),
    'limit': limit.clamp(1, 20),
  };
}

Map<String, dynamic> buildMcpFileAttachContextBody(McpFileSearchResult result) {
  return <String, dynamic>{
    'action': 'mcp_file.attach_context',
    'connector_id': result.connectorId,
    'file_id': result.id,
    'uri': result.uri,
  };
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map(_map).toList(growable: false);
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
