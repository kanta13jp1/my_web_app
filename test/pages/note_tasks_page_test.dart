import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_tasks_page.dart';
import 'package:my_web_app/services/note_task_service.dart';

void main() {
  testWidgets(
      'shows open Evernote Tasks and filters completed on narrow screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeNoteTaskRepository(<NoteTask>[
      _task(
        id: 'open-imported',
        title: '税務資料を確認',
        noteId: 11,
        noteTitle: '経理ノート',
        sourceSystem: 'evernote',
        dueAt: DateTime.now().add(const Duration(days: 2)),
      ),
      _task(
        id: 'completed',
        title: '完了済みタスク',
        noteId: 12,
        noteTitle: '完了ノート',
        status: 'completed',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NoteTasksPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_tasks_page_narrow')), findsOneWidget);
    expect(find.text('税務資料を確認'), findsOneWidget);
    expect(find.text('経理ノート'), findsOneWidget);
    expect(find.text('Evernote移行'), findsOneWidget);
    expect(find.text('完了済みタスク'), findsNothing);
    expect(find.text('未完了 1'), findsOneWidget);
    expect(find.text('完了 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('note_tasks_filter_completed')),
    );
    await tester.pumpAndSettle();

    expect(find.text('完了済みタスク'), findsOneWidget);
    expect(find.text('税務資料を確認'), findsNothing);
  });

  testWidgets(
      'searches by note title and opens the source note on wide screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeNoteTaskRepository(<NoteTask>[
      _task(
        id: 'alpha',
        title: 'Alpha task',
        noteId: 21,
        noteTitle: 'Project Alpha',
      ),
      _task(
        id: 'beta',
        title: 'Beta task',
        noteId: 22,
        noteTitle: 'Project Beta',
      ),
    ]);
    int? openedNoteId;

    await tester.pumpWidget(
      MaterialApp(
        home: NoteTasksPage(
          repository: repository,
          onOpenNote: (noteId) {
            openedNoteId = noteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_tasks_page_wide')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('note_tasks_page_search')),
      'Project Beta',
    );
    await tester.pump();

    expect(find.text('Beta task'), findsOneWidget);
    expect(find.text('Alpha task'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('note_tasks_page_open_note_beta')),
    );
    await tester.pump();

    expect(openedNoteId, 22);
  });

  testWidgets('completes a Task and removes it from the open filter',
      (tester) async {
    final repository = _FakeNoteTaskRepository(<NoteTask>[
      _task(
        id: 'toggle',
        title: '完了にする',
        noteId: 31,
        noteTitle: '操作ノート',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NoteTasksPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('note_tasks_page_checkbox_toggle')),
    );
    await tester.pumpAndSettle();

    expect(repository.completedChanges, <(String, bool)>[('toggle', true)]);
    expect(find.text('完了にする'), findsNothing);
    expect(find.text('未完了のタスクはありません。'), findsOneWidget);
  });

  testWidgets('searches assignees and protects an unshared source note',
      (tester) async {
    final repository = _FakeNoteTaskRepository(<NoteTask>[
      _task(
        id: 'shared',
        title: 'Review the draft',
        noteId: 51,
        noteTitle: null,
        isOwnedByCurrentUser: false,
        assigneeEmail: 'delegate@example.com',
        assigneeDisplayName: 'Delegated reviewer',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NoteTasksPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('note_tasks_page_search')),
      'Delegated reviewer',
    );
    await tester.pump();

    expect(find.text('Review the draft'), findsOneWidget);
    expect(find.text('共有タスク（メモ本文は非公開）'), findsOneWidget);
    final openButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('note_tasks_page_open_note_shared')),
    );
    expect(openButton.onPressed, isNull);
  });

  testWidgets(
      'shows assignment and reminder inbox without exposing an unshared note',
      (tester) async {
    final repository = _FakeNoteTaskRepository(
      const <NoteTask>[],
      notifications: <NoteFeatureNotification>[
        _notification(
          id: 'assigned',
          kind: NoteFeatureNotificationKind.taskAssigned,
          title: 'タスクが割り当てられました',
          message: 'Review the private draft',
          noteId: 61,
        ),
        _notification(
          id: 'note-reminder',
          kind: NoteFeatureNotificationKind.noteReminder,
          title: 'ノートリマインダー',
          message: '公開可能な自分のメモ',
          noteId: 62,
          noteTitle: '公開可能な自分のメモ',
          notifyAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ],
    );
    int? openedNoteId;

    await tester.pumpWidget(
      MaterialApp(
        home: NoteTasksPage(
          repository: repository,
          onOpenNote: (noteId) {
            openedNoteId = noteId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('通知 2'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('note_tasks_notification_unread_count')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('note_tasks_notification_inbox')),
      findsOneWidget,
    );
    expect(find.text('Review the private draft'), findsOneWidget);
    expect(find.text('元のメモは共有されていません'), findsOneWidget);

    final privateOpen = tester.widget<IconButton>(
      find.byKey(
        const ValueKey('note_feature_notification_open_assigned'),
      ),
    );
    expect(privateOpen.onPressed, isNull);

    await tester.tap(
      find.byKey(
        const ValueKey('note_feature_notification_read_assigned'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.readChanges, <(String, bool)>[('assigned', true)]);
    expect(find.text('通知 1'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('note_feature_notification_open_note-reminder'),
      ),
    );
    await tester.pump();
    expect(openedNoteId, 62);
  });

  testWidgets('dismisses a reminder from the inbox', (tester) async {
    final repository = _FakeNoteTaskRepository(
      const <NoteTask>[],
      notifications: <NoteFeatureNotification>[
        _notification(
          id: 'dismiss-me',
          kind: NoteFeatureNotificationKind.taskReminder,
          title: 'タスクリマインダー',
          message: '提出',
          noteId: 71,
          notifyAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteTasksPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('note_tasks_notification_unread_count')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('note_feature_notification_dismiss_dismiss-me'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.dismissedIds, <String>['dismiss-me']);
    expect(find.text('通知はありません。'), findsOneWidget);
  });

  testWidgets('isolates overdue Tasks from future and undated Tasks',
      (tester) async {
    final repository = _FakeNoteTaskRepository(<NoteTask>[
      _task(
        id: 'overdue',
        title: '期限切れ',
        noteId: 41,
        noteTitle: '期限ノート',
        dueAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      _task(
        id: 'future',
        title: '今後',
        noteId: 42,
        noteTitle: '未来ノート',
        dueAt: DateTime.now().add(const Duration(days: 3)),
      ),
      _task(
        id: 'undated',
        title: '期限なし',
        noteId: 43,
        noteTitle: '未設定ノート',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(home: NoteTasksPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('note_tasks_filter_overdue')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('note_tasks_page_card_overdue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note_tasks_page_card_future')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note_tasks_page_card_undated')),
      findsNothing,
    );
  });
}

class _FakeNoteTaskRepository
    implements NoteTaskRepository, NoteTaskNotificationRepository {
  _FakeNoteTaskRepository(
    List<NoteTask> tasks, {
    List<NoteFeatureNotification> notifications =
        const <NoteFeatureNotification>[],
  })  : _tasks = List<NoteTask>.from(tasks),
        _notifications = List<NoteFeatureNotification>.from(notifications);

  List<NoteTask> _tasks;
  List<NoteFeatureNotification> _notifications;
  final List<(String, bool)> completedChanges = <(String, bool)>[];
  final List<(String, bool)> readChanges = <(String, bool)>[];
  final List<String> dismissedIds = <String>[];

  @override
  Future<List<NoteTask>> loadAllTasks() async => List<NoteTask>.from(_tasks);

  @override
  Future<List<NoteTask>> loadTasks({required int noteId}) async {
    return _tasks
        .where((task) => task.noteId == noteId)
        .toList(growable: false);
  }

  @override
  Future<List<NoteFeatureNotification>> loadNotifications() async {
    return List<NoteFeatureNotification>.from(_notifications);
  }

  @override
  Future<void> markNotificationRead({
    required NoteFeatureNotification notification,
    required bool read,
  }) async {
    readChanges.add((notification.id, read));
    _notifications = _notifications.map((candidate) {
      if (candidate.id != notification.id) return candidate;
      return _copyNotification(
        candidate,
        readAt: read ? DateTime.now().toUtc() : null,
        clearReadAt: !read,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> dismissNotification(
    NoteFeatureNotification notification,
  ) async {
    dismissedIds.add(notification.id);
    _notifications = _notifications
        .where((candidate) => candidate.id != notification.id)
        .toList(growable: false);
  }

  @override
  Future<void> setCompleted({
    required NoteTask task,
    required bool completed,
  }) async {
    completedChanges.add((task.id, completed));
    _tasks = _tasks.map((candidate) {
      if (candidate.id != task.id) return candidate;
      return NoteTask(
        id: candidate.id,
        noteId: candidate.noteId,
        title: candidate.title,
        status: completed ? 'completed' : 'open',
        inNote: candidate.inNote,
        taskFlag: candidate.taskFlag,
        sortWeight: candidate.sortWeight,
        noteLevelId: candidate.noteLevelId,
        taskGroupNoteLevelId: candidate.taskGroupNoteLevelId,
        sourceSystem: candidate.sourceSystem,
        reminders: candidate.reminders,
        noteTitle: candidate.noteTitle,
        dueAt: candidate.dueAt,
        dueDateUiOption: candidate.dueDateUiOption,
        timeZone: candidate.timeZone,
        recurrence: candidate.recurrence,
        repeatAfterCompletion: candidate.repeatAfterCompletion,
        statusUpdatedAt: candidate.statusUpdatedAt,
        creator: candidate.creator,
        lastEditor: candidate.lastEditor,
        ownerUserId: candidate.ownerUserId,
        isOwnedByCurrentUser: candidate.isOwnedByCurrentUser,
        assigneeUserId: candidate.assigneeUserId,
        assigneeEmail: candidate.assigneeEmail,
        assigneeDisplayName: candidate.assigneeDisplayName,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> assignTask({
    required NoteTask task,
    String? email,
    String? displayName,
  }) async {}

  @override
  Future<void> addReminder({
    required NoteTask task,
    required DateTime remindAt,
  }) async {}

  @override
  Future<void> createTask({
    required int noteId,
    required NoteTaskDraft draft,
  }) async {}

  @override
  Future<void> deleteReminder(NoteTaskReminder reminder) async {}

  @override
  Future<void> deleteTask(NoteTask task) async {}

  @override
  Future<void> updateTask({
    required NoteTask task,
    required NoteTaskDraft draft,
  }) async {}
}

NoteFeatureNotification _notification({
  required String id,
  required NoteFeatureNotificationKind kind,
  required String title,
  required String message,
  required int noteId,
  String? noteTitle,
  DateTime? notifyAt,
}) {
  return NoteFeatureNotification(
    id: id,
    noteId: noteId,
    kind: kind,
    title: title,
    message: message,
    sourceKey: 'source-$id',
    createdAt: DateTime.utc(2026, 8, 31),
    notifyAt: notifyAt?.toUtc(),
    noteTitle: noteTitle,
  );
}

NoteFeatureNotification _copyNotification(
  NoteFeatureNotification notification, {
  DateTime? readAt,
  bool clearReadAt = false,
}) {
  return NoteFeatureNotification(
    id: notification.id,
    noteId: notification.noteId,
    taskId: notification.taskId,
    kind: notification.kind,
    title: notification.title,
    message: notification.message,
    notifyAt: notification.notifyAt,
    readAt: clearReadAt ? null : (readAt ?? notification.readAt),
    sourceKey: notification.sourceKey,
    createdAt: notification.createdAt,
    noteTitle: notification.noteTitle,
  );
}

NoteTask _task({
  required String id,
  required String title,
  required int noteId,
  required String? noteTitle,
  String status = 'open',
  String sourceSystem = 'native',
  DateTime? dueAt,
  bool isOwnedByCurrentUser = true,
  String? assigneeEmail,
  String? assigneeDisplayName,
}) {
  return NoteTask(
    id: id,
    noteId: noteId,
    title: title,
    status: status,
    inNote: true,
    taskFlag: 'false',
    sortWeight: '0',
    noteLevelId: id,
    taskGroupNoteLevelId: 'note-$noteId',
    sourceSystem: sourceSystem,
    reminders: const <NoteTaskReminder>[],
    noteTitle: noteTitle,
    dueAt: dueAt?.toUtc(),
    isOwnedByCurrentUser: isOwnedByCurrentUser,
    assigneeEmail: assigneeEmail,
    assigneeDisplayName: assigneeDisplayName,
  );
}
