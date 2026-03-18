import 'package:flutter/material.dart';

import '../models/agent_memory_entry.dart';
import '../models/agent_message.dart';
import '../models/agent_profile.dart';
import '../models/agent_relationship.dart';
import '../models/agent_task.dart';
import '../services/agent_org_service.dart';

class AgentOrgPage extends StatefulWidget {
  final AgentOrgService service;

  AgentOrgPage({
    super.key,
    AgentOrgService? service,
  }) : service = service ?? AgentOrgService();

  @override
  State<AgentOrgPage> createState() => _AgentOrgPageState();
}

class _AgentOrgPageState extends State<AgentOrgPage> {
  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final TextEditingController _boardMessageController =
      TextEditingController();

  AgentOrgSnapshot _snapshot = const AgentOrgSnapshot.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPostingBoardMessage = false;
  String? _selectedAssigneeId;
  String? _selectedBoardAuthorId;
  String _selectedBoardChannel = AgentOrgService.boardChannels.first.id;
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
    _boardMessageController.dispose();
    super.dispose();
  }

  List<AgentProfile> get _delegableAgents => _snapshot.agents
      .where(
        (agent) =>
            agent.slug == 'cfo' || agent.slug == 'cmo' || agent.slug == 'chro',
      )
      .toList();

  List<AgentProfile> get _boardAuthors =>
      _snapshot.agents.where((agent) => agent.isActive).toList();

  AgentProfile? get _ceoAgent {
    for (final agent in _snapshot.agents) {
      if (agent.slug == 'ceo') {
        return agent;
      }
    }
    return null;
  }

  String? _defaultBoardAuthorIdForSnapshot(AgentOrgSnapshot snapshot) {
    for (final agent in snapshot.agents) {
      if (agent.slug == 'ceo' && agent.isActive) {
        return agent.id;
      }
    }
    for (final agent in snapshot.agents) {
      if (agent.isActive) {
        return agent.id;
      }
    }
    return null;
  }

  AgentBoardChannel get _selectedBoardChannelConfig {
    for (final channel in AgentOrgService.boardChannels) {
      if (channel.id == _selectedBoardChannel) {
        return channel;
      }
    }
    return AgentOrgService.boardChannels.first;
  }

  String? _boardChannelFor(AgentMessage message) {
    final raw = message.metadata['channel']?.toString().trim().toLowerCase();
    if (!AgentOrgService.isSupportedBoardChannel(raw)) {
      return null;
    }
    return raw;
  }

  List<AgentMessage> get _boardMessages => _snapshot.recentMessages
      .where((message) => message.messageKind == 'board')
      .toList();

  List<AgentMessage> get _directMessages => _snapshot.recentMessages
      .where((message) => message.messageKind != 'board')
      .toList();

  Map<String, int> get _boardMessageCounts {
    final counts = <String, int>{};
    for (final message in _boardMessages) {
      final channel = _boardChannelFor(message);
      if (channel == null) {
        continue;
      }
      counts[channel] = (counts[channel] ?? 0) + 1;
    }
    return counts;
  }

  List<AgentMessage> get _selectedBoardMessages => _boardMessages
      .where((message) => _boardChannelFor(message) == _selectedBoardChannel)
      .toList();

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final snapshot = await widget.service.loadSnapshot();
      if (!mounted) {
        return;
      }
      final delegable = snapshot.agents
          .where(
            (agent) =>
                agent.slug == 'cfo' ||
                agent.slug == 'cmo' ||
                agent.slug == 'chro',
          )
          .toList();
      setState(() {
        _snapshot = snapshot;
        _selectedAssigneeId =
            delegable.any((agent) => agent.id == _selectedAssigneeId)
                ? _selectedAssigneeId
                : (delegable.isNotEmpty ? delegable.first.id : null);
        _selectedBoardAuthorId =
            snapshot.agents.any(
                  (agent) =>
                      agent.isActive && agent.id == _selectedBoardAuthorId,
                )
                ? _selectedBoardAuthorId
                : _defaultBoardAuthorIdForSnapshot(snapshot);
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
      await widget.service.delegateTask(
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
      await widget.service.updateTaskStatus(taskId: task.id, status: status);
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
      await widget.service.setAgentStatus(
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
      await widget.service.appendMemoryEntry(
        agentId: agent.id,
        content: controller.text.trim(),
        memoryLayer: 'state',
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

  Future<void> _postBoardMessage() async {
    final authorId = _selectedBoardAuthorId;
    final message = _boardMessageController.text.trim();
    if (authorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an active agent before posting.')),
      );
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a board update before posting.')),
      );
      return;
    }

    setState(() => _isPostingBoardMessage = true);
    try {
      await widget.service.postBoardMessage(
        fromAgentId: authorId,
        channel: _selectedBoardChannel,
        summary: message,
      );
      if (!mounted) {
        return;
      }
      _boardMessageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Posted to #${_selectedBoardChannelConfig.label}.',
          ),
        ),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Board post failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPostingBoardMessage = false);
      }
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
                              _buildSummaryChip(
                                label: '通信ログ',
                                value: '${_snapshot.recentMessages.length}',
                                color: Colors.orange,
                              ),
                              _buildSummaryChip(
                                label: '関係マップ',
                                value: '${_snapshot.relationships.length}',
                                color: Colors.teal,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDelegationComposer(),
                      const SizedBox(height: 24),
                      _buildBoardSection(),
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
                        'agent_relationships',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.relationships.isEmpty)
                        _buildEmptyCard('関係マップはありません。')
                      else
                        ..._snapshot.relationships
                            .take(12)
                            .map(_buildRelationshipCard),
                      const SizedBox(height: 24),
                      const Text(
                        'agent_messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_directMessages.isEmpty)
                        _buildEmptyCard('通信ログはありません。')
                      else
                        ..._directMessages
                            .take(12)
                            .map(_buildStructuredMessageCard),
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
              'CEO -> CFO / CMO / CHRO 委任',
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

  Widget _buildBoardSection() {
    final boardAuthors = _boardAuthors;
    final boardCounts = _boardMessageCounts;

    return Card(
      key: const Key('agent_org_board_section'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Board Channels',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'AnimaWorks-style shared channels for cross-team coordination.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AgentOrgService.boardChannels.map((channel) {
                final count = boardCounts[channel.id] ?? 0;
                return ChoiceChip(
                  key: Key('agent_org_board_channel_${channel.id}'),
                  label: Text('#${channel.label} ($count)'),
                  selected: _selectedBoardChannel == channel.id,
                  onSelected: (selected) {
                    if (!selected) {
                      return;
                    }
                    setState(() => _selectedBoardChannel = channel.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedBoardChannelConfig.description,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('agent_org_board_author_field'),
              initialValue: _selectedBoardAuthorId,
              decoration: const InputDecoration(
                labelText: 'Speaker',
                border: OutlineInputBorder(),
              ),
              items: boardAuthors
                  .map(
                    (agent) => DropdownMenuItem<String>(
                      value: agent.id,
                      child: Text('${agent.displayName} (${agent.department})'),
                    ),
                  )
                  .toList(),
              onChanged: _isPostingBoardMessage
                  ? null
                  : (value) => setState(() => _selectedBoardAuthorId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('agent_org_board_message_field'),
              controller: _boardMessageController,
              enabled: !_isPostingBoardMessage,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Post to #${_selectedBoardChannelConfig.label}',
                hintText:
                    'Share blockers, updates, or asks for the whole channel.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('agent_org_board_post_button'),
                onPressed: _isPostingBoardMessage ? null : _postBoardMessage,
                icon: _isPostingBoardMessage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: Text('Post to #${_selectedBoardChannelConfig.label}'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Channel Timeline',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_selectedBoardMessages.isEmpty)
              _buildEmptyCard(
                'No posts yet in #${_selectedBoardChannelConfig.label}.',
              )
            else
              ..._selectedBoardMessages.take(10).map(_buildBoardMessageCard),
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

  AgentProfile? _findAgentById(String id) {
    for (final agent in _snapshot.agents) {
      if (agent.id == id) {
        return agent;
      }
    }
    return null;
  }

  Widget _buildRelationshipCard(AgentRelationship relationship) {
    final from = _findAgentById(relationship.fromAgentId);
    final to = _findAgentById(relationship.toAgentId);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.alt_route, color: Colors.teal),
        title: Text(
          '${from?.displayName ?? relationship.fromAgentId} -> ${to?.displayName ?? relationship.toAgentId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${relationship.relationshipType} / ${relationship.communicationProtocol}',
          style: const TextStyle(height: 1.4),
        ),
        trailing: _buildStatusBadge(relationship.status),
      ),
    );
  }

  Widget _buildBoardMessageCard(AgentMessage message) {
    final from = _findAgentById(message.fromAgentId);
    final channelId = _boardChannelFor(message) ?? _selectedBoardChannel;
    final channel = AgentOrgService.boardChannels.firstWhere(
      (item) => item.id == channelId,
      orElse: () => _selectedBoardChannelConfig,
    );
    final createdAt = message.createdAt;
    final timestamp =
        '${createdAt.month}/${createdAt.day} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    from?.displayName ?? message.fromAgentId,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  timestamp,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniTag(
                  icon: Icons.tag,
                  label: '#${channel.label}',
                  color: Colors.deepPurple,
                ),
                _buildMiniTag(
                  icon: Icons.forum_outlined,
                  label: message.status,
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.summary,
              style: const TextStyle(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredMessageCard(AgentMessage message) {
    if (message.messageKind == 'board') {
      return _buildBoardMessageCard(message);
    }
    final from = _findAgentById(message.fromAgentId);
    final to = _findAgentById(message.toAgentId);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${from?.displayName ?? message.fromAgentId} -> ${to?.displayName ?? message.toAgentId}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildStatusBadge(message.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${message.messageKind}: ${message.summary}',
              style: const TextStyle(height: 1.4),
            ),
            if (message.linkedTaskId != null &&
                message.linkedTaskId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'task: ${message.linkedTaskId}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
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
      case 'active':
      case 'sent':
        color = Colors.teal;
        break;
      case 'completed':
      case 'resolved':
        color = Colors.green;
        break;
      case 'acknowledged':
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
