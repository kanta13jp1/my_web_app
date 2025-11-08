import 'package:flutter/material.dart';
import '../services/presence_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// グロースメトリクス表示バナー - ホームページに表示
class GrowthMetricsBanner extends StatefulWidget {
  const GrowthMetricsBanner({super.key});

  @override
  State<GrowthMetricsBanner> createState() => _GrowthMetricsBannerState();
}

class _GrowthMetricsBannerState extends State<GrowthMetricsBanner> {
  final _supabase = Supabase.instance.client;
  late PresenceService _presenceService;

  int _totalUsers = 0;
  int _onlineUsers = 0;
  int _onlineGuests = 0;
  int _newUsersToday = 0;

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(_supabase);
    _loadMetrics();
    _startRealTimeUpdates();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadMetrics() async {
    try {
      final stats = await _presenceService.getSiteStatistics();
      final onlineUsers = await _presenceService.getOnlineUsersCount();
      final onlineGuests = await _presenceService.getOnlineGuestsCount();

      if (mounted) {
        setState(() {
          _totalUsers = stats?.totalUsers ?? 0;
          _onlineUsers = onlineUsers;
          _onlineGuests = onlineGuests;
          _newUsersToday = stats?.newUsersToday ?? 0;
        });
      }
    } catch (e) {
      // エラーは無視（バナー表示は任意）
    }
  }

  void _startRealTimeUpdates() {
    // 30秒ごとに更新
    Stream.periodic(const Duration(seconds: 30), (_) async {
      await _loadMetrics();
    }).listen((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final totalOnline = _onlineUsers + _onlineGuests;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetric(
            icon: Icons.people,
            label: '総登録者',
            value: _totalUsers.toString(),
            color: Colors.blue,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          _buildMetric(
            icon: Icons.circle,
            label: 'オンライン',
            value: totalOnline.toString(),
            color: Colors.green,
          ),
          Container(
            height: 30,
            width: 1,
            color: Colors.grey.shade300,
          ),
          _buildMetric(
            icon: Icons.fiber_new,
            label: '本日の新規',
            value: _newUsersToday.toString(),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
