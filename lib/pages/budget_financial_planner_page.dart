import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 予算・財務プランナーページ
/// budget-financial-planner Edge Function と連携して予算を管理
class BudgetFinancialPlannerPage extends StatefulWidget {
  const BudgetFinancialPlannerPage({super.key});

  @override
  State<BudgetFinancialPlannerPage> createState() =>
      _BudgetFinancialPlannerPageState();
}

class _BudgetFinancialPlannerPageState
    extends State<BudgetFinancialPlannerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _budgets = [];

  @override
  void initState() {
    super.initState();
    _fetchBudgets();
  }

  Future<void> _fetchBudgets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'budget-financial-planner',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['budgets'] is List) {
        setState(() => _budgets = data['budgets'] as List);
      } else if (data is List) {
        setState(() => _budgets = data);
      } else {
        setState(() => _budgets = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '予算データの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('予算・財務プランナー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBudgets,
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
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red,),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBudgets,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _budgets.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              size: 64, color: Colors.grey,),
                          SizedBox(height: 16),
                          Text('予算データがありません',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey,),),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _budgets.length,
                      itemBuilder: (context, index) {
                        final item = _budgets[index] as Map<String, dynamic>;
                        final name = item['name']?.toString() ??
                            item['category']?.toString() ??
                            'カテゴリ ${index + 1}';
                        final amount = item['amount']?.toString() ??
                            item['budget']?.toString() ??
                            '';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF6366F1),),
                            title: Text(name),
                            subtitle: amount.isNotEmpty
                                ? Text('¥$amount')
                                : null,
                          ),
                        );
                      },
                    ),
    );
  }
}
