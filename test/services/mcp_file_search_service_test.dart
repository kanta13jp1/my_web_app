import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/mcp_file_search_service.dart';

void main() {
  const result = McpFileSearchResult(
    id: 'file-1',
    title: 'Roadmap',
    uri: 'mcp://drive/file-1',
    mimeType: 'text/markdown',
    snippet: 'Q3 plan',
    connectorId: 'drive',
    connectorName: 'Company Drive',
    contextEligible: true,
  );

  test('builds bounded MCP file search request', () {
    expect(
      buildMcpFileSearchBody(
        connectorId: ' drive ',
        query: ' roadmap ',
        limit: 200,
      ),
      <String, dynamic>{
        'action': 'mcp_file.search',
        'connector_id': 'drive',
        'query': 'roadmap',
        'limit': 20,
      },
    );
  });

  test('attach request contains identity, connector, and URI only', () {
    expect(buildMcpFileAttachContextBody(result), <String, dynamic>{
      'action': 'mcp_file.attach_context',
      'connector_id': 'drive',
      'file_id': 'file-1',
      'uri': 'mcp://drive/file-1',
    });
  });

  test('parses a safe search result without file content', () {
    final parsed = McpFileSearchResult.fromJson(<String, dynamic>{
      'id': 'file-1',
      'title': 'Roadmap',
      'uri': 'mcp://drive/file-1',
      'mime_type': 'text/markdown',
      'snippet': 'Q3 plan',
      'connector_id': 'drive',
      'connector_name': 'Company Drive',
      'context_eligible': true,
      'modified_at': '2026-07-17T10:00:00Z',
      'score': 0.92,
      'content': 'must not be represented by the model',
    });

    expect(parsed.id, 'file-1');
    expect(parsed.contextEligible, isTrue);
    expect(parsed.modifiedAt, DateTime.utc(2026, 7, 17, 10));
    expect(parsed.score, 0.92);
  });
}
