import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/agent_task.dart';
import 'package:my_web_app/services/task_clarity_service.dart';
import 'package:my_web_app/widgets/task_clarity_badge.dart';
import 'package:my_web_app/widgets/task_clarity_dialog.dart';

void main() {
  AgentTask buildTask(Map<String, dynamic> clarity) {
    final now = DateTime.utc(2026, 7, 20);
    return AgentTask(
      id: 'task-1',
      userId: 'user-1',
      supervisorAgentId: 'ceo-1',
      assigneeAgentId: 'cmo-1',
      title: 'Improve launch plan',
      description: '',
      status: 'queued',
      priority: 'high',
      taskType: 'delegated_action',
      source: 'manual_delegate',
      createdAt: now,
      updatedAt: now,
      metadata: <String, dynamic>{'clarity': clarity},
    );
  }

  testWidgets('badge visually distinguishes an unclear task', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskClarityBadge(
            task: buildTask(<String, dynamic>{
              'score': 4,
              'threshold': 6,
              'status': 'needs_clarification',
            }),
          ),
        ),
      ),
    );

    expect(find.text('明確さ 4/10・要確認'), findsOneWidget);
    expect(find.byKey(const Key('task_clarity_badge')), findsOneWidget);
  });

  testWidgets('dialog requires every answer and returns question mapping', (
    tester,
  ) async {
    final evaluation = TaskClarityEvaluation.fromJson(<String, dynamic>{
      'score': 3,
      'threshold': 6,
      'source': 'test',
      'questions': <String>['期限は？', '完了条件は？'],
      'evaluated_at': '2026-07-20T00:00:00Z',
    });
    Map<String, String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTaskClarityDialog(
                  context: context,
                  evaluation: evaluation,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('タスクの曖昧さを確認'), findsOneWidget);

    final submit = find.byKey(const Key('task_clarity_submit_button'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('task_clarity_answer_0')),
      '7月31日',
    );
    await tester.enterText(
      find.byKey(const Key('task_clarity_answer_1')),
      '登録率10%増加',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(result, <String, String>{'期限は？': '7月31日', '完了条件は？': '登録率10%増加'});
  });
}
