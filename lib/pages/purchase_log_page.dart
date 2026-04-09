import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PurchaseLogPage extends StatefulWidget {
  const PurchaseLogPage({super.key});

  @override
  State<PurchaseLogPage> createState() => _PurchaseLogPageState();
}

class _PurchaseLogPageState extends State<PurchaseLogPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _sessions = [];
  int _totalThisMonth = 0;

  static const Map<String, String> _storeCategories = {
    'convenience': '🏪 コンビニ',
    'supermarket': '🛒 スーパー',
    'drugstore': '💊 ドラッグストア',
    'online': '📦 オンライン',
    'restaurant': '🍽 飲食店',
    'vending': '🥤 自販機',
    'other': '📌 その他',
  };

  static const Map<String, String> _paymentMethods = {
    'cash': '💴 現金',
    'credit': '💳 クレジット',
    'debit': '🏧 デビット',
    'qr': '📱 QR決済',
    'ic_card': '🚃 ICカード',
    'other': '📌 その他',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final sessions = await _supabase
          .from('purchase_sessions')
          .select('*, purchase_items(*)')
          .eq('user_id', userId)
          .order('purchased_at', ascending: false)
          .limit(30);

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final monthData = await _supabase
          .from('purchase_sessions')
          .select('total_amount')
          .eq('user_id', userId)
          .gte('purchased_at', monthStart);

      int monthTotal = 0;
      for (final s in monthData as List<dynamic>) {
        final row = s as Map<String, dynamic>;
        monthTotal += (row['total_amount'] as int? ?? 0);
      }

      if (mounted) {
        setState(() {
          _sessions = List<Map<String, dynamic>>.from(sessions as List);
          _totalThisMonth = monthTotal;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final storeCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String storeCategory = 'convenience';
    String paymentMethod = 'cash';
    final itemCtrls = <TextEditingController>[TextEditingController()];
    final itemPriceCtrls = <TextEditingController>[TextEditingController()];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('買い物を記録'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: storeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'お店の名前',
                      hintText: '例: セブンイレブン渋谷店',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: storeCategory,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      border: OutlineInputBorder(),
                    ),
                    items: _storeCategories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => storeCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: '支払い方法',
                      border: OutlineInputBorder(),
                    ),
                    items: _paymentMethods.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => paymentMethod = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '合計金額 (円)',
                      border: OutlineInputBorder(),
                      prefixText: '¥',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '購入品目 (任意)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...List.generate(
                    itemCtrls.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: itemCtrls[i],
                              decoration: InputDecoration(
                                hintText: '商品名 ${i + 1}',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: itemPriceCtrls[i],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '金額',
                                border: OutlineInputBorder(),
                                prefixText: '¥',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setS(() {
                      itemCtrls.add(TextEditingController());
                      itemPriceCtrls.add(TextEditingController());
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('品目を追加'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'メモ (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                final userId = _supabase.auth.currentUser?.id;
                if (userId == null) return;
                final store = storeCtrl.text.trim();
                if (store.isEmpty) return;
                final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;

                final session = await _supabase
                    .from('purchase_sessions')
                    .insert({
                      'user_id': userId,
                      'store_name': store,
                      'store_category': storeCategory,
                      'total_amount': amount,
                      'payment_method': paymentMethod,
                      'memo': memoCtrl.text.trim().isEmpty
                          ? null
                          : memoCtrl.text.trim(),
                      'purchased_at': DateTime.now().toIso8601String(),
                    })
                    .select()
                    .single();

                final sessionId = session['id'] as String;
                final items = <Map<String, dynamic>>[];
                for (int i = 0; i < itemCtrls.length; i++) {
                  final name = itemCtrls[i].text.trim();
                  if (name.isEmpty) continue;
                  final price = int.tryParse(itemPriceCtrls[i].text.trim());
                  items.add({
                    'session_id': sessionId,
                    'user_id': userId,
                    'item_name': name,
                    'price': price,
                    'quantity': 1,
                  });
                }
                if (items.isNotEmpty) {
                  await _supabase.from('purchase_items').insert(items);
                }

                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('記録する'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('買い物ログ'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFF6366F1),
        label: const Text('記録', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildMonthSummary(isDark),
                Expanded(
                  child: _sessions.isEmpty
                      ? _buildEmpty(isDark)
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _sessions.length,
                          itemBuilder: (ctx, i) =>
                              _buildSessionCard(_sessions[i], isDark),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthSummary(bool isDark) {
    final fmt = NumberFormat('#,###');
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今月の合計',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '¥${fmt.format(_totalThisMonth)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_sessions.length}件の記録',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isDark) {
    final storeName = session['store_name'] as String? ?? '';
    final category = session['store_category'] as String? ?? 'other';
    final amount = session['total_amount'] as int? ?? 0;
    final payment = session['payment_method'] as String? ?? 'cash';
    final memo = session['memo'] as String?;
    final purchasedAt = session['purchased_at'] as String?;
    final items = session['purchase_items'] as List? ?? [];
    final fmt = NumberFormat('#,###');
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _storeCategories[category] ?? category,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    storeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Text(
                  '¥${fmt.format(amount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _paymentMethods[payment] ?? payment,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                if (purchasedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM/dd HH:mm').format(
                      DateTime.tryParse(purchasedAt)?.toLocal() ??
                          DateTime.now(),
                    ),
                    style:
                        TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: items.take(5).map<Widget>((dynamic item) {
                  final row = item as Map<String, dynamic>;
                  final name = row['item_name'] as String? ?? '';
                  final price = row['price'] as int?;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      price != null ? '$name ¥${fmt.format(price)}' : name,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey[300]
                            : Colors.grey[600],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (memo != null && memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                memo,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Theme.of(context).colorScheme.surfaceContainerHighest,),
          const SizedBox(height: 16),
          Text(
            '買い物を記録しよう',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'レシート代わりに\nサッと記録できます',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
