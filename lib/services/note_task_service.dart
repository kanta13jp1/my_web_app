import 'package:supabase_flutter/supabase_flutter.dart';

const String _noteTaskColumns =
    'id,note_id,user_id,title,status,in_note,task_flag,sort_weight,'
    'note_level_id,task_group_note_level_id,due_at,due_date_ui_option,'
    'time_zone,recurrence,repeat_after_completion,status_updated_at,'
    'creator,last_editor,source_created_at,source_updated_at,source_system,'
    'source_key,created_at,updated_at';

const String _noteTaskReminderColumns =
    'id,task_id,note_id,user_id,note_level_id,remind_at,'
    'reminder_date_ui_option,time_zone,due_date_offset,status,'
    'source_created_at,source_updated_at,source_system,source_key,'
    'created_at,updated_at';

class NoteTaskReminder {
  const NoteTaskReminder({
    required this.id,
    required this.taskId,
    required this.noteId,
    required this.noteLevelId,
    required this.sourceSystem,
    this.remindAt,
    this.reminderDateUiOption,
    this.timeZone,
    this.dueDateOffset,
    this.status,
  });

  final String id;
  final String taskId;
  final int noteId;
  final String noteLevelId;
  final DateTime? remindAt;
  final String? reminderDateUiOption;
  final String? timeZone;
  final int? dueDateOffset;
  final String? status;
  final String sourceSystem;

  bool get isImported => sourceSystem == 'evernote';

  factory NoteTaskReminder.fromJson(Map<String, dynamic> json) {
    return NoteTaskReminder(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      noteId: _asInt(json['note_id']),
      noteLevelId: json['note_level_id']?.toString() ?? '',
      remindAt: _asOptionalDateTime(json['remind_at']),
      reminderDateUiOption: _emptyToNull(json['reminder_date_ui_option']),
      timeZone: _emptyToNull(json['time_zone']),
      dueDateOffset: _asOptionalInt(json['due_date_offset']),
      status: _emptyToNull(json['status']),
      sourceSystem: json['source_system']?.toString() ?? 'native',
    );
  }
}

class NoteTask {
  const NoteTask({
    required this.id,
    required this.noteId,
    required this.title,
    required this.status,
    required this.inNote,
    required this.taskFlag,
    required this.sortWeight,
    required this.noteLevelId,
    required this.taskGroupNoteLevelId,
    required this.sourceSystem,
    required this.reminders,
    this.dueAt,
    this.dueDateUiOption,
    this.timeZone,
    this.recurrence,
    this.repeatAfterCompletion,
    this.statusUpdatedAt,
    this.creator,
    this.lastEditor,
  });

  final String id;
  final int noteId;
  final String title;
  final String status;
  final bool inNote;
  final String taskFlag;
  final String sortWeight;
  final String noteLevelId;
  final String taskGroupNoteLevelId;
  final DateTime? dueAt;
  final String? dueDateUiOption;
  final String? timeZone;
  final String? recurrence;
  final bool? repeatAfterCompletion;
  final DateTime? statusUpdatedAt;
  final String? creator;
  final String? lastEditor;
  final String sourceSystem;
  final List<NoteTaskReminder> reminders;

  bool get isCompleted => status == 'completed';
  bool get isImported => sourceSystem == 'evernote';

  factory NoteTask.fromJson(
    Map<String, dynamic> json, {
    List<NoteTaskReminder> reminders = const <NoteTaskReminder>[],
  }) {
    return NoteTask(
      id: json['id']?.toString() ?? '',
      noteId: _asInt(json['note_id']),
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      inNote: json['in_note'] != false,
      taskFlag: json['task_flag']?.toString() ?? 'false',
      sortWeight: json['sort_weight']?.toString() ?? '0',
      noteLevelId: json['note_level_id']?.toString() ?? '',
      taskGroupNoteLevelId: json['task_group_note_level_id']?.toString() ?? '',
      dueAt: _asOptionalDateTime(json['due_at']),
      dueDateUiOption: _emptyToNull(json['due_date_ui_option']),
      timeZone: _emptyToNull(json['time_zone']),
      recurrence: _emptyToNull(json['recurrence']),
      repeatAfterCompletion: json['repeat_after_completion'] as bool?,
      statusUpdatedAt: _asOptionalDateTime(json['status_updated_at']),
      creator: _emptyToNull(json['creator']),
      lastEditor: _emptyToNull(json['last_editor']),
      sourceSystem: json['source_system']?.toString() ?? 'native',
      reminders: List<NoteTaskReminder>.unmodifiable(reminders),
    );
  }
}

class NoteTaskDraft {
  const NoteTaskDraft({
    required this.title,
    this.dueAt,
    this.recurrence,
    this.repeatAfterCompletion = false,
  });

  final String title;
  final DateTime? dueAt;
  final String? recurrence;
  final bool repeatAfterCompletion;
}

abstract class NoteTaskRepository {
  Future<List<NoteTask>> loadTasks({required int noteId});

  Future<void> createTask({
    required int noteId,
    required NoteTaskDraft draft,
  });

  Future<void> updateTask({
    required NoteTask task,
    required NoteTaskDraft draft,
  });

  Future<void> setCompleted({
    required NoteTask task,
    required bool completed,
  });

  Future<void> deleteTask(NoteTask task);

  Future<void> addReminder({
    required NoteTask task,
    required DateTime remindAt,
  });

  Future<void> deleteReminder(NoteTaskReminder reminder);
}

class SupabaseNoteTaskRepository implements NoteTaskRepository {
  SupabaseNoteTaskRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NoteTask>> loadTasks({required int noteId}) async {
    final taskRows = await _client
        .from('note_tasks')
        .select(_noteTaskColumns)
        .eq('note_id', noteId)
        .order('sort_weight');
    final reminderRows = await _client
        .from('note_task_reminders')
        .select(_noteTaskReminderColumns)
        .eq('note_id', noteId)
        .order('remind_at');

    final remindersByTask = <String, List<NoteTaskReminder>>{};
    for (final row in reminderRows) {
      final reminder = NoteTaskReminder.fromJson(
        Map<String, dynamic>.from(row),
      );
      remindersByTask
          .putIfAbsent(reminder.taskId, () => <NoteTaskReminder>[])
          .add(reminder);
    }

    return taskRows.map(
      (row) {
        final json = Map<String, dynamic>.from(row);
        final id = json['id']?.toString() ?? '';
        return NoteTask.fromJson(
          json,
          reminders: remindersByTask[id] ?? const <NoteTaskReminder>[],
        );
      },
    ).toList(growable: false);
  }

  @override
  Future<void> createTask({
    required int noteId,
    required NoteTaskDraft draft,
  }) async {
    final user = _requireUser();
    final title = _validatedTitle(draft.title);
    final now = DateTime.now().toUtc();
    final sourceKey = 'native-$noteId-${now.microsecondsSinceEpoch.toString()}';
    await _client.from('note_tasks').insert(<String, dynamic>{
      'note_id': noteId,
      'user_id': user.id,
      'title': title,
      'status': 'open',
      'in_note': true,
      'task_flag': 'false',
      'sort_weight': now.microsecondsSinceEpoch.toString(),
      'note_level_id': sourceKey,
      'task_group_note_level_id': 'native-note-$noteId',
      'due_at': draft.dueAt?.toUtc().toIso8601String(),
      'due_date_ui_option': draft.dueAt == null ? null : 'date_time',
      'time_zone': draft.dueAt?.timeZoneName,
      'recurrence': _normalizedRecurrence(draft.recurrence),
      'repeat_after_completion': draft.repeatAfterCompletion,
      'source_created_at': now.toIso8601String(),
      'source_updated_at': now.toIso8601String(),
      'source_system': 'native',
      'updated_at': now.toIso8601String(),
    });
  }

  @override
  Future<void> updateTask({
    required NoteTask task,
    required NoteTaskDraft draft,
  }) async {
    final title = _validatedTitle(draft.title);
    await _client
        .from('note_tasks')
        .update(<String, dynamic>{
          'title': title,
          'due_at': draft.dueAt?.toUtc().toIso8601String(),
          'due_date_ui_option': draft.dueAt == null ? null : 'date_time',
          'time_zone': draft.dueAt?.timeZoneName,
          'recurrence': _normalizedRecurrence(draft.recurrence),
          'repeat_after_completion': draft.repeatAfterCompletion,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', task.id)
        .eq('note_id', task.noteId);
  }

  @override
  Future<void> setCompleted({
    required NoteTask task,
    required bool completed,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('note_tasks')
        .update(<String, dynamic>{
          'status': completed ? 'completed' : 'open',
          'status_updated_at': now,
          'updated_at': now,
        })
        .eq('id', task.id)
        .eq('note_id', task.noteId);
  }

  @override
  Future<void> deleteTask(NoteTask task) async {
    if (task.isImported) {
      throw StateError(
        'Imported Evernote Tasks remain protected until source deletion '
        'is recorded.',
      );
    }
    await _client
        .from('note_tasks')
        .delete()
        .eq('id', task.id)
        .eq('note_id', task.noteId);
  }

  @override
  Future<void> addReminder({
    required NoteTask task,
    required DateTime remindAt,
  }) async {
    final user = _requireUser();
    final now = DateTime.now().toUtc();
    final sourceKey =
        'native-reminder-${task.noteId}-${now.microsecondsSinceEpoch}';
    await _client.from('note_task_reminders').insert(<String, dynamic>{
      'task_id': task.id,
      'note_id': task.noteId,
      'user_id': user.id,
      'note_level_id': sourceKey,
      'remind_at': remindAt.toUtc().toIso8601String(),
      'reminder_date_ui_option': 'date_time',
      'time_zone': remindAt.timeZoneName,
      'status': 'active',
      'source_created_at': now.toIso8601String(),
      'source_updated_at': now.toIso8601String(),
      'source_system': 'native',
      'updated_at': now.toIso8601String(),
    });
  }

  @override
  Future<void> deleteReminder(NoteTaskReminder reminder) async {
    if (reminder.isImported) {
      throw StateError(
        'Imported Evernote reminders remain protected until source deletion '
        'is recorded.',
      );
    }
    await _client
        .from('note_task_reminders')
        .delete()
        .eq('id', reminder.id)
        .eq('note_id', reminder.noteId);
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before changing note Tasks.');
    }
    return user;
  }

  String _validatedTitle(String title) {
    final value = title.trim();
    if (value.isEmpty || value.length > 4096) {
      throw ArgumentError.value(
        title,
        'title',
        'Task title must contain 1 to 4096 characters.',
      );
    }
    return value;
  }

  String? _normalizedRecurrence(String? recurrence) {
    final value = recurrence?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asOptionalInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

DateTime? _asOptionalDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toUtc();
}

String? _emptyToNull(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
