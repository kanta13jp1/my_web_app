import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/models/virtual_org_agent.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 仮想AI組織マネージャー
/// 部署ごとに自分のAIエージェントを登録・一覧する。
/// `ai-hub` の `org.get` / `agent.create` と連携。
class VirtualOrganizationPage extends StatefulWidget {
  const VirtualOrganizationPage({super.key});

  @override
  State<VirtualOrganizationPage> createState() =>
      _VirtualOrganizationPageState();
}

class _VirtualOrganizationPageState extends State<VirtualOrganizationPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>[
        'departments',
        'agents',
        'tasks',
      ];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  VirtualOrganization _organization = VirtualOrganization.empty;

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
      if (!mounted) return;
      setState(() {
        _organization = VirtualOrganization.fromResponse(orgRes.data);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAgent(VirtualOrgAgentDraft draft) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _supabase.functions.invoke('ai-hub', body: draft.toRequestBody());
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${draft.name.trim()} を登録しました')),
      );
      await _fetchOrganization();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('登録に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAddAgentDialog() async {
    if (_supabase.auth.currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('エージェントの登録にはログインが必要です')));
      return;
    }
    final draft = await showDialog<VirtualOrgAgentDraft>(
      context: context,
      builder: (_) =>
          VirtualOrgAgentDialog(departments: _organization.departments),
    );
    if (draft != null) await _createAgent(draft);
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
        onPressed: _isSaving ? null : _showAddAgentDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('エージェント追加'),
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
    final departments = _organization.departments;
    if (departments.isEmpty) {
      return const Center(
        child: Text(
          '部署を取得できませんでした\n右上の更新ボタンで再読み込みしてください',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: departments.length,
      itemBuilder: (ctx, i) {
        final name = departments[i];
        final agentCount = _organization.agentCountOf(name);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.apartment),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
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
    final agents = _organization.agents;
    if (agents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text(
              'エージェントがいません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _showAddAgentDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('最初のエージェントを登録する'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: agents.length,
      itemBuilder: (ctx, i) {
        final a = agents[i];
        final status = a.status.isEmpty ? 'idle' : a.status;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withValues(alpha: 0.2),
              child: Icon(Icons.smart_toy, color: _statusColor(status)),
            ),
            title: Text(a.name.isEmpty ? '(名前未設定)' : a.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (a.affiliationLabel.isNotEmpty) Text(a.affiliationLabel),
                if (a.personality.isNotEmpty)
                  Text(
                    a.personality,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            trailing: _statusChip(status),
            isThreeLine: a.personality.isNotEmpty,
          ),
        );
      },
    );
  }

  /// タスクの自動実行はサーバー側に実行系が無い (`agent.run` は記録を
  /// 積むだけで、読み出す処理も実行する処理も存在しない)。入力を受けて
  /// 捨てる UI は置かず、未提供であることをそのまま伝える。
  Widget _buildTasksTab() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'タスクの自動割り振りは未提供です',
              style: TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            SizedBox(height: 8),
            Text(
              'エージェントにタスクを実行させる仕組みはまだありません。\n'
              '現在は「エージェント」タブで組織の構成を登録・確認できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      ),
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
        style: const TextStyle(fontSize: 11, height: 1.5),
      ),
      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
      side: BorderSide(color: _statusColor(status).withValues(alpha: 0.4)),
      padding: EdgeInsets.zero,
    );
  }
}

/// エージェント登録ダイアログ。検証を通った [VirtualOrgAgentDraft] を返す。
class VirtualOrgAgentDialog extends StatefulWidget {
  const VirtualOrgAgentDialog({super.key, required this.departments});

  final List<String> departments;

  @override
  State<VirtualOrgAgentDialog> createState() => _VirtualOrgAgentDialogState();
}

class _VirtualOrgAgentDialogState extends State<VirtualOrgAgentDialog> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _personalityController = TextEditingController();
  String? _department;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.departments.isNotEmpty) _department = widget.departments.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _personalityController.dispose();
    super.dispose();
  }

  void _submit() {
    final draft = VirtualOrgAgentDraft(
      name: _nameController.text,
      department: _department ?? '',
      role: _roleController.text,
      personality: _personalityController.text,
    );
    final error = draft.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('エージェントを登録'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'エージェント名 *',
                hintText: '例: マーケ担当AI',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department,
              decoration: const InputDecoration(
                labelText: '部署 *',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final d in widget.departments)
                  DropdownMenuItem(value: d, child: Text(d)),
              ],
              onChanged: (v) => setState(() => _department = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: '役割',
                hintText: '例: SNS投稿の下書き',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _personalityController,
              decoration: const InputDecoration(
                labelText: '性格メモ',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const Text(
              '組織構成の記録です。登録したエージェントが自動でタスクを実行することはありません。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(onPressed: _submit, child: const Text('登録')),
      ],
    );
  }
}
