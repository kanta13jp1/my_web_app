import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('price', ascending: false);

      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // テーブルがない場合などは空リストとして扱う
        setState(() {
          _subscriptions = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('読み込みエラー: $e')));
      }
    }
  }

  Future<void> _addSubscription() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サブスク追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration:
                  const InputDecoration(labelText: 'サービス名 (例: Netflix)'),
            ),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: '月額料金 (円)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = int.tryParse(priceController.text.trim()) ?? 0;
              if (name.isEmpty) return;

              final userId = _supabase.auth.currentUser?.id;
              if (userId != null) {
                await _supabase.from('subscriptions').insert({
                  'user_id': userId,
                  'service_name': name,
                  'price': price,
                });
                if (context.mounted) Navigator.pop(context);
                _fetchSubscriptions();
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSubscription(String id) async {
    await _supabase.from('subscriptions').delete().eq('id', id);
    _fetchSubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    int totalCost = 0;
    for (var sub in _subscriptions) {
      totalCost += (sub['price'] as num).toInt();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('固定費削減室'),
        backgroundColor: Colors.green[700],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.green[50],
                  width: double.infinity,
                  child: Column(
                    children: [
                      const Text(
                        '月額固定費 合計',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      Text(
                        totalCost.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _subscriptions.isEmpty
                      ? const Center(child: Text('登録されたサブスクリプションはありません'))
                      : ListView.builder(
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) {
                            final item = _subscriptions[index];
                            return ListTile(
                              leading: const Icon(
                                Icons.payment,
                                color: Colors.green,
                              ),
                              title: Text(item['service_name'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${item['price']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () =>
                                        _deleteSubscription(item['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSubscription,
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add),
      ),
    );
  }
}
