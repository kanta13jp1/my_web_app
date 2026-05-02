import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/meal_nutrition_tracker.dart';

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
  List<Map<String, dynamic>> _recipes = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _weekPlan = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _shoppingList = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
      final recipesRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: <String, dynamic>{'action': 'recipe.list'},
      );
      final planRes = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: <String, dynamic>{'action': 'meal.list_plans'},
      );

      setState(() {
        _recipes = _readMapList(recipesRes.data, 'recipes');
        _weekPlan = _readMapList(planRes.data, 'plans');
        _shoppingList = <Map<String, dynamic>>[];
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _readMapList(Object? data, String key) {
    if (data is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }
    final list = data[key];
    if (list is! List) {
      return <Map<String, dynamic>>[];
    }
    return list.whereType<Map>().map((item) {
      return item.cast<String, dynamic>();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ・食事プランナー'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.restaurant_menu), text: 'レシピ'),
            Tab(icon: Icon(Icons.calendar_today), text: '週間プラン'),
            Tab(icon: Icon(Icons.shopping_cart), text: '買い物'),
            Tab(icon: Icon(Icons.monitor_heart_outlined), text: '栄養ログ'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildRecipesTab(),
                    _buildWeekPlanTab(),
                    _buildShoppingListTab(),
                    const MealNutritionTracker(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
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
          children: <Widget>[
            Icon(Icons.restaurant_menu, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'レシピがありません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final recipe = _recipes[index];
        final name = recipe['name'] as String? ?? 'レシピ ${index + 1}';
        final category = recipe['category'] as String? ?? '';
        final time = recipe['cookingTime'] as int? ?? 0;
        final calories = recipe['calories'] as int? ?? 0;
        final emoji = recipe['emoji'] as String? ?? '🍽️';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            subtitle: Text('$category${time > 0 ? " / $time分" : ""}'),
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
    const days = <String>['月', '火', '水', '木', '金', '土', '日'];
    if (_weekPlan.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.calendar_today,
              size: 64,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            const Text(
              '週間プランがありません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await _supabase.functions.invoke(
                    'lifestyle-hub',
                    body: <String, dynamic>{'action': 'meal.plan'},
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
      itemBuilder: (context, index) {
        final plan = _weekPlan[index];
        final day = days[index % 7];
        final breakfast = plan['breakfast'] as String? ?? '-';
        final lunch = plan['lunch'] as String? ?? '-';
        final dinner = plan['dinner'] as String? ?? '-';
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
          children: <Widget>[
            Icon(Icons.shopping_cart, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '買い物リストが空です',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _shoppingList.length,
      itemBuilder: (context, index) {
        final item = _shoppingList[index];
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
              height: 1.5,
            ),
          ),
          subtitle: Text('$category${qty.isNotEmpty ? " / $qty" : ""}'),
        );
      },
    );
  }
}
