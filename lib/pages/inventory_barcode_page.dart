import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item_summary.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 在庫バーコード管理ページ
/// 商品一覧・在庫数・入出庫記録。
/// social-commerce-hub Edge Function (inventory.list) と連携。
class InventoryBarcodePage extends StatefulWidget {
  const InventoryBarcodePage({super.key});

  @override
  State<InventoryBarcodePage> createState() => _InventoryBarcodePageState();
}

class _InventoryBarcodePageState extends State<InventoryBarcodePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['items', 'movements'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<InventoryItemSummary> _items = [];
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      final iRes = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'inventory.list'},
      );
      setState(() {
        _items = parseInventoryItems(iRes.data);
        _movements = [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('在庫管理'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory),
              text: '在庫 (${_items.length})',
            ),
            const Tab(icon: Icon(Icons.swap_horiz), text: '入出庫'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildItemsTab(), _buildMovementsTab()],
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

  Widget _buildItemsTab() {
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '商品が登録されていません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final name = item.name.isEmpty ? '商品 ${i + 1}' : item.name;
        final alert = item.isOutOfStock || item.isLowStock;
        final subtitleParts = [
          if (item.sku.isNotEmpty) 'SKU: ${item.sku}',
          if (item.category.isNotEmpty) item.category,
        ];
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: alert
              ? (isDark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEE))
              : null,
          child: ListTile(
            leading: Icon(
              Icons.qr_code,
              color: alert ? const Color(0xFFE53935) : const Color(0xFF9CA3AF),
            ),
            title: Text(name),
            subtitle: subtitleParts.isNotEmpty
                ? Text(subtitleParts.join(' · '))
                : null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.quantity} 個',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: alert ? const Color(0xFFE53935) : null,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                if (item.isOutOfStock || item.isLowStock)
                  Text(
                    item.isOutOfStock ? '在庫切れ' : '在庫不足',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMovementsTab() {
    if (_movements.isEmpty) {
      return const Center(
        child: Text(
          '入出庫記録がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _movements.length,
      itemBuilder: (ctx, i) {
        final m = _movements[i];
        final itemName = m['itemName'] as String? ?? '';
        final type = m['type'] as String? ?? 'in';
        final qty = m['quantity'] as int? ?? 0;
        final date = m['date'] as String? ?? '';
        final isIn = type == 'in';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            ),
            title: Text(itemName),
            subtitle: date.length >= 10 ? Text(date.substring(0, 10)) : null,
            trailing: Text(
              '${isIn ? "+" : "-"}$qty',
              style: TextStyle(
                color: isIn ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
