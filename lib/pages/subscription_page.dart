import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;
  bool _isAuditing = false; // 監査中フラグ

  // 監査結果
  String? _auditResult;
  String? _usedModel;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('subscriptions')
          .select()
          .eq('user_id', userId)
          .order('price', ascending: false); // 高い順に表示

      if (mounted) {
        setState(() {
          _subscriptions = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSubscription(
      String name, double price, String cycle, String desc) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('subscriptions').insert({
        'user_id': userId,
        'service_name': name,
        'price': price,
        'billing_cycle': cycle,
        'description': desc,
      });

      _fetchSubscriptions();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('登録エラー: $e')));
    }
  }

  Future<void> _deleteSubscription(int id) async {
    try {
      await supabase.from('subscriptions').delete().eq('id', id);
      _fetchSubscriptions();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('削除エラー: $e')));
    }
  }

  //  14モデルによる財務監査を実行
  Future<void> _runFinancialAudit() async {
    if (_subscriptions.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('まずはサブスクを登録してください')));
      return;
    }

    setState(() => _isAuditing = true);

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'audit_subscriptions',
          'subscriptions': _subscriptions,
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      setState(() {
        _auditResult = data['result'];
        _usedModel = data['used_model'];
      });

      if (mounted) _showAuditResultDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('監査エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isAuditing = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String cycle = 'monthly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('固定費の登録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'サービス名 (例: Netflix)')),
              TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: '金額'),
                  keyboardType: TextInputType.number),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: '用途備考')),
              DropdownButton<String>(
                value: cycle,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('月額')),
                  DropdownMenuItem(value: 'yearly', child: Text('年額')),
                ],
                onChanged: (v) => setState(() => cycle = v!),
              )
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () {
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (nameCtrl.text.isNotEmpty && price > 0) {
                  _addSubscription(nameCtrl.text, price, cycle, descCtrl.text);
                }
              },
              child: const Text('登録'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.gavel, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text('AI CFOの監査報告書')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_usedModel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Auditor: $_usedModel',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber[900],
                          fontWeight: FontWeight.bold)),
                ),
              MarkdownBody(data: _auditResult ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Share.share(
                '【自分株式会社 財務監査】\n14種類のAI CFOに固定費をメッタ斬りにされました\n\n${_auditResult?.substring(0, 100)}...\n\n#マイメモ #固定費削減',
                subject: 'AI CFOの監査結果',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('シェアして戒める'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 月間固定費の概算
    double monthlyTotal = 0;
    for (var sub in _subscriptions) {
      double price = (sub['price'] as num).toDouble();
      if (sub['billing_cycle'] == 'yearly') price /= 12;
      monthlyTotal += price;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(' 固定費削減室'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ヘッダー: 合計金額と監査ボタン
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.teal.shade50,
                  child: Column(
                    children: [
                      const Text('月間固定費 (概算)',
                          style: TextStyle(fontSize: 14, color: Colors.teal)),
                      Text(
                        '${monthlyTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAuditing ? null : _runFinancialAudit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isAuditing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.gavel),
                          label: const Text('14モデルによる財務監査を実行',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),

                // リスト
                Expanded(
                  child: _subscriptions.isEmpty
                      ? const Center(child: Text('固定費を追加してください'))
                      : ListView.builder(
                          itemCount: _subscriptions.length,
                          itemBuilder: (context, index) {
                            final sub = _subscriptions[index];
                            final isMonthly = sub['billing_cycle'] == 'monthly';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(sub['service_name'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(sub['description'] ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${sub['price']} / ${isMonthly ? '月' : '年'}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.grey),
                                      onPressed: () =>
                                          _deleteSubscription(sub['id']),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
