import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ScheduleTaskMonitorCard extends StatefulWidget {
  const ScheduleTaskMonitorCard({super.key});

  @override
  State<ScheduleTaskMonitorCard> createState() =>
      _ScheduleTaskMonitorCardState();
}

class _ScheduleTaskMonitorCardState extends State<ScheduleTaskMonitorCard> {
  static const List<_TriggerDef> _registeredTriggers = <_TriggerDef>[
    _TriggerDef(
      id: 'trig_01MwKBLD1sffGZwxeMR1Gkxt',
      taskId: 'cs-check',
      name: 'cs-check',
      description: 'CS, bug fix, health checks, and Edge UI sync',
      schedule: 'Hourly',
      icon: Icons.support_agent,
    ),
    _TriggerDef(
      id: 'trig_01NMatLGr6gsxoTsYLXW4yQb',
      taskId: 'daily-report',
      name: 'daily-report',
      description: 'Daily digest, X post, and competitor monitoring',
      schedule: 'Daily 09:00 JST',
      icon: Icons.summarize,
    ),
    _TriggerDef(
      id: 'trig_019hVur8DeDvSsSSnGh1ppuE',
      taskId: 'blog-draft',
      name: 'blog-draft',
      description: 'Daily blog draft generation',
      schedule: 'Daily 08:00 JST',
      icon: Icons.article,
    ),
    _TriggerDef(
      id: 'trig_01Ch9p74Nxoyv7P1GaKFeRH9',
      taskId: 'weekly-sns-draft',
      name: 'weekly-sns-draft',
      description: 'Weekly SNS draft and dependency review pair',
      schedule: 'Monday 09:00 JST',
      icon: Icons.edit_note,
    ),
  ];

  static const List<_TaskDef> _definedTasks = <_TaskDef>[
    _TaskDef(
      'daily-report',
      'Daily report + X post',
      'Daily 09:00 JST',
      Icons.summarize,
    ),
    _TaskDef(
      'cs-check',
      'CS / bug fix / Edge UI sync',
      'Hourly',
      Icons.support_agent,
    ),
    _TaskDef(
      'weekly-sns-draft',
      'Weekly SNS draft',
      'Monday 09:00 JST',
      Icons.edit_note,
    ),
    _TaskDef(
      'github-issue-fix',
      'Issue -> branch -> draft PR',
      'Daily 10:00 JST',
      Icons.alt_route,
    ),
    _TaskDef(
      'ci-auto-fix',
      'CI self-heal (dart fix / deno fmt)',
      'workflow_run',
      Icons.auto_fix_high,
    ),
    _TaskDef(
      'blog-draft',
      'Blog draft generation',
      'Daily 08:00 JST',
      Icons.article,
    ),
    _TaskDef(
      'competitor-monitoring',
      'Competitor monitoring',
      'Daily 09:00 JST',
      Icons.monitor,
    ),
    _TaskDef(
      'infra-health-check',
      'Infra health check',
      'Scheduled',
      Icons.health_and_safety,
    ),
    _TaskDef(
      'dependency-audit',
      'Dependency audit',
      'Monday 09:00 JST',
      Icons.security,
    ),
    _TaskDef(
      'edge-function-ui-sync',
      'Edge Function UI sync',
      'Scheduled',
      Icons.sync,
    ),
    _TaskDef(
      'schedule-health-monitor',
      'Schedule health monitor',
      'Scheduled',
      Icons.monitor_heart,
    ),
    _TaskDef(
      'guitar-health-check',
      'Guitar health check',
      'Scheduled',
      Icons.music_note,
    ),
  ];

  bool _loading = true;
  bool _showTriggers = true;
  List<_ScheduleTaskInfo> _tasks = <_ScheduleTaskInfo>[];
  final Set<String> _expandedTasks = <String>{};

  @override
  void initState() {
    super.initState();
    _loadTaskStatus();
  }

  Future<void> _loadTaskStatus() async {
    setState(() => _loading = true);
    try {
      final SupabaseClient supabase = Supabase.instance.client;
      List<Map<String, dynamic>> runs = <Map<String, dynamic>>[];
      try {
        final dynamic data = await supabase
            .from('schedule_task_runs')
            .select(
              'task_id, status, started_at, finished_at, summary, error_message',
            )
            .order('started_at', ascending: false)
            .limit(120);
        runs = List<Map<String, dynamic>>.from(data as List<dynamic>);
      } catch (_) {
        runs = <Map<String, dynamic>>[];
      }

      final List<_ScheduleTaskInfo> tasks = _definedTasks.map((
        final _TaskDef def,
      ) {
        final List<Map<String, dynamic>> latestRuns = runs
            .where((final Map<String, dynamic> row) => row['task_id'] == def.id)
            .toList();
        if (latestRuns.isEmpty) {
          return _ScheduleTaskInfo(def: def);
        }
        final Map<String, dynamic> run = latestRuns.first;
        int consecutiveErrors = 0;
        for (final Map<String, dynamic> row in latestRuns) {
          if (row['status'] == 'error') {
            consecutiveErrors += 1;
          } else {
            break;
          }
        }
        return _ScheduleTaskInfo(
          def: def,
          lastStatus: run['status']?.toString() ?? 'unknown',
          lastRunAt:
              DateTime.tryParse(run['started_at']?.toString() ?? '')?.toLocal(),
          summary: run['summary']?.toString(),
          errorMessage: run['error_message']?.toString(),
          consecutiveErrors: consecutiveErrors,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int successCount = _tasks
        .where((final _ScheduleTaskInfo task) => task.lastStatus == 'success')
        .length;
    final int errorCount = _tasks
        .where((final _ScheduleTaskInfo task) => task.lastStatus == 'error')
        .length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.schedule, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Claude Code Schedule',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Open Claude Code Schedule',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => launchUrl(
                      Uri.parse('https://claude.ai/code/scheduled'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadTaskStatus,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showTriggers = !_showTriggers),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Registered triggers ${_registeredTriggers.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showTriggers ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: const Color(0xFFB0B0B0),
                    ),
                  ],
                ),
              ),
            ),
            if (_showTriggers) ...<Widget>[
              ..._registeredTriggers.map(
                (final _TriggerDef trigger) =>
                    _buildTriggerRow(trigger, isDark),
              ),
              const Divider(height: 20),
            ],
            Row(
              children: <Widget>[
                Text(
                  'Execution log (${_tasks.length} tasks)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF757575),
                    height: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (successCount > 0)
                  _buildBadge('OK $successCount', Colors.green),
                if (errorCount > 0) ...<Widget>[
                  const SizedBox(width: 4),
                  _buildBadge('ERR $errorCount', Colors.red),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tasks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final _ScheduleTaskInfo task = _tasks[index];
                  return _buildTaskRow(task, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerRow(_TriggerDef trigger, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => launchUrl(
        Uri.parse(trigger.url),
        mode: LaunchMode.externalApplication,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                trigger.icon,
                size: 14,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    trigger.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    '${trigger.schedule} | ${trigger.description}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF757575),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Live',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.open_in_new, size: 12, color: Color(0xFFB0B0B0)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTaskRow(_ScheduleTaskInfo task, bool isDark) {
    final Color statusColor = _statusColor(task.lastStatus);
    final String statusLabel = _statusLabel(task.lastStatus);
    final bool isExpanded = _expandedTasks.contains(task.def.id);
    final bool hasDetail = (task.errorMessage?.isNotEmpty ?? false) ||
        (task.summary?.isNotEmpty ?? false);
    final String lastRunLabel = task.lastRunAt == null
        ? 'No run yet'
        : '${task.lastRunAt!.month.toString().padLeft(2, '0')}/'
            '${task.lastRunAt!.day.toString().padLeft(2, '0')} '
            '${task.lastRunAt!.hour.toString().padLeft(2, '0')}:'
            '${task.lastRunAt!.minute.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: hasDetail
          ? () {
              setState(() {
                if (isExpanded) {
                  _expandedTasks.remove(task.def.id);
                } else {
                  _expandedTasks.add(task.def.id);
                }
              });
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(task.def.icon, size: 16, color: statusColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              task.def.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (task.consecutiveErrors >= 3)
                            _buildBadge(
                              'ERR x${task.consecutiveErrors}',
                              Colors.red,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${task.def.schedule} | Last run $lastRunLabel',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF757575),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (hasDetail) ...<Widget>[
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (isExpanded && hasDetail) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: task.lastStatus == 'error'
                      ? Colors.red.withValues(alpha: 0.08)
                      : Colors.green.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.lastStatus == 'error'
                        ? Colors.red.withValues(alpha: 0.25)
                        : Colors.green.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (task.errorMessage?.isNotEmpty ?? false) ...<Widget>[
                      const Row(
                        children: <Widget>[
                          Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Error detail',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.errorMessage!,
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                      if (task.summary?.isNotEmpty ?? false)
                        const SizedBox(height: 8),
                    ],
                    if (task.summary?.isNotEmpty ?? false) ...<Widget>[
                      const Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.summary!,
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'running':
        return const Color(0xFF3D5AFE);
      case 'error':
        return Colors.red;
      case 'skipped':
        return const Color(0xFFFF6B35);
      default:
        return const Color(0xFFB0B0B0);
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'success':
        return 'Success';
      case 'running':
        return 'Running';
      case 'error':
        return 'Error';
      case 'skipped':
        return 'Skipped';
      default:
        return 'Waiting';
    }
  }
}

class _TriggerDef {
  final String id;
  final String taskId;
  final String name;
  final String description;
  final String schedule;
  final IconData icon;

  const _TriggerDef({
    required this.id,
    required this.taskId,
    required this.name,
    required this.description,
    required this.schedule,
    required this.icon,
  });

  String get url => 'https://claude.ai/code/scheduled/$id';
}

class _TaskDef {
  final String id;
  final String name;
  final String schedule;
  final IconData icon;

  const _TaskDef(this.id, this.name, this.schedule, this.icon);
}

class _ScheduleTaskInfo {
  final _TaskDef def;
  final String? lastStatus;
  final DateTime? lastRunAt;
  final String? summary;
  final String? errorMessage;
  final int consecutiveErrors;

  const _ScheduleTaskInfo({
    required this.def,
    this.lastStatus,
    this.lastRunAt,
    this.summary,
    this.errorMessage,
    this.consecutiveErrors = 0,
  });
}
