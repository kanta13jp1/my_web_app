import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// レシピ・食事プランナーページ
/// recipe-meal-planner Edge Function と連携
/// Amazon Fresh / Liven / クックパッド 競合
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
  List<Map<String, dynamic>> _mealPlan = [];
  List<Map<String, dynamic>> _shoppingList = [];
  List<String> _categories = [];
  String _selectedCategory = 'すべて';

  final _recipeNameCtrl = TextEditingController();
  final _ingredientsCtrl = TextEditingController();
  final _cookTimeCtrl = TextEditingController();
  String _selectedRecipeCategory = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchOptions();
    _fetchRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipeNameCtrl.dispose();
    _ingredientsCtrl.dispose();
    _cookTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final response = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'options'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _categories = ['すべて', ...((data['categories'] as List?)?.cast<String>() ?? [])];
          if (_selectedRecipeCategory.isEmpty && _categories.length > 1) {
            _selectedRecipeCategory = _categories[1];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchRecipes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final params = <String, String>{'view': 'recipes'};
      if (_selectedCategory != 'すべて') params['category'] = _selectedCategory;
      final response = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: params,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['recipes'] is List) {
        setState(() => _recipes = (data['recipes'] as List).cast<Map<String, dynamic>>());
      } else {
        setState(() => _recipes = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'レシピの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMealPlan() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'meal_plan'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['mealPlan'] is List) {
        setState(() => _mealPlan = (data['mealPlan'] as List).cast<Map<String, dynamic>>());
      } else {
        setState(() => _mealPlan = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '献立の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchShoppingList() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'recipe-meal-planner',
        queryParameters: {'view': 'shopping_list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] is List) {
        setState(() => _shoppingList = (data['items'] as List).cast<Map<String, dynamic>>());
      } else {
        setState(() => _shoppingList = []);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '買い物リストの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addRecipe() async {
    _recipeNameCtrl.clear();
    _ingredientsCtrl.clear();
    _cookTimeCtrl.clear();
    if (_categories.length > 1) _selectedRecipeCategory = _categories[1];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt) => AlertDialog(
          title: const Text('レシピを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _recipeNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'レシピ名',
                    hintText: '例: 肉じゃが',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ingredientsCtrl,
                  decoration: const InputDecoration(
                    labelText: '材料 (カンマ区切り)',
                    hintText: '例: じゃがいも, 牛肉, 玉ねぎ',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _cookTimeCtrl,
                  decoration: const InputDecoration(
                    labelText: '調理時間 (分)',
                    hintText: '例: 30',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                if (_categories.length > 1) ...[
                  const Text('カテゴリ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  DropdownButton<String>(
                    value: _selectedRecipeCategory.isNotEmpty &&
                            _categories.contains(_selectedRecipeCategory)
                        ? _selectedRecipeCategory
                        : _categories.length > 1
                            ? _categories[1]
                            : null,
                    isExpanded: true,
                    items: _categories.skip(1).map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (v) => setSt(() => _selectedRecipeCategory = v ?? ''),
                  ),
                ],
              ],
            ),
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
      ),
    );
    if (confirmed != true) return;
    if (_recipeNameCtrl.text.trim().isEmpty) return;
    try {
      final ingredients = _ingredientsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final cookTime = int.tryParse(_cookTimeCtrl.text.trim()) ?? 0;
      await _supabase.functions.invoke(
        'recipe-meal-planner',
        body: {
          'action': 'create_recipe',
          'name': _recipeNameCtrl.text.trim(),
          'ingredients': ingredients,
          'cook_time_minutes': cookTime,
          'category': _selectedRecipeCategory,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レシピを追加しました')),
        );
      }
      await _fetchRecipes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _generateShoppingList() async {
    try {
      await _supabase.functions.invoke(
        'recipe-meal-planner',
        body: {'action': 'generate_shopping_list'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('買い物リストを生成しました')),
        );
      }
      await _fetchShoppingList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成に失敗しました: $e')),
        );
      }
    }
  }

  Color _mealTypeColor(String type) {
    switch (type) {
      case 'breakfast': return Colors.orange;
      case 'lunch': return Colors.green;
      case 'dinner': return Colors.indigo;
      case 'snack': return Colors.pink;
      default: return Colors.grey;
    }
  }

  String _mealTypeLabel(String type) {
    switch (type) {
      case 'breakfast': return '朝食';
      case 'lunch': return '昼食';
      case 'dinner': return '夕食';
      case 'snack': return '間食';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レシピ・食事プランナー'),
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (i) {
            if (i == 1) _fetchMealPlan();
            if (i == 2) _fetchShoppingList();
          },
          tabs: const [
            Tab(icon: Icon(Icons.restaurant_menu), text: 'レシピ'),
            Tab(icon: Icon(Icons.calendar_today), text: '献立'),
            Tab(icon: Icon(Icons.shopping_cart), text: '買い物'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: () {
              if (_tabController.index == 0) _fetchRecipes();
              if (_tabController.index == 1) _fetchMealPlan();
              if (_tabController.index == 2) _fetchShoppingList();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecipe,
        backgroundColor: const Color(0xFFEF4444),
        tooltip: 'レシピを追加',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _fetchRecipes, child: const Text('再試行')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRecipesTab(),
                    _buildMealPlanTab(),
                    _buildShoppingListTab(),
                  ],
                ),
    );
  }

  Widget _buildRecipesTab() {
    return Column(
      children: [
        // Category filter
        if (_categories.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (v) {
                      setState(() => _selectedCategory = cat);
                      _fetchRecipes();
                    },
                    selectedColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFFEF4444),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _recipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('レシピがありません', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _addRecipe,
                        icon: const Icon(Icons.add),
                        label: const Text('レシピを追加'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 160,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _recipes[index];
                    final name = recipe['name']?.toString() ?? '';
                    final category = recipe['category']?.toString() ?? '';
                    final cookTime = (recipe['cookTimeMinutes'] as num?)?.toInt() ??
                        (recipe['cook_time_minutes'] as num?)?.toInt() ?? 0;
                    final ingredients = (recipe['ingredients'] as List?)?.cast<String>() ?? [];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (category.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Chip(
                                  label: Text(category, style: const TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                ),
                              ),
                            if (cookTime > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.timer, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('$cookTime分', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            if (ingredients.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  ingredients.take(3).join('、') + (ingredients.length > 3 ? '...' : ''),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMealPlanTab() {
    if (_mealPlan.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('献立がありません', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _mealPlan.length,
      itemBuilder: (context, index) {
        final plan = _mealPlan[index];
        final date = plan['date']?.toString() ?? '';
        final mealType = plan['meal_type']?.toString() ?? plan['mealType']?.toString() ?? '';
        final recipeName = plan['recipe_name']?.toString() ?? plan['recipeName']?.toString() ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _mealTypeColor(mealType).withValues(alpha: 0.15),
              child: Icon(Icons.restaurant, color: _mealTypeColor(mealType), size: 20),
            ),
            title: Text(recipeName.isNotEmpty ? recipeName : '未設定'),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _mealTypeColor(mealType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _mealTypeLabel(mealType),
                    style: TextStyle(fontSize: 11, color: _mealTypeColor(mealType)),
                  ),
                ),
                const SizedBox(width: 8),
                if (date.isNotEmpty)
                  Text(
                    date.length > 10 ? date.substring(0, 10) : date,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShoppingListTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(
                '買い物リスト (${_shoppingList.length}件)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _generateShoppingList,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('自動生成'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _shoppingList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_cart, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('買い物リストがありません', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _generateShoppingList,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('献立から自動生成'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _shoppingList.length,
                  itemBuilder: (context, index) {
                    final item = _shoppingList[index];
                    final name = item['name']?.toString() ?? item['ingredient']?.toString() ?? '';
                    final qty = item['quantity']?.toString() ?? '';
                    return Card(
                      child: CheckboxListTile(
                        value: item['checked'] as bool? ?? false,
                        onChanged: (_) {},
                        title: Text(name),
                        subtitle: qty.isNotEmpty ? Text(qty, style: const TextStyle(fontSize: 12)) : null,
                        activeColor: const Color(0xFFEF4444),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
