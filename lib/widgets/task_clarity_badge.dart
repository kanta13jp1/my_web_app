import 'package:flutter/material.dart';

import '../models/agent_task.dart';

class TaskClarityBadge extends StatelessWidget {
  final AgentTask task;

  const TaskClarityBadge({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final score = task.clarityScore;
    if (score == null) return const SizedBox.shrink();

    final isClarified = task.clarityStatus == 'clarified';
    final needsClarification = task.needsClarification;
    final label = isClarified
        ? '明確化済み $score/10'
        : needsClarification
            ? '明確さ $score/10・要確認'
            : '明確さ $score/10';
    final color =
        needsClarification ? const Color(0xFFD84315) : const Color(0xFF2E7D32);

    return Container(
      key: const Key('task_clarity_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
