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

  // ── Issue ミラー行 と 素のタイトル行 の collapse (幽霊タスク対策) ──────────
  // 同じ要望が「[Issue #N] タイトル」(起票後 / completed) と「タイトル」
  // (起票前 / pending) の 2 行に分かれ、完了済みの作業が未完了として
  // 二重計上されていた回帰の防止。

  test('mirrored [Issue #N] row collapses with its bare-title row', () {
    final tasks = dedupeWbsTasksForDisplay([
      _task(
        id: 'bare-pending',
        title: '[追加要望] [資産管理] 月次支払不足額の早期アラートと強制対応フロー',
        status: 'pending',
      ),
      _task(
        id: 'issue-completed',
        title: '[Issue #3367] [追加要望] [資産管理] 月次支払不足額の早期アラートと強制対応フロー',
        issueNumber: 3367,
        status: 'completed',
        progress: 100,
      ),
    ]);

    // 1 行に畳まれ、生存するのは Issue 番号を持つ完了行 (= 未完了に数えない)。
    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'issue-completed');
    expect(tasks.single.isEffectivelyCompleted, isTrue);
  });

  test('collapse works regardless of row order', () {
    final tasks = dedupeWbsTasksForDisplay([
      _task(
        id: 'issue-completed',
        title: '[Issue #3367] Shared title',
        issueNumber: 3367,
        status: 'completed',
        progress: 100,
      ),
      _task(id: 'bare-pending', title: 'Shared title', status: 'pending'),
    ]);

    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'issue-completed');
  });

  test('repeated filings of the same request collapse to one row', () {
    // 同一タイトルで別 Issue 番号の重複起票 (例 #2941/#2948/#2955) も 1 行に。
    final tasks = dedupeWbsTasksForDisplay([
      _task(id: 'i-2941', title: '[Issue #2941] 口座間移動タスク管理', issueNumber: 2941),
      _task(id: 'i-2948', title: '[Issue #2948] 口座間移動タスク管理', issueNumber: 2948),
      _task(id: 'i-2955', title: '[Issue #2955] 口座間移動タスク管理', issueNumber: 2955),
    ]);

    expect(tasks, hasLength(1));
  });

  test('different titles stay separate even when both are Issue rows', () {
    final tasks = dedupeWbsTasksForDisplay([
      _task(
        id: 'issue-1',
        title: '[Issue #1962] VSCode sync',
        issueNumber: 1962,
      ),
      _task(
        id: 'issue-2',
        title: '[Issue #2204] Calendar sync',
        issueNumber: 2204,
      ),
    ]);

    expect(tasks.map((task) => task.id), ['issue-1', 'issue-2']);
  });

  test('WBS task owner drag rules allow assignment and unassignment', () {
    final unassigned = _task(
      id: 'unassigned',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'unassigned',
    );
    final codexOwned = _task(
      id: 'codex-owned',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'codex',
    );

    expect(canMoveWbsTaskToOwner(unassigned, 'codex'), isTrue);
    expect(canMoveWbsTaskToOwner(codexOwned, 'unassigned'), isTrue);
    expect(canMoveWbsTaskToOwner(codexOwned, 'codex'), isFalse);
  });

  test('blank owner is treated as unassigned for assignment board', () {
    final task = _task(
      id: 'blank-owner',
      title: '[Issue #2912] Drag assignment',
      instance: 'claude',
    );

    expect(task.activeInstanceKey, 'claude');
    expect(task.activeOwnerKey, 'claude');
    expect(task.assignmentOwnerKey, 'unassigned');
    expect(task.matchesActiveInstanceFilter('unassigned'), isTrue);
    expect(canMoveWbsTaskToOwner(task, 'codex'), isTrue);
  });

  test('assignment board filtering ignores owner instance filter', () {
    final codexTask = _task(
      id: 'codex',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'codex',
      createdAt: DateTime.utc(2026, 6, 10),
    );
    final userTask = _task(
      id: 'user',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'user',
      createdAt: DateTime.utc(2026, 6, 10),
    );

    final tasks = filterWbsTasksForAssignmentBoard(
      [codexTask, userTask],
      hideCompleted: false,
    );

    expect(tasks.map((task) => task.id), ['codex', 'user']);
  });

  test('completed WBS task owner drag is rejected', () {
    final completed = _task(
      id: 'completed',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'codex',
      status: 'completed',
      progress: 100,
    );

    expect(canMoveWbsTaskToOwner(completed, 'user'), isFalse);
    expect(canMoveWbsTaskToOwner(completed, 'unassigned'), isFalse);
  });

  test('WBS owner reassignment stores normalized owner key', () {
    final task = _task(
      id: 'schedule',
      title: '[Issue #2912] Drag assignment',
      ownerInstance: 'schedule',
    );

    final reassigned = reassignWbsTaskOwner(task, 'github-actions');
    final unassigned = reassignWbsTaskOwner(task, 'none');

    expect(reassigned.ownerInstance, 'automation');
    expect(unassigned.ownerInstance, 'unassigned');
    expect(unassigned.activeOwnerLabel, 'Unassigned');
  });
}
