import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// サブスクリプション請求ページ
/// subscription-billing Edge Function と連携して請求情報を管理
class SubscriptionBillingPage extends StatefulWidget {
  const SubscriptionBillingPage({super.key});

  @override
  State<SubscriptionBillingPage> createState() =>
      _SubscriptionBillingPageState();
}

class _SubscriptionBillingPageState extends State<SubscriptionBillingPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _billingInfo;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchBillingInfo();
  }

  Future<void> _fetchBillingInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'billing.status'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _billingInfo = data['billing'] as Map<String, dynamic>?;
          _invoices = data['invoices'] as List? ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '請求情報の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サブスクリプション・請求'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBillingInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '現在のプラン',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_billingInfo != null) ...[
                            _infoRow(
                              'プラン',
                              _billingInfo!['plan']?.toString() ?? 'Free',
                            ),
                            _infoRow(
                              'ステータス',
                              _billingInfo!['status']?.toString() ?? '-',
                            ),
                            _infoRow(
                              '次回更新日',
                              _billingInfo!['next_billing_date']?.toString() ??
                                  '-',
                            ),
                          ] else
                            const Text('プラン情報なし'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '請求履歴',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                  const Divider(),
                  if (_invoices.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('請求履歴はありません'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _invoices.length,
                      itemBuilder: (context, index) {
                        final invoice = _invoices[index];
                        final amount =
                            invoice is Map ? (invoice['amount'] ?? '-') : '-';
                        final date = invoice is Map
                            ? (invoice['date'] ?? invoice['created_at'] ?? '-')
                            : '-';
                        final status =
                            invoice is Map ? (invoice['status'] ?? '-') : '-';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.receipt_outlined),
                            title: Text('¥$amount'),
                            subtitle: Text(date.toString()),
                            trailing: Chip(
                              label: Text(status.toString()),
                              backgroundColor: status.toString() == 'paid'
                                  ? Colors.green.shade100
                                  : const Color(0xFFFFE0B2),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
