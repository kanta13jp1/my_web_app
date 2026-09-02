import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminToolExecutionGuardCard extends StatelessWidget {
  final List<Map<String, dynamic>> toolExecutionLogs;
  final int allowedToolExecutionCount;
  final int blockedToolExecutionCount;
  final Map<String, int> blockedReasonBreakdown;
  final DateTime? currentTime;

  const AdminToolExecutionGuardCard({
    super.key,
    required this.toolExecutionLogs,
    required this.allowedToolExecutionCount,
    required this.blockedToolExecutionCount,
    required this.blockedReasonBreakdown,
    this.currentTime,
  });

  @override
  Widget build(BuildContext context) {
    if (toolExecutionLogs.isEmpty) {
      return Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'agent_tool_execution_logs のデータがありません。マイグレーション適用後に表示されます。',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final totalExecutions =
        allowedToolExecutionCount + blockedToolExecutionCount;
    final blockedRate = totalExecutions == 0
        ? 0.0
        : (blockedToolExecutionCount / totalExecutions * 100);
    final recentLogs = toolExecutionLogs.take(12).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminToolGuardMetricChip(
                  label: 'Allowed',
                  value: '$allowedToolExecutionCount',
                  color: const Color(0xFF0D9488),
                ),
                _AdminToolGuardMetricChip(
                  label: 'Blocked',
                  value: '$blockedToolExecutionCount',
                  color: const Color(0xFFB91C1C),
                ),
                _AdminToolGuardMetricChip(
                  label: 'Blocked Rate',
                  value: '${blockedRate.toStringAsFixed(1)}%',
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ),
            if (blockedReasonBreakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Blocked Reasons',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ...blockedReasonBreakdown.entries.take(6).map((entry) {
                final ratio = blockedToolExecutionCount == 0
                    ? 0.0
                    : (entry.value / blockedToolExecutionCount).clamp(
                        0.0,
                        1.0,
                      );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: ratio,
                          backgroundColor: const Color(
                            0xFFB91C1C,
                          ).withValues(alpha: 0.08),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            const Text(
              'Recent Tool Executions',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...recentLogs.map((log) {
              final allowed = _toBool(log['allowed']);
              final rawReason = log['blocked_reason']?.toString().trim() ?? '';
              final reasonText =
                  rawReason.isEmpty ? 'No block reason' : rawReason;
              final toolName = _formatToolName(log['tool_name']?.toString());
              final createdAt = _formatTimestamp(log['created_at']);

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: allowed
                      ? const Color(0xFF0D9488).withValues(alpha: 0.05)
                      : const Color(0xFFB91C1C).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: allowed
                        ? const Color(0xFF0D9488).withValues(alpha: 0.2)
                        : const Color(0xFFB91C1C).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          allowed ? Icons.check_circle : Icons.block,
                          size: 16,
                          color: allowed
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            toolName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    if (!allowed) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasonText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  String _formatToolName(String? raw) {
    switch (raw) {
      case 'delegate_task':
        return 'delegate_task';
      case 'process_task':
        return 'process_task';
      case 'update_task_status':
        return 'update_task_status';
      case 'send_message':
        return 'send_message';
      case 'append_memory':
        return 'append_memory';
      case 'set_agent_status':
        return 'set_agent_status';
      case 'run_heartbeat':
        return 'run_heartbeat';
      case 'run_nightly_consolidation':
        return 'run_nightly_consolidation';
      case 'run_forgetting':
        return 'run_forgetting';
      case 'run_runtime_cycle':
        return 'run_runtime_cycle';
      default:
        return raw == null || raw.trim().isEmpty ? 'unknown_tool' : raw;
    }
  }

  String _formatTimestamp(dynamic rawValue) {
    if (rawValue == null) return '--';
    final parsed = DateTime.tryParse(rawValue.toString())?.toLocal();
    if (parsed == null) return '--';
    final now = currentTime ?? DateTime.now();
    final stale = parsed.year != now.year || now.difference(parsed).inDays > 30;
    return DateFormat(
      stale ? 'yyyy/MM/dd HH:mm:ss' : 'MM/dd HH:mm:ss',
    ).format(parsed);
  }
}

class _AdminToolGuardMetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AdminToolGuardMetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
