import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// デジタルウォレットページ
/// digital-wallet Edge Function と連携して残高・取引履歴を管理
class DigitalWalletPage extends StatefulWidget {
  const DigitalWalletPage({super.key});

  @override
  State<DigitalWalletPage> createState() => _DigitalWalletPageState();
}

class _DigitalWalletPageState extends State<DigitalWalletPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'digital-wallet',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['transactions'] is List) {
        setState(
          () => _transactions =
              (data['transactions'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _transactions = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _transactions = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '取引履歴の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('デジタルウォレット'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTransactions,
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
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchTransactions,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(child: Text('取引履歴はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        final description =
                            tx['description']?.toString() ?? '取引 ${index + 1}';
                        final amount = tx['amount']?.toString() ?? '0';
                        final type = tx['type']?.toString() ?? 'debit';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              type == 'credit'
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color:
                                  type == 'credit' ? Colors.green : Colors.red,
                            ),
                            title: Text(
                              description,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(tx['created_at']?.toString() ?? ''),
                            trailing: Text(
                              '¥$amount',
                              style: TextStyle(
                                color: type == 'credit'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('送金機能は準備中です')),
          );
        },
        icon: const Icon(Icons.send),
        label: const Text('送金'),
      ),
    );
  }
}
