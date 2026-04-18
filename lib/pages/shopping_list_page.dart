import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 日用品買い物リマインダーページ。
/// 箱ティッシュ、コーヒー、調味料など定期的に必要な日用品を管理する。
class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  bool _showPurchased = false;

  static const _categories = [
    ('daily', '日用品', Icons.home, Color(0xFF795548)),
    ('food', '食品', Icons.restaurant, Color(0xFFFF9800)),
    ('drink', '飲料', Icons.local_cafe, Color(0xFF6D4C41)),
    ('seasoning', '調味料', Icons.soup_kitchen, Color(0xFFE91E63)),
    ('cleaning', '掃除・洗濯', Icons.cleaning_services, Color(0xFF2196F3)),
    ('health', '健康・衛生', Icons.medical_services, Color(0xFF4CAF50)),
    ('pet', 'ペット', Icons.pets, Color(0xFFFF5722)),
    ('other', 'その他', Icons.shopping_bag, Color(0xFF607D8B)),
  ];

  static const _presets = [
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

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('shopping_items')
          .select()
          .eq('user_id', userId)
          .order('is_purchased')
          .order('priority')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ShoppingListPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _needsBuy(Map<String, dynamic> item) {
    if (item['is_purchased'] == true) return false;
    final remindDate = item['next_remind_date']?.toString();
    if (remindDate == null || remindDate.isEmpty) return true;
    final rd = DateTime.tryParse(remindDate);
    if (rd == null) return true;
    return !rd.isAfter(DateTime.now());
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
    return const Color(0xFF607D8B);
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return const Color(0xFF9CA3AF);
      default:
        return Colors.blue;
    }
  }

  Future<void> _addItem({
    String? presetName,
    String? presetCat,
    int? presetDays,
  }) async {
    final nameCtrl = TextEditingController(text: presetName ?? '');
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final shopCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = presetCat ?? 'daily';
    String selectedPriority = 'normal';
    bool isRecurring = presetDays != null;
    final recurringCtrl = TextEditingController(
      text: presetDays?.toString() ?? '30',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('買い物リストに追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '品名 *',
                    hintText: '箱ティッシュ、コーヒー など',
                    prefixIcon: Icon(Icons.shopping_cart),
                  ),
                  autofocus: presetName == null,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: qtyCtrl,
                        decoration: const InputDecoration(
                          labelText: '数量',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: '単位',
                          hintText: '個, 箱, 本',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c.$1,
                      child: Row(
                        children: [
                          Icon(c.$3, size: 18, color: c.$4),
                          const SizedBox(width: 8),
                          Text(c.$2),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => selectedCategory = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        decoration: const InputDecoration(
                          labelText: '目安金額',
                          prefixIcon: Icon(Icons.currency_yen),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: shopCtrl,
                        decoration: const InputDecoration(
                          labelText: '購入店',
                          hintText: 'Amazon, ドラッグストア',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: '優先度',
                    prefixIcon: Icon(Icons.flag),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'urgent', child: Text('🔴 緊急')),
                    DropdownMenuItem(value: 'high', child: Text('🟠 高')),
                    DropdownMenuItem(value: 'normal', child: Text('🔵 普通')),
                    DropdownMenuItem(value: 'low', child: Text('⚪ 低')),
                  ],
                  onChanged: (v) {
                    if (v != null) setD(() => selectedPriority = v);
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('定期リマインド'),
                  subtitle: const Text('一定日数ごとにリマインド'),
                  value: isRecurring,
                  onChanged: (v) => setD(() => isRecurring = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isRecurring)
                  TextField(
                    controller: recurringCtrl,
                    decoration: const InputDecoration(
                      labelText: 'リマインド間隔 (日)',
                      hintText: '30',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final recurDays = int.tryParse(recurringCtrl.text) ?? 30;

    try {
      await _supabase.from('shopping_items').insert({
        'user_id': userId,
        'name': name,
        'category': selectedCategory,
        'quantity': int.tryParse(qtyCtrl.text) ?? 1,
        'unit': unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
        'estimated_price': int.tryParse(priceCtrl.text),
        'shop': shopCtrl.text.trim().isEmpty ? null : shopCtrl.text.trim(),
        'priority': selectedPriority,
        'is_recurring': isRecurring,
        'recurring_days': isRecurring ? recurDays : null,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markPurchased(Map<String, dynamic> item) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final isRecurring = item['is_recurring'] == true;
    final recurDays = item['recurring_days'] as int? ?? 30;
    final now = DateTime.now();

    try {
      final updates = <String, dynamic>{
        'is_purchased': true,
        'purchased_at': now.toIso8601String(),
        'last_purchased_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      if (isRecurring) {
        final nextDate = now.add(Duration(days: recurDays));
        updates['next_remind_date'] = DateFormat('yyyy-MM-dd').format(nextDate);
        updates['is_purchased'] = false; // 定期品はリストに残す
      }

      await _supabase
          .from('shopping_items')
          .update(updates)
          .eq('id', item['id']);

      await _supabase.from('shopping_purchase_logs').insert({
        'user_id': userId,
        'item_id': item['id'],
        'actual_price': item['estimated_price'],
        'shop': item['shop'],
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRecurring ? '✅ 購入済み ($recurDays日後にリマインド)' : '✅ 購入済み',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {
      await _supabase
          .from('shopping_items')
          .delete()
          .eq('id', item['id'])
          .select();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toBuy =
        _items.where((i) => i['is_purchased'] != true || _needsBuy(i)).toList();
    final purchased = _items
        .where((i) => i['is_purchased'] == true && !_needsBuy(i))
        .toList();
    final urgentCount = toBuy.where(_needsBuy).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('買い物リスト'),
        elevation: 0,
        actions: [
          if (purchased.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _showPurchased = !_showPurchased),
              icon: Icon(
                _showPurchased ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(_showPurchased ? '非表示' : '購入済み'),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'preset',
            onPressed: _showPresetPicker,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.flash_on),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: () => _addItem(),
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (urgentCount > 0) _buildUrgentBanner(urgentCount),
                    if (urgentCount > 0) const SizedBox(height: 12),
                    ...toBuy.map(_buildItemCard),
                    if (_showPurchased && purchased.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '購入済み (${purchased.length}件)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...purchased.map(_buildItemCard),
                    ],
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              '買い物リストに日用品を追加して\n買い忘れを防ぎましょう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showPresetPicker,
              icon: const Icon(Icons.flash_on),
              label: const Text('テンプレートから追加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPresetPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'よくある日用品を追加',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _buildUrgentBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart, color: Colors.orange),
          const SizedBox(width: 10),
          Text(
            '🛒 $count件の買い物が必要です',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final cat = item['category']?.toString() ?? 'other';
    final qty = item['quantity'] as int? ?? 1;
    final unit = item['unit']?.toString() ?? '';
    final price = item['estimated_price'] as int?;
    final shop = item['shop']?.toString();
    final priority = item['priority']?.toString() ?? 'normal';
    final isPurchased = item['is_purchased'] == true;
    final isRecurring = item['is_recurring'] == true;
    final needs = _needsBuy(item);
    final fmt = NumberFormat('#,###');

    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        _deleteItem(item);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: needs
                ? _priorityColor(priority).withAlpha(80)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
        ),
        child: InkWell(
          onTap: isPurchased && !needs ? null : () => _markPurchased(item),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPurchased && !needs
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : _categoryColor(cat).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPurchased && !needs ? Icons.check : _categoryIcon(cat),
                    color: isPurchased && !needs
                        ? const Color(0xFF9CA3AF)
                        : _categoryColor(cat),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                decoration: isPurchased && !needs
                                    ? TextDecoration.lineThrough
                                    : null,
                                color:
                                    isPurchased && !needs ? const Color(0xFF9CA3AF) : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecurring) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.repeat,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '$qty${unit.isNotEmpty ? unit : '個'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          if (price != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '¥${fmt.format(price)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (shop != null && shop.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              shop,
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (needs && !isPurchased)
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _priorityColor(priority),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
