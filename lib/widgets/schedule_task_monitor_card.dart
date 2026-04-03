import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Claude Code Schedule タスクの実行状況を管理者ダッシュボードで表示するカード。
///
/// `schedule_task_runs` テーブルから直近の実行ログを取得し、
/// 各タスクのステータス・最終実行日時・エラー詳細を表示する。
/// タップで詳細展開・管理ページへのリンクを提供。
class ScheduleTaskMonitorCard extends StatefulWidget {
  const ScheduleTaskMonitorCard({super.key});

  @override
  State<ScheduleTaskMonitorCard> createState() =>
      _ScheduleTaskMonitorCardState();
}

class _ScheduleTaskMonitorCardState extends State<ScheduleTaskMonitorCard> {
  bool _loading = true;
  List<_ScheduleTaskInfo> _tasks = [];
  final Set<String> _expandedTasks = {};

  // 定義済みタスク一覧（CLAUDE.md に記載の全タスク）
  static const _definedTasks = [
    _TaskDef('daily-report', '日次レポート + X投稿', '毎日 09:00 JST', Icons.summarize),
    _TaskDef('cs-check', 'CS対応・バグ修正・Edge UI', '毎時', Icons.support_agent),
    _TaskDef(
      'weekly-sns-draft',
      '週次SNSドラフト',
      '毎週月曜 09:00 JST',
      Icons.edit_note,
    ),
    _TaskDef('blog-draft', 'ブログ下書き生成', '毎日 08:00 JST', Icons.article),
    _TaskDef('daily-development', 'ロードマップ推進', '毎日 10:00 JST', Icons.code),
    _TaskDef('pr-auto-review', 'PRコードレビュー', '3時間毎', Icons.rate_review),
    _TaskDef(
      'competitor-monitoring',
      '競合21社モニタリング',
      '毎日 07:00 JST',
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
      '毎週月曜 08:00 JST',
      Icons.security,
    ),
    _TaskDef(
      'blog-auto-post',
      'ブログ自動投稿',
      '毎日 12:00 JST',
      Icons.publish,
    ),
    _TaskDef(
      'schedule-health-monitor',
      'Scheduleヘルスモニター',
      '毎時',
      Icons.monitor_heart,
    ),
    _TaskDef(
      'edge-function-ui-sync',
      'Edge Function UI同期',
      '毎時',
      Icons.sync,
    ),
    _TaskDef(
      'self-heal-check',
      'タスク失敗時の自己修復',
      '毎時 15分',
      Icons.auto_fix_high,
    ),
    _TaskDef(
      'guitar-health-check',
      'ギター録音スタジオ監視',
      '毎時 (cs-check内)',
      Icons.music_note,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTaskStatus();
  }

  Future<void> _loadTaskStatus() async {
    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> runs = [];
      try {
        final data = await supabase
            .from('schedule_task_runs')
            .select(
              'task_id, status, started_at, finished_at, summary, error_message',
            )
            .order('started_at', ascending: false)
            .limit(100);
        runs = List<Map<String, dynamic>>.from(data as List);
      } catch (_) {
        // テーブル未作成の場合は空リストのまま
      }

      // 各タスク定義に最新の実行情報をマッピング
      final tasks = _definedTasks.map((def) {
        final latestRuns =
            runs.where((r) => r['task_id'] == def.id).toList();
        if (latestRuns.isNotEmpty) {
          final run = latestRuns.first;
          // 連続失敗回数を計算
          int consecutiveErrors = 0;
          for (final r in latestRuns) {
            if (r['status'] == 'error') {
              consecutiveErrors++;
            } else {
              break;
            }
          }
          return _ScheduleTaskInfo(
            def: def,
            lastStatus: run['status']?.toString() ?? 'unknown',
            lastRunAt: DateTime.tryParse(run['started_at']?.toString() ?? ''),
            summary: run['summary']?.toString(),
            errorMessage: run['error_message']?.toString(),
            consecutiveErrors: consecutiveErrors,
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
    final errorCount = _tasks.where((t) => t.lastStatus == 'error').length;
    final successCount = _tasks.where((t) => t.lastStatus == 'success').length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Schedule タスク実行状況',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 管理ページリンク
                Tooltip(
                  message: 'Claude.ai スケジュール管理',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'https://claude.ai/code/scheduled でスケジュール管理できます',
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _loadTaskStatus,
                  tooltip: '更新',
                ),
              ],
            ),
            // サマリーバッジ
            Row(
              children: [
                Text(
                  'Claude Code Schedule (${_tasks.length}タスク登録)',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 8),
                if (successCount > 0)
                  _buildBadge('✓ $successCount', Colors.green),
                if (errorCount > 0) ...[
                  const SizedBox(width: 4),
                  _buildBadge('✗ $errorCount', Colors.red),
                ],
              ],
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTaskRow(_ScheduleTaskInfo task, bool isDark) {
    final statusColor = _statusColor(task.lastStatus);
    final statusLabel = _statusLabel(task.lastStatus);
    final lastRunStr = task.lastRunAt != null
        ? '${task.lastRunAt!.month}/${task.lastRunAt!.day} '
            '${task.lastRunAt!.hour.toString().padLeft(2, '0')}:'
            '${task.lastRunAt!.minute.toString().padLeft(2, '0')}'
        : '未実行';
    final isExpanded = _expandedTasks.contains(task.def.id);
    final hasDetail =
        (task.errorMessage != null && task.errorMessage!.isNotEmpty) ||
            (task.summary != null && task.summary!.isNotEmpty);

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
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // アイコン
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
                // テキスト
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            task.def.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (task.consecutiveErrors >= 3) ...[
                            const SizedBox(width: 6),
                            _buildBadge(
                              '連続失敗${task.consecutiveErrors}回',
                              Colors.red,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${task.def.schedule}  |  最終: $lastRunStr',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // ステータスバッジ + 展開アイコン
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                    if (hasDetail) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            // 展開: エラー詳細 or サマリー
            if (isExpanded && hasDetail) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: task.lastStatus == 'error'
                      ? Colors.red.withAlpha(15)
                      : Colors.green.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.lastStatus == 'error'
                        ? Colors.red.withAlpha(60)
                        : Colors.green.withAlpha(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.errorMessage != null &&
                        task.errorMessage!.isNotEmpty) ...[
                      const Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'エラー詳細',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.errorMessage!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (task.summary != null) const SizedBox(height: 8),
                    ],
                    if (task.summary != null && task.summary!.isNotEmpty) ...[
                      const Text(
                        '実行サマリー',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.summary!,
                        style: const TextStyle(fontSize: 11),
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
