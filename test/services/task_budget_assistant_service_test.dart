import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/task_budget_assistant_service.dart';

void main() {
  test('listJobs parses token budget assistant jobs', () async {
    final service = TaskBudgetAssistantService(
      invoker: (body) async {
        expect(body['action'], 'task_budget_assistant.job.list');
        expect(body['limit'], 20);
        return {
          'success': true,
          'jobs': [
            {
              'id': 'job-1',
              'title': 'Inbox run',
              'objective': 'Aggregate files',
              'budget_tokens': 20000,
              'consumed_tokens': 8600,
              'effort': 'medium',
              'status': 'completed',
              'progress_percent': 100,
              'document_count': 2,
              'summary': 'Two documents extracted.',
              'artifact': {
                'folders': ['Finance'],
              },
            },
          ],
        };
      },
    );

    final jobs = await service.listJobs();

    expect(jobs.single.id, 'job-1');
    expect(jobs.single.budgetTokens, 20000);
    expect(jobs.single.consumedTokens, 8600);
    expect(jobs.single.artifact['folders'], ['Finance']);
  });

  test('createJob sends budget, effort, and documents', () async {
    final service = TaskBudgetAssistantService(
      invoker: (body) async {
        expect(body['action'], 'task_budget_assistant.job.create');
        expect(body['title'], 'Folder pass');
        expect(body['objective'], 'Extract and organize project notes');
        expect(body['budget_tokens'], 25000);
        expect(body['effort'], 'xhigh');
        expect(body['documents'], [
          {'title': 'Spec', 'content': 'Build the dashboard.'},
        ]);
        return {
          'success': true,
          'job': {
            'id': 'job-2',
            'title': 'Folder pass',
            'objective': 'Extract and organize project notes',
            'budget_tokens': 25000,
            'consumed_tokens': 23000,
            'effort': 'xhigh',
            'status': 'budget_safed',
            'progress_percent': 92,
            'document_count': 1,
            'summary': 'Safe stop saved current progress.',
            'artifact': {
              'safe_stop': true,
              'documents': [
                {'title': 'Spec'},
              ],
            },
          },
          'steps': [
            {
              'step_index': 1,
              'title': 'Extract Spec',
              'status': 'completed',
              'input_tokens': 1200,
              'output_tokens': 260,
              'notes': 'Captured key points.',
            },
            {
              'step_index': 2,
              'title': 'Safe stop',
              'status': 'budget_safed',
              'input_tokens': 40,
              'output_tokens': 120,
              'notes': 'Budget threshold reached.',
            },
          ],
        };
      },
    );

    final detail = await service.createJob(
      title: 'Folder pass',
      objective: 'Extract and organize project notes',
      budgetTokens: 25000,
      effort: 'xhigh',
      documents: const [
        TaskBudgetAssistantDocument(
          title: 'Spec',
          content: 'Build the dashboard.',
        ),
      ],
    );

    expect(detail.job.stoppedSafely, isTrue);
    expect(detail.steps, hasLength(2));
    expect(detail.steps.last.status, 'budget_safed');
  });
}
