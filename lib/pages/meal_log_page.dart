import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 食事ログ MVP — 1タップ記録 + 栄養バランスサマリ (#1665/#1744)
/// meal.log / meal.today / meal.list actions on lifestyle-hub EF (Codex#2担当).
class MealLogPage extends StatefulWidget {
  const MealLogPage({super.key});

  @override
  State<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends State<MealLogPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['log', 'summary'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _todaySummary;
  List<Map<String, dynamic>> _recentLogs = [];

  // 手動入力フォーム
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _selectedMealType = 'lunch';

  static const _mealTypes = [
    ('breakfast', '朝食', Icons.wb_sunny_outlined),
    ('lunch', '昼食', Icons.wb_sunny),
    ('dinner', '夕食', Icons.nights_stay_outlined),
    ('snack', '間食', Icons.cookie_outlined),
  ];

  static const _presets = [
    (name: '白米(1杯)', cal: 252, protein: 3.8, carbs: 55.7, fat: 0.5),
    (name: '卵(1個)', cal: 76, protein: 6.2, carbs: 0.2, fat: 5.2),
    (name: 'バナナ(1本)', cal: 86, protein: 1.1, carbs: 22.5, fat: 0.2),
    (name: '鶏むね肉(100g)', cal: 116, protein: 23.3, carbs: 0.0, fat: 1.9),
    (name: '豆腐(半丁)', cal: 56, protein: 4.9, carbs: 1.7, fat: 3.0),
    (name: 'プロテイン(1杯)', cal: 120, protein: 25.0, carbs: 3.0, fat: 1.5),
    (name: 'ヨーグルト(100g)', cal: 62, protein: 3.6, carbs: 4.9, fat: 3.0),
    (name: '食パン(1枚)', cal: 149, protein: 5.6, carbs: 26.6, fat: 2.5),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
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
      final todayRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'meal.today'},
      );
      final listRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'meal.list', 'limit': 20},
      );
      setState(() {
        final td = todayRes.data;
        if (td is Map<String, dynamic>) _todaySummary = td;

        final ld = listRes.data;
        if (ld is Map<String, dynamic>) {
          final list = ld['logs'];
          if (list is List) {
            _recentLogs = list.map((e) => e as Map<String, dynamic>).toList();
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

  Future<void> _logMeal({
    required String foodName,
    required int calories,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    if (foodName.isEmpty || calories <= 0) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'meal.log',
          'food_name': foodName,
          'meal_type': _selectedMealType,
          'calories': calories,
          'protein_g': protein,
          'carbs_g': carbs,
          'fat_g': fat,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$foodName を記録しました (${calories}kcal)')),
      );
      _foodNameController.clear();
      _caloriesController.clear();
      _proteinController.clear();
      _carbsController.clear();
      _fatController.clear();
      await _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('記録に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('食事ログ'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '記録'),
            Tab(text: '今日のサマリ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLogTab(),
                _buildSummaryTab(),
              ],
            ),
    );
  }

  Widget _buildLogTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMealTypeSelector(),
          const SizedBox(height: 16),
          _buildPresets(),
          const SizedBox(height: 16),
          _buildManualForm(),
          const SizedBox(height: 16),
          _buildAiEstimationStub(),
          const SizedBox(height: 16),
          _buildRecentLogs(),
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: _mealTypes.map((t) {
            final selected = _selectedMealType == t.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedMealType = t.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.orange[700] : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        t.$3,
                        size: 18,
                        color: selected ? Colors.white : Colors.grey[600],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.$2,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white : Colors.grey[600],
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPresets() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'クイック記録',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((p) {
            return ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text('${p.name} (${p.cal}kcal)'),
              onPressed: _isSaving
                  ? null
                  : () => _logMeal(
                        foodName: p.name,
                        calories: p.cal,
                        protein: p.protein,
                        carbs: p.carbs,
                        fat: p.fat,
                      ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildManualForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '手動入力',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _foodNameController,
              decoration: const InputDecoration(
                labelText: '食品名',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'カロリー(kcal)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'タンパク質(g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '炭水化物(g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '脂質(g)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _logMeal(
                          foodName: _foodNameController.text.trim(),
                          calories: int.tryParse(_caloriesController.text) ?? 0,
                          protein:
                              double.tryParse(_proteinController.text) ?? 0,
                          carbs: double.tryParse(_carbsController.text) ?? 0,
                          fat: double.tryParse(_fatController.text) ?? 0,
                        ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? '記録中...' : '記録する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiEstimationStub() {
    return Card(
      color: Colors.orange[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange[100],
          child: const Icon(Icons.camera_alt, color: Colors.orange),
        ),
        title: const Text(
          'AI 栄養推定 (写真)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          '写真を撮るだけでAIが栄養素を自動推定\n(ai-hub food_analysis — Codex#2準備中)',
        ),
        trailing: OutlinedButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI栄養推定は準備中です。')),
          ),
          child: const Text('準備中'),
        ),
      ),
    );
  }

  Widget _buildRecentLogs() {
    if (_recentLogs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('まだ記録がありません'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近の記録',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ..._recentLogs.map((log) => _buildLogTile(log)),
      ],
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final name = log['food_name'] as String? ?? '不明';
    final cal = log['calories'] as int? ?? 0;
    final mealType = log['meal_type'] as String? ?? '';
    final mealLabel = _mealTypes
        .firstWhere(
          (t) => t.$1 == mealType,
          orElse: () => ('', '食事', Icons.restaurant),
        )
        .$2;
    final loggedAt = log['logged_at'] as String? ?? '';
    final timeStr = loggedAt.length >= 16 ? loggedAt.substring(11, 16) : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.restaurant, color: Colors.orange[700]),
        title: Text(name),
        subtitle: Text('$mealLabel $timeStr'),
        trailing: Text(
          '${cal}kcal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange[700],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    const target = 2000;
    final totalCal = _todaySummary?['total_calories'] as int? ?? 0;
    final protein =
        (_todaySummary?['total_protein_g'] as num?)?.toDouble() ?? 0;
    final carbs = (_todaySummary?['total_carbs_g'] as num?)?.toDouble() ?? 0;
    final fat = (_todaySummary?['total_fat_g'] as num?)?.toDouble() ?? 0;
    final progress = (totalCal / target).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errorMessage != null)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          _buildCalorieCard(totalCal, target, progress),
          const SizedBox(height: 12),
          _buildMacroRow(protein, carbs, fat),
          const SizedBox(height: 12),
          _buildMealBreakdown(),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(int total, int target, double progress) {
    final remaining = target - total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '今日のカロリー',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '目標: ${target}kcal',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(' kcal'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.orange[100],
              color: progress >= 1.0 ? Colors.red : Colors.orange[700],
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              remaining >= 0
                  ? 'あと ${remaining}kcal'
                  : '目標を ${-remaining}kcal オーバー',
              style: TextStyle(
                color: remaining >= 0 ? Colors.grey[600] : Colors.red,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroRow(double protein, double carbs, double fat) {
    return Row(
      children: [
        _buildMacroCard('タンパク質', protein, 'g', Colors.blue),
        const SizedBox(width: 8),
        _buildMacroCard('炭水化物', carbs, 'g', Colors.green),
        const SizedBox(width: 8),
        _buildMacroCard('脂質', fat, 'g', Colors.amber),
      ],
    );
  }

  Widget _buildMacroCard(String label, double value, String unit, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                '${value.toStringAsFixed(1)}$unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealBreakdown() {
    final byMeal = _todaySummary?['by_meal'] as Map<String, dynamic>?;
    if (byMeal == null || byMeal.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('今日の記録がありません')),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '食事別内訳',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ...byMeal.entries.map((e) {
              final label = _mealTypes
                  .firstWhere(
                    (t) => t.$1 == e.key,
                    orElse: () => ('', e.key, Icons.restaurant),
                  )
                  .$2;
              final cal = (e.value as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label),
                    Text(
                      '${cal}kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
