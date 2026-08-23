import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ホーム IoT 管理ページ
/// スマートデバイス一覧・状態制御・自動化ルール。
/// home-iot-manager Edge Function と連携。
class HomeIotManagerPage extends StatefulWidget {
  const HomeIotManagerPage({super.key});

  @override
  State<HomeIotManagerPage> createState() => _HomeIotManagerPageState();
}

class _HomeIotManagerPageState extends State<HomeIotManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['devices', 'automations'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _automations = [];

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
      final devRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'smarthome.list_devices'},
      );
      final autoRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'smarthome.list_automations'},
      );
      setState(() {
        _devices = _toList(devRes.data, 'devices');
        _automations = _toList(autoRes.data, 'automations');
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

  Future<void> _toggleDevice(String deviceId, bool currentState) async {
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'smarthome.control',
          'device_id': deviceId,
          'state': !currentState,
        },
      );
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ホーム IoT'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.devices),
              text: 'デバイス (${_devices.length})',
            ),
            const Tab(icon: Icon(Icons.auto_mode), text: '自動化'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildDevicesTab(), _buildAutomationsTab()],
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

  Widget _buildDevicesTab() {
    if (_devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'デバイスがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Group by room
    final rooms = <String, List<Map<String, dynamic>>>{};
    for (final d in _devices) {
      final room = d['room'] as String? ?? 'その他';
      rooms.putIfAbsent(room, () => []).add(d);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: rooms.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1.5,
                ),
              ),
            ),
            ...entry.value.map((d) {
              final name = d['name'] as String? ?? '';
              final type = d['type'] as String? ?? '';
              final isOn = d['isOn'] as bool? ?? false;
              final value = d['value'];
              final deviceId = d['id'] as String? ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Icon(
                    _deviceIcon(type),
                    color: isOn
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF9CA3AF),
                  ),
                  title: Text(name),
                  subtitle: value != null ? Text('$value') : null,
                  trailing: Switch(
                    value: isOn,
                    onChanged: (_) => _toggleDevice(deviceId, isOn),
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildAutomationsTab() {
    if (_automations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_mode, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '自動化ルールがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _automations.length,
      itemBuilder: (ctx, i) {
        final a = _automations[i];
        final name = a['name'] as String? ?? '自動化 ${i + 1}';
        final trigger = a['trigger'] as String? ?? '';
        final action = a['action'] as String? ?? '';
        final enabled = a['enabled'] as bool? ?? true;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              Icons.auto_mode,
              color:
                  enabled ? const Color(0xFF4CAF50) : const Color(0xFF9CA3AF),
            ),
            title: Text(name),
            subtitle: Text(
              '${trigger.isNotEmpty ? "IF $trigger" : ""}'
              '${action.isNotEmpty ? " → $action" : ""}',
            ),
            trailing: Switch(
              value: enabled,
              onChanged: (_) {},
            ),
          ),
        );
      },
    );
  }

  IconData _deviceIcon(String type) {
    switch (type) {
      case 'light':
        return Icons.lightbulb;
      case 'thermostat':
        return Icons.thermostat;
      case 'lock':
        return Icons.lock;
      case 'camera':
        return Icons.videocam;
      case 'speaker':
        return Icons.speaker;
      case 'tv':
        return Icons.tv;
      case 'outlet':
        return Icons.outlet;
      default:
        return Icons.device_unknown;
    }
  }
}
