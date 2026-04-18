import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 毎月の支払いリマインダーページ。
/// au、家賃、サブスク、保険、税金などの定期支払いを管理する。
class PaymentReminderPage extends StatefulWidget {
  const PaymentReminderPage({super.key});

  @override
  State<PaymentReminderPage> createState() => _PaymentReminderPageState();
}

class _PaymentReminderPageState extends State<PaymentReminderPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _reminders = [];

  static const _categories = [
    ('telecom', '通信', Icons.phone_android, Color(0xFFE91E63)),
    ('rent', '家賃', Icons.home, Color(0xFF795548)),
    ('utility', '光熱費', Icons.bolt, Color(0xFFFF9800)),
    ('subscription', 'サブスク', Icons.subscriptions, Color(0xFF9C27B0)),
    ('insurance', '保険', Icons.health_and_safety, Color(0xFF4CAF50)),
    ('tax', '税金', Icons.account_balance, Color(0xFF607D8B)),
    ('loan', 'ローン', Icons.credit_card, Color(0xFFF44336)),
    ('other', 'その他', Icons.payments, Color(0xFF2196F3)),
  ];

  static const _paymentMethods = [
    '口座引落',
    'クレジットカード',
    '銀行振込',
    'コンビニ払い',
    'PayPay',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('payment_reminders')
          .select()
          .eq('user_id', userId)
          .order('due_day');
      if (mounted) {
        setState(() {
          _reminders = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('PaymentReminderPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isDueSoon(Map<String, dynamic> r) {
    if (r['is_active'] != true) return false;
    final dueDay = r['due_day'] as int? ?? 1;
    final now = DateTime.now();
    final today = now.day;
    final diff = dueDay - today;
    // 3日以内 or 当日
    return diff >= 0 && diff <= 3;
  }

  bool _isOverdue(Map<String, dynamic> r) {
    if (r['is_active'] != true) return false;
    final dueDay = r['due_day'] as int? ?? 1;
    final now = DateTime.now();
    final today = now.day;
    final lastPaid = r['last_paid_at']?.toString();
    if (lastPaid != null && lastPaid.isNotEmpty) {
      final lastDate = DateTime.tryParse(lastPaid);
      if (lastDate != null &&
          lastDate.month == now.month &&
          lastDate.year == now.year) {
        return false; // 今月支払い済み
      }
    }
    return today > dueDay;
  }

  IconData _categoryIcon(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$3;
    }
    return Icons.payments;
  }

  Color _categoryColor(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$4;
    }
    return const Color(0xFF2196F3);
  }

  String _categoryLabel(String cat) {
    for (final c in _categories) {
      if (c.$1 == cat) return c.$2;
    }
    return 'その他';
  }

  Future<void> _addReminder() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final payeeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = 'telecom';
    String selectedMethod = '口座引落';
    int dueDay = 25;
    bool isAutoPay = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('支払いリマインダー追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '支払い名 *',
                    hintText: 'au携帯料金、家賃、Netflix など',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(
                    labelText: '金額 (円)',
                    hintText: '10000',
                    prefixIcon: Icon(Icons.currency_yen),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: payeeCtrl,
                  decoration: const InputDecoration(
                    labelText: '振込先・支払先',
                    hintText: 'KDDI、不動産会社 など',
                    prefixIcon: Icon(Icons.business),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c.$1,
                      child: Row(
                        children: [
                          Icon(c.$3, size: 18, color: c.$4),
                          const SizedBox(width: 8),
                          Text(c.$2),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedCategory = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: dueDay,
                  decoration: const InputDecoration(
                    labelText: '毎月の支払日',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  items: List.generate(31, (i) => i + 1).map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text('$d日'),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => dueDay = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedMethod,
                  decoration: const InputDecoration(
                    labelText: '支払方法',
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: _paymentMethods.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedMethod = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('自動引落し'),
                  subtitle: const Text('口座引落やカード自動払いの場合'),
                  value: isAutoPay,
                  onChanged: (v) => setDialogState(() => isAutoPay = v),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'メモ',
                    hintText: '契約番号、お客様番号 など',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('payment_reminders').insert({
        'user_id': userId,
        'title': title,
        'amount': int.tryParse(amountCtrl.text),
        'payee': payeeCtrl.text.trim().isEmpty ? null : payeeCtrl.text.trim(),
        'payment_method': selectedMethod,
        'category': selectedCategory,
        'due_day': dueDay,
        'is_auto_pay': isAutoPay,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支払いリマインダーを追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markPaid(Map<String, dynamic> reminder) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('payment_reminders').update({
        'last_paid_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', reminder['id']);

      await _supabase.from('payment_logs').insert({
        'user_id': userId,
        'reminder_id': reminder['id'],
        'amount': reminder['amount'],
      });

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 支払い完了を記録しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteReminder(Map<String, dynamic> reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('リマインダーを削除'),
        content: Text('「${reminder['title']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase
          .from('payment_reminders')
          .delete()
          .eq('id', reminder['id'])
          .select();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int get _monthlyTotal {
    int total = 0;
    for (final r in _reminders) {
      if (r['is_active'] == true && r['amount'] != null) {
        total += r['amount'] as int;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final dueSoon =
        _reminders.where((r) => _isDueSoon(r) || _isOverdue(r)).toList();
    final fmt = NumberFormat('#,###');

    return Scaffold(
      appBar: AppBar(title: const Text('支払いリマインダー'), elevation: 0),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add),
        label: const Text('支払い追加'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(fmt),
                    if (dueSoon.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDueSoonBanner(dueSoon.length),
                    ],
                    const SizedBox(height: 16),
                    ..._reminders.map((r) => _buildReminderCard(r, fmt)),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              '毎月の支払いを登録して\n忘れずにリマインドしましょう',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.add),
              label: const Text('支払いを追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(NumberFormat fmt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF303F9F), Color(0xFF3F51B5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '毎月の固定支出',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '¥${fmt.format(_monthlyTotal)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_reminders.where((r) => r['is_active'] == true).length}件',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueSoonBanner(int count) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.red),
          const SizedBox(width: 10),
          Text(
            '⚠️ $count件の支払いが期日間近・超過です',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> r, NumberFormat fmt) {
    final cat = r['category']?.toString() ?? 'other';
    final title = r['title']?.toString() ?? '';
    final amount = r['amount'] as int?;
    final dueDay = r['due_day'] as int? ?? 1;
    final payee = r['payee']?.toString();
    final method = r['payment_method']?.toString();
    final isAuto = r['is_auto_pay'] == true;
    final note = r['note']?.toString();
    final overdue = _isOverdue(r);
    final dueSoon = _isDueSoon(r);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: overdue ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: overdue
              ? Colors.red.shade300
              : (dueSoon
                  ? const Color(0xFFFFB74D)
                  : Theme.of(context).colorScheme.surfaceContainerHigh),
          width: overdue || dueSoon ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _categoryColor(cat).withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcon(cat),
                    color: _categoryColor(cat),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isAuto) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '自動',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF3D5AFE),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (payee != null && payee.isNotEmpty)
                        Text(
                          payee,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (amount != null)
                      Text(
                        '¥${fmt.format(amount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      '毎月$dueDay日',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (method != null)
                  _buildMiniTag(
                    method,
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                  ),
                const SizedBox(width: 6),
                _buildMiniTag(
                  _categoryLabel(cat),
                  _categoryColor(cat).withAlpha(20),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                if (overdue || dueSoon)
                  TextButton.icon(
                    onPressed: () => _markPaid(r),
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('支払い完了'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'paid') _markPaid(r);
                    if (v == 'delete') _deleteReminder(r);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'paid', child: Text('支払い完了')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('削除', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }
}
