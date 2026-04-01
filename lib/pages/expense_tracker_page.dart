import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 支出トラッカーページ
/// expense-tracker Edge Function と連携して支出を管理
class ExpenseTrackerPage extends StatefulWidget {
  const ExpenseTrackerPage({super.key});

  @override
  State<ExpenseTrackerPage> createState() => _ExpenseTrackerPageState();
}

class _ExpenseTrackerPageState extends State<ExpenseTrackerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _expenses = [];

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'expense-tracker',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['expenses'] is List) {
        setState(() => _expenses = data['expenses'] as List);
      } else if (data is List) {
        setState(() => _expenses = data);
      } else {
        setState(() => _expenses = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '支出の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支出トラッカー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExpenses,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null) ...[
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _expenses.isEmpty
                      ? const Center(child: Text('支出記録はありません'))
                      : ListView.builder(
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final item = _expenses[index];
                            final title = item is Map
                                ? (item['title'] ?? item['name'] ?? item['category'] ?? '支出')
                                : item.toString();
                            final amount = item is Map
                                ? (item['amount'] ?? '')
                                : '';
                            final date = item is Map
                                ? (item['date'] ?? item['created_at'] ?? '')
                                : '';
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long),
                                title: Text(title.toString()),
                                subtitle: date.toString().isNotEmpty
                                    ? Text(date.toString())
                                    : null,
                                trailing: amount.toString().isNotEmpty
                                    ? Text(
                                        '¥${amount}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('支出を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '内容'),
            ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: '金額'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'expense-tracker',
                  body: {
                    'action': 'add',
                    'title': titleController.text.trim(),
                    'amount': int.tryParse(amountController.text.trim()) ?? 0,
                  },
                );
                await _fetchExpenses();
              } catch (e) {
                if (mounted) {
                  setState(() => _errorMessage = '支出の追加に失敗しました: $e');
                }
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }
}
