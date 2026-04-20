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
  List<Map<String, dynamic>> _items = [];

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
        setState(
          () => _items = (data['items'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _items = data.cast<Map<String, dynamic>>());
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
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('オークション・マーケットプレイス'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
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
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
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
                        final title =
                            item['title']?.toString() ?? 'アイテム ${index + 1}';
                        final currentPrice = item['current_price'];
                        final description =
                            item['description']?.toString() ?? '';
                        final endAt = item['end_at'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.gavel,
                              color: Color(0xFFFFC107),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle: Text(
                              currentPrice != null
                                  ? '現在価格: ¥$currentPrice'
                                  : description,
                            ),
                            trailing: endAt != null
                                ? Text(
                                    '終了: $endAt',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
