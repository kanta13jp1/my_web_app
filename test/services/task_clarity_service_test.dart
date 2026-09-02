import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/task_clarity_service.dart';

void main() {
  test('offline evaluation asks questions for a vague task', () {
    final evaluation = TaskClarityEvaluation.offline(title: '売上を改善する');

    expect(evaluation.score, lessThanOrEqualTo(evaluation.threshold));
    expect(evaluation.needsClarification, isTrue);
    expect(evaluation.questions, isNotEmpty);
    expect(evaluation.ambiguities, contains('期限が未指定です'));
  });

  test('offline evaluation recognizes a measurable scoped task', () {
    final evaluation = TaskClarityEvaluation.offline(
      title: 'LPの登録率を改善する',
      description: '料金ページの新規ユーザー向けCTAを7月31日までに更新し、登録率を10%増加させる。',
    );

    expect(evaluation.score, greaterThan(evaluation.threshold));
    expect(evaluation.needsClarification, isFalse);
    expect(evaluation.status, 'clear');
  });

  test('service routes evaluation through the authenticated ai-hub action',
      () async {
    final service = TaskClarityService(
      invoker: (body) async {
        expect(body, <String, dynamic>{
          'action': 'task.clarity.evaluate',
          'title': '売上を改善する',
          'description': '',
        });
        return <String, dynamic>{
          'success': true,
          'evaluation': <String, dynamic>{
            'score': 3,
            'threshold': 6,
            'source': 'heuristic',
            'questions': <String>['期限はいつですか？'],
            'ambiguities': <String>['期限が未指定です'],
            'evaluated_at': '2026-08-21T00:00:00Z',
          },
        };
      },
    );

    final evaluation = await service.evaluate(title: ' 売上を改善する ');

    expect(evaluation.needsClarification, isTrue);
    expect(evaluation.questions, <String>['期限はいつですか？']);
  });

  test('fromJson clamps score and derives a consistent status', () {
    final evaluation = TaskClarityEvaluation.fromJson(<String, dynamic>{
      'score': 99,
      'threshold': 0,
      'status': 'needs_clarification',
      'source': 'gemini',
      'questions': <String>['Question'],
      'evaluated_at': '2026-07-20T00:00:00Z',
    });

    expect(evaluation.score, 10);
    expect(evaluation.threshold, 1);
    expect(evaluation.status, 'clear');
  });

  test('fromJson supplies a question whenever a low score needs clarification',
      () {
    final evaluation = TaskClarityEvaluation.fromJson(<String, dynamic>{
      'score': 4,
      'threshold': 6,
      'source': 'gemini',
      'questions': const <String>[],
      'evaluated_at': '2026-07-20T00:00:00Z',
    });

    expect(evaluation.needsClarification, isTrue);
    expect(evaluation.questions, isNotEmpty);
  });

  test('answered questions are stored as clarified metadata', () {
    final evaluation = TaskClarityEvaluation.fromJson(<String, dynamic>{
      'score': 3,
      'threshold': 6,
      'source': 'gemini',
      'questions': <String>['期限は？'],
      'ambiguities': <String>['期限が未指定です'],
      'evaluated_at': '2026-07-20T00:00:00Z',
    });

    final metadata = evaluation.toMetadata(
      answers: const <String, String>{'期限は？': '7月31日'},
      clarifiedAt: DateTime.utc(2026, 7, 20, 1),
    );

    expect(metadata['status'], 'clarified');
    expect(metadata['clarified_at'], '2026-07-20T01:00:00.000Z');
    expect(metadata['answers'], <Map<String, String>>[
      <String, String>{'question': '期限は？', 'answer': '7月31日'},
    ]);
  });
}
