@TestOn('browser')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/site_guide_catalog_item.dart';
import 'package:my_web_app/pages/site_guide_chat_page.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/site_guide_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSiteGuideChatService extends SiteGuideChatService {
  _FakeSiteGuideChatService(this._answer);

  final SiteGuideChatAnswer _answer;
  String? lastQuestion;
  String? lastSessionId;

  @override
  Future<SiteGuideChatAnswer> answerQuestion(
    String question, {
    String? sessionId,
  }) async {
    lastQuestion = question;
    lastSessionId = sessionId;
    return _answer;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('SiteGuideChatPage sends questions and shows observability', (
    tester,
  ) async {
    var openedTool = false;
    var openedManual = false;
    final service = _FakeSiteGuideChatService(
      SiteGuideChatAnswer(
        text: '資産管理を開くと、お金まわりを一か所で見られます。',
        source: 'test-source',
        answeredAt: DateTime(2026, 4, 23, 22, 30),
        observability: const AiHubChatObservability(
          provider: 'deepinfra',
          latencyMs: 150,
          traceId: 'trace-12345678',
          sessionId: 'session-87654321',
        ),
        suggestions: const <SiteGuideToolSuggestion>[
          SiteGuideToolSuggestion(
            id: 'asset-management',
            title: '資産管理',
            subtitle: 'お金の入口',
            sectionId: 'office',
            sectionTitle: 'Office',
            score: 12,
          ),
        ],
      ),
    );

    final toolCatalog = <SiteGuideActionEntry>[
      SiteGuideActionEntry(
        item: const SiteGuideCatalogItem(
          id: 'asset-management',
          sectionId: 'office',
          sectionTitle: 'Office',
          title: '資産管理',
          subtitle: 'お金の入口',
          keywords: <String>['資産管理'],
        ),
        onOpen: (_) async {
          openedTool = true;
        },
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SiteGuideChatPage(
          service: service,
          toolCatalog: toolCatalog,
          onOpenUserManual: () {
            openedManual = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '資産管理はどこですか');
    await tester.tap(find.byKey(const Key('site_guide_send')));
    await tester.pumpAndSettle();

    expect(service.lastQuestion, '資産管理はどこですか');
    expect(service.lastSessionId, isNotNull);
    expect(find.text('資産管理を開くと、お金まわりを一か所で見られます。'), findsOneWidget);
    expect(find.text('AI observability'), findsOneWidget);
    expect(find.textContaining('trace '), findsOneWidget);
    expect(
      find.byKey(const Key('site_guide_open_asset-management')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('site_guide_open_asset-management')));
    await tester.pumpAndSettle();
    expect(openedTool, isTrue);

    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(openedManual, isTrue);
  });

  testWidgets('SiteGuideChatPage sends the initial question automatically', (
    tester,
  ) async {
    final service = _FakeSiteGuideChatService(
      SiteGuideChatAnswer(
        text: 'まずは今日の一手から始めましょう。',
        source: 'test-source',
        answeredAt: DateTime(2026, 4, 23, 22, 31),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SiteGuideChatPage(
          initialQuestion: 'まずは何を使えばよいですか',
          service: service,
          toolCatalog: const <SiteGuideActionEntry>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.lastQuestion, 'まずは何を使えばよいですか');
    expect(find.text('まずは今日の一手から始めましょう。'), findsOneWidget);
  });
}
