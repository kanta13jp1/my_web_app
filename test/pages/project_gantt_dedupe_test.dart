import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

WbsTask _task({
  required String id,
  required String title,
  int? issueNumber,
  String instance = 'codex',
  String ownerInstance = '',
  String status = 'in_progress',
  int progress = 0,
  String remainingWork = '',
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return WbsTask(
    id: id,
    category: 'GitHub Issue',
    categoryIcon: 'I',
    categoryOrder: 1,
    title: title,
    description: '',
    instance: instance,
    status: status,
    progress: progress,
    priority: 'medium',
    ownerInstance: ownerInstance,
    remainingWork: remainingWork,
    githubIssueNumber: issueNumber,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

void main() {
  test('duplicate GitHub-origin WBS rows are treated as completed', () {
    final duplicate = _task(
      id: 'duplicate',
      title: '[Issue #1962] VSCode sync',
      issueNumber: 1962,
      remainingWork:
          'Duplicate of WBS task canonical; GitHub Issue #1962 is kept on one canonical WBS row.',
    );

    expect(duplicate.isDuplicateGithubIssueMirror, isTrue);
    expect(duplicate.isEffectivelyCompleted, isTrue);
  });

  test('display dedupe keeps one canonical row per GitHub Issue', () {
    final duplicate = _task(
      id: 'duplicate',
      title: '[Issue #1962] VSCode sync',
      issueNumber: 1962,
      progress: 10,
      remainingWork:
          'Duplicate of WBS task canonical; GitHub Issue #1962 is kept on one canonical WBS row.',
      createdAt: DateTime.utc(2026, 5, 11, 1),
    );
    final canonical = _task(
      id: 'canonical',
      title: '[Issue #1962] VSCode sync',
      issueNumber: 1962,
      progress: 40,
      createdAt: DateTime.utc(2026, 5, 11, 2),
    );

    final tasks = dedupeWbsTasksForDisplay([duplicate, canonical]);

    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'canonical');
  });

  test('display dedupe does not merge different GitHub Issues', () {
    final tasks = dedupeWbsTasksForDisplay([
      _task(id: 'issue-1', title: '[Issue #1962] VSCode sync'),
      _task(id: 'issue-2', title: '[Issue #2204] Calendar sync'),
    ]);

    expect(tasks.map((task) => task.id), ['issue-1', 'issue-2']);
  });

  test('display dedupe keeps one canonical row per duplicate title', () {
    final tasks = dedupeWbsTasksForDisplay([
      _task(
        id: 'automation-copy',
        title: 'SOC 2 Type 1 認証準備',
        instance: 'automation',
        ownerInstance: 'automation',
        progress: 0,
        createdAt: DateTime.utc(2026, 5, 11, 1),
      ),
      _task(
        id: 'codex-copy',
        title: 'SOC 2 Type 1 認証準備',
        instance: 'codex',
        ownerInstance: 'codex',
        progress: 25,
        createdAt: DateTime.utc(2026, 5, 11, 2),
      ),
    ]);

    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'codex-copy');
  });

  test('additional request titles are treated as feature request tasks', () {
    final task = _task(
      id: 'additional-request',
      title: '[\u8ffd\u52a0\u8981\u671b] WBS schedule priority',
    );

    expect(task.isFeatureRequestTask, isTrue);
  });

  test('Issue-linked tasks are detected from explicit issue numbers', () {
    final task = _task(
      id: 'issue-linked',
      title: '[Issue #1559] AI Tool Watch routing',
      issueNumber: 1559,
    );

    expect(task.isGithubIssueLinkedTask, isTrue);
  });
}
