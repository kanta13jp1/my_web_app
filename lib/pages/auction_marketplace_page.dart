import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// オークション・マーケットプレイスページ
/// auction-marketplace Edge Function と連携してオークション出品・入札を管理
class AuctionMarketplacePage extends StatefulWidget {
  const AuctionMarketplacePage({super.key});

  @override
  State<AuctionMarketplacePage> createState() => _AuctionMarketplacePageState();
}

class _AuctionMarketplacePageState extends State<AuctionMarketplacePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'auction-marketplace',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] is List) {
        setState(() => _items = data['items'] as List);
      } else if (data is List) {
        setState(() => _items = data);
      } else {
        setState(() => _items = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'オークション一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('オークション・マーケットプレイス'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchItems,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchItems,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('出品中のアイテムはありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading:
                                const Icon(Icons.gavel, color: Colors.amber),
                            title: Text(
                              item['title']?.toString() ?? 'アイテム ${index + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              item['current_price'] != null
                                  ? '現在価格: ¥${item['current_price']}'
                                  : item['description']?.toString() ?? '',
                            ),
                            trailing: item['end_at'] != null
                                ? Text(
                                    '終了: ${item['end_at']}',
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
