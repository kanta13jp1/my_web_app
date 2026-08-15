import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/task_budget_assistant_page.dart';
import 'package:my_web_app/services/task_budget_assistant_service.dart';

void main() {
  testWidgets('creates a budgeted assistant job and renders progress', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <Map<String, dynamic>>[];
    final service = TaskBudgetAssistantService(
      invoker: (body) async {
        calls.add(Map<String, dynamic>.from(body));
        switch (body['action']) {
          case 'task_budget_assistant.job.list':
            return {'success': true, 'jobs': []};
          case 'task_budget_assistant.job.create':
            return {
              'success': true,
              'job': {
                'id': 'job-ui',
                'title': body['title'],
                'objective': body['objective'],
                'budget_tokens': body['budget_tokens'],
                'consumed_tokens': 12000,
                'effort': body['effort'],
                'status': 'completed',
                'progress_percent': 100,
                'document_count': 2,
                'summary': 'Aggregated 2 documents and saved artifacts.',
                'artifact': {
                  'folders': ['Finance', 'Specs'],
                  'documents': [
                    {'title': 'Quarter notes'},
                    {'title': 'Spec draft'},
                  ],
                },
              },
              'steps': [
                {
                  'step_index': 1,
                  'title': 'Search documents',
                  'status': 'completed',
                  'input_tokens': 900,
                  'output_tokens': 120,
                  'notes': 'Two sources found.',
                },
              ],
            };
          default:
            throw StateError('Unexpected action ${body['action']}');
        }
      },
    );

    await tester.pumpWidget(
      MaterialApp(home: TaskBudgetAssistantPage(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Task Budget Assistant'), findsOneWidget);
    expect(find.text('Minimum 20,000 tokens'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(1),
      'Summarize and organize the uploaded notes',
    );
    await tester.ensureVisible(
      find.byKey(const Key('task-budget-documents-field')),
    );
    await tester.enterText(
      find.byKey(const Key('task-budget-documents-field')),
      'Quarter notes\nRevenue grew after the launch.\n---\n'
      'Spec draft\nAdd a safe stop dashboard.',
    );
    await tester.ensureVisible(
      find.byKey(const Key('task-budget-create-button')),
    );
    await tester.tap(find.byKey(const Key('task-budget-create-button')));
    await tester.pumpAndSettle();

    final createCall = calls.singleWhere(
      (call) => call['action'] == 'task_budget_assistant.job.create',
    );
    expect(createCall['budget_tokens'], 20000);
    expect(createCall['effort'], 'medium');
    expect(createCall['documents'], hasLength(2));

    expect(find.text('12000/20000'), findsOneWidget);
    expect(
      find.text('Aggregated 2 documents and saved artifacts.'),
      findsOneWidget,
    );
    expect(find.text('Finance'), findsOneWidget);
  });
}
