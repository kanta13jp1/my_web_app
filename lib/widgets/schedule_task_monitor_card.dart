import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Claude Code Schedule タスクの実行状況を管理者ダッシュボードで表示するカード。
///
/// `schedule_task_runs` テーブルから直近の実行ログを取得し、
/// 各タスクのステータス・最終実行日時・次回予定を表示する。
class ScheduleTaskMonitorCard extends StatefulWidget {
  const ScheduleTaskMonitorCard({super.key});

  @override
  State<ScheduleTaskMonitorCard> createState() =>
      _ScheduleTaskMonitorCardState();
}

class _ScheduleTaskMonitorCardState extends State<ScheduleTaskMonitorCard> {
  bool _loading = true;
  List<_ScheduleTaskInfo> _tasks = [];

  // 定義済みタスク一覧（CLAUDE.md に記載の全タスク）
  static const _definedTasks = [
    _TaskDef('daily-report', '日次レポート + X投稿', '毎日 09:00', Icons.summarize),
    _TaskDef('cs-check', 'CS対応・バグ修正', '毎時', Icons.support_agent),
    _TaskDef(
      'weekly-sns-draft',
      '週次SNSドラフト',
      '毎週月曜 09:00',
      Icons.edit_note,
    ),
    _TaskDef('daily-development', 'ロードマップ推進', '毎日 10:00', Icons.code),
    _TaskDef('pr-auto-review', 'PRコードレビュー', '3時間毎', Icons.rate_review),
    _TaskDef(
      'competitor-monitoring',
      '競合14社モニタリング',
      '毎日 07:00',
      Icons.monitor,
    ),
    _TaskDef(
      'infra-health-check',
      'インフラ監視',
      '毎時 30分',
      Icons.health_and_safety,
    ),
    _TaskDef(
      'dependency-audit',
      '脆弱性チェック',
      '毎週月曜 08:00',
      Icons.security,
    ),
    _TaskDef('blog-draft', 'ブログ下書き生成', '毎日 08:00', Icons.article),
  ];

  @override
  void initState() {
    super.initState();
    _loadTaskStatus();
  }

  Future<void> _loadTaskStatus() async {
    setState(() => _loading = true);
    try {
      // schedule_task_runs テーブルが存在すれば最新の実行ログを取得
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> runs = [];
      try {
        final data = await supabase
            .from('schedule_task_runs')
            .select('task_id, status, started_at, finished_at, summary')
            .order('started_at', ascending: false)
            .limit(50);
        runs = List<Map<String, dynamic>>.from(data as List);
      } catch (_) {
        // テーブル未作成の場合は空リストのまま
      }

      // 各タスク定義に最新の実行情報をマッピング
      final tasks = _definedTasks.map((def) {
        final latestRun = runs
            .where((r) => r['task_id'] == def.id)
            .toList();
        if (latestRun.isNotEmpty) {
          final run = latestRun.first;
          return _ScheduleTaskInfo(
            def: def,
            lastStatus: run['status']?.toString() ?? 'unknown',
            lastRunAt: DateTime.tryParse(run['started_at']?.toString() ?? ''),
            summary: run['summary']?.toString(),
          );
        }
        return _ScheduleTaskInfo(def: def);
      }).toList();

      if (mounted) {
        setState(() {
          _tasks = tasks;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Schedule タスク実行状況',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadTaskStatus,
                  tooltip: '更新',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Claude Code Schedule で定期実行中のタスク (${_tasks.length}件)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
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
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return _buildTaskRow(task, isDark);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskRow(_ScheduleTaskInfo task, bool isDark) {
    final statusColor = _statusColor(task.lastStatus);
    final statusLabel = _statusLabel(task.lastStatus);
    final lastRunStr = task.lastRunAt != null
        ? '${task.lastRunAt!.month}/${task.lastRunAt!.day} ${task.lastRunAt!.hour.toString().padLeft(2, '0')}:${task.lastRunAt!.minute.toString().padLeft(2, '0')}'
        : '未実行';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(task.def.icon, size: 16, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.def.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${task.def.schedule}  |  最終: $lastRunStr',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (task.summary != null && task.summary!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.summary!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'running':
        return Colors.blue;
      case 'error':
        return Colors.red;
      case 'skipped':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'success':
        return '成功';
      case 'running':
        return '実行中';
      case 'error':
        return 'エラー';
      case 'skipped':
        return 'スキップ';
      default:
        return '待機中';
    }
  }
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
  const _ScheduleTaskInfo({
    required this.def,
    this.lastStatus,
    this.lastRunAt,
    this.summary,
  });
}
