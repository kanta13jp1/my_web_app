import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/project_gantt_page.dart';

WbsTask _task({
  required String id,
  required String title,
  int? issueNumber,
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
    instance: 'codex',
    status: status,
    progress: progress,
    priority: 'medium',
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
}
