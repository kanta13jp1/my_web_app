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
          keywords: <String>['資産管理', 'お金', '家計'],
        ),
      ],
      invoker: (body) async {
        expect(body['action'], 'provider.chat_auto');
        expect((body['message'] as String), contains('資産管理はどこですか'));
        return <String, dynamic>{
          'success': true,
          'text': '資産管理は Office セクションから開けます。',
          'observability': <String, dynamic>{
            'provider': 'deepinfra',
            'latency_ms': 280,
            'trace_id': 'trace-abcdefgh',
            'session_id': 'session-zxyw',
          },
          'provider': 'deepinfra',
        };
      },
    );

    final answer = await service.answerQuestion('資産管理はどこですか');

    expect(answer.text, '資産管理は Office セクションから開けます。');
    expect(answer.source, 'ai-hub provider.chat_auto / deepinfra');
    expect(answer.observability?.latencyMs, 280);
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

    final answer = await service.answerQuestion('まずは何を使えばよいですか');

    expect(answer.source, 'local-site-guide');
    expect(answer.isFallback, isTrue);
    expect(answer.suggestions, isNotEmpty);
  });
}
