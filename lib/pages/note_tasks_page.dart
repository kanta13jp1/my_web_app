import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/note_task_service.dart';
import '../services/notification_service.dart';
import 'note_editor_page.dart';

enum _NoteTasksSection { tasks, notifications }

enum NoteTaskOverviewFilter {
  open,
  overdue,
  dueToday,
  upcoming,
  completed,
  all,
}

extension on NoteTaskOverviewFilter {
  String get label => switch (this) {
        NoteTaskOverviewFilter.open => '未完了',
        NoteTaskOverviewFilter.overdue => '期限切れ',
        NoteTaskOverviewFilter.dueToday => '今日',
        NoteTaskOverviewFilter.upcoming => '今後',
        NoteTaskOverviewFilter.completed => '完了済み',
        NoteTaskOverviewFilter.all => 'すべて',
      };

  IconData get icon => switch (this) {
        NoteTaskOverviewFilter.open => Icons.radio_button_unchecked,
        NoteTaskOverviewFilter.overdue => Icons.warning_amber_rounded,
        NoteTaskOverviewFilter.dueToday => Icons.today_outlined,
        NoteTaskOverviewFilter.upcoming => Icons.event_outlined,
        NoteTaskOverviewFilter.completed => Icons.task_alt,
        NoteTaskOverviewFilter.all => Icons.list_alt,
      };
}

class NoteTasksPage extends StatefulWidget {
  const NoteTasksPage({
    super.key,
    this.repository,
    this.onOpenNote,
    this.notificationService,
  });

  final NoteTaskRepository? repository;
  final ValueChanged<int>? onOpenNote;
  final NotificationService? notificationService;

  @override
  State<NoteTasksPage> createState() => _NoteTasksPageState();
}

class _NoteTasksPageState extends State<NoteTasksPage> {
  late final NoteTaskRepository _repository;
  late final NoteTaskNotificationRepository? _notificationRepository;
  late final NotificationService _notificationService;
  late final bool _localNotificationSchedulingEnabled;
  final TextEditingController _searchController = TextEditingController();
  List<NoteTask> _tasks = const <NoteTask>[];
  List<NoteFeatureNotification> _notifications =
      const <NoteFeatureNotification>[];
  NoteTaskOverviewFilter _filter = NoteTaskOverviewFilter.open;
  _NoteTasksSection _section = _NoteTasksSection.tasks;
  bool _isLoading = true;
  final Set<String> _mutatingTaskIds = <String>{};
  final Set<String> _mutatingNotificationIds = <String>{};
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        SupabaseNoteTaskRepository(Supabase.instance.client);
    _notificationRepository = _repository is NoteTaskNotificationRepository
        ? _repository as NoteTaskNotificationRepository
        : null;
    _notificationService = widget.notificationService ?? NotificationService();
    _localNotificationSchedulingEnabled =
        widget.repository == null || widget.notificationService != null;
    unawaited(_loadTasks());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final tasksFuture = _repository.loadAllTasks();
      final notificationsFuture =
          _notificationRepository?.loadNotifications() ??
              Future<List<NoteFeatureNotification>>.value(
                const <NoteFeatureNotification>[],
              );
      final tasks = await tasksFuture;
      final notifications = await notificationsFuture;
      tasks.sort(_compareTasks);
      notifications.sort(_compareNotifications);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _notifications = notifications;
        _error = null;
      });
      unawaited(_schedulePendingNotifications(notifications));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted && showLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _compareNotifications(
    NoteFeatureNotification left,
    NoteFeatureNotification right,
  ) {
    if (left.isRead != right.isRead) return left.isRead ? 1 : -1;
    final leftAt = left.notifyAt ?? left.createdAt;
    final rightAt = right.notifyAt ?? right.createdAt;
    return rightAt.compareTo(leftAt);
  }

  Future<void> _schedulePendingNotifications(
    List<NoteFeatureNotification> notifications,
  ) async {
    if (!_localNotificationSchedulingEnabled) return;
    final now = DateTime.now().toUtc();
    for (final notification in notifications) {
      final notifyAt = notification.notifyAt;
      if (!notification.isReminder ||
          notification.isRead ||
          notifyAt == null ||
          !notifyAt.isAfter(now)) {
        continue;
      }
      try {
        await _notificationService.scheduleNoteFeatureReminder(
          sourceKey: notification.sourceKey,
          title: notification.title,
          body: notification.message,
          notifyAt: notifyAt,
        );
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'note_tasks_page',
            context: ErrorDescription(
              'while scheduling a Task or note reminder',
            ),
          ),
        );
      }
    }
  }

  int _compareTasks(NoteTask left, NoteTask right) {
    if (left.isCompleted != right.isCompleted) {
      return left.isCompleted ? 1 : -1;
    }
    final leftDue = left.dueAt;
    final rightDue = right.dueAt;
    if (leftDue == null && rightDue != null) return 1;
    if (leftDue != null && rightDue == null) return -1;
    if (leftDue != null && rightDue != null) {
      final dueOrder = leftDue.compareTo(rightDue);
      if (dueOrder != 0) return dueOrder;
    }
    final noteOrder = (left.noteTitle ?? '').compareTo(right.noteTitle ?? '');
    if (noteOrder != 0) return noteOrder;
    return left.title.compareTo(right.title);
  }

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _tomorrowStart => _todayStart.add(const Duration(days: 1));

  bool _isOverdue(NoteTask task) {
    final due = task.dueAt?.toLocal();
    return !task.isCompleted && due != null && due.isBefore(_todayStart);
  }

  bool _isDueToday(NoteTask task) {
    final due = task.dueAt?.toLocal();
    return !task.isCompleted &&
        due != null &&
        !due.isBefore(_todayStart) &&
        due.isBefore(_tomorrowStart);
  }

  bool _matchesFilter(NoteTask task) {
    return switch (_filter) {
      NoteTaskOverviewFilter.open => !task.isCompleted,
      NoteTaskOverviewFilter.overdue => _isOverdue(task),
      NoteTaskOverviewFilter.dueToday => _isDueToday(task),
      NoteTaskOverviewFilter.upcoming => !task.isCompleted &&
          task.dueAt != null &&
          !task.dueAt!.toLocal().isBefore(_tomorrowStart),
      NoteTaskOverviewFilter.completed => task.isCompleted,
      NoteTaskOverviewFilter.all => true,
    };
  }

  List<NoteTask> get _visibleTasks {
    final query = _searchQuery.trim().toLowerCase();
    return _tasks.where((task) {
      if (!_matchesFilter(task)) return false;
      if (query.isEmpty) return true;
      return task.title.toLowerCase().contains(query) ||
          (task.noteTitle ?? '').toLowerCase().contains(query) ||
          (task.assigneeLabel ?? '').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Future<void> _setCompleted(NoteTask task, bool completed) async {
    if (_mutatingTaskIds.contains(task.id)) return;
    setState(() {
      _mutatingTaskIds.add(task.id);
      _error = null;
    });
    try {
      await _repository.setCompleted(task: task, completed: completed);
      await _loadTasks(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completed ? 'タスクを完了しました' : 'タスクを再開しました'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _mutatingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _markNotificationRead(
    NoteFeatureNotification notification,
    bool read,
  ) async {
    if (_mutatingNotificationIds.contains(notification.id)) return;
    setState(() {
      _mutatingNotificationIds.add(notification.id);
      _error = null;
    });
    try {
      final notificationRepository = _notificationRepository;
      if (notificationRepository == null) return;
      await notificationRepository.markNotificationRead(
        notification: notification,
        read: read,
      );
      await _loadTasks(showLoading: false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _mutatingNotificationIds.remove(notification.id);
        });
      }
    }
  }

  Future<void> _dismissNotification(
    NoteFeatureNotification notification,
  ) async {
    if (_mutatingNotificationIds.contains(notification.id)) return;
    setState(() {
      _mutatingNotificationIds.add(notification.id);
      _error = null;
    });
    try {
      final notificationRepository = _notificationRepository;
      if (notificationRepository == null) return;
      await notificationRepository.dismissNotification(notification);
      if (notification.isReminder && _localNotificationSchedulingEnabled) {
        await _notificationService.cancelNoteFeatureReminder(
          sourceKey: notification.sourceKey,
        );
      }
      await _loadTasks(showLoading: false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _mutatingNotificationIds.remove(notification.id);
        });
      }
    }
  }

  Future<void> _openNotificationNote(
    NoteFeatureNotification notification,
  ) async {
    if (!notification.canOpenNote) return;
    final callback = widget.onOpenNote;
    if (callback != null) {
      callback(notification.noteId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/note-editor'),
        builder: (_) => NoteEditorPage(
          noteId: notification.noteId.toString(),
        ),
      ),
    );
    if (mounted) {
      await _loadTasks(showLoading: false);
    }
  }

  Future<void> _openNote(NoteTask task) async {
    final callback = widget.onOpenNote;
    if (callback != null) {
      callback(task.noteId);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/note-editor'),
        builder: (_) => NoteEditorPage(noteId: task.noteId.toString()),
      ),
    );
    if (mounted) {
      await _loadTasks(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openCount = _tasks.where((task) => !task.isCompleted).length;
    final overdueCount = _tasks.where(_isOverdue).length;
    final todayCount = _tasks.where(_isDueToday).length;
    final completedCount = _tasks.where((task) => task.isCompleted).length;

    return Scaffold(
      key: const Key('note_tasks_page_scaffold'),
      appBar: AppBar(
        title: const Text('ノートタスク'),
        actions: [
          IconButton(
            key: const Key('note_tasks_page_refresh'),
            tooltip: '更新',
            onPressed: _isLoading ? null : _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSectionSelector(),
          const Divider(height: 1),
          Expanded(
            child: _section == _NoteTasksSection.notifications
                ? _buildNotificationContent()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 760;
                      final content = _buildContent(
                        openCount: openCount,
                        overdueCount: overdueCount,
                        todayCount: todayCount,
                        completedCount: completedCount,
                      );
                      if (isNarrow) {
                        return Column(
                          key: const Key('note_tasks_page_narrow'),
                          children: [
                            _buildNarrowFilters(),
                            Expanded(child: content),
                          ],
                        );
                      }
                      return Row(
                        key: const Key('note_tasks_page_wide'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Material(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLowest,
                              child: ListView(
                                padding: const EdgeInsets.all(12),
                                children: [
                                  Text(
                                    '表示',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  for (final filter
                                      in NoteTaskOverviewFilter.values)
                                    ListTile(
                                      key: ValueKey(
                                        'note_tasks_filter_${filter.name}',
                                      ),
                                      selected: _filter == filter,
                                      leading: Icon(filter.icon),
                                      title: Text(filter.label),
                                      onTap: () {
                                        setState(() {
                                          _filter = filter;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(child: content),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    final unreadCount =
        _notifications.where((notification) => !notification.isRead).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SegmentedButton<_NoteTasksSection>(
        key: const Key('note_tasks_page_section_selector'),
        segments: <ButtonSegment<_NoteTasksSection>>[
          const ButtonSegment<_NoteTasksSection>(
            value: _NoteTasksSection.tasks,
            icon: Icon(Icons.task_alt_outlined),
            label: Text('タスク'),
          ),
          ButtonSegment<_NoteTasksSection>(
            value: _NoteTasksSection.notifications,
            icon: const Icon(Icons.notifications_outlined),
            label: Text(
              '通知 $unreadCount',
              key: const Key('note_tasks_notification_unread_count'),
            ),
          ),
        ],
        selected: <_NoteTasksSection>{_section},
        onSelectionChanged: (selection) {
          setState(() {
            _section = selection.single;
          });
        },
      ),
    );
  }

  Widget _buildNotificationContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      key: const Key('note_tasks_notification_inbox'),
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text('通知の読み込みまたは更新に失敗しました: $_error'),
            actions: [
              TextButton(
                onPressed: _loadTasks,
                child: const Text('再試行'),
              ),
            ],
          ),
        if (_mutatingNotificationIds.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _notifications.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: const [
                    Icon(Icons.notifications_none, size: 52),
                    SizedBox(height: 12),
                    Text(
                      '通知はありません。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.separated(
                    key: const Key('note_tasks_notification_list'),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      return _NoteFeatureNotificationCard(
                        notification: notification,
                        busy:
                            _mutatingNotificationIds.contains(notification.id),
                        onReadChanged: (read) {
                          unawaited(
                            _markNotificationRead(notification, read),
                          );
                        },
                        onDismiss: () {
                          unawaited(_dismissNotification(notification));
                        },
                        onOpenNote: notification.canOpenNote
                            ? () {
                                unawaited(
                                  _openNotificationNote(notification),
                                );
                              }
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNarrowFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        children: [
          for (final filter in NoteTaskOverviewFilter.values) ...[
            ChoiceChip(
              key: ValueKey('note_tasks_filter_${filter.name}'),
              avatar: Icon(filter.icon, size: 18),
              label: Text(filter.label),
              selected: _filter == filter,
              onSelected: (_) {
                setState(() {
                  _filter = filter;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildContent({
    required int openCount,
    required int overdueCount,
    required int todayCount,
    required int completedCount,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('note_tasks_page_search'),
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'タスク・メモ名・担当者を検索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('note_tasks_page_search_clear'),
                      tooltip: '検索をクリア',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                key: const Key('note_tasks_open_count'),
                label: '未完了',
                count: openCount,
                icon: Icons.radio_button_unchecked,
              ),
              _SummaryChip(
                key: const Key('note_tasks_overdue_count'),
                label: '期限切れ',
                count: overdueCount,
                icon: Icons.warning_amber_rounded,
              ),
              _SummaryChip(
                key: const Key('note_tasks_today_count'),
                label: '今日',
                count: todayCount,
                icon: Icons.today_outlined,
              ),
              _SummaryChip(
                key: const Key('note_tasks_completed_count'),
                label: '完了',
                count: completedCount,
                icon: Icons.task_alt,
              ),
            ],
          ),
        ),
        if (_mutatingTaskIds.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_error != null)
          MaterialBanner(
            content: Text('タスクの読み込みまたは更新に失敗しました: $_error'),
            actions: [
              TextButton(
                onPressed: _loadTasks,
                child: const Text('再試行'),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Expanded(child: _buildTaskList()),
      ],
    );
  }

  Widget _buildTaskList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tasks = _visibleTasks;
    if (tasks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          const Icon(Icons.task_alt, size: 52),
          const SizedBox(height: 12),
          Text(
            _searchQuery.trim().isNotEmpty
                ? '検索条件に一致するタスクはありません。'
                : '${_filter.label}のタスクはありません。',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.separated(
        key: const Key('note_tasks_page_list'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _TaskOverviewCard(
          task: tasks[index],
          busy: _mutatingTaskIds.contains(tasks[index].id),
          overdue: _isOverdue(tasks[index]),
          dueToday: _isDueToday(tasks[index]),
          onCompletedChanged: (value) {
            unawaited(_setCompleted(tasks[index], value));
          },
          onOpenNote: tasks[index].noteTitle == null &&
                  !tasks[index].isOwnedByCurrentUser
              ? null
              : () {
                  unawaited(_openNote(tasks[index]));
                },
        ),
      ),
    );
  }
}

class _NoteFeatureNotificationCard extends StatelessWidget {
  const _NoteFeatureNotificationCard({
    required this.notification,
    required this.busy,
    required this.onReadChanged,
    required this.onDismiss,
    required this.onOpenNote,
  });

  final NoteFeatureNotification notification;
  final bool busy;
  final ValueChanged<bool> onReadChanged;
  final VoidCallback onDismiss;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final notifyAt = notification.notifyAt?.toLocal();
    final isDue = notifyAt != null && !notifyAt.isAfter(DateTime.now());
    final colorScheme = Theme.of(context).colorScheme;
    final kindLabel = switch (notification.kind) {
      NoteFeatureNotificationKind.taskAssigned => '担当タスク',
      NoteFeatureNotificationKind.taskReminder => 'タスクリマインダー',
      NoteFeatureNotificationKind.noteReminder => 'ノートリマインダー',
    };
    final icon = switch (notification.kind) {
      NoteFeatureNotificationKind.taskAssigned => Icons.assignment_ind_outlined,
      NoteFeatureNotificationKind.taskReminder => Icons.alarm_outlined,
      NoteFeatureNotificationKind.noteReminder =>
        Icons.notifications_active_outlined,
    };

    return Card(
      key: ValueKey('note_feature_notification_${notification.id}'),
      color: notification.isRead
          ? null
          : colorScheme.primaryContainer.withValues(alpha: 0.34),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(notification.message),
                    ],
                  ),
                ),
                if (!notification.isRead)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, right: 8),
                    child: Icon(Icons.circle, size: 10),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: Icon(icon, size: 16),
                  label: Text(kindLabel),
                ),
                if (notifyAt != null)
                  Chip(
                    avatar: Icon(
                      isDue ? Icons.notification_important : Icons.schedule,
                      size: 16,
                    ),
                    label: Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(notifyAt),
                    ),
                  ),
                if (notification.noteTitle != null)
                  Chip(
                    avatar: const Icon(Icons.note_outlined, size: 16),
                    label: Text(notification.noteTitle!),
                  )
                else
                  const Chip(
                    avatar: Icon(Icons.lock_outline, size: 16),
                    label: Text('元のメモは共有されていません'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: ValueKey(
                    'note_feature_notification_read_${notification.id}',
                  ),
                  onPressed:
                      busy ? null : () => onReadChanged(!notification.isRead),
                  icon: Icon(
                    notification.isRead
                        ? Icons.mark_email_unread_outlined
                        : Icons.done,
                  ),
                  label: Text(notification.isRead ? '未読に戻す' : '既読'),
                ),
                IconButton(
                  key: ValueKey(
                    'note_feature_notification_open_${notification.id}',
                  ),
                  tooltip: onOpenNote == null ? '元のメモは共有されていません' : '元のメモを開く',
                  onPressed: busy ? null : onOpenNote,
                  icon: const Icon(Icons.open_in_new),
                ),
                IconButton(
                  key: ValueKey(
                    'note_feature_notification_dismiss_${notification.id}',
                  ),
                  tooltip: '非表示',
                  onPressed: busy ? null : onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label $count'),
    );
  }
}

class _TaskOverviewCard extends StatelessWidget {
  const _TaskOverviewCard({
    required this.task,
    required this.busy,
    required this.overdue,
    required this.dueToday,
    required this.onCompletedChanged,
    required this.onOpenNote,
  });

  final NoteTask task;
  final bool busy;
  final bool overdue;
  final bool dueToday;
  final ValueChanged<bool> onCompletedChanged;
  final VoidCallback? onOpenNote;

  @override
  Widget build(BuildContext context) {
    final dueAt = task.dueAt?.toLocal();
    final noteTitle = task.noteTitle ??
        (task.isOwnedByCurrentUser ? 'メモ #${task.noteId}' : '共有タスク（メモ本文は非公開）');
    return Card(
      key: ValueKey('note_tasks_page_card_${task.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: ValueKey(
                    'note_tasks_page_checkbox_${task.id}',
                  ),
                  value: task.isCompleted,
                  onChanged: busy
                      ? null
                      : (value) => onCompletedChanged(value == true),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey(
                    'note_tasks_page_open_note_${task.id}',
                  ),
                  tooltip: onOpenNote == null ? '元のメモは共有されていません' : '元のメモを開く',
                  onPressed: onOpenNote,
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text(
                noteTitle,
                key: ValueKey(
                  'note_tasks_page_note_title_${task.id}',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.isImported)
                    const Chip(
                      avatar: Icon(Icons.cloud_done_outlined, size: 16),
                      label: Text('Evernote移行'),
                    ),
                  if (task.hasAssignee)
                    Chip(
                      key: ValueKey(
                        'note_tasks_page_assignee_${task.id}',
                      ),
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(task.assigneeLabel!),
                    ),
                  if (dueAt != null)
                    Chip(
                      avatar: Icon(
                        overdue
                            ? Icons.warning_amber_rounded
                            : dueToday
                                ? Icons.today_outlined
                                : Icons.event_outlined,
                        size: 16,
                      ),
                      label: Text(
                        DateFormat('yyyy/MM/dd HH:mm').format(dueAt),
                      ),
                    ),
                  if (task.recurrence != null)
                    Chip(
                      avatar: const Icon(Icons.repeat, size: 16),
                      label: Text(task.recurrence!),
                    ),
                  if (task.reminders.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.alarm_outlined, size: 16),
                      label: Text(
                        'リマインダー ${task.reminders.length}',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
