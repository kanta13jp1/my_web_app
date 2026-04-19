import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 価格トラッカー — 商品 URL を貼って目標価格まで自動追跡
///
/// NotebookLM "Building a Zero-Cost Amazon Price Tracker" (d6dd44af) の知見統合 (Win版#131)
/// バックエンド: lifestyle-hub の price.* actions
/// テーブル: tracked_products + price_logs
///
/// 既存機能との関係:
/// - shopping_items: 日用品リマインダー (URL/価格なし)
/// - purchase_sessions: 購入後ログ (事前 wishlist なし)
/// - tracked_products: 「目標価格 + URL + 価格推移」を持つ wishlist (本ページ)
class PriceTrackerPage extends StatefulWidget {
  const PriceTrackerPage({super.key});

  @override
  State<PriceTrackerPage> createState() => _PriceTrackerPageState();
}

class _PriceTrackerPageState extends State<PriceTrackerPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'price.list', 'only_active': true},
      );
      final data = resp.data as Map<String, dynamic>?;
      final items =
          (data?['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() => _products = items);
    } catch (e) {
      if (mounted) setState(() => _error = '読込失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddProductSheet(),
    );
    if (added == true) await _load();
  }

  Future<void> _logPrice(Map<String, dynamic> p) async {
    final price = await _promptInt(
      title: '${p['product_name']} の現在価格',
      hint: '例: 12800',
    );
    if (price == null) return;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'price.log',
          'product_id': p['id'],
          'price': price,
          'source': 'manual',
        },
      );
      await _load();
    } catch (e) {
      _snack('記録失敗: $e');
    }
  }

  Future<void> _markPurchased(Map<String, dynamic> p) async {
    final price = await _promptInt(
      title: '${p['product_name']} の購入価格',
      hint: p['current_price']?.toString() ?? '',
    );
    if (price == null) return;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'price.mark_purchased',
          'product_id': p['id'],
          'purchased_price': price,
        },
      );
      _snack('購入記録しました');
      await _load();
    } catch (e) {
      _snack('記録失敗: $e');
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          '${p['product_name']} を追跡停止',
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
        content: const Text(
          '価格履歴も削除されます。',
          style: TextStyle(color: Color(0xFFB0B0B0), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'price.delete',
          'product_id': p['id'],
        },
      );
      await _load();
    } catch (e) {
      _snack('削除失敗: $e');
    }
  }

  Future<int?> _promptInt({required String title, String hint = ''}) {
    final ctrl = TextEditingController(text: hint);
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, height: 1.5),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6B7280)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFFF97316))),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('価格トラッカー'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF97316)),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _products.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _productCard(_products[i]),
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFFF97316),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '商品を追加',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              color: Color(0xFF6366F1),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '欲しい商品の URL を貼って\n目標価格を設定しましょう',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 15,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Amazon / 楽天 / Yahoo! ショッピング 等の URL に対応。\n衝動買い → 計画的な「買い時」判断へ',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                height: 1.7,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> p) {
    final name = (p['product_name'] as String?)?.trim().isNotEmpty == true
        ? p['product_name'] as String
        : (p['product_url'] as String? ?? '商品');
    final current = p['current_price'] as int?;
    final target = p['target_price'] as int?;
    final lowest = p['lowest_price'] as int?;
    final highest = p['highest_price'] as int?;
    final store = p['store_domain'] as String? ?? '';
    final isOnTarget = current != null && target != null && current <= target;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnTarget ? const Color(0xFFF97316) : const Color(0xFF1F1F1F),
          width: isOnTarget ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOnTarget)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🎯 買い時',
                    style: TextStyle(
                      color: Color(0xFFF97316),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
          if (store.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              store,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _priceBlock('現在', current, const Color(0xFFF97316)),
              const SizedBox(width: 12),
              _priceBlock('目標', target, const Color(0xFF6366F1)),
              const SizedBox(width: 12),
              _priceBlock('史上最安', lowest, const Color(0xFF22C55E)),
              const SizedBox(width: 12),
              _priceBlock('史上最高', highest, const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: () => _logPrice(p),
                  icon: const Icon(Icons.add_chart, size: 14),
                  label: const Text(
                    '価格を記録',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF97316),
                    side: const BorderSide(color: Color(0xFFF97316)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: () => _markPurchased(p),
                  icon: const Icon(Icons.check_circle, size: 14),
                  label: const Text(
                    '購入済み',
                    style: TextStyle(fontSize: 11, height: 1.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF22C55E),
                    side: const BorderSide(color: Color(0xFF22C55E)),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _delete(p),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFF6B7280),
                visualDensity: VisualDensity.compact,
                tooltip: '削除',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceBlock(String label, int? value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value == null ? '—' : '¥${_format(value)}',
            style: TextStyle(
              color: value == null ? const Color(0xFF6B7280) : color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _format(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _AddProductSheet extends StatefulWidget {
  const _AddProductSheet();

  @override
  State<_AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends State<_AddProductSheet> {
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _currentCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    if (url.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL と商品名は必須です')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'price.add',
          'product_url': url,
          'product_name': name,
          'current_price': int.tryParse(_currentCtrl.text.trim()),
          'target_price': int.tryParse(_targetCtrl.text.trim()),
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6B7280),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            '商品を追跡',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Amazon・楽天・Yahoo! ショッピングなどの商品ページ URL を貼り付け',
            style:
                TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 16),
          _field(_urlCtrl, '商品 URL *', 'https://www.amazon.co.jp/dp/...'),
          const SizedBox(height: 10),
          _field(_nameCtrl, '商品名 *', '例: ロジクール MX Master 3S'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _field(
                  _currentCtrl,
                  '現在価格 (円)',
                  '12800',
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _targetCtrl,
                  '目標価格 (円)',
                  '9800',
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '追跡を開始',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, height: 1.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFF0A0A0A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1F1F1F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1F1F1F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFF97316)),
        ),
      ),
    );
  }
}
