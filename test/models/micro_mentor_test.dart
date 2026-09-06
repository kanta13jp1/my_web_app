import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/micro_mentor.dart';

void main() {
  group('MicroMentor', () {
    test('reads the user-authored prompt config from agent metadata', () {
      final mentor = MicroMentor.fromAgentJson(<String, dynamic>{
        'id': 'mentor-1',
        'user_id': 'user-1',
        'slug': 'health-mentor',
        'display_name': 'ヘルスコーチ',
        'role_title': 'fallback role',
        'department': 'fallback domain',
        'status': 'active',
        'metadata': <String, dynamic>{
          'profile_type': 'micro_mentor',
          'prompt_config': <String, dynamic>{
            'role': '無理のない習慣を提案する',
            'domain': '健康',
            'tone': '穏やか',
            'important_values': <String>['継続', '安全', '継続'],
          },
        },
        'created_at': '2026-07-22T00:00:00Z',
        'updated_at': '2026-07-22T00:00:00Z',
      });

      expect(mentor.domain, '健康');
      expect(mentor.role, '無理のない習慣を提案する');
      expect(mentor.tone, '穏やか');
      expect(mentor.values, <String>['継続', '安全']);
      expect(mentor.enabled, isTrue);
    });

    test(
      'system prompt includes settings and preserves user final decision',
      () {
        final prompt = composeMicroMentorSystemPrompt(
          name: '学習コーチ',
          promptConfig: const <String, dynamic>{
            'role': '学習計画を分解する',
            'domain': '学習',
            'tone': '率直',
            'important_values': <String>['理解', '再現性'],
          },
        );

        expect(prompt, contains('学習コーチ'));
        expect(prompt, contains('学習計画を分解する'));
        expect(prompt, contains('率直'));
        expect(prompt, contains('理解'));
        expect(prompt, contains('The user must'));
        expect(prompt, contains('edit, accept, or reject'));
      },
    );
  });

  test('proposal model maps editable status and schedule values', () {
    final proposal = MicroMentorProposal.fromJson(<String, dynamic>{
      'id': 'proposal-1',
      'user_id': 'user-1',
      'mentor_id': 'mentor-1',
      'focus': '来週の計画',
      'proposal_type': 'schedule',
      'title': '朝の集中時間',
      'description': '月曜の朝に30分確保する',
      'rationale': '先に時間を確保すると継続しやすい',
      'status': 'accepted',
      'scheduled_for': '2026-07-27T09:00:00Z',
      'original_payload': <String, dynamic>{'source': 'ai'},
      'created_at': '2026-07-22T00:00:00Z',
      'updated_at': '2026-07-22T00:00:00Z',
    });

    expect(proposal.type, MicroMentorProposalType.schedule);
    expect(proposal.status, MicroMentorProposalStatus.accepted);
    expect(proposal.scheduledFor, DateTime.utc(2026, 7, 27, 9));
    expect(proposal.originalPayload['source'], 'ai');
  });
}
