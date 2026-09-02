import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// アクセス制御・権限管理ページ
/// ロール一覧・ユーザー権限・アクセスログ表示。
/// access-control Edge Function と連携。
class AccessControlPage extends StatefulWidget {
  const AccessControlPage({super.key});

  @override
  State<AccessControlPage> createState() => _AccessControlPageState();
}

class _AccessControlPageState extends State<AccessControlPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['roles', 'logs'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _accessLogs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final rolesRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'access.list_roles'},
      );
      final logsRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'access.list_access_logs'},
      );
      setState(() {
        _roles = _toList(rolesRes.data, 'roles');
        _accessLogs = _toList(logsRes.data, 'logs');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFE53935);
      case 'manager':
        return const Color(0xFFFF6B35);
      case 'editor':
        return const Color(0xFF3D5AFE);
      case 'viewer':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFF3D5AFE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アクセス制御'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.admin_panel_settings),
              text: 'ロール (${_roles.length})',
            ),
            const Tab(icon: Icon(Icons.history), text: 'アクセスログ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildRolesTab(), _buildLogsTab()],
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
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildRolesTab() {
    if (_roles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 12),
            Text(
              'ロールが定義されていません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _roles.length,
      itemBuilder: (ctx, i) {
        final role = _roles[i];
        final name = role['name'] as String? ?? 'ロール ${i + 1}';
        final displayName = role['displayName'] as String? ?? name;
        final userCount = role['userCount'] as int? ?? 0;
        final permissions = role['permissions'] as List<dynamic>? ?? [];
        final color = _roleColor(name);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.shield, color: color),
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            subtitle: Text('$userCount ユーザー'),
            children: [
              if (permissions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: permissions
                        .map(
                          (p) => Chip(
                            label: Text(
                              '$p',
                              style: const TextStyle(fontSize: 11, height: 1.5),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    if (_accessLogs.isEmpty) {
      return const Center(
        child: Text(
          'アクセスログがありません',
          style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _accessLogs.length,
      itemBuilder: (ctx, i) {
        final log = _accessLogs[i];
        final user = log['user'] as String? ?? '—';
        final action = log['action'] as String? ?? '';
        final resource = log['resource'] as String? ?? '';
        final result = log['result'] as String? ?? 'allow';
        final timestamp = log['timestamp'] as String? ?? '';
        final isAllow = result == 'allow';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Icon(
              isAllow ? Icons.check_circle : Icons.cancel,
              color:
                  isAllow ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            ),
            title: Text('$user  $action'),
            subtitle: resource.isNotEmpty ? Text(resource) : null,
            trailing: timestamp.length >= 10
                ? Text(
                    timestamp.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
