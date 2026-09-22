import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/micro_mentor.dart';
import 'package:my_web_app/services/micro_mentor_service.dart';

void main() {
  group('MicroMentorProposalGenerator', () {
    test(
      'starts active mentors in parallel before waiting for their responses',
      () async {
        final completions = <String, Completer<Map<String, dynamic>>>{
          'mentor-1': Completer<Map<String, dynamic>>(),
          'mentor-2': Completer<Map<String, dynamic>>(),
        };
        final started = <String>[];
        final generator = MicroMentorProposalGenerator(
          invoker: ({
            required MicroMentor mentor,
            required String userPrompt,
            required String systemPrompt,
            required Map<String, dynamic> context,
          }) {
            started.add(mentor.id);
            return completions[mentor.id]!.future;
          },
        );

        final pending = generator.generate(
          mentors: <MicroMentor>[
            _mentor(id: 'mentor-1', name: '健康コーチ'),
            _mentor(id: 'mentor-2', name: '学習コーチ'),
          ],
          focus: '来週の予定を整える',
        );
        await Future<void>.delayed(Duration.zero);

        expect(started, containsAll(<String>['mentor-1', 'mentor-2']));
        completions['mentor-1']!.complete(_proposalPayload('散歩を予定する'));
        completions['mentor-2']!.complete(_proposalPayload('復習を予定する'));

        final result = await pending;
        expect(result.proposals, hasLength(2));
        expect(result.failedMentorCount, 0);
        expect(
          result.proposals.map((proposal) => proposal.mentorId),
          containsAll(<String>['mentor-1', 'mentor-2']),
        );
      },
    );

    test('limits concurrent mentor requests', () async {
      final completions = List<Completer<Map<String, dynamic>>>.generate(
        6,
        (_) => Completer<Map<String, dynamic>>(),
      );
      final started = <int>[];
      final generator = MicroMentorProposalGenerator(
        maxConcurrentMentors: 2,
        invoker: ({
          required MicroMentor mentor,
          required String userPrompt,
          required String systemPrompt,
          required Map<String, dynamic> context,
        }) {
          final index = int.parse(mentor.id.replaceFirst('mentor-', ''));
          started.add(index);
          return completions[index].future;
        },
      );

      final pending = generator.generate(
        mentors: List<MicroMentor>.generate(
          6,
          (index) => _mentor(id: 'mentor-$index', name: 'コーチ$index'),
        ),
        focus: '今週の優先順位を決める',
      );
      await Future<void>.delayed(Duration.zero);

      expect(started, <int>[0, 1]);
      for (var batchStart = 0; batchStart < 6; batchStart += 2) {
        completions[batchStart].complete(_proposalPayload('提案$batchStart'));
        completions[batchStart + 1]
            .complete(_proposalPayload('提案${batchStart + 1}'));
        await Future<void>.delayed(Duration.zero);
        expect(started.length, <int>[4, 6, 6][batchStart ~/ 2]);
      }

      final result = await pending;
      expect(result.proposals, hasLength(6));
      expect(result.failedMentorCount, 0);
    });

    test('drops scheduled_for from generated task proposals', () async {
      final generator = MicroMentorProposalGenerator(
        invoker: ({
          required MicroMentor mentor,
          required String userPrompt,
          required String systemPrompt,
          required Map<String, dynamic> context,
        }) async {
          return <String, dynamic>{
            ..._proposalPayload('15分だけ着手する'),
            'scheduled_for': '2026-08-24T09:00:00Z',
          };
        },
      );

      final result = await generator.generate(
        mentors: <MicroMentor>[_mentor(id: 'mentor-1', name: '仕事コーチ')],
        focus: '先延ばしを減らす',
      );

      expect(result.proposals.single.type, MicroMentorProposalType.task);
      expect(result.proposals.single.scheduledFor, isNull);
    });

    test('rejects an oversized focus before invoking mentors', () async {
      var invoked = false;
      final generator = MicroMentorProposalGenerator(
        invoker: ({
          required MicroMentor mentor,
          required String userPrompt,
          required String systemPrompt,
          required Map<String, dynamic> context,
        }) async {
          invoked = true;
          return _proposalPayload('提案');
        },
      );

      await expectLater(
        generator.generate(
          mentors: <MicroMentor>[_mentor(id: 'mentor-1', name: '仕事コーチ')],
          focus: List<String>.filled(
            microMentorFocusMaxLength + 1,
            '長',
          ).join(),
        ),
        throwsA(isA<MicroMentorGenerationException>()),
      );
      expect(invoked, isFalse);
    });

    test('injects each saved prompt config into the LLM request', () async {
      String? capturedSystemPrompt;
      Map<String, dynamic>? capturedContext;
      final generator = MicroMentorProposalGenerator(
        invoker: ({
          required MicroMentor mentor,
          required String userPrompt,
          required String systemPrompt,
          required Map<String, dynamic> context,
        }) async {
          capturedSystemPrompt = systemPrompt;
          capturedContext = context;
          return _proposalPayload('15分だけ着手する');
        },
      );

      await generator.generate(
        mentors: <MicroMentor>[_mentor(id: 'mentor-1', name: '仕事コーチ')],
        focus: '先延ばしを減らす',
      );

      expect(capturedSystemPrompt, contains('仕事コーチ'));
      expect(capturedSystemPrompt, contains('穏やか'));
      expect(capturedSystemPrompt, contains('継続'));
      expect(capturedContext?['decision_policy'], 'proposal_only_user_decides');
    });

    test('keeps successful proposals when one mentor fails', () async {
      final generator = MicroMentorProposalGenerator(
        invoker: ({
          required MicroMentor mentor,
          required String userPrompt,
          required String systemPrompt,
          required Map<String, dynamic> context,
        }) async {
          if (mentor.id == 'mentor-2') throw StateError('provider timeout');
          return _proposalPayload('短い振り返りを行う');
        },
      );

      final result = await generator.generate(
        mentors: <MicroMentor>[
          _mentor(id: 'mentor-1', name: '健康コーチ'),
          _mentor(id: 'mentor-2', name: '学習コーチ'),
        ],
        focus: '今日を振り返る',
      );

      expect(result.proposals, hasLength(1));
      expect(result.failedMentorCount, 1);
    });
  });
}

MicroMentor _mentor({required String id, required String name}) {
  return MicroMentor(
    id: id,
    userId: 'user-1',
    slug: id,
    name: name,
    domain: '生活',
    role: '小さく実行できる提案を作る',
    tone: '穏やか',
    values: const <String>['継続', '自律'],
    enabled: true,
    createdAt: DateTime.utc(2026, 7, 22),
    updatedAt: DateTime.utc(2026, 7, 22),
  );
}

Map<String, dynamic> _proposalPayload(String title) {
  return <String, dynamic>{
    'proposal_type': 'task',
    'title': title,
    'description': '$titleための具体的な一歩',
    'rationale': '小さく始めると継続しやすいため',
    'scheduled_for': null,
  };
}
