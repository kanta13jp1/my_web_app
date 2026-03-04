import 'package:flutter/material.dart';

import '../models/agent_memory_entry.dart';
import '../models/agent_profile.dart';
import '../models/agent_task.dart';
import '../services/agent_org_service.dart';

class AgentOrgPage extends StatefulWidget {
  const AgentOrgPage({super.key});

  @override
  State<AgentOrgPage> createState() => _AgentOrgPageState();
}

class _AgentOrgPageState extends State<AgentOrgPage> {
  final AgentOrgService _service = AgentOrgService();
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();

  AgentOrgSnapshot _snapshot = const AgentOrgSnapshot.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedAssigneeId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDescriptionController.dispose();
    super.dispose();
  }

  List<AgentProfile> get _delegableAgents => _snapshot.agents
      .where((agent) => agent.slug == 'cfo' || agent.slug == 'cmo')
      .toList();

  AgentProfile? get _ceoAgent {
    for (final agent in _snapshot.agents) {
      if (agent.slug == 'ceo') {
        return agent;
      }
    }
    return null;
  }

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final snapshot = await _service.loadSnapshot();
      if (!mounted) {
        return;
      }
      final delegable = snapshot.agents
          .where((agent) => agent.slug == 'cfo' || agent.slug == 'cmo')
          .toList();
      setState(() {
        _snapshot = snapshot;
        _selectedAssigneeId =
            delegable.any((agent) => agent.id == _selectedAssigneeId)
                ? _selectedAssigneeId
                : (delegable.isNotEmpty ? delegable.first.id : null);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'AI組織の初期化に失敗しました: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitDelegation() async {
    final ceoAgent = _ceoAgent;
    final assigneeId = _selectedAssigneeId;
    if (ceoAgent == null || assigneeId == null) {
      return;
    }

    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('委任タスクのタイトルを入力してください。')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _service.delegateTask(
        supervisorAgentId: ceoAgent.id,
        assigneeAgentId: assigneeId,
        title: title,
        description: _taskDescriptionController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      _taskTitleController.clear();
      _taskDescriptionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEOから役員へタスクを委任しました。')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('委任に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _setTaskStatus(AgentTask task, String status) async {
    try {
      await _service.updateTaskStatus(taskId: task.id, status: status);
      if (!mounted) {
        return;
      }
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('タスク更新に失敗しました: $error')),
      );
    }
  }

  Future<void> _toggleAgentStatus(AgentProfile agent) async {
    try {
      await _service.setAgentStatus(
        agentId: agent.id,
        enabled: !agent.isActive,
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エージェント状態の更新に失敗しました: $error')),
      );
    }
  }

  Future<void> _openMemoryDialog(AgentProfile agent) async {
    final controller = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('${agent.displayName} の記憶を追加'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '引き継ぎ・判断基準・注意事項',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );

      if (submitted != true) {
        return;
      }
      await _service.appendMemoryEntry(
        agentId: agent.id,
        content: controller.text.trim(),
        memoryLayer: 'identity_note',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${agent.displayName} の記憶を保存しました。')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('記憶の保存に失敗しました: $error')),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAgents =
        _snapshot.agents.where((agent) => agent.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI組織OS'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSnapshot,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildSummaryChip(
                                label: '稼働役員',
                                value:
                                    '$activeAgents / ${_snapshot.agents.length}',
                                color: Colors.green,
                              ),
                              _buildSummaryChip(
                                label: '未完了タスク',
                                value: '${_snapshot.tasks.length}',
                                color: Colors.deepPurple,
                              ),
                              _buildSummaryChip(
                                label: '記憶ログ',
                                value: '${_snapshot.recentMemories.length}',
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDelegationComposer(),
                      const SizedBox(height: 24),
                      const Text(
                        'Agent Registry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._snapshot.agents.map(_buildAgentCard),
                      const SizedBox(height: 24),
                      const Text(
                        'agent_tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.tasks.isEmpty)
                        _buildEmptyCard('未完了タスクはありません。')
                      else
                        ..._snapshot.tasks.map(_buildTaskCard),
                      const SizedBox(height: 24),
                      const Text(
                        'Memory Stack (recent)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.recentMemories.isEmpty)
                        _buildEmptyCard('まだ記憶ログはありません。')
                      else
                        ..._snapshot.recentMemories
                            .take(8)
                            .map(_buildMemoryCard),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDelegationComposer() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CEO -> CFO / CMO 委任',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'ここから永続エージェントへタスクを委任します。委任内容は agent_tasks と記憶ログに保存されます。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedAssigneeId),
              initialValue: _selectedAssigneeId,
              decoration: const InputDecoration(
                labelText: '委任先',
                border: OutlineInputBorder(),
              ),
              items: _delegableAgents
                  .map(
                    (agent) => DropdownMenuItem<String>(
                      value: agent.id,
                      child: Text('${agent.displayName} (${agent.department})'),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedAssigneeId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskTitleController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: '委任タスク',
                hintText: '例: 今日の登録率改善プランを作る',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskDescriptionController,
              enabled: !_isSubmitting,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '補足指示',
                hintText: '例: LPの体験導線と認証摩擦を優先で見る',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitDelegation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('delegateTask を実行'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(AgentProfile agent) {
    final taskCount = _snapshot.openTaskCountsByAgent[agent.id] ?? 0;
    final memoryCount = _snapshot.memoryCountsByAgent[agent.id] ?? 0;
    final cardColor = agent.isActive ? Colors.deepPurple : Colors.grey.shade600;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cardColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: cardColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${agent.displayName} (${agent.roleTitle})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        agent.department,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    agent.isActive ? '稼働中' : '停止中',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cardColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              agent.identityPrompt,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '権限: ${agent.permissionsSummary}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniTag(
                  icon: Icons.assignment_late_outlined,
                  label: '未完了 $taskCount',
                  color: Colors.deepPurple,
                ),
                _buildMiniTag(
                  icon: Icons.memory,
                  label: '記憶 $memoryCount',
                  color: Colors.blue,
                ),
                if (agent.lastActiveAt != null)
                  _buildMiniTag(
                    icon: Icons.schedule,
                    label:
                        '最終稼働 ${agent.lastActiveAt!.month}/${agent.lastActiveAt!.day} ${agent.lastActiveAt!.hour.toString().padLeft(2, '0')}:${agent.lastActiveAt!.minute.toString().padLeft(2, '0')}',
                    color: Colors.teal,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openMemoryDialog(agent),
                  icon: const Icon(Icons.note_add),
                  label: const Text('記憶を追加'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleAgentStatus(agent),
                  icon: Icon(
                    agent.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_arrow,
                  ),
                  label: Text(agent.isActive ? '休止' : '再開'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(AgentTask task) {
    AgentProfile? assignee;
    for (final agent in _snapshot.agents) {
      if (agent.id == task.assigneeAgentId) {
        assignee = agent;
        break;
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _buildStatusBadge(task.status),
              ],
            ),
            if (assignee != null) ...[
              const SizedBox(height: 6),
              Text(
                '担当: ${assignee.displayName} (${assignee.department})',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(height: 1.5),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniTag(
                  icon: Icons.flag_outlined,
                  label: '優先度 ${task.priority}',
                  color: Colors.orange,
                ),
                _buildMiniTag(
                  icon: Icons.inventory_2_outlined,
                  label: task.taskType,
                  color: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.isQueued)
                  FilledButton.tonalIcon(
                    onPressed: () => _setTaskStatus(task, 'in_progress'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('着手'),
                  ),
                if (!task.isCompleted)
                  FilledButton.icon(
                    onPressed: () => _setTaskStatus(task, 'completed'),
                    icon: const Icon(Icons.check),
                    label: const Text('完了'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(AgentMemoryEntry memory) {
    AgentProfile? owner;
    for (final agent in _snapshot.agents) {
      if (agent.id == memory.agentId) {
        owner = agent;
        break;
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.memory, color: Colors.blue),
        title: Text(
          owner == null
              ? memory.memoryLayer
              : '${owner.displayName} / ${memory.memoryLayer}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            memory.content,
            style: const TextStyle(height: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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

  Widget _buildEmptyCard(String text) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      ),
    );
  }
}
