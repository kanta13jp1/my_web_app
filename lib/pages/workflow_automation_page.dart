import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// AIワークフロー自動化ページ
/// ai-workflow-automation Edge Function と連携
class WorkflowAutomationPage extends StatefulWidget {
  const WorkflowAutomationPage({super.key});

  @override
  State<WorkflowAutomationPage> createState() => _WorkflowAutomationPageState();
}

class _WorkflowAutomationPageState extends State<WorkflowAutomationPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['workflows', 'templates', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _workflows = [];
  List<dynamic> _templates = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'ai_workflow.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _workflows = (data['workflows'] as List?) ?? [];
          _templates = (data['templates'] as List?) ?? [];
          _stats = data['stats'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleWorkflow(String id, bool enabled) async {
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'ai_workflow.run',
          'workflow_id': id,
          'enabled': enabled,
        },
      );
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _createFromTemplate(Map<String, dynamic> template) async {
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'ai_workflow.create', 'template_key': template['key']},
      );
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ワークフローを作成しました')),
        );
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return const Color(0xFF4CAF50);
      case 'paused':
        return const Color(0xFFFF6B35);
      case 'error':
        return const Color(0xFFE53935);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AIワークフロー自動化'),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _isLoading ? null : _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ワークフロー'),
            Tab(text: 'テンプレート'),
            Tab(text: '統計'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildWorkflowsTab(),
                    _buildTemplatesTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildWorkflowsTab() {
    if (_workflows.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 8),
            Text(
              'ワークフローがありません\nテンプレートから作成してください',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _workflows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final wf = _workflows[i] as Map<String, dynamic>;
        final status = wf['status']?.toString() ?? 'inactive';
        final isEnabled = status == 'active';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _statusColor(status).withAlpha(30),
              child: Icon(
                Icons.account_tree,
                color: _statusColor(status),
              ),
            ),
            title: Text(wf['name']?.toString() ?? 'ワークフロー'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('トリガー: ${wf['trigger_type'] ?? '-'}'),
                Text(
                  'ステータス: $status',
                  style: TextStyle(
                    color: _statusColor(status),
                    height: 1.5,
                  ),
                ),
              ],
            ),
            trailing: Switch(
              value: isEnabled,
              onChanged: (val) {
                final id = wf['id']?.toString() ?? '';
                if (id.isNotEmpty) _toggleWorkflow(id, val);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTemplatesTab() {
    if (_templates.isEmpty) {
      return const Center(
        child: Text(
          'テンプレートがありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _templates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final tmpl = _templates[i] as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x206366F1),
              child: Icon(Icons.auto_fix_high, color: Color(0xFF6366F1)),
            ),
            title: Text(tmpl['name']?.toString() ?? 'テンプレート'),
            subtitle: Text(
              'トリガー: ${tmpl['trigger'] ?? '-'}  '
              'アクション: ${(tmpl['actions'] as List?)?.length ?? 0}件',
            ),
            trailing: ElevatedButton(
              onPressed: () => _createFromTemplate(tmpl),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text('作成'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(
        child: Text(
          '統計データがありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    final items = [
      ('総ワークフロー', _stats!['total_workflows']?.toString() ?? '0'),
      ('アクティブ', _stats!['active_workflows']?.toString() ?? '0'),
      ('今日の実行数', _stats!['executions_today']?.toString() ?? '0'),
      ('成功率', '${_stats!['success_rate'] ?? 0}%'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map((item) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
