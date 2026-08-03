import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/mcp_file_search_page.dart';
import 'package:my_web_app/services/mcp_file_search_service.dart';

void main() {
  testWidgets(
    'searches, attaches an allowed file, and passes only context IDs',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gateway = _FakeMcpFileSearchGateway();
      Object? chatArguments;

      await tester.pumpWidget(
        MaterialApp(
          home: McpFileSearchPage(gateway: gateway),
          onGenerateRoute: (settings) {
            if (settings.name != '/ai-assistant-chat') return null;
            chatArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('AI chat opened')),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Company Drive'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('mcp_file_query')),
        'roadmap',
      );
      await tester.tap(find.byKey(const Key('mcp_file_search_button')));
      await tester.pumpAndSettle();

      expect(gateway.lastQuery, 'roadmap');
      expect(find.text('Roadmap.md'), findsOneWidget);
      expect(find.textContaining('権限 1 / 安全性 1'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mcp_file_attach_file-1')));
      await tester.pumpAndSettle();
      expect(gateway.attachedFileIds, <String>['file-1']);
      expect(find.byKey(const Key('mcp_file_open_chat')), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('mcp_file_open_chat')));
      await tester.pumpAndSettle();
      expect(find.text('AI chat opened'), findsOneWidget);
      expect(chatArguments, <String, dynamic>{
        'context_file_ids': <String>['context-1'],
        'context_titles': <String>['Roadmap.md'],
      });
    },
  );

  testWidgets('keeps an ineligible file unavailable for context attachment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: McpFileSearchPage(gateway: _FakeMcpFileSearchGateway()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('mcp_file_query')), 'roadmap');
    await tester.tap(find.byKey(const Key('mcp_file_search_button')));
    await tester.pumpAndSettle();

    final button = tester.widget<IconButton>(
      find.byKey(const Key('mcp_file_attach_file-2')),
    );
    expect(button.onPressed, isNull);
  });
}

class _FakeMcpFileSearchGateway implements McpFileSearchGateway {
  String? lastQuery;
  final List<String> attachedFileIds = [];

  @override
  Future<List<McpFileConnector>> loadConnectors() async {
    return const <McpFileConnector>[
      McpFileConnector(
        id: 'drive',
        name: 'Company Drive',
        canAttachContext: true,
      ),
    ];
  }

  @override
  Future<McpFileSearchResponse> search({
    required String connectorId,
    required String query,
    int limit = 20,
  }) async {
    lastQuery = query;
    return const McpFileSearchResponse(
      deniedCount: 1,
      unsafeCount: 1,
      results: <McpFileSearchResult>[
        McpFileSearchResult(
          id: 'file-1',
          title: 'Roadmap.md',
          uri: 'mcp://drive/file-1',
          mimeType: 'text/markdown',
          snippet: 'Q3 delivery plan',
          connectorId: 'drive',
          connectorName: 'Company Drive',
          contextEligible: true,
        ),
        McpFileSearchResult(
          id: 'file-2',
          title: 'Archive.txt',
          uri: 'mcp://drive/file-2',
          mimeType: 'text/plain',
          snippet: 'Read-only archive',
          connectorId: 'drive',
          connectorName: 'Company Drive',
          contextEligible: false,
        ),
      ],
    );
  }

  @override
  Future<McpFileContextAttachment> attachContext(
    McpFileSearchResult result,
  ) async {
    attachedFileIds.add(result.id);
    return McpFileContextAttachment(
      id: 'context-1',
      title: result.title,
      uri: result.uri,
      connectorId: result.connectorId,
      connectorName: result.connectorName,
      truncated: false,
    );
  }
}
