import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 旅行プランナーページ
/// lifestyle-hub (travel.*) 連携
/// Google Travel / TripAdvisor / Amazon Travel 競合
class TravelItineraryPage extends StatefulWidget {
  const TravelItineraryPage({super.key});

  @override
  State<TravelItineraryPage> createState() => _TravelItineraryPageState();
}

class _TravelItineraryPageState extends State<TravelItineraryPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['itinerary', 'bookings', 'packing', 'budget'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _trips = [];
  Map<String, dynamic>? _selectedTrip;
  Map<String, List<Map<String, dynamic>>> _itinerary = {};
  List<Map<String, dynamic>> _bookings = [];
  List<String> _packingItems = [];
  Map<String, dynamic> _budget = {};

  final _tripNameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchTrips();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tripNameCtrl.dispose();
    _destinationCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'travel.list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['trips'] is List) {
        setState(() {
          _trips = (data['trips'] as List).cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => _trips = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '旅行データの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchItinerary(String tripId) async {
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'travel.get_items',
          'trip_id': tripId,
          'type': 'activity',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['itinerary'] is Map) {
        final raw = data['itinerary'] as Map;
        setState(() {
          _itinerary = raw.map(
            (k, v) => MapEntry(
              k.toString(),
              (v as List).cast<Map<String, dynamic>>(),
            ),
          );
        });
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        setState(
          () => _itinerary = {
            'all': (data['items'] as List).cast<Map<String, dynamic>>(),
          },
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchBookings(String tripId) async {
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'travel.get_items',
          'trip_id': tripId,
          'type': 'booking',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = (data['items'] ?? data['bookings']) as List?;
        if (list != null) {
          setState(() => _bookings = list.cast<Map<String, dynamic>>());
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchPacking(String tripId) async {
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'travel.get_items',
          'trip_id': tripId,
          'type': 'packing',
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final list = (data['items'] ?? data['packing']) as List?;
        if (list != null) {
          setState(
            () => _packingItems = list.map((e) => e.toString()).toList(),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchBudget(String tripId) async {
    try {
      final response = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'travel.get_budget', 'trip_id': tripId},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _budget = data);
      }
    } catch (_) {}
  }

  Future<void> _selectTrip(Map<String, dynamic> trip) async {
    final tripId = trip['id']?.toString() ?? '';
    setState(() => _selectedTrip = trip);
    await Future.wait([
      _fetchItinerary(tripId),
      _fetchBookings(tripId),
      _fetchPacking(tripId),
      _fetchBudget(tripId),
    ]);
  }

  Future<void> _createTrip() async {
    _tripNameCtrl.clear();
    _destinationCtrl.clear();
    _startDateCtrl.clear();
    _endDateCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しい旅行プランを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _tripNameCtrl,
              decoration: const InputDecoration(
                labelText: '旅行名',
                hintText: '例: 沖縄家族旅行',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationCtrl,
              decoration: const InputDecoration(
                labelText: '目的地',
                hintText: '例: 沖縄県那覇市',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _startDateCtrl,
              decoration: const InputDecoration(
                labelText: '出発日 (YYYY-MM-DD)',
                hintText: '例: 2026-08-01',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _endDateCtrl,
              decoration: const InputDecoration(
                labelText: '帰着日 (YYYY-MM-DD)',
                hintText: '例: 2026-08-05',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (_tripNameCtrl.text.trim().isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'travel.create',
          'name': _tripNameCtrl.text.trim(),
          'destination': _destinationCtrl.text.trim(),
          'start_date': _startDateCtrl.text.trim(),
          'end_date': _endDateCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('旅行プランを作成しました')),
        );
      }
      await _fetchTrips();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('作成に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _addActivity() async {
    final trip = _selectedTrip;
    if (trip == null) return;
    final nameCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: 'Day 1');
    final timeCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アクティビティを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'アクティビティ名'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: dayCtrl,
              decoration: const InputDecoration(labelText: '日程 (例: Day 1)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(labelText: '時間 (例: 10:00)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    dayCtrl.dispose();
    timeCtrl.dispose();
    if (confirmed != true) return;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'travel.add_item',
          'trip_id': trip['id'],
          'name': nameCtrl.text.trim(),
          'day': dayCtrl.text.trim(),
          'time': timeCtrl.text.trim(),
        },
      );
      await _fetchItinerary(trip['id'].toString());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗しました: $e')),
        );
      }
    }
  }

  Color _bookingTypeColor(String type) {
    switch (type) {
      case 'hotel':
        return const Color(0xFF6366F1);
      case 'flight':
        return const Color(0xFF0EA5E9);
      case 'train':
        return const Color(0xFF10B981);
      case 'rental_car':
        return const Color(0xFFF59E0B);
      case 'restaurant':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _bookingTypeIcon(String type) {
    switch (type) {
      case 'hotel':
        return Icons.hotel;
      case 'flight':
        return Icons.flight;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'rental_car':
        return Icons.directions_car;
      case 'restaurant':
        return Icons.restaurant;
      case 'activity':
        return Icons.local_activity;
      default:
        return Icons.bookmark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTrip != null
              ? _selectedTrip!['name']?.toString() ?? '旅行プランナー'
              : '旅行プランナー',
        ),
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        leading: _selectedTrip != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '旅行一覧に戻る',
                onPressed: () => setState(() {
                  _selectedTrip = null;
                  _itinerary = {};
                  _bookings = [];
                  _packingItems = [];
                  _budget = {};
                }),
              )
            : null,
        bottom: _selectedTrip != null
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.map), text: '日程'),
                  Tab(icon: Icon(Icons.bookmark), text: '予約'),
                  Tab(icon: Icon(Icons.checklist), text: '持ち物'),
                  Tab(icon: Icon(Icons.account_balance_wallet), text: '予算'),
                ],
              )
            : null,
        actions: [
          if (_selectedTrip != null && _tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add_location),
              tooltip: 'アクティビティを追加',
              onPressed: _addActivity,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _selectedTrip == null
                ? _fetchTrips
                : () => _selectTrip(_selectedTrip!),
          ),
        ],
      ),
      floatingActionButton: _selectedTrip == null
          ? FloatingActionButton(
              onPressed: _createTrip,
              backgroundColor: const Color(0xFF0EA5E9),
              tooltip: '新しい旅行プランを作成',
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchTrips,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _selectedTrip == null
                  ? _buildTripList()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildItineraryTab(),
                        _buildBookingsTab(),
                        _buildPackingTab(),
                        _buildBudgetTab(),
                      ],
                    ),
    );
  }

  Widget _buildTripList() {
    if (_trips.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 16),
            Text(
              '旅行プランがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '右下の + から新しい旅行を作成してください',
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
      padding: const EdgeInsets.all(16),
      itemCount: _trips.length,
      itemBuilder: (context, index) {
        final trip = _trips[index];
        final name = trip['name']?.toString() ?? '無題';
        final destination = trip['destination']?.toString() ?? '';
        final startDate = trip['startDate']?.toString() ??
            trip['start_date']?.toString() ??
            '';
        final endDate =
            trip['endDate']?.toString() ?? trip['end_date']?.toString() ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
              child: const Icon(Icons.flight_takeoff, color: Color(0xFF0EA5E9)),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (destination.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        destination,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                if (startDate.isNotEmpty)
                  Text(
                    '$startDate${endDate.isNotEmpty ? ' 〜 $endDate' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectTrip(trip),
          ),
        );
      },
    );
  }

  Widget _buildItineraryTab() {
    if (_itinerary.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map, size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              '日程がまだありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addActivity,
              icon: const Icon(Icons.add),
              label: const Text('アクティビティを追加'),
            ),
          ],
        ),
      );
    }
    final days = _itinerary.keys.toList()..sort();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, dayIndex) {
        final day = days[dayIndex];
        final activities = _itinerary[day] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0EA5E9),
                  height: 1.5,
                ),
              ),
            ),
            ...activities.map((activity) {
              final actName = activity['name']?.toString() ??
                  activity['activity']?.toString() ??
                  '未定';
              final time = activity['time']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0EA5E9),
                    child: Icon(Icons.place, color: Colors.white, size: 18),
                  ),
                  title: Text(actName),
                  trailing: time.isNotEmpty
                      ? Text(
                          time,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        )
                      : null,
                ),
              );
            }),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildBookingsTab() {
    if (_bookings.isEmpty) {
      return const Center(
        child: Text(
          '予約情報がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (context, index) {
        final booking = _bookings[index];
        final type = booking['type']?.toString() ?? 'other';
        final name = booking['name']?.toString() ??
            booking['provider']?.toString() ??
            '未登録';
        final date =
            booking['date']?.toString() ?? booking['checkIn']?.toString() ?? '';
        final confirmNo = booking['confirmation_number']?.toString() ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _bookingTypeColor(type).withValues(alpha: 0.15),
              child: Icon(
                _bookingTypeIcon(type),
                color: _bookingTypeColor(type),
                size: 20,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    color: _bookingTypeColor(type),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                if (confirmNo.isNotEmpty)
                  Text(
                    '確認番号: $confirmNo',
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

  Widget _buildPackingTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.luggage, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              Text(
                '持ち物リスト (${_packingItems.length}件)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _packingItems.isEmpty
              ? const Center(
                  child: Text(
                    '持ち物リストがありません',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _packingItems.length,
                  itemBuilder: (context, index) {
                    return Card(
                      child: CheckboxListTile(
                        value: false,
                        onChanged: (_) {},
                        title: Text(_packingItems[index]),
                        activeColor: const Color(0xFF0EA5E9),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBudgetTab() {
    final totalBudget = (_budget['totalBudget'] as num?)?.toDouble() ?? 0;
    final spent = (_budget['spent'] as num?)?.toDouble() ?? 0;
    final remaining = totalBudget - spent;
    final ratio = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '予算サマリー',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _budgetStat(
                        '総予算',
                        '¥${_formatNum(totalBudget)}',
                        const Color(0xFF3D5AFE),
                      ),
                      _budgetStat(
                        '支出',
                        '¥${_formatNum(spent)}',
                        const Color(0xFFE53935),
                      ),
                      _budgetStat(
                        '残高',
                        '¥${_formatNum(remaining)}',
                        remaining >= 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ratio,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      ratio < 0.7
                          ? const Color(0xFF4CAF50)
                          : ratio < 0.9
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFFE53935),
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}% 使用',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_budget['categories'] is List)
            ...((_budget['categories'] as List).cast<Map<String, dynamic>>())
                .map((cat) {
              final catName = cat['name']?.toString() ?? '';
              final catAmount = (cat['amount'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(catName)),
                    Text(
                      '¥${_formatNum(catAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (_budget['categories'] == null ||
              (_budget['categories'] as List?)?.isEmpty == true)
            const Center(
              child: Text(
                '予算データがありません',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _budgetStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  String _formatNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}
