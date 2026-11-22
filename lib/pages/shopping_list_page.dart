import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ShoppingItemsLoader = Future<List<Map<String, dynamic>>> Function(
  String userId,
);
typedef ShoppingItemInserter = Future<void> Function(
  Map<String, dynamic> payload,
);
typedef ShoppingItemPurchaseMarker = Future<bool> Function(
  String userId,
  Map<String, dynamic> item,
  DateTime purchasedAt,
);
typedef ShoppingItemDeleter = Future<bool> Function(
  String userId,
  Object? itemId,
);

/// 日用品買い物リマインダーページ。
/// 箱ティッシュ、コーヒー、調味料など定期的に必要な日用品を管理する。
class ShoppingListPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  final DateTime Function()? nowProvider;
  final ShoppingItemsLoader? loadItems;
  final ShoppingItemInserter? insertItem;
  final ShoppingItemPurchaseMarker? markItemPurchased;
  final ShoppingItemDeleter? deleteItem;

  const ShoppingListPage({
    super.key,
    this.supabaseClient,
    this.nowProvider,
    this.loadItems,
    this.insertItem,
    this.markItemPurchased,
    this.deleteItem,
  });

  static int? safeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final cleaned = value.trim().replaceAll(',', '');
      return int.tryParse(cleaned);
    }
    return null;
  }

  static bool needsBuy(Map<String, dynamic> item, DateTime now) {
    if (item['is_purchased'] == true) return false;
    final remindDate = item['next_remind_date']?.toString();
    if (remindDate == null || remindDate.isEmpty) return true;
    final parsed = DateTime.tryParse(remindDate);
    if (parsed == null) return true;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final remindDay = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    return !remindDay.isAfter(today);
  }

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  bool _loading = true;
  bool _requiresLogin = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _showPurchased = false;
  final Set<String> _purchasingIds = <String>{};

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  DateTime _now() => (widget.nowProvider ?? DateTime.now)();

  static const _categories = <(String, String, IconData, Color)>[
    ('daily', '日用品', Icons.home, Color(0xFF795548)),
    ('food', '食品', Icons.restaurant, Color(0xFFE65100)),
    ('drink', '飲料', Icons.local_cafe, Color(0xFF6D4C41)),
    ('seasoning', '調味料', Icons.soup_kitchen, Color(0xFFC2185B)),
    ('cleaning', '掃除・洗濯', Icons.cleaning_services, Color(0xFF1565C0)),
    ('health', '健康・衛生', Icons.medical_services, Color(0xFF2E7D32)),
    ('pet', 'ペット', Icons.pets, Color(0xFFD84315)),
    ('other', 'その他', Icons.shopping_bag, Color(0xFF455A64)),
  ];

  static const _presets = <(String, String, int)>[
    ('箱ティッシュ', 'daily', 30),
    ('トイレットペーパー', 'daily', 30),
    ('洗剤 (食器用)', 'cleaning', 30),
    ('洗剤 (洗濯用)', 'cleaning', 45),
    ('シャンプー', 'health', 60),
    ('ボディソープ', 'health', 60),
    ('歯磨き粉', 'health', 90),
    ('コーヒー', 'drink', 14),
    ('お茶', 'drink', 14),
    ('水', 'drink', 7),
    ('米', 'food', 30),
    ('醤油', 'seasoning', 60),
    ('塩', 'seasoning', 90),
    ('砂糖', 'seasoning', 90),
    ('食用油', 'seasoning', 60),
    ('ラップ', 'daily', 45),
    ('ゴミ袋', 'daily', 30),
    ('電池', 'daily', 90),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<Map<String, dynamic>>> _defaultLoad(String userId) async {
    final data = await _supabase
        .from('shopping_items')
        .select()
        .eq('user_id', userId)
        .order('is_purchased')
        .order('priority')
        .order('created_at', ascending: false);
    return data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _requiresLogin = false;
      _errorMessage = null;
    });

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _items = <Map<String, dynamic>>[];
        _loading = false;
      });
      return;
    }

    try {
      final loader = widget.loadItems ?? _defaultLoad;
      final rows = await loader(userId);
      if (!mounted) return;
      setState(() {
        _items = rows.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('ShoppingListPage load error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = '買い物リストの読み込みに失敗しました。';
        _loading = false;
      });
    }
  }

  IconData _categoryIcon(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$3;
    }
    return Icons.shopping_bag;
  }

  Color _categoryColor(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$4;
    }
    return const Color(0xFF455A64);
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'urgent':
        return '緊急';
      case 'high':
        return '高';
      case 'low':
        return '低';
      default:
        return '普通';
    }
  }

  (Color fg, Color bg, Color border) _priorityColors(
    String p,
    Brightness brightness,
    ColorScheme colorScheme,
  ) {
    final isDark = brightness == Brightness.dark;
    switch (p) {
      case 'urgent':
        return isDark
            ? (
                const Color(0xFFFFB4AB),
                const Color(0xFF4E1616),
                const Color(0xFFE57373),
              )
            : (
                const Color(0xFFB71C1C),
                const Color(0xFFFFEBEE),
                const Color(0xFFD32F2F),
              );
      case 'high':
        return isDark
            ? (
                const Color(0xFFFFCC80),
                const Color(0xFF3E2209),
                const Color(0xFFFFB74D),
              )
            : (
                const Color(0xFF9A3412),
                const Color(0xFFFFEDD5),
                const Color(0xFFEA580C),
              );
      case 'low':
        return (
          colorScheme.onSurfaceVariant,
          colorScheme.surfaceContainerHighest,
          colorScheme.outlineVariant,
        );
      default:
        return isDark
            ? (
                const Color(0xFFBAC8FF),
                const Color(0xFF162447),
                const Color(0xFF5C7CFA),
              )
            : (
                const Color(0xFF1E3A8A),
                const Color(0xFFE8EEFF),
                const Color(0xFF3D5AFE),
              );
    }
  }

  Future<void> _defaultInsert(Map<String, dynamic> payload) async {
    await _supabase.from('shopping_items').insert(payload);
  }

  Future<bool> _defaultMarkPurchased(
    String userId,
    Map<String, dynamic> item,
    DateTime purchasedAt,
  ) async {
    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty) return false;

    final isRecurring = item['is_recurring'] == true;
    final recurDays =
        (ShoppingListPage.safeInt(item['recurring_days']) ?? 30).clamp(1, 3650);

    final updates = <String, dynamic>{
      'is_purchased': true,
      'purchased_at': purchasedAt.toIso8601String(),
      'last_purchased_at': purchasedAt.toIso8601String(),
      'updated_at': purchasedAt.toIso8601String(),
    };

    if (isRecurring) {
      final nextDate = purchasedAt.add(Duration(days: recurDays));
      updates['next_remind_date'] = DateFormat('yyyy-MM-dd').format(nextDate);
      updates['is_purchased'] = false; // 定期品はリストに残す
    }

    final updated = await _supabase
        .from('shopping_items')
        .update(updates)
        .eq('id', itemId)
        .eq('user_id', userId)
        .select('id');
    if (updated.isEmpty) return false;

    await _supabase.from('shopping_purchase_logs').insert(<String, dynamic>{
      'user_id': userId,
      'item_id': itemId,
      'actual_price': ShoppingListPage.safeInt(item['estimated_price']),
      'shop': item['shop'],
    });
    return true;
  }

  Future<bool> _defaultDelete(String userId, Object? itemId) async {
    if (itemId == null) return false;
    final deleted = await _supabase
        .from('shopping_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', userId)
        .select('id');
    return deleted.isNotEmpty;
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: backgroundColor != null
              ? const TextStyle(color: Colors.white)
              : null,
        ),
        backgroundColor: backgroundColor,
      ),
    );
  }

  Future<void> _addItem({
    String? presetName,
    String? presetCat,
    int? presetDays,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('商品を登録するにはログインしてください。');
      return;
    }

    final input = await showDialog<_NewShoppingItemInput>(
      context: context,
      builder: (_) => _AddShoppingItemDialog(
        categories: _categories,
        presetName: presetName,
        presetCategory: presetCat,
        presetDays: presetDays,
      ),
    );
    if (input == null) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _showSnack('商品を登録するにはログインしてください。');
      return;
    }

    try {
      final inserter = widget.insertItem ?? _defaultInsert;
      await inserter(<String, dynamic>{
        'user_id': currentUserId,
        'name': input.name,
        'category': input.category,
        'quantity': input.quantity,
        'unit': input.unit,
        'estimated_price': input.estimatedPrice,
        'shop': input.shop,
        'priority': input.priority,
        'is_recurring': input.isRecurring,
        'recurring_days': input.recurringDays,
        'note': input.note,
      });
      if (!mounted) return;
      await _load();
      _showSnack('${input.name} を追加しました');
    } catch (e) {
      _showSnack(
        '追加に失敗しました。時間をおいて再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    }
  }

  Future<void> _markPurchased(Map<String, dynamic> item) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('購入を記録するにはログインしてください。');
      return;
    }

    final itemId = item['id']?.toString() ?? '';
    if (itemId.isEmpty || _purchasingIds.contains(itemId)) return;

    final isRecurring = item['is_recurring'] == true;
    final recurDays =
        (ShoppingListPage.safeInt(item['recurring_days']) ?? 30).clamp(1, 3650);

    setState(() => _purchasingIds.add(itemId));
    try {
      final marker = widget.markItemPurchased ?? _defaultMarkPurchased;
      final saved = await marker(userId, item, _now());
      if (!mounted) return;
      if (!saved) {
        _showSnack(
          '購入記録を更新できませんでした。画面を更新してもう一度お試しください。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }
      await _load();
      _showSnack(
        isRecurring ? '購入済みを記録しました ($recurDays日後にリマインド)' : '購入済みを記録しました',
        backgroundColor: const Color(0xFF2E7D32),
      );
    } catch (e) {
      _showSnack(
        '購入の記録に失敗しました。再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    } finally {
      if (mounted) {
        setState(() => _purchasingIds.remove(itemId));
      }
    }
  }

  Future<void> _confirmAndDeleteItem(Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品を削除'),
        content: Text('「$name」を買い物リストから削除しますか？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('削除するにはログインしてください。');
      return;
    }

    try {
      final deleter = widget.deleteItem ?? _defaultDelete;
      final deleted = await deleter(userId, item['id']);
      if (!mounted) return;
      if (!deleted) {
        _showSnack(
          '削除対象が見つからず、削除できませんでした。',
          backgroundColor: const Color(0xFFB71C1C),
        );
        return;
      }
      await _load();
      _showSnack('「$name」を削除しました');
    } catch (e) {
      _showSnack(
        '削除に失敗しました。再試行してください。',
        backgroundColor: const Color(0xFFB71C1C),
      );
    }
  }

  void _openLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _showPresetPicker() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _showSnack('商品を登録するにはログインしてください。');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'よくある日用品を追加',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _presets.map((p) {
                  return ListTile(
                    leading: Icon(
                      _categoryIcon(p.$2),
                      color: _categoryColor(p.$2),
                    ),
                    title: Text(p.$1),
                    subtitle: Text('約${p.$3}日ごと'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      Navigator.pop(ctx);
                      _addItem(
                        presetName: p.$1,
                        presetCat: p.$2,
                        presetDays: p.$3,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = _now();
    final toBuy = _items
        .where(
          (i) => i['is_purchased'] != true || ShoppingListPage.needsBuy(i, now),
        )
        .toList();
    final purchased = _items
        .where(
          (i) =>
              i['is_purchased'] == true && !ShoppingListPage.needsBuy(i, now),
        )
        .toList();
    final urgentCount =
        toBuy.where((i) => ShoppingListPage.needsBuy(i, now)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),
        elevation: 0,
        actions: <Widget>[
          if (purchased.isNotEmpty)
            TextButton.icon(
              key: const Key('shopping_list_toggle_purchased_button'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: () => setState(() => _showPurchased = !_showPurchased),
              icon: Icon(
                _showPurchased ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(_showPurchased ? '非表示' : '購入済み'),
            ),
          if (!_requiresLogin) ...<Widget>[
            IconButton(
              key: const Key('shopping_list_appbar_preset_button'),
              tooltip: 'テンプレートから追加',
              onPressed: _showPresetPicker,
              icon: const Icon(Icons.flash_on),
            ),
            IconButton(
              key: const Key('shopping_list_appbar_add_button'),
              tooltip: '商品を追加',
              onPressed: () => _addItem(),
              icon: const Icon(Icons.add),
            ),
          ],
        ],
      ),
      body: _buildBody(toBuy, purchased, urgentCount, now),
    );
  }

  Widget _buildBody(
    List<Map<String, dynamic>> toBuy,
    List<Map<String, dynamic>> purchased,
    int urgentCount,
    DateTime now,
  ) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_requiresLogin) {
      return _buildSignedOutState();
    }
    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }
    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('shopping_list_header_preset_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: _showPresetPicker,
                icon: const Icon(Icons.flash_on),
                label: const Text('テンプレート'),
              ),
              FilledButton.icon(
                key: const Key('shopping_list_header_add_button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                onPressed: () => _addItem(),
                icon: const Icon(Icons.add),
                label: const Text('商品を追加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (urgentCount > 0) ...<Widget>[
            _buildUrgentBanner(urgentCount),
            const SizedBox(height: 12),
          ],
          ...toBuy.map((item) => _buildItemCard(item, now)),
          if (_showPurchased && purchased.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              '購入済み (${purchased.length}件)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ...purchased.map((item) => _buildItemCard(item, now)),
          ],
        ],
      ),
    );
  }

  Widget _buildSignedOutState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('shopping_list_signed_out_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.lock_outline,
              size: 56,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'ログインすると買い物リストや日用品のリマインダーを管理できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _openLogin,
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('shopping_list_error_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('shopping_list_retry_button'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('shopping_list_empty_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '買い物リストに日用品を追加して\n買い忘れを防ぎましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: <Widget>[
                FilledButton.icon(
                  key: const Key('shopping_list_empty_add_button'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: () => _addItem(),
                  icon: const Icon(Icons.add),
                  label: const Text('商品を追加'),
                ),
                OutlinedButton.icon(
                  key: const Key('shopping_list_empty_preset_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  onPressed: _showPresetPicker,
                  icon: const Icon(Icons.flash_on),
                  label: const Text('テンプレートから追加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentBanner(int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A1F0A) : const Color(0xFFFFF3E0);
    final fgColor = isDark ? const Color(0xFFFFE0B2) : const Color(0xFF7C2D12);
    final borderColor =
        isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('shopping_list_urgent_banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.shopping_cart, color: fgColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count件の買い物が必要です',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: fgColor,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, DateTime now) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final itemId = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    final cat = item['category']?.toString() ?? 'other';
    final qty = ShoppingListPage.safeInt(item['quantity']) ?? 1;
    final unit = item['unit']?.toString() ?? '';
    final price = ShoppingListPage.safeInt(item['estimated_price']);
    final shop = item['shop']?.toString().trim() ?? '';
    final note = item['note']?.toString().trim() ?? '';
    final priority = item['priority']?.toString() ?? 'normal';
    final isPurchased = item['is_purchased'] == true;
    final isRecurring = item['is_recurring'] == true;
    final recurDays = ShoppingListPage.safeInt(item['recurring_days']);
    final needs = ShoppingListPage.needsBuy(item, now);
    final settledPurchased = isPurchased && !needs;
    final isSavingPurchase =
        itemId.isNotEmpty && _purchasingIds.contains(itemId);
    final fmt = NumberFormat('#,###');
    final (prioFg, prioBg, prioBorder) =
        _priorityColors(priority, theme.brightness, colorScheme);
    final repeatAccent =
        isDark ? const Color(0xFFBAC8FF) : const Color(0xFF1E3A8A);

    return Dismissible(
      key: ValueKey<Object?>(item['id'] ?? name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3A1010) : const Color(0xFFFFCDD2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          Icons.delete,
          color: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFB71C1C),
        ),
      ),
      confirmDismiss: (_) async {
        await _confirmAndDeleteItem(item);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: needs
                ? prioBorder.withValues(alpha: 0.55)
                : colorScheme.surfaceContainerHigh,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: settledPurchased
                          ? colorScheme.surfaceContainerHigh
                          : _categoryColor(cat).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      settledPurchased ? Icons.check : _categoryIcon(cat),
                      color: settledPurchased
                          ? colorScheme.onSurfaceVariant
                          : _categoryColor(cat),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                decoration: settledPurchased
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: settledPurchased
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                            if (!settledPurchased &&
                                (priority == 'urgent' || priority == 'high'))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: prioBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: prioBorder.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  _priorityLabel(priority),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: prioFg,
                                  ),
                                ),
                              ),
                            if (isRecurring)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.repeat,
                                    size: 14,
                                    color: repeatAccent,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    recurDays != null ? '$recurDays日ごと' : '定期',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: repeatAccent,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text(
                              '$qty${unit.isNotEmpty ? unit : '個'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            if (price != null)
                              Text(
                                '¥${fmt.format(price)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            if (shop.isNotEmpty)
                              Text(
                                shop,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                          ],
                        ),
                        if (note.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            note,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (settledPurchased)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF14331B)
                            : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: isDark
                                ? const Color(0xFFA5D6A7)
                                : const Color(0xFF1B5E20),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '購入済み',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFA5D6A7)
                                  : const Color(0xFF1B5E20),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                      ),
                      onPressed:
                          isSavingPurchase ? null : () => _markPurchased(item),
                      icon: isSavingPurchase
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(isSavingPurchase ? '記録中' : '購入完了'),
                    ),
                  IconButton(
                    tooltip: '削除',
                    onPressed: () => _confirmAndDeleteItem(item),
                    icon: Icon(
                      Icons.delete_outline,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewShoppingItemInput {
  final String name;
  final String category;
  final int quantity;
  final String? unit;
  final int? estimatedPrice;
  final String? shop;
  final String priority;
  final bool isRecurring;
  final int? recurringDays;
  final String? note;

  const _NewShoppingItemInput({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.estimatedPrice,
    required this.shop,
    required this.priority,
    required this.isRecurring,
    required this.recurringDays,
    required this.note,
  });
}

class _AddShoppingItemDialog extends StatefulWidget {
  final List<(String, String, IconData, Color)> categories;
  final String? presetName;
  final String? presetCategory;
  final int? presetDays;

  const _AddShoppingItemDialog({
    required this.categories,
    this.presetName,
    this.presetCategory,
    this.presetDays,
  });

  @override
  State<_AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<_AddShoppingItemDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _shopCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _recurringCtrl;

  late String _selectedCategory;
  String _selectedPriority = 'normal';
  late bool _isRecurring;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.presetName ?? '');
    _qtyCtrl = TextEditingController(text: '1');
    _unitCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _shopCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _recurringCtrl = TextEditingController(
      text: widget.presetDays?.toString() ?? '30',
    );
    _selectedCategory = widget.presetCategory ?? 'daily';
    _isRecurring = widget.presetDays != null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _shopCtrl.dispose();
    _noteCtrl.dispose();
    _recurringCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '品名を入力してください');
      return;
    }

    final unitText = _unitCtrl.text.trim();
    final shopText = _shopCtrl.text.trim();
    final noteText = _noteCtrl.text.trim();
    final qty = (int.tryParse(_qtyCtrl.text.trim()) ?? 1).clamp(1, 9999);
    final recurDays =
        (int.tryParse(_recurringCtrl.text.trim()) ?? 30).clamp(1, 3650);

    Navigator.pop(
      context,
      _NewShoppingItemInput(
        name: name,
        category: _selectedCategory,
        quantity: qty,
        unit: unitText.isEmpty ? null : unitText,
        estimatedPrice: int.tryParse(_priceCtrl.text.trim()),
        shop: shopText.isEmpty ? null : shopText,
        priority: _selectedPriority,
        isRecurring: _isRecurring,
        recurringDays: _isRecurring ? recurDays : null,
        note: noteText.isEmpty ? null : noteText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380 ||
        MediaQuery.textScalerOf(context).scale(16) > 22;
    final qtyField = TextField(
      controller: _qtyCtrl,
      decoration: const InputDecoration(
        labelText: '数量',
        prefixIcon: Icon(Icons.numbers),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
    final unitField = TextField(
      controller: _unitCtrl,
      decoration: const InputDecoration(
        labelText: '単位',
        hintText: '個, 箱, 本',
      ),
    );
    final priceField = TextField(
      controller: _priceCtrl,
      decoration: const InputDecoration(
        labelText: '目安金額',
        prefixIcon: Icon(Icons.currency_yen),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
    final shopField = TextField(
      controller: _shopCtrl,
      decoration: const InputDecoration(
        labelText: '購入店',
        hintText: 'Amazon, ドラッグストア',
      ),
    );

    return AlertDialog(
      title: const Text('買い物リストに追加'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: '品名 *',
                hintText: '箱ティッシュ、コーヒー など',
                errorText: _nameError,
                prefixIcon: const Icon(Icons.shopping_cart),
              ),
              autofocus: widget.presetName == null,
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: 10),
            if (compact) ...<Widget>[
              qtyField,
              const SizedBox(height: 10),
              unitField,
            ] else
              Row(
                children: <Widget>[
                  Expanded(flex: 2, child: qtyField),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: unitField),
                ],
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                prefixIcon: Icon(Icons.category),
              ),
              items: widget.categories.map((c) {
                return DropdownMenuItem<String>(
                  value: c.$1,
                  child: Row(
                    children: <Widget>[
                      Icon(c.$3, size: 18, color: c.$4),
                      const SizedBox(width: 8),
                      Text(c.$2),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedCategory = v);
                }
              },
            ),
            const SizedBox(height: 10),
            if (compact) ...<Widget>[
              priceField,
              const SizedBox(height: 10),
              shopField,
            ] else
              Row(
                children: <Widget>[
                  Expanded(child: priceField),
                  const SizedBox(width: 8),
                  Expanded(child: shopField),
                ],
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              decoration: const InputDecoration(
                labelText: '優先度',
                prefixIcon: Icon(Icons.flag),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'urgent', child: Text('緊急')),
                DropdownMenuItem<String>(value: 'high', child: Text('高')),
                DropdownMenuItem<String>(value: 'normal', child: Text('普通')),
                DropdownMenuItem<String>(value: 'low', child: Text('低')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _selectedPriority = v);
                }
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('定期リマインド'),
              subtitle: const Text('一定日数ごとにリマインド'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isRecurring)
              TextField(
                controller: _recurringCtrl,
                decoration: const InputDecoration(
                  labelText: 'リマインド間隔 (日)',
                  hintText: '30',
                  prefixIcon: Icon(Icons.repeat),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ',
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('追加'),
        ),
      ],
    );
  }
}
