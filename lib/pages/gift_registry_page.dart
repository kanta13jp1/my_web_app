import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ギフトレジストリページ
/// gift-registry Edge Function と連携してギフトリストを管理
class GiftRegistryPage extends StatefulWidget {
  const GiftRegistryPage({super.key});

  @override
  State<GiftRegistryPage> createState() => _GiftRegistryPageState();
}

class _GiftRegistryPageState extends State<GiftRegistryPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _gifts = [];

  @override
  void initState() {
    super.initState();
    _fetchGifts();
  }

  Future<void> _fetchGifts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'gift.list'},
      );
      final data = response.data;
      final giftList = data is Map<String, dynamic>
          ? (data['gifts'] ?? data['items'])
          : null;
      if (giftList is List) {
        setState(
          () => _gifts = giftList.cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _gifts = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _gifts = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ギフトリストの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ギフトレジストリ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchGifts,
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
                        onPressed: _fetchGifts,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _gifts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.card_giftcard,
                            size: 64,
                            color: Color(0xFF9CA3AF),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'ギフトリストが空です',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9CA3AF),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _gifts.length,
                      itemBuilder: (context, index) {
                        final gift = _gifts[index];
                        final title =
                            (gift['title'] ?? gift['name'] ?? 'ギフト $index')
                                .toString();
                        final price =
                            (gift['price'] ?? gift['amount'] ?? '').toString();
                        final reserved = gift['reserved'] == true;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.card_giftcard,
                              color: reserved
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFFF6B35),
                            ),
                            title: Text(title),
                            subtitle: price.isNotEmpty ? Text('¥$price') : null,
                            trailing: reserved
                                ? const Chip(
                                    label: Text('予約済'),
                                    backgroundColor: Color(0xFF9CA3AF),
                                  )
                                : const Icon(Icons.chevron_right),
                          ),
                        );
                      },
                    ),
    );
  }
}
