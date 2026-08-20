import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

class AgentHubPage extends StatefulWidget {
  const AgentHubPage({super.key});

  @override
  State<AgentHubPage> createState() => _AgentHubPageState();
}

class _AgentHubPageState extends State<AgentHubPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['departments', 'performance', 'routing'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _performance = [];
  Map<String, dynamic>? _routing;

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
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'agent.departments'}),
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'agent.performance'}),
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'agent.routing'}),
      ]);
      setState(() {
        final deptData = results[0].data;
        if (deptData is Map && deptData['departments'] is List) {
          _departments =
              (deptData['departments'] as List).cast<Map<String, dynamic>>();
        }
        final perfData = results[1].data;
        if (perfData is Map && perfData['ranking'] is List) {
          _performance =
              (perfData['ranking'] as List).cast<Map<String, dynamic>>();
        }
        final routeData = results[2].data;
        if (routeData is Map) _routing = Map<String, dynamic>.from(routeData);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'データ取得失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIエージェントハブ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: '再読み込み',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: '部署'),
            Tab(icon: Icon(Icons.bar_chart), text: 'パフォーマンス'),
            Tab(icon: Icon(Icons.route), text: 'ルーティング'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _DepartmentsTab(departments: _departments),
                    _PerformanceTab(performance: _performance),
                    _RoutingTab(routing: _routing),
                  ],
                ),
    );
  }
}

class _DepartmentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> departments;
  const _DepartmentsTab({required this.departments});

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) {
      return const Center(child: Text('部署データがありません'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: departments.length,
      itemBuilder: (context, i) {
        final dept = departments[i];
        final agentCount = dept['agent_count'] as int? ?? 0;
        final maxAgents = dept['max_agents'] as int? ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6366F1).withAlpha(30),
              child: Text(
                (dept['label'] as String? ?? '?').substring(0, 1),
                style: const TextStyle(
                  color: Color(0xFF6366F1),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            title:
                Text(dept['label'] as String? ?? dept['key'] as String? ?? ''),
            subtitle: Text(dept['goal'] as String? ?? ''),
            trailing: Chip(
              label: Text('$agentCount / $maxAgents'),
              backgroundColor: agentCount >= maxAgents
                  ? const Color(0xFFFF6B35).withAlpha(30)
                  : const Color(0xFF4CAF50).withAlpha(30),
            ),
          ),
        );
      },
    );
  }
}

class _PerformanceTab extends StatelessWidget {
  final List<Map<String, dynamic>> performance;
  const _PerformanceTab({required this.performance});

  @override
  Widget build(BuildContext context) {
    if (performance.isEmpty) {
      return const Center(child: Text('パフォーマンスデータがありません'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: performance.length,
      itemBuilder: (context, i) {
        final agent = performance[i];
        final score = (agent['score'] as num?)?.toDouble() ?? 0.0;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF97316).withAlpha(30),
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                  color: Color(0xFFF97316),
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              agent['name'] as String? ?? agent['agent_id'] as String? ?? '',
            ),
            subtitle: Text(agent['department'] as String? ?? ''),
            trailing: Text(
              score.toStringAsFixed(1),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.7,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoutingTab extends StatelessWidget {
  final Map<String, dynamic>? routing;
  const _RoutingTab({required this.routing});

  @override
  Widget build(BuildContext context) {
    if (routing == null) {
      return const Center(child: Text('ルーティングデータがありません'));
    }
    final workload = routing!['workload'];
    final unassigned = routing!['unassigned_count'] as int? ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '未割り当てタスク',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$unassigned 件',
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFFF97316),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (workload is List)
          ...(workload.cast<Map<String, dynamic>>().map(
                (w) => Card(
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    title: Text(w['department'] as String? ?? ''),
                    trailing: Text('${w['task_count'] ?? 0} タスク'),
                  ),
                ),
              )),
      ],
    );
  }
}
