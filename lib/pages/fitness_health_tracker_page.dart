import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// フィットネス・健康トラッカー
/// ワークアウト記録・体重推移・健康メトリクス管理。
/// fitness-health-tracker Edge Function と連携。
class FitnessHealthTrackerPage extends StatefulWidget {
  const FitnessHealthTrackerPage({super.key});

  @override
  State<FitnessHealthTrackerPage> createState() =>
      _FitnessHealthTrackerPageState();
}

class _FitnessHealthTrackerPageState extends State<FitnessHealthTrackerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['summary', 'workout', 'weight'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _workouts = [];
  List<Map<String, dynamic>> _weightHistory = [];

  // 記録フォーム
  String _selectedWorkoutType = 'running';
  final _durationController = TextEditingController(text: '30');
  final _caloriesController = TextEditingController(text: '200');
  final _weightController = TextEditingController();
  bool _isSaving = false;

  static const _workoutTypes = [
    ('running', 'ランニング', Icons.directions_run),
    ('walking', 'ウォーキング', Icons.directions_walk),
    ('cycling', 'サイクリング', Icons.directions_bike),
    ('gym', 'ジム', Icons.fitness_center),
    ('yoga', 'ヨガ', Icons.self_improvement),
    ('swimming', '水泳', Icons.pool),
    ('hiit', 'HIIT', Icons.flash_on),
    ('sports', 'スポーツ', Icons.sports),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    _weightController.dispose();
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
      final summaryRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'fitness.stats'},
      );
      final workoutRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'fitness.list'},
      );
      final weightRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'fitness.list_weight'},
      );

      setState(() {
        final sd = summaryRes.data;
        if (sd is Map<String, dynamic>) _summary = sd;

        final wd = workoutRes.data;
        if (wd is Map<String, dynamic>) {
          final list = wd['workouts'] ?? wd['logs'];
          if (list is List) {
            _workouts = list.map((w) => w as Map<String, dynamic>).toList();
          }
        }

        final wgd = weightRes.data;
        if (wgd is Map<String, dynamic>) {
          final list = wgd['records'];
          if (list is List) {
            _weightHistory =
                list.map((w) => w as Map<String, dynamic>).toList();
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

  Future<void> _logWorkout() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'fitness.log',
          'activity': _selectedWorkoutType,
          'duration_min': int.tryParse(_durationController.text) ?? 30,
          'calories': int.tryParse(_caloriesController.text) ?? 0,
        },
      );
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ワークアウトを記録しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'fitness.log_weight',
          'weight': weight,
        },
      );
      _weightController.clear();
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('体重を記録しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フィットネス・健康'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'サマリー'),
            Tab(icon: Icon(Icons.fitness_center), text: '記録'),
            Tab(icon: Icon(Icons.monitor_weight), text: '体重'),
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
                    _buildSummaryTab(),
                    _buildWorkoutTab(),
                    _buildWeightTab(),
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
            onPressed: _fetchData,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    final totalWorkouts = _summary?['totalWorkouts'] as int? ?? 0;
    final totalMinutes = _summary?['totalMinutes'] as int? ?? 0;
    final totalCalories = _summary?['totalCalories'] as int? ?? 0;
    final streakDays = _summary?['streakDays'] as int? ?? 0;
    final latestWeight = _summary?['latestWeight'] as double?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '$totalWorkouts',
                  '総ワークアウト',
                  Icons.fitness_center,
                  const Color(0xFF3D5AFE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '$streakDays',
                  '連続日数',
                  Icons.local_fire_department,
                  const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '$totalMinutes分',
                  '総運動時間',
                  Icons.timer,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '${totalCalories}kcal',
                  '総消費カロリー',
                  Icons.bolt,
                  const Color(0xFFE53935),
                ),
              ),
            ],
          ),
          if (latestWeight != null) ...[
            const SizedBox(height: 12),
            _statCard(
              '${latestWeight}kg',
              '最新体重',
              Icons.monitor_weight,
              const Color(0xFF3D5AFE),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            color: Colors.orange[50],
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: const Icon(Icons.restaurant, color: Colors.orange),
              ),
              title: const Text(
                '今日の食事を記録',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('カロリー・栄養バランスを管理'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.of(context).pushNamed('/meal-log'),
            ),
          ),
          if (_workouts.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '直近のワークアウト',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ..._workouts.take(5).map((w) => _workoutTile(w)),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
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
        ),
      ),
    );
  }

  Widget _workoutTile(Map<String, dynamic> w) {
    final type = w['type'] as String? ?? '';
    final duration = w['durationMinutes'] as int? ?? 0;
    final calories = w['calories'] as int? ?? 0;
    final date = w['recordedAt'] as String? ?? '';
    final (_, label, icon) = _workoutTypes.firstWhere(
      (t) => t.$1 == type,
      orElse: () => ('other', type, Icons.sports),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon, size: 20),
        ),
        title: Text(label),
        subtitle: Text('$duration分 • ${calories}kcal'),
        trailing: Text(
          date.length >= 10 ? date.substring(0, 10) : date,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ワークアウトを記録',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // ワークアウト種類
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _workoutTypes.map((t) {
              final isSelected = t.$1 == _selectedWorkoutType;
              return FilterChip(
                avatar: Icon(t.$3, size: 16),
                label: Text(t.$2),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedWorkoutType = t.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: '時間 (分)',
                    border: OutlineInputBorder(),
                    suffixText: '分',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'カロリー',
                    border: OutlineInputBorder(),
                    suffixText: 'kcal',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _logWorkout,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isSaving ? '保存中...' : 'ワークアウトを記録'),
            ),
          ),
          const SizedBox(height: 24),
          if (_workouts.isNotEmpty) ...[
            const Text(
              '履歴',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ..._workouts.map((w) => _workoutTile(w)),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '体重を記録',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: '体重',
                    border: OutlineInputBorder(),
                    suffixText: 'kg',
                    hintText: '例: 70.5',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _logWeight,
                child: const Text('記録'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_weightHistory.isNotEmpty) ...[
            const Text(
              '体重推移',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _weightHistory.length,
              itemBuilder: (ctx, i) {
                final w = _weightHistory[i];
                final weight = w['weight'] as double? ?? 0;
                final date = w['recordedAt'] as String? ?? '';
                final prev = i < _weightHistory.length - 1
                    ? _weightHistory[i + 1]['weight'] as double? ?? weight
                    : weight;
                final diff = weight - prev;
                return ListTile(
                  leading: Icon(
                    diff < 0
                        ? Icons.trending_down
                        : diff > 0
                            ? Icons.trending_up
                            : Icons.trending_flat,
                    color: diff < 0
                        ? const Color(0xFF4CAF50)
                        : diff > 0
                            ? const Color(0xFFE53935)
                            : const Color(0xFF9CA3AF),
                  ),
                  title: Text(
                    '${weight}kg',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                  subtitle: Text(
                    date.length >= 10 ? date.substring(0, 10) : date,
                  ),
                  trailing: diff != 0
                      ? Text(
                          '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}kg',
                          style: TextStyle(
                            color: diff < 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE53935),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        )
                      : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
