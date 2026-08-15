import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 車両・フリート管理ページ
/// 車両一覧・走行記録・メンテナンス管理。
/// vehicle-fleet-manager Edge Function と連携。
class VehicleFleetManagerPage extends StatefulWidget {
  const VehicleFleetManagerPage({super.key});

  @override
  State<VehicleFleetManagerPage> createState() =>
      _VehicleFleetManagerPageState();
}

class _VehicleFleetManagerPageState extends State<VehicleFleetManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['vehicles', 'trips', 'maintenance'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _tripLogs = [];
  List<Map<String, dynamic>> _maintenance = [];

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
      final vRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'vehicle.list'},
      );
      final tRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'vehicle.list_trips'},
      );
      final mRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'vehicle.maintenance'},
      );
      setState(() {
        _vehicles = _toList(vRes.data, 'vehicles');
        _tripLogs = _toList(tRes.data, 'trips');
        _maintenance = _toList(mRes.data, 'maintenance');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('車両・フリート管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: '車両'),
            Tab(icon: Icon(Icons.route), text: '走行記録'),
            Tab(icon: Icon(Icons.build), text: 'メンテ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVehiclesTab(),
                    _buildTripsTab(),
                    _buildMaintenanceTab(),
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
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildVehiclesTab() {
    if (_vehicles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '車両が登録されていません',
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
      itemCount: _vehicles.length,
      itemBuilder: (ctx, i) {
        final v = _vehicles[i];
        final name = v['name'] as String? ?? '車両 ${i + 1}';
        final plate = v['licensePlate'] as String? ?? '';
        final model = v['model'] as String? ?? '';
        final odometer = v['odometer'] as num? ?? 0;
        final status = v['status'] as String? ?? 'active';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: status == 'active'
                  ? const Color(0xFFC8E6C9)
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Icon(
                Icons.directions_car,
                color: status == 'active'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF9CA3AF),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(
              '${model.isNotEmpty ? "$model · " : ""}${plate.isNotEmpty ? plate : ""}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (odometer > 0)
                  Text(
                    '${odometer.toStringAsFixed(0)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                Text(
                  status == 'active' ? '稼働中' : '停止中',
                  style: TextStyle(
                    fontSize: 11,
                    color: status == 'active'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTripsTab() {
    if (_tripLogs.isEmpty) {
      return const Center(
        child: Text(
          '走行記録がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _tripLogs.length,
      itemBuilder: (ctx, i) {
        final t = _tripLogs[i];
        final vehicle = t['vehicleName'] as String? ?? '';
        final from = t['from'] as String? ?? '';
        final to = t['to'] as String? ?? '';
        final distance = t['distanceKm'] as num? ?? 0;
        final date = t['date'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: const Icon(Icons.route, color: Color(0xFF3D5AFE)),
            title: Text(
              '${from.isNotEmpty ? from : "出発地"} → ${to.isNotEmpty ? to : "目的地"}',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
            subtitle: Text(vehicle),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (distance > 0)
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceTab() {
    if (_maintenance.isEmpty) {
      return const Center(
        child: Text(
          'メンテナンス記録がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _maintenance.length,
      itemBuilder: (ctx, i) {
        final m = _maintenance[i];
        final vehicle = m['vehicleName'] as String? ?? '';
        final type = m['type'] as String? ?? '';
        final cost = m['cost'] as num? ?? 0;
        final date = m['date'] as String? ?? '';
        final nextDue = m['nextDueDate'] as String? ?? '';
        final overdue = m['overdue'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Icon(
              Icons.build,
              color:
                  overdue ? const Color(0xFFE53935) : const Color(0xFFFF6B35),
            ),
            title: Text('$vehicle — $type'),
            subtitle: cost > 0 ? Text('費用: ¥${cost.toStringAsFixed(0)}') : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                if (nextDue.length >= 10)
                  Text(
                    '次回: ${nextDue.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: overdue
                          ? const Color(0xFFE53935)
                          : const Color(0xFF9CA3AF),
                      fontWeight: overdue ? FontWeight.bold : null,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
