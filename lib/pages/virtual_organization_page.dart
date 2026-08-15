import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 仮想AI組織マネージャー
/// 12部署20エージェントの仮想組織を管理する。
/// virtual-organization Edge Function と連携。
class VirtualOrganizationPage extends StatefulWidget {
  const VirtualOrganizationPage({super.key});

  @override
  State<VirtualOrganizationPage> createState() =>
      _VirtualOrganizationPageState();
}

class _VirtualOrganizationPageState extends State<VirtualOrganizationPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['departments', 'agents', 'tasks'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _agents = [];
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOrganization();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrganization() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final orgRes = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'org.get'},
      );

      final orgData = orgRes.data;
      setState(() {
        if (orgData is Map<String, dynamic>) {
          final org = orgData['org'] as Map<String, dynamic>? ?? {};
          final deptList = org['departments'];
          if (deptList is List) {
            _departments = deptList.map((d) {
              if (d is Map<String, dynamic>) return d;
              return <String, dynamic>{'name': d.toString()};
            }).toList();
          }
          final agentList = org['agents'];
          if (agentList is List) {
            _agents = agentList.map((a) => a as Map<String, dynamic>).toList();
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignTask(String goal) async {
    // org.assign action は未実装 (org.get のみ利用可能)
    // タスク割り振り機能は今後追加予定
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('タスク割り振り機能は準備中です')),
      );
    }
  }

  void _showAssignTaskDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('タスクをAIに割り振る'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '例: ユーザー獲得施策を考えて実行する',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final goal = controller.text.trim();
              Navigator.pop(ctx);
              if (goal.isNotEmpty) _assignTask(goal);
            },
            child: const Text('割り振る'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仮想AI組織'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrganization,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.apartment), text: '部署'),
            Tab(icon: Icon(Icons.smart_toy), text: 'エージェント'),
            Tab(icon: Icon(Icons.task_alt), text: 'タスク'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignTaskDialog,
        icon: const Icon(Icons.add),
        label: const Text('タスク割振り'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDepartmentsTab(),
                    _buildAgentsTab(),
                    _buildTasksTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchOrganization,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsTab() {
    if (_departments.isEmpty) {
      return const Center(
        child: Text(
          '部署がまだありません\n仮想組織を初期化してください',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _departments.length,
      itemBuilder: (ctx, i) {
        final d = _departments[i];
        final icon = d['icon'] as String? ?? '🏢';
        final name = d['name'] as String? ?? '';
        final desc = d['description'] as String? ?? '';
        final agentCount = d['agentCount'] as int? ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                icon,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(desc),
            trailing: Chip(
              label: Text('$agentCount 人'),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAgentsTab() {
    if (_agents.isEmpty) {
      return const Center(
        child: Text(
          'エージェントがいません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _agents.length,
      itemBuilder: (ctx, i) {
        final a = _agents[i];
        final name = a['name'] as String? ?? 'Agent ${i + 1}';
        final role = a['role'] as String? ?? '';
        final dept = a['department'] as String? ?? '';
        final personality = a['personality'] as String? ?? '';
        final status = a['status'] as String? ?? 'idle';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withValues(alpha: 0.2),
              child: Icon(Icons.smart_toy, color: _statusColor(status)),
            ),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dept • $role'),
                if (personality.isNotEmpty)
                  Text(
                    personality,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            trailing: _statusChip(status),
            isThreeLine: personality.isNotEmpty,
          ),
        );
      },
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text(
              'タスクがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAssignTaskDialog,
              icon: const Icon(Icons.add),
              label: const Text('最初のタスクを割り振る'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tasks.length,
      itemBuilder: (ctx, i) {
        final t = _tasks[i];
        final goal = t['goal'] as String? ?? '';
        final dept = t['department'] as String? ?? '';
        final status = t['status'] as String? ?? 'pending';
        final assignedTo = t['assignedTo'] as String? ?? '';
        final createdAt = t['createdAt'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              _taskStatusIcon(status),
              color: _statusColor(status),
            ),
            title: Text(goal),
            subtitle: Text(
              '$dept${assignedTo.isNotEmpty ? " → $assignedTo" : ""}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(status),
                if (createdAt.length >= 10)
                  Text(
                    createdAt.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            isThreeLine: false,
          ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
      case 'running':
      case 'in_progress':
        return const Color(0xFF3D5AFE);
      case 'completed':
      case 'done':
        return const Color(0xFF4CAF50);
      case 'error':
      case 'failed':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFFFF6B35);
    }
  }

  Widget _statusChip(String status) {
    const labels = <String, String>{
      'active': '稼働中',
      'running': '実行中',
      'in_progress': '進行中',
      'idle': '待機',
      'completed': '完了',
      'done': '完了',
      'pending': '未開始',
      'error': 'エラー',
      'failed': '失敗',
    };
    return Chip(
      label: Text(
        labels[status] ?? status,
        style: const TextStyle(
          fontSize: 11,
          height: 1.5,
        ),
      ),
      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
      side: BorderSide(color: _statusColor(status).withValues(alpha: 0.4)),
      padding: EdgeInsets.zero,
    );
  }

  IconData _taskStatusIcon(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return Icons.check_circle;
      case 'in_progress':
      case 'running':
        return Icons.play_circle;
      case 'error':
      case 'failed':
        return Icons.error;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}
