import 'package:flutter/material.dart';

import '../models/agent_task.dart';
import '../services/agent_org_service.dart';

class AgentWorkspacePanel extends StatelessWidget {
  final String officeLabel;
  final Color accentColor;
  final bool isLoading;
  final AgentWorkspaceSnapshot? workspace;
  final Future<void> Function(AgentTask task, String status) onProcessTask;

  const AgentWorkspacePanel({
    super.key,
    required this.officeLabel,
    required this.accentColor,
    required this.isLoading,
    required this.workspace,
    required this.onProcessTask,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentWorkspace = workspace;
    if (currentWorkspace == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '$officeLabel の永続エージェントを読み込めませんでした。',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$officeLabel 起動時プロンプト',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'identity と直近の agent_memories を自動注入した起動コンテキストです。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.16),
                    ),
                  ),
                  child: SelectableText(
                    currentWorkspace.startupPrompt,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.55,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$officeLabel 宛て agent_tasks',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '自分宛ての未完了タスクだけを表示します。${currentWorkspace.tasks.length}件',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                if (currentWorkspace.tasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '未完了タスクはありません。',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  )
                else
                  ...currentWorkspace.tasks.map(
                    (task) => _TaskCard(
                      task: task,
                      accentColor: accentColor,
                      onProcessTask: onProcessTask,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AgentTask task;
  final Color accentColor;
  final Future<void> Function(AgentTask task, String status) onProcessTask;

  const _TaskCard({
    required this.task,
    required this.accentColor,
    required this.onProcessTask,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.flag_outlined,
                label: '優先度 ${task.priority}',
                color: Colors.orange,
              ),
              _MetaChip(
                icon: Icons.hourglass_top,
                label: task.status,
                color: accentColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (task.isQueued)
                FilledButton.tonalIcon(
                  onPressed: () => onProcessTask(task, 'in_progress'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('着手'),
                ),
              if (!task.isCompleted)
                FilledButton.icon(
                  onPressed: () => onProcessTask(task, 'completed'),
                  icon: const Icon(Icons.check),
                  label: const Text('完了'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
