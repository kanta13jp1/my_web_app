import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/virtual_org_agent.dart';

/// `ai-hub` の `org.get` が返す hub_data 行 (nested metadata) を模す。
Map<String, dynamic> row(Map<String, dynamic> metadata, {String id = 'a1'}) => {
      'id': id,
      'created_at': '2026-10-07T00:00:00Z',
      'metadata': {'user_id': 'u1', ...metadata},
    };

void main() {
  group('VirtualOrganization.fromResponse', () {
    test('nested metadata からエージェントを読み、部署ごとに数える', () {
      final org = VirtualOrganization.fromResponse({
        'success': true,
        'org': {
          'departments': ['CEO', 'CMO', 'CTO'],
          'agents': [
            row({'name': 'マーケAI', 'role': 'SNS', 'department': 'CMO'}),
            row({'name': '広報AI', 'department': 'CMO'}, id: 'a2'),
            row({'name': '開発AI', 'department': 'CTO'}, id: 'a3'),
          ],
        },
      });
      expect(org.departments, ['CEO', 'CMO', 'CTO']);
      expect(org.agents.first.name, 'マーケAI');
      expect(org.agents.first.affiliationLabel, 'CMO • SNS');
      expect(org.agents[1].affiliationLabel, 'CMO');
      expect(org.agentCountOf('CMO'), 2);
      expect(org.agentCountOf('CTO'), 1);
      expect(org.agentCountOf('CEO'), 0);
    });

    test('EF 既定の personality {} は空文字に落とす (cast で落ちない)', () {
      final agent = VirtualOrgAgent.fromRow(
        row({'name': 'A', 'personality': <String, dynamic>{}}),
      );
      expect(agent.personality, '');
      expect(
        VirtualOrgAgent.fromRow(row({'personality': ' 几帳面 '})).personality,
        '几帳面',
      );
    });

    test('壊れた応答は空の組織になる', () {
      expect(VirtualOrganization.fromResponse(null).agents, isEmpty);
      expect(VirtualOrganization.fromResponse('x').departments, isEmpty);
      expect(
        VirtualOrganization.fromResponse({'org': 'broken'}).agents,
        isEmpty,
      );
    });
  });

  group('VirtualOrgAgentDraft', () {
    test('送信 body を一覧側が読めるキーで組み、読み戻せる', () {
      final body = const VirtualOrgAgentDraft(
        name: ' マーケAI ',
        department: 'CMO',
        role: ' SNS投稿 ',
        personality: '几帳面',
      ).toRequestBody();
      expect(body['action'], 'agent.create');
      // EF は name/role/department/personality を metadata へ保存する。
      final agent = VirtualOrgAgent.fromRow(row({...body}..remove('action')));
      expect(agent.name, 'マーケAI');
      expect(agent.role, 'SNS投稿');
      expect(agent.department, 'CMO');
      expect(agent.personality, '几帳面');
    });

    test('役割が空なら送らず EF 既定値に任せる', () {
      final body = const VirtualOrgAgentDraft(
        name: 'A',
        department: 'CEO',
      ).toRequestBody();
      expect(body.containsKey('role'), isFalse);
    });

    test('必須項目と長さを検証する', () {
      expect(
        const VirtualOrgAgentDraft(name: '  ', department: 'CEO').validate(),
        isNotNull,
      );
      expect(
        const VirtualOrgAgentDraft(name: 'A', department: '').validate(),
        isNotNull,
      );
      expect(
        VirtualOrgAgentDraft(
          name: 'あ' * (VirtualOrgAgentDraft.maxNameLength + 1),
          department: 'CEO',
        ).validate(),
        isNotNull,
      );
      expect(
        VirtualOrgAgentDraft(
          name: 'あ' * VirtualOrgAgentDraft.maxNameLength,
          department: 'CEO',
        ).validate(),
        isNull,
      );
    });
  });
}
