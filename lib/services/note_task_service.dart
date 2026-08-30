import 'package:supabase_flutter/supabase_flutter.dart';

const String _noteTaskColumns =
    'id,note_id,user_id,title,status,in_note,task_flag,sort_weight,'
    'note_level_id,task_group_note_level_id,due_at,due_date_ui_option,'
    'time_zone,recurrence,repeat_after_completion,status_updated_at,'
    'creator,last_editor,source_created_at,source_updated_at,source_system,'
    'source_key,assignee_user_id,assignee_email,assignee_display_name,'
    'source_assignee,created_at,updated_at';

const String _noteTaskReminderColumns =
    'id,task_id,note_id,user_id,note_level_id,remind_at,'
    'reminder_date_ui_option,time_zone,due_date_offset,status,'
    'source_created_at,source_updated_at,source_system,source_key,'
    'created_at,updated_at';

const String _noteFeatureNotificationColumns =
    'id,user_id,owner_user_id,note_id,task_id,task_reminder_id,'
    'note_reminder_id,kind,title,message,notify_at,read_at,dismissed_at,'
    'cancelled_at,source_key,created_at,updated_at';

enum NoteFeatureNotificationKind {
  taskAssigned,
  taskReminder,
  noteReminder,
}

class NoteFeatureNotification {
  const NoteFeatureNotification({
    required this.id,
    required this.noteId,
    required this.kind,
    required this.title,
    required this.message,
    required this.sourceKey,
    required this.createdAt,
    this.taskId,
    this.notifyAt,
    this.readAt,
    this.noteTitle,
  });

  final String id;
  final int noteId;
  final String? taskId;
  final NoteFeatureNotificationKind kind;
  final String title;
  final String message;
  final DateTime? notifyAt;
  final DateTime? readAt;
  final String sourceKey;
  final DateTime createdAt;
  final String? noteTitle;

  bool get isRead => readAt != null;
  bool get isReminder => kind != NoteFeatureNotificationKind.taskAssigned;
  bool get canOpenNote => noteTitle != null;

  factory NoteFeatureNotification.fromJson(Map<String, dynamic> json) {
    return NoteFeatureNotification(
      id: json['id']?.toString() ?? '',
      noteId: _asInt(json['note_id']),
      taskId: _emptyToNull(json['task_id']),
      kind: switch (json['kind']?.toString()) {
        'task_assigned' => NoteFeatureNotificationKind.taskAssigned,
        'task_reminder' => NoteFeatureNotificationKind.taskReminder,
        'note_reminder' => NoteFeatureNotificationKind.noteReminder,
        _ => throw FormatException(
            'Unsupported note notification kind: ${json['kind']}',
          ),
      },
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notifyAt: _asOptionalDateTime(json['notify_at']),
      readAt: _asOptionalDateTime(json['read_at']),
      sourceKey: json['source_key']?.toString() ?? '',
      createdAt: _asOptionalDateTime(json['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      noteTitle: _emptyToNull(json['note_title']),
    );
  }
}

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
    this.noteTitle,
    this.dueAt,
    this.dueDateUiOption,
    this.timeZone,
    this.recurrence,
    this.repeatAfterCompletion,
    this.statusUpdatedAt,
    this.creator,
    this.lastEditor,
    this.ownerUserId = '',
    this.isOwnedByCurrentUser = true,
    this.assigneeUserId,
    this.assigneeEmail,
    this.assigneeDisplayName,
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
  final String ownerUserId;
  final bool isOwnedByCurrentUser;
  final String? assigneeUserId;
  final String? assigneeEmail;
  final String? assigneeDisplayName;
  final String sourceSystem;
  final List<NoteTaskReminder> reminders;
  final String? noteTitle;

  bool get isCompleted => status == 'completed';
  bool get isImported => sourceSystem == 'evernote';
  bool get hasAssignee =>
      assigneeUserId != null ||
      assigneeEmail != null ||
      assigneeDisplayName != null;
  String? get assigneeLabel =>
      assigneeDisplayName ?? assigneeEmail ?? assigneeUserId;

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
      ownerUserId: json['user_id']?.toString() ?? '',
      isOwnedByCurrentUser: json['current_user_id'] == null ||
          json['user_id']?.toString() == json['current_user_id']?.toString(),
      assigneeUserId: _emptyToNull(json['assignee_user_id']),
      assigneeEmail: _emptyToNull(json['assignee_email']),
      assigneeDisplayName: _emptyToNull(json['assignee_display_name']),
      sourceSystem: json['source_system']?.toString() ?? 'native',
      reminders: List<NoteTaskReminder>.unmodifiable(reminders),
      noteTitle: _emptyToNull(json['note_title']),
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

abstract class NoteTaskNotificationRepository {
  Future<List<NoteFeatureNotification>> loadNotifications();

  Future<void> markNotificationRead({
    required NoteFeatureNotification notification,
    required bool read,
  });

  Future<void> dismissNotification(
    NoteFeatureNotification notification,
  );
}

abstract class NoteTaskRepository {
  Future<List<NoteTask>> loadTasks({required int noteId});

  Future<List<NoteTask>> loadAllTasks();

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

  Future<void> assignTask({
    required NoteTask task,
    String? email,
    String? displayName,
  }) {
    throw UnsupportedError('Task assignment is not supported.');
  }

  Future<void> deleteTask(NoteTask task);

  Future<void> addReminder({
    required NoteTask task,
    required DateTime remindAt,
  });

  Future<void> deleteReminder(NoteTaskReminder reminder);
}

class SupabaseNoteTaskRepository
    implements NoteTaskRepository, NoteTaskNotificationRepository {
  SupabaseNoteTaskRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<NoteTask>> loadTasks({required int noteId}) async {
    final taskRows = List<Map<String, dynamic>>.from(
      await _client
          .from('note_tasks')
          .select(_noteTaskColumns)
          .eq('note_id', noteId)
          .order('sort_weight'),
    );
    final reminderRows = List<Map<String, dynamic>>.from(
      await _client
          .from('note_task_reminders')
          .select(_noteTaskReminderColumns)
          .eq('note_id', noteId)
          .order('remind_at'),
    );
    return _buildTasks(taskRows, reminderRows);
  }

  @override
  Future<List<NoteTask>> loadAllTasks() async {
    final taskRows = await _loadPagedRows(
      table: 'note_tasks',
      columns: _noteTaskColumns,
      orderColumn: 'created_at',
    );
    final reminderRows = await _loadPagedRows(
      table: 'note_task_reminders',
      columns: _noteTaskReminderColumns,
      orderColumn: 'created_at',
    );
    final noteTitles = await _loadNoteTitles(
      taskRows.map((row) => _asInt(row['note_id'])).toSet(),
    );
    return _buildTasks(
      taskRows,
      reminderRows,
      noteTitles: noteTitles,
    );
  }

  Future<List<Map<String, dynamic>>> _loadPagedRows({
    required String table,
    required String columns,
    required String orderColumn,
  }) async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final page = List<Map<String, dynamic>>.from(
        await _client
            .from(table)
            .select(columns)
            .order(orderColumn)
            .order('id')
            .range(offset, offset + pageSize - 1),
      );
      rows.addAll(page);
      if (page.length < pageSize) break;
    }
    return rows;
  }

  Future<Map<int, String>> _loadNoteTitles(Set<int> noteIds) async {
    const chunkSize = 200;
    final ids = noteIds.where((id) => id > 0).toList(growable: false);
    final titles = <int, String>{};
    for (var offset = 0; offset < ids.length; offset += chunkSize) {
      final end =
          offset + chunkSize < ids.length ? offset + chunkSize : ids.length;
      final chunk = ids.sublist(offset, end);
      final rows = List<Map<String, dynamic>>.from(
        await _client.from('notes').select('id,title').inFilter('id', chunk),
      );
      for (final row in rows) {
        final id = _asInt(row['id']);
        final title = _emptyToNull(row['title']);
        if (id > 0 && title != null) {
          titles[id] = title;
        }
      }
    }
    return titles;
  }

  List<NoteTask> _buildTasks(
    List<Map<String, dynamic>> taskRows,
    List<Map<String, dynamic>> reminderRows, {
    Map<int, String> noteTitles = const <int, String>{},
  }) {
    final remindersByTask = <String, List<NoteTaskReminder>>{};
    for (final row in reminderRows) {
      final reminder = NoteTaskReminder.fromJson(row);
      remindersByTask
          .putIfAbsent(reminder.taskId, () => <NoteTaskReminder>[])
          .add(reminder);
    }

    return taskRows.map(
      (row) {
        final json = Map<String, dynamic>.from(row);
        final id = json['id']?.toString() ?? '';
        final noteId = _asInt(json['note_id']);
        json['note_title'] = noteTitles[noteId];
        json['current_user_id'] = _client.auth.currentUser?.id;
        return NoteTask.fromJson(
          json,
          reminders: remindersByTask[id] ?? const <NoteTaskReminder>[],
        );
      },
    ).toList(growable: false);
  }

  @override
  Future<List<NoteFeatureNotification>> loadNotifications() async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += pageSize) {
      final page = List<Map<String, dynamic>>.from(
        await _client
            .from('note_feature_notifications')
            .select(_noteFeatureNotificationColumns)
            .isFilter('dismissed_at', null)
            .isFilter('cancelled_at', null)
            .order('created_at', ascending: false)
            .order('id')
            .range(offset, offset + pageSize - 1),
      );
      rows.addAll(page);
      if (page.length < pageSize) break;
    }

    final noteTitles = await _loadNoteTitles(
      rows.map((row) => _asInt(row['note_id'])).toSet(),
    );
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row);
      json['note_title'] = noteTitles[_asInt(row['note_id'])];
      return NoteFeatureNotification.fromJson(json);
    }).toList(growable: false);
  }

  @override
  Future<void> markNotificationRead({
    required NoteFeatureNotification notification,
    required bool read,
  }) async {
    _requireUser();
    await _client.rpc(
      'note_feature_notification_mark_read',
      params: <String, dynamic>{
        'p_notification_id': notification.id,
        'p_read': read,
      },
    );
  }

  @override
  Future<void> dismissNotification(
    NoteFeatureNotification notification,
  ) async {
    _requireUser();
    await _client.rpc(
      'note_feature_notification_dismiss',
      params: <String, dynamic>{
        'p_notification_id': notification.id,
      },
    );
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
    _requireUser();
    await _client.rpc(
      'note_task_set_completion',
      params: <String, dynamic>{
        'p_task_id': task.id,
        'p_completed': completed,
      },
    );
  }

  @override
  Future<void> assignTask({
    required NoteTask task,
    String? email,
    String? displayName,
  }) async {
    _requireUser();
    if (!task.isOwnedByCurrentUser) {
      throw StateError('Only the Task owner can change its assignee.');
    }
    await _client.rpc(
      'note_task_assign',
      params: <String, dynamic>{
        'p_task_id': task.id,
        'p_assignee_email': _emptyToNull(email),
        'p_assignee_display_name': _emptyToNull(displayName),
      },
    );
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
