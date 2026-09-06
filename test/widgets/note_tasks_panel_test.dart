import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_task_service.dart';
import 'package:my_web_app/widgets/note_tasks_panel.dart';

void main() {
  testWidgets('shows imported and native Tasks responsively and toggles status',
      (tester) async {
    final repository = _FakeNoteTaskRepository(
      tasks: <NoteTask>[
        _task(id: 'imported', sourceSystem: 'evernote'),
        _task(id: 'native', title: 'Native task'),
      ],
    );

    await _pumpPanel(tester, repository, width: 390);

    expect(
      find.byKey(const Key('note_tasks_panel_narrow')),
      findsOneWidget,
    );
    expect(find.text('Imported task'), findsOneWidget);
    expect(find.text('Evernote移行'), findsOneWidget);
    expect(find.text('Native task'), findsOneWidget);

    final importedDelete = tester.widget<IconButton>(
      find.byKey(const ValueKey('note_task_delete_imported')),
    );
    expect(importedDelete.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('note_task_checkbox_native')),
    );
    await tester.pumpAndSettle();

    expect(repository.completedTaskIds, <String>['native']);
    expect(find.text('1 / 2 完了'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a Task and renders the wide layout', (tester) async {
    final repository = _FakeNoteTaskRepository(tasks: <NoteTask>[]);

    await _pumpPanel(tester, repository, width: 1000);

    expect(
      find.byKey(const Key('note_tasks_panel_wide')),
      findsOneWidget,
    );
    expect(find.text('このメモにはタスクがありません。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('note_task_add_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_task_title_field')),
      'Added from UI',
    );
    await tester.tap(find.byKey(const Key('note_task_save_button')));
    await tester.pumpAndSettle();

    expect(repository.createdDrafts, hasLength(1));
    expect(repository.createdDrafts.single.title, 'Added from UI');
    expect(find.text('Added from UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assigns a Task by email and shows the assignee', (tester) async {
    final repository = _FakeNoteTaskRepository(
      tasks: <NoteTask>[
        _task(
          id: 'assigned',
          assigneeEmail: 'old@example.com',
          assigneeDisplayName: 'Old reviewer',
        ),
      ],
    );

    await _pumpPanel(tester, repository, width: 900);

    expect(find.text('Old reviewer'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('note_task_assignee_assigned')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_task_assignee_email_field')),
      'new@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('note_task_assignee_name_field')),
      'New reviewer',
    );
    await tester.tap(
      find.byKey(const Key('note_task_assignee_save_button')),
    );
    await tester.pumpAndSettle();

    expect(
      repository.assigneeChanges,
      <(String, String?, String?)>[
        ('assigned', 'new@example.com', 'New reviewer'),
      ],
    );
    expect(find.text('New reviewer'), findsOneWidget);
  });

  testWidgets('deletes a native reminder but preserves imported reminders',
      (tester) async {
    final nativeReminder = _reminder(id: 'native-reminder');
    final importedReminder = _reminder(
      id: 'imported-reminder',
      sourceSystem: 'evernote',
    );
    final repository = _FakeNoteTaskRepository(
      tasks: <NoteTask>[
        _task(
          id: 'native',
          reminders: <NoteTaskReminder>[
            nativeReminder,
            importedReminder,
          ],
        ),
      ],
    );

    await _pumpPanel(tester, repository, width: 900);

    final nativeChip = tester.widget<InputChip>(
      find.byKey(const ValueKey('note_task_reminder_native-reminder')),
    );
    final importedChip = tester.widget<InputChip>(
      find.byKey(const ValueKey('note_task_reminder_imported-reminder')),
    );
    expect(nativeChip.onDeleted, isNotNull);
    expect(importedChip.onDeleted, isNull);

    nativeChip.onDeleted!();
    await tester.pumpAndSettle();

    expect(repository.deletedReminderIds, <String>['native-reminder']);
    expect(
      find.byKey(const ValueKey('note_task_reminder_native-reminder')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeNoteTaskRepository repository, {
  required double width,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoteTasksPanel(noteId: 429, repository: repository),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

NoteTask _task({
  required String id,
  String title = 'Imported task',
  String status = 'open',
  String sourceSystem = 'native',
  List<NoteTaskReminder> reminders = const <NoteTaskReminder>[],
  String? assigneeEmail,
  String? assigneeDisplayName,
}) {
  return NoteTask(
    id: id,
    noteId: 429,
    title: title,
    status: status,
    inNote: true,
    taskFlag: 'false',
    sortWeight: '1',
    noteLevelId: 'level-$id',
    taskGroupNoteLevelId: 'group-429',
    sourceSystem: sourceSystem,
    reminders: reminders,
    dueAt: DateTime.utc(2026, 9, 1, 9),
    recurrence: 'RRULE:FREQ=WEEKLY',
    repeatAfterCompletion: true,
    assigneeEmail: assigneeEmail,
    assigneeDisplayName: assigneeDisplayName,
  );
}

NoteTaskReminder _reminder({
  required String id,
  String sourceSystem = 'native',
}) {
  return NoteTaskReminder(
    id: id,
    taskId: 'native',
    noteId: 429,
    noteLevelId: 'reminder-$id',
    sourceSystem: sourceSystem,
    remindAt: DateTime.utc(2026, 9, 1, 8),
  );
}

class _FakeNoteTaskRepository implements NoteTaskRepository {
  _FakeNoteTaskRepository({required List<NoteTask> tasks})
      : _tasks = List<NoteTask>.from(tasks);

  final List<NoteTask> _tasks;
  final List<String> completedTaskIds = <String>[];
  final List<NoteTaskDraft> createdDrafts = <NoteTaskDraft>[];
  final List<String> deletedReminderIds = <String>[];
  final List<(String, String?, String?)> assigneeChanges =
      <(String, String?, String?)>[];

  @override
  Future<List<NoteTask>> loadAllTasks() async {
    return List<NoteTask>.unmodifiable(_tasks);
  }

  @override
  Future<List<NoteTask>> loadTasks({required int noteId}) async {
    return List<NoteTask>.unmodifiable(_tasks);
  }

  @override
  Future<void> createTask({
    required int noteId,
    required NoteTaskDraft draft,
  }) async {
    createdDrafts.add(draft);
    _tasks.add(
      _task(
        id: 'created-${createdDrafts.length}',
        title: draft.title,
      ),
    );
  }

  @override
  Future<void> assignTask({
    required NoteTask task,
    String? email,
    String? displayName,
  }) async {
    assigneeChanges.add((task.id, email, displayName));
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    _tasks[index] = _task(
      id: task.id,
      title: task.title,
      status: task.status,
      sourceSystem: task.sourceSystem,
      reminders: task.reminders,
      assigneeEmail: email,
      assigneeDisplayName: displayName,
    );
  }

  @override
  Future<void> setCompleted({
    required NoteTask task,
    required bool completed,
  }) async {
    completedTaskIds.add(task.id);
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    _tasks[index] = _task(
      id: task.id,
      title: task.title,
      status: completed ? 'completed' : 'open',
      sourceSystem: task.sourceSystem,
      reminders: task.reminders,
    );
  }

  @override
  Future<void> updateTask({
    required NoteTask task,
    required NoteTaskDraft draft,
  }) async {
    final index = _tasks.indexWhere((candidate) => candidate.id == task.id);
    _tasks[index] = _task(
      id: task.id,
      title: draft.title,
      status: task.status,
      sourceSystem: task.sourceSystem,
      reminders: task.reminders,
    );
  }

  @override
  Future<void> deleteTask(NoteTask task) async {
    _tasks.removeWhere((candidate) => candidate.id == task.id);
  }

  @override
  Future<void> addReminder({
    required NoteTask task,
    required DateTime remindAt,
  }) async {}

  @override
  Future<void> deleteReminder(NoteTaskReminder reminder) async {
    deletedReminderIds.add(reminder.id);
    final index = _tasks.indexWhere(
      (task) => task.reminders.any((item) => item.id == reminder.id),
    );
    final task = _tasks[index];
    _tasks[index] = _task(
      id: task.id,
      title: task.title,
      status: task.status,
      sourceSystem: task.sourceSystem,
      reminders: task.reminders
          .where((item) => item.id != reminder.id)
          .toList(growable: false),
    );
  }
}
