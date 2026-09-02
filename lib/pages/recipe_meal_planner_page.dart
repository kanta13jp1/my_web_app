import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/meal_nutrition_tracker.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

const _accentOrange = Color(0xFFFF6B35);
const _accentIndigo = Color(0xFF3D5AFE);
const _softText = Color(0xFF6B7280);

const _mealTypes = [
  _MealTypeOption(
    value: 'breakfast',
    label: '朝食',
    shortLabel: '朝',
    emoji: '🌅',
    icon: Icons.wb_twilight,
  ),
  _MealTypeOption(
    value: 'lunch',
    label: '昼食',
    shortLabel: '昼',
    emoji: '🌞',
    icon: Icons.wb_sunny_outlined,
  ),
  _MealTypeOption(
    value: 'dinner',
    label: '夜食',
    shortLabel: '夜',
    emoji: '🌙',
    icon: Icons.dinner_dining,
  ),
  _MealTypeOption(
    value: 'snack',
    label: '間食',
    shortLabel: '間食',
    emoji: '🍪',
    icon: Icons.cookie_outlined,
  ),
];

/// レシピ・食事プランナーページ
/// レシピ管理・週間食事計画・買い物リスト・食事ログを扱う。
class RecipeMealPlannerPage extends StatefulWidget {
  const RecipeMealPlannerPage({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  State<RecipeMealPlannerPage> createState() => _RecipeMealPlannerPageState();
}

class _RecipeMealPlannerPageState extends State<RecipeMealPlannerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  // タブ: レシピ / 週間プラン / 買い物リスト / 食事ログ / 栄養ログ
  @override
  List<String> get tabUrlSlugs => const <String>[
        'recipes',
        'weekly-plan',
        'shopping-list',
        'meal-log',
        'nutrition-log',
      ];

  @override
  TabController get tabUrlController => _tabController;

  late final SupabaseClient _supabase;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _weekPlan = [];
  List<Map<String, dynamic>> _shoppingList = [];
  List<Map<String, dynamic>> _mealLogs = [];
  Map<String, dynamic> _todaySummary = const {};

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _tabController = TabController(length: 5, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _invokeHub(Map<String, dynamic> body) async {
    final response = await _supabase.functions.invoke(
      'lifestyle-hub',
      body: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error != null) {
        throw Exception(error);
      }
      return data;
    }
    if (data is Map) {
      final mapped = Map<String, dynamic>.from(data);
      final error = mapped['error'];
      if (error != null) {
        throw Exception(error);
      }
      return mapped;
    }
    return {};
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _recipes = [];
        _weekPlan = [];
        _shoppingList = [];
        _mealLogs = [];
        _todaySummary = const {};
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final recipesRes = await _invokeHub({'action': 'recipe.list'});
      final planRes = await _invokeHub({'action': 'meal.list_plans'});
      final logsRes = await _invokeHub({'action': 'meal_log.list'});
      final summaryRes = await _invokeHub({'action': 'meal_log.summary_today'});

      setState(() {
        _recipes = _mapList(recipesRes['recipes']);
        _weekPlan = _mapList(planRes['plans']);
        _mealLogs = _mapList(logsRes['logs']);
        _todaySummary = summaryRes;
        _shoppingList = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
            Tab(icon: Icon(Icons.dinner_dining), text: '食事ログ'),
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
                  children: [
                    _buildRecipesTab(),
                    _buildWeekPlanTab(),
                    _buildShoppingListTab(),
                    _buildMealLogTab(),
                    const MealNutritionTracker(),
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

  Widget _buildRecipesTab() {
    if (_recipes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20, height: 1.5),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            subtitle: Text('$category${time > 0 ? " · $time分" : ""}'),
            trailing: calories > 0
                ? Chip(
                    label: Text('${calories}kcal'),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.secondaryContainer,
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
                  await _invokeHub({'action': 'meal.plan'});
                  await _fetchData();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('エラー: $e')));
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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
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
              height: 1.5,
            ),
          ),
          subtitle: Text('$category${qty.isNotEmpty ? " · $qty" : ""}'),
        );
      },
    );
  }

  Widget _buildMealLogTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mealType in _mealTypes)
                ElevatedButton.icon(
                  onPressed: () => _showMealLogInputDialog(mealType),
                  icon: Icon(mealType.icon),
                  label: Text('+ ${mealType.label}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentOrange,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildMealLogSummary(),
          const SizedBox(height: 16),
          Text(
            '本日のログ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_mealLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'まだ食事ログがありません',
                  style: TextStyle(color: _softText, height: 1.5),
                ),
              ),
            )
          else
            for (final log in _mealLogs) _buildMealLogCard(log),
        ],
      ),
    );
  }

  Widget _buildMealLogSummary() {
    final byType = _safeMap(_todaySummary['by_meal_type']);
    final kcal = _toNum(_todaySummary['kcal_total']);
    final protein = _toNum(_todaySummary['protein_g_total']);
    final fat = _toNum(_todaySummary['fat_g_total']);
    final carb = _toNum(_todaySummary['carb_g_total']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: _accentIndigo),
                const SizedBox(width: 8),
                Text(
                  '本日のサマリ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '合計 ${_formatNumber(kcal)} kcal',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _accentIndigo,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'P: ${_formatNumber(protein)} g  /  F: ${_formatNumber(fat)} g  /  C: ${_formatNumber(carb)} g',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final mealType in _mealTypes)
                  Text(
                    '${mealType.shortLabel}: ${_formatNumber(_toNum(byType[mealType.value]))} kcal',
                    style: const TextStyle(color: _softText),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealLogCard(Map<String, dynamic> log) {
    final mealType = _mealTypeFor(log['meal_type']);
    final menuName = (log['menu_name'] as String?) ?? '食事ログ';
    final storeName = (log['store_name'] as String?) ?? '';
    final kcal = _toNum(log['kcal']);
    final protein = _toNum(log['protein_g']);
    final fat = _toNum(log['fat_g']);
    final carb = _toNum(log['carb_g']);
    final vegetablesNote = (log['vegetables_note'] as String?) ?? '';
    final saltNote = (log['salt_note'] as String?) ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFEEE8),
          child: Text(mealType.emoji),
        ),
        title: Text(
          '${mealType.shortLabel} ${_formatLoggedAt(log['logged_at'])} / $menuName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (storeName.isNotEmpty) Text(storeName),
              Text(
                '${_formatNumber(kcal)} kcal / P ${_formatNumber(protein)} g / F ${_formatNumber(fat)} g / C ${_formatNumber(carb)} g',
              ),
              if (vegetablesNote.isNotEmpty || saltNote.isNotEmpty)
                Text(
                  [
                    if (vegetablesNote.isNotEmpty) '野菜: $vegetablesNote',
                    if (saltNote.isNotEmpty) '塩分: $saltNote',
                  ].join('  /  '),
                  style: const TextStyle(color: _softText),
                ),
            ],
          ),
        ),
        trailing: Tooltip(
          message: '削除',
          child: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: _softText,
            onPressed: () => _deleteMealLog(log),
          ),
        ),
      ),
    );
  }

  Future<void> _showMealLogInputDialog(_MealTypeOption mealType) async {
    final menuController = TextEditingController();
    final storeController = TextEditingController();
    final kcalController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbController = TextEditingController();
    final vegetablesController = TextEditingController();
    final saltController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSaving = false;
          String? localError;

          Future<void> submit(
            void Function(void Function()) setDialogState,
          ) async {
            final menuName = menuController.text.trim();
            if (menuName.isEmpty) {
              setDialogState(() => localError = 'メニュー名を入力してください');
              return;
            }

            setDialogState(() {
              isSaving = true;
              localError = null;
            });

            final payload = <String, dynamic>{
              'action': 'meal_log.add',
              'meal_type': mealType.value,
              'menu_name': menuName,
              'store_name': _optionalText(storeController),
              'kcal': _optionalInt(kcalController),
              'protein_g': _optionalNumber(proteinController),
              'fat_g': _optionalNumber(fatController),
              'carb_g': _optionalNumber(carbController),
              'vegetables_note': _optionalText(vegetablesController),
              'salt_note': _optionalText(saltController),
            };

            try {
              await _invokeHub(payload);
              if (!mounted || !dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              await _fetchData();
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('食事ログを追加しました')));
            } catch (e) {
              if (!mounted || !dialogContext.mounted) return;
              setDialogState(() {
                localError = '$e';
                isSaving = false;
              });
            }
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('${mealType.label}を記録'),
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: menuController,
                          decoration: const InputDecoration(
                            labelText: 'メニュー名',
                            prefixIcon: Icon(Icons.restaurant),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: storeController,
                          decoration: const InputDecoration(
                            labelText: '外食チェーン名',
                            prefixIcon: Icon(Icons.storefront),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 10),
                        _numberField(kcalController, '概算 kcal'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _numberField(proteinController, 'たんぱく質 g'),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _numberField(fatController, '脂質 g'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _numberField(carbController, '炭水化物 g'),
                        const SizedBox(height: 10),
                        TextField(
                          controller: vegetablesController,
                          decoration: const InputDecoration(
                            labelText: '野菜メモ',
                            prefixIcon: Icon(Icons.eco_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: saltController,
                          decoration: const InputDecoration(
                            labelText: '塩分メモ',
                            prefixIcon: Icon(Icons.grain_outlined),
                          ),
                        ),
                        if (localError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            localError!,
                            style: const TextStyle(color: Color(0xFFE53935)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('キャンセル'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () => submit(setDialogState),
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('保存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      menuController.dispose();
      storeController.dispose();
      kcalController.dispose();
      proteinController.dispose();
      fatController.dispose();
      carbController.dispose();
      vegetablesController.dispose();
      saltController.dispose();
    }
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calculate_outlined),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
    );
  }

  Future<void> _deleteMealLog(Map<String, dynamic> log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('食事ログを削除'),
        content: Text('${log['menu_name'] ?? 'このログ'}を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _invokeHub({'action': 'meal_log.delete', 'id': log['id']});
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事ログを削除しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除できませんでした: $e')));
    }
  }

  Map<String, dynamic> _safeMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  _MealTypeOption _mealTypeFor(Object? value) {
    return _mealTypes.firstWhere(
      (option) => option.value == value,
      orElse: () => _mealTypes.first,
    );
  }

  num _toNum(Object? value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String _formatLoggedAt(Object? value) {
    if (value is! String || value.isEmpty) return '--:--';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '--:--';
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  int? _optionalInt(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  num? _optionalNumber(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }
}

class _MealTypeOption {
  const _MealTypeOption({
    required this.value,
    required this.label,
    required this.shortLabel,
    required this.emoji,
    required this.icon,
  });

  final String value;
  final String label;
  final String shortLabel;
  final String emoji;
  final IconData icon;
}
