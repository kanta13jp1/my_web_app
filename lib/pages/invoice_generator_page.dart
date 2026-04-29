import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 請求書ジェネレーターページ
/// invoice-generator Edge Function と連携して請求書を生成
class InvoiceGeneratorPage extends StatefulWidget {
  const InvoiceGeneratorPage({super.key});

  @override
  State<InvoiceGeneratorPage> createState() => _InvoiceGeneratorPageState();
}

class _InvoiceGeneratorPageState extends State<InvoiceGeneratorPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _invoices = [];

  final _clientController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvoices() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'billing.invoice'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['invoices'];
        setState(() {
          _invoices = items is List
              ? items.map<Map<String, dynamic>>((dynamic inv) {
                  final row = inv as Map<String, dynamic>;
                  final meta = (row['metadata'] as Map<String, dynamic>?) ?? {};
                  return {
                    'id': row['id'],
                    'client_name':
                        meta['client_name'] ?? row['client_name'] ?? '不明',
                    'amount': meta['amount'] ?? row['amount'] ?? 0,
                    'description':
                        meta['description'] ?? row['description'] ?? '',
                    'status': meta['status'] ?? row['status'] ?? 'draft',
                  };
                }).toList()
              : [];
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '請求書の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvoice() async {
    final client = _clientController.text.trim();
    final amount = _amountController.text.trim();
    final description = _descriptionController.text.trim();
    if (client.isEmpty || amount.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'billing.create_invoice',
          'client_name': client,
          'amount': double.tryParse(amount) ?? 0,
          'description': description,
        },
      );
      _clientController.clear();
      _amountController.clear();
      _descriptionController.clear();
      await _fetchInvoices();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '請求書の作成に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('請求書ジェネレーター'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          // 作成フォーム
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF303030) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF616161) : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新規請求書作成',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientController,
                  decoration: const InputDecoration(
                    labelText: 'クライアント名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '金額 (円)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '説明 (任意)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('請求書を作成'),
                    onPressed: _isLoading ? null : _createInvoice,
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          // リスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: isDark
                                  ? const Color(0xFF757575)
                                  : const Color(0xFFBDBDBD),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '請求書がありません',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF757575),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _invoices.length,
                        itemBuilder: (context, i) {
                          final inv = _invoices[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.receipt,
                                color: Color(0xFF6366F1),
                              ),
                              title: Text(
                                inv['client_name']?.toString() ?? '不明',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                              subtitle: Text(
                                inv['description']?.toString() ?? '',
                              ),
                              trailing: Text(
                                '¥${inv['amount']?.toString() ?? '0'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
