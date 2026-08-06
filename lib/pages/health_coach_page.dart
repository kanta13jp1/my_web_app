import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ヘルスコーチ — Liven 対抗
/// lifestyle-hub (fitness.* / meal.* / recipe.*) 連携
class HealthCoachPage extends StatefulWidget {
  const HealthCoachPage({super.key});

  @override
  State<HealthCoachPage> createState() => _HealthCoachPageState();
}

class _HealthCoachPageState extends State<HealthCoachPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['summary', 'meals', 'advice'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;

  // フィットネス
  Map<String, dynamic>? _fitnessData;
  // 食事
  List<Map<String, dynamic>> _meals = [];
  // AIアドバイス
  String? _aiAdvice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'lifestyle-hub',
          body: {'action': 'fitness.stats'},
        ),
        _supabase.functions.invoke(
          'lifestyle-hub',
          body: {'action': 'meal.list_plans'},
        ),
      ]);
      final fitnessData = results[0].data;
      final mealData = results[1].data;

      setState(() {
        if (fitnessData is Map<String, dynamic>) {
          _fitnessData = fitnessData;
          _aiAdvice = fitnessData['ai_advice']?.toString();
        }
        if (mealData is Map && mealData['meals'] is List) {
          _meals = List<Map<String, dynamic>>.from(
            (mealData['meals'] as List).whereType<Map>(),
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルスコーチ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'サマリー'),
            Tab(text: '食事'),
            Tab(text: 'AIアドバイス'),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _fetchAll,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF3A1010)
                  : const Color(0xFFFFEBEE),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(data: _fitnessData),
                _MealsTab(meals: _meals, supabase: _supabase),
                _AdviceTab(advice: _aiAdvice),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.data});
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Center(child: Text('データがありません'));
    }
    final metrics = [
      (
        '今日の歩数',
        data!['steps']?.toString() ?? '—',
        Icons.directions_walk,
        const Color(0xFF4CAF50)
      ),
      (
        '消費カロリー',
        '${data!['calories_burned'] ?? '—'} kcal',
        Icons.local_fire_department,
        const Color(0xFFFF6B35)
      ),
      (
        '睡眠時間',
        '${data!['sleep_hours'] ?? '—'} 時間',
        Icons.bedtime,
        const Color(0xFF3D5AFE)
      ),
      (
        '水分摂取',
        '${data!['water_ml'] ?? '—'} ml',
        Icons.water_drop,
        const Color(0xFF3D5AFE)
      ),
    ];
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: metrics.map((m) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(m.$3, size: 16, color: m.$4),
                          const SizedBox(width: 4),
                          Text(
                            m.$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        m.$2,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (data!['goal_progress'] != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '今日の目標達成率',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          (data!['goal_progress'] as num?)?.toDouble() ?? 0.0,
                      backgroundColor: const Color(0xFFEEEEEE),
                      color: const Color(0xFF4CAF50),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((data!['goal_progress'] as num?)?.toDouble() ?? 0.0) * 100 ~/ 1}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealsTab extends StatelessWidget {
  const _MealsTab({required this.meals, required this.supabase});
  final List<Map<String, dynamic>> meals;
  final SupabaseClient supabase;

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return const Center(child: Text('今日の食事記録がありません'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      itemBuilder: (_, i) {
        final meal = meals[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFE0B2),
              child: Icon(
                Icons.restaurant,
                color: Color(0xFFF57C00),
                size: 20,
              ),
            ),
            title: Text(meal['name']?.toString() ?? '食事'),
            subtitle: Text(meal['time']?.toString() ?? ''),
            trailing: Text(
              '${meal['calories'] ?? '—'} kcal',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B35),
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdviceTab extends StatelessWidget {
  const _AdviceTab({required this.advice});
  final String? advice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0A1A0A)
              : const Color(0xFFE8F5E9),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      color: Color(0xFF388E3C),
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'AIヘルスアドバイス',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF388E3C),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  advice ?? 'データが蓄積されるとAIがパーソナライズされたアドバイスを提供します。',
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _HealthTipCard(
          icon: Icons.directions_run,
          color: Color(0xFFFF6B35),
          title: '運動のヒント',
          body: '1日30分の有酸素運動で代謝が10〜15%向上します。'
              'ウォーキングから始めて徐々に強度を上げましょう。',
        ),
        const SizedBox(height: 8),
        const _HealthTipCard(
          icon: Icons.nights_stay,
          color: Color(0xFF3D5AFE),
          title: '睡眠のヒント',
          body: '質の良い睡眠は免疫力・集中力・代謝を改善します。'
              '就寝1時間前のスクリーンタイムを控えましょう。',
        ),
        const SizedBox(height: 8),
        const _HealthTipCard(
          icon: Icons.eco,
          color: Color(0xFF4CAF50),
          title: '食事のヒント',
          body: '野菜・タンパク質・炭水化物のバランスを意識し、'
              '1日1.5〜2Lの水分補給を心がけましょう。',
        ),
      ],
    );
  }
}

class _HealthTipCard extends StatelessWidget {
  const _HealthTipCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (color).withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          body,
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        isThreeLine: true,
      ),
    );
  }
}
