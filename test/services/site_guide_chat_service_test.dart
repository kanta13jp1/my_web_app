import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/site_guide_catalog_item.dart';
import 'package:my_web_app/services/site_guide_chat_service.dart';

void main() {
  test('answerQuestion returns AI response with ranked suggestions', () async {
    final service = SiteGuideChatService(
      catalog: const <SiteGuideCatalogItem>[
        SiteGuideCatalogItem(
          id: 'asset-management',
          sectionId: 'office',
          sectionTitle: 'Office',
          title: '資産管理',
          subtitle: 'お金の入口',
          keywords: <String>['資産管理', 'お金', '予算'],
        ),
      ],
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['provider'], 'deepinfra');
        expect(
          (body['message'] as String),
          contains('資産管理はどこ？'),
        );
        return <String, dynamic>{
          'success': true,
          'text': '資産管理は Office セクションから開けます。',
        };
      },
    );

    final answer = await service.answerQuestion('資産管理はどこ？');

    expect(answer.text, '資産管理は Office セクションから開けます。');
    expect(answer.source, 'ai-hub provider.chat / deepinfra');
    expect(answer.isFallback, isFalse);
    expect(
      answer.suggestions.any((tool) => tool.id == 'asset-management'),
      isTrue,
    );
  });

  test('answerQuestion falls back locally when AI fails', () async {
    final service = SiteGuideChatService(
      catalog: const <SiteGuideCatalogItem>[
        SiteGuideCatalogItem(
          id: 'morning-briefing',
          sectionId: 'today',
          sectionTitle: 'Today',
          title: 'モーニングブリーフィング',
          subtitle: '今日の最初の一手',
          keywords: <String>['最初', '使い方', '朝'],
        ),
      ],
      invoker: (_) async => throw Exception('temporary failure'),
    );

    final answer = await service.answerQuestion('まず何から使えばいい？');

    expect(answer.source, 'local-site-guide');
    expect(answer.isFallback, isTrue);
    expect(answer.suggestions, isNotEmpty);
  });
}
