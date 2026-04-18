import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// レシピ・食事プランナーページ
/// レシピ管理・週間食事計画・買い物リスト自動生成。
/// recipe-meal-planner Edge Function と連携。
class RecipeMealPlannerPage extends StatefulWidget {
  const RecipeMealPlannerPage({super.key});

  @override
  State<RecipeMealPlannerPage> createState() => _RecipeMealPlannerPageState();
}

class _RecipeMealPlannerPageState extends State<RecipeMealPlannerPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _weekPlan = [];
  List<Map<String, dynamic>> _shoppingList = [];

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final recipesRes = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'recipes'},
      );
      final planRes = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'weekly_plan'},
      );
      final shoppingRes = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'shopping_list'},
      );

      setState(() {
        final rd = recipesRes.data;
        if (rd is Map<String, dynamic>) {
          final list = rd['recipes'];
          if (list is List) {
            _recipes = list.map((r) => r as Map<String, dynamic>).toList();
          }
        }

        final pd = planRes.data;
        if (pd is Map<String, dynamic>) {
          final list = pd['plan'];
          if (list is List) {
            _weekPlan = list.map((p) => p as Map<String, dynamic>).toList();
          }
        }

        final sd = shoppingRes.data;
        if (sd is Map<String, dynamic>) {
          final list = sd['items'];
          if (list is List) {
            _shoppingList = list.map((s) => s as Map<String, dynamic>).toList();
          }
        }
      });
    } catch (e) {
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ・食事プランナー'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'レシピ'),
            Tab(icon: Icon(Icons.calendar_today), text: '週間プラン'),
            Tab(icon: Icon(Icons.shopping_cart), text: '買い物リスト'),
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
                    _buildRecipesTab(),
                    _buildWeekPlanTab(),
                    _buildShoppingListTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildRecipesTab() {
    if (_recipes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu,
                size: 64, color: const Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('レシピがありません', style: TextStyle(color: const Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recipes.length,
      itemBuilder: (ctx, i) {
        final r = _recipes[i];
        final name = r['name'] as String? ?? 'レシピ ${i + 1}';
        final category = r['category'] as String? ?? '';
        final time = r['cookingTime'] as int? ?? 0;
        final calories = r['calories'] as int? ?? 0;
        final emoji = r['emoji'] as String? ?? '🍽️';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$category${time > 0 ? " · $time分" : ""}'),
            trailing: calories > 0
                ? Chip(
                    label: Text('${calories}kcal'),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildWeekPlanTab() {
    const days = ['月', '火', '水', '木', '金', '土', '日'];
    if (_weekPlan.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today,
                size: 64, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text('週間プランがありません',
                style: TextStyle(color: const Color(0xFF9CA3AF))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await _supabase.functions.invoke(
                    'recipe-meal-planner',
                    body: {'action': 'generate_weekly_plan'},
                  );
                  await _fetchData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラー: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('AIで自動生成'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _weekPlan.length,
      itemBuilder: (ctx, i) {
        final p = _weekPlan[i];
        final day = days[i % 7];
        final breakfast = p['breakfast'] as String? ?? '-';
        final lunch = p['lunch'] as String? ?? '-';
        final dinner = p['dinner'] as String? ?? '-';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text('朝: $breakfast'),
            subtitle: Text('昼: $lunch\n夜: $dinner'),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildShoppingListTab() {
    if (_shoppingList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 64, color: const Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text('買い物リストが空です',
                style: TextStyle(color: const Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _shoppingList.length,
      itemBuilder: (ctx, i) {
        final item = _shoppingList[i];
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as String? ?? '';
        final category = item['category'] as String? ?? '';
        final bought = item['bought'] as bool? ?? false;
        return CheckboxListTile(
          value: bought,
          onChanged: (_) {},
          title: Text(
            name,
            style: TextStyle(
              decoration: bought ? TextDecoration.lineThrough : null,
              color: bought ? const Color(0xFF9CA3AF) : null,
            ),
          ),
          subtitle: Text('$category${qty.isNotEmpty ? " · $qty" : ""}'),
        );
      },
    );
  }
}
