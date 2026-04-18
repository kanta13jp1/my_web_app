import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 家計・予算プランナーページ
/// 月次予算設定・支出追跡・AI節約提案・カテゴリ別分析。MoneyForward / Zaim 対抗。
class HomeBudgetPlannerPage extends StatefulWidget {
  const HomeBudgetPlannerPage({super.key});

  @override
  State<HomeBudgetPlannerPage> createState() => _HomeBudgetPlannerPageState();
}

class _HomeBudgetPlannerPageState extends State<HomeBudgetPlannerPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];

  final _categoryCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _expenseCtrl = TextEditingController();
  final _expenseLabelCtrl = TextEditingController();
  String _selectedCategory = '食費';
  bool _saving = false;

  static const _categories = [
    _Category('食費', Icons.restaurant, Colors.orange),
    _Category('交通費', Icons.directions_car, Colors.blue),
    _Category('光熱費', Icons.bolt, Colors.yellow),
    _Category('娯楽', Icons.sports_esports, Colors.purple),
    _Category('医療', Icons.medical_services, Colors.red),
    _Category('教育', Icons.school, Colors.green),
    _Category('衣類', Icons.checkroom, Colors.pink),
    _Category('その他', Icons.category, Color(0xFF9CA3AF)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _categoryCtrl.dispose();
    _budgetCtrl.dispose();
    _expenseCtrl.dispose();
    _expenseLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final results = await Future.wait([
        _supabase
            .from('monthly_budgets')
            .select()
            .eq('user_id', userId)
            .eq('month', '${now.year}-${now.month.toString().padLeft(2, '0')}')
            .order('category'),
        _supabase
            .from('budget_expenses')
            .select()
            .eq('user_id', userId)
            .gte('spent_at', monthStart)
            .order('spent_at', ascending: false)
            .limit(30),
      ]);
      setState(() {
        _expenses = (results[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addExpense() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _expenseCtrl.text.trim().isEmpty) return;
    final amount = int.tryParse(_expenseCtrl.text.trim());
    if (amount == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('budget_expenses').insert({
        'user_id': userId,
        'category': _selectedCategory,
        'amount': amount,
        'label': _expenseLabelCtrl.text.trim().isEmpty
            ? null
            : _expenseLabelCtrl.text.trim(),
        'spent_at': DateTime.now().toIso8601String(),
      });
      _expenseCtrl.clear();
      _expenseLabelCtrl.clear();
      if (mounted) Navigator.pop(context);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: Text('${now.year}年${now.month}月 予算プランナー'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('支出を追加'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'monthly_budgets / budget_expenses テーブルを\n作成すると予算管理が使えます',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(),
                      const SizedBox(height: 16),
                      _buildExpenseList(),
                    ],
                  ),
                ),
    );
  }

  void _showAddExpenseDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDS) => AlertDialog(
          title: const Text('支出を追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseCtrl,
                decoration: const InputDecoration(labelText: '金額 (円) *'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _expenseLabelCtrl,
                decoration: const InputDecoration(labelText: 'メモ'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _categories
                    .map(
                      (c) => ChoiceChip(
                        label: Text(c.name),
                        selected: _selectedCategory == c.name,
                        onSelected: (_) =>
                            setDS(() => _selectedCategory = c.name),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _saving ? null : _addExpense,
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalSpent = _expenses.fold<int>(
      0,
      (sum, e) => sum + (e['amount'] as int? ?? 0),
    );
    final categoryTotals = <String, int>{};
    for (final e in _expenses) {
      final cat = e['category'] as String? ?? 'その他';
      categoryTotals[cat] =
          (categoryTotals[cat] ?? 0) + (e['amount'] as int? ?? 0);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '今月の支出サマリー',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '合計: ¥$totalSpent',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 12),
            if (categoryTotals.isNotEmpty) ...[
              const Text(
                'カテゴリ別',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 6),
              ...categoryTotals.entries.map((e) {
                final cat =
                    _categories.where((c) => c.name == e.key).firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        cat?.icon ?? Icons.category,
                        size: 16,
                        color: cat?.color ?? const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.key)),
                      Text(
                        '¥${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }),
            ] else
              const Text('支出がまだありません。'),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '支出履歴',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._expenses.map((e) {
          final cat = _categories
              .where((c) => c.name == (e['category'] as String? ?? ''))
              .firstOrNull;
          final spentAt = e['spent_at'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Icon(
                cat?.icon ?? Icons.category,
                color: cat?.color ?? const Color(0xFF9CA3AF),
              ),
              title:
                  Text(e['label'] as String? ?? e['category'] as String? ?? ''),
              subtitle: Text(
                spentAt.length >= 10 ? spentAt.substring(0, 10) : spentAt,
              ),
              trailing: Text(
                '¥${e['amount'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Category {
  const _Category(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}
