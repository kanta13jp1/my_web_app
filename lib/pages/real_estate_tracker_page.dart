import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 不動産管理ページ
/// real-estate-tracker Edge Function と連携
/// MoneyForward / Suumo 競合
class RealEstateTrackerPage extends StatefulWidget {
  const RealEstateTrackerPage({super.key});

  @override
  State<RealEstateTrackerPage> createState() => _RealEstateTrackerPageState();
}

class _RealEstateTrackerPageState extends State<RealEstateTrackerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['properties', 'finances', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _properties = [];
  Map<String, dynamic>? _selectedProperty;
  List<Map<String, dynamic>> _finances = [];
  Map<String, dynamic> _stats = {};

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  String _selectedType = 'apartment';

  final _txnAmountCtrl = TextEditingController();
  final _txnDescCtrl = TextEditingController();
  String _selectedTxnType = 'rent_income';

  static const _typeLabels = {
    'apartment': 'アパート・マンション',
    'house': '一戸建て',
    'condo': 'マンション(区分)',
    'land': '土地',
    'commercial': '商業施設',
    'parking': '駐車場',
    'other': 'その他',
  };

  static const _txnTypeLabels = {
    'rent_income': '家賃収入',
    'maintenance_cost': 'メンテナンス費',
    'tax': '税金',
    'insurance': '保険料',
    'mortgage': 'ローン返済',
    'utility': '光熱費',
    'other_expense': 'その他支出',
    'other_income': 'その他収入',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchProperties();
    _fetchStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _priceCtrl.dispose();
    _areaCtrl.dispose();
    _txnAmountCtrl.dispose();
    _txnDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProperties() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions
          .invoke('lifestyle-hub', body: {'action': 'realestate.list'});
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['properties'];
        if (list is List) {
          setState(() {
            _properties = list.map((p) => p as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final res = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'realestate.stats'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final stats = data['stats'];
        if (stats is Map<String, dynamic>) setState(() => _stats = stats);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _fetchFinances(String propertyId) async {
    try {
      final res = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {'action': 'realestate.finances', 'property_id': propertyId},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['transactions'];
        if (list is List) {
          setState(() {
            _finances = list.map((t) => t as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _registerProperty() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('物件名を入力してください')),
      );
      return;
    }
    try {
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      final area = double.tryParse(_areaCtrl.text.trim());
      final res = await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'realestate.register',
          'name': name,
          'property_type': _selectedType,
          'address': _addressCtrl.text.trim(),
          'purchase_price': price,
          'area_sqm': area,
        },
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        if (mounted) {
          Navigator.of(context).pop();
          _nameCtrl.clear();
          _addressCtrl.clear();
          _priceCtrl.clear();
          _areaCtrl.clear();
          _fetchProperties();
          _fetchStats();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('物件を登録しました'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _recordTransaction(String propertyId) async {
    final amountStr = _txnAmountCtrl.text.trim();
    if (amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr) ?? 0;
    try {
      await _supabase.functions.invoke(
        'lifestyle-hub',
        body: {
          'action': 'realestate.record_txn',
          'property_id': propertyId,
          'type': _selectedTxnType,
          'amount': amount,
          'description': _txnDescCtrl.text.trim(),
          'date': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        _txnAmountCtrl.clear();
        _txnDescCtrl.clear();
        _fetchFinances(propertyId);
        _fetchStats();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('収支を記録しました'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  void _showRegisterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('物件を登録'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '物件名 *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: '種別',
                      border: OutlineInputBorder(),
                    ),
                    items: _typeLabels.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlg(() => _selectedType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: '住所',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '購入価格 (円)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _areaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '面積 (㎡)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(onPressed: _registerProperty, child: const Text('登録')),
          ],
        ),
      ),
    );
  }

  void _showTransactionDialog(String propertyId) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('収支を記録'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedTxnType,
                decoration: const InputDecoration(
                  labelText: '種別',
                  border: OutlineInputBorder(),
                ),
                items: _txnTypeLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlg(() => _selectedTxnType = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _txnAmountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額 (円)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _txnDescCtrl,
                decoration: const InputDecoration(
                  labelText: '説明',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => _recordTransaction(propertyId),
              child: const Text('記録'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('不動産管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home_work), text: '物件一覧'),
            Tab(icon: Icon(Icons.account_balance_wallet), text: '収支'),
            Tab(icon: Icon(Icons.pie_chart), text: '統計'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _fetchProperties,
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterDialog,
        icon: const Icon(Icons.add_home),
        label: const Text('物件を登録'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                      TextButton(
                        onPressed: _fetchProperties,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPropertiesTab(),
                    _buildFinancesTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildPropertiesTab() {
    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            const Text('物件が登録されていません'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _showRegisterDialog,
              icon: const Icon(Icons.add_home),
              label: const Text('物件を登録'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchProperties,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _properties.length,
        itemBuilder: (context, i) {
          final p = _properties[i];
          final name = p['name'] as String? ?? '';
          final type = p['property_type'] as String? ?? '';
          final typeLabel = _typeLabels[type] ?? type;
          final address = p['address'] as String? ?? '';
          final price = p['purchase_price'] as num? ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(
                Icons.home_work,
                color: Color(0xFF009688),
                size: 36,
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(typeLabel),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  if (price > 0)
                    Text(
                      '購入価格: ¥${_fmt(price.toDouble())}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF607D8B),
                        height: 1.5,
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'finance') {
                    setState(() => _selectedProperty = p);
                    _fetchFinances(p['property_id'] as String? ?? '');
                    _tabController.animateTo(1);
                  } else if (v == 'add_txn') {
                    setState(() => _selectedProperty = p);
                    _showTransactionDialog(p['property_id'] as String? ?? '');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'finance', child: Text('収支を見る')),
                  PopupMenuItem(value: 'add_txn', child: Text('収支を追加')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinancesTab() {
    final propName = _selectedProperty != null
        ? (_selectedProperty!['name'] as String? ?? '')
        : '';
    return Column(
      children: [
        if (_selectedProperty != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '物件: $propName',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _showTransactionDialog(
                      _selectedProperty!['property_id'] as String? ?? '',
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('収支追加'),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '物件タブから物件を選択してください',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ),
        Expanded(
          child: _finances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 48,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      const SizedBox(height: 8),
                      const Text('収支記録がありません'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _finances.length,
                  itemBuilder: (context, i) {
                    final t = _finances[i];
                    final type = t['type'] as String? ?? '';
                    final isIncome = type.contains('income');
                    final amount = t['amount'] as num? ?? 0;
                    final desc = t['description'] as String? ?? '';
                    final label = _txnTypeLabels[type] ?? type;
                    return ListTile(
                      leading: Icon(
                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isIncome
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE53935),
                      ),
                      title: Text(label),
                      subtitle: desc.isNotEmpty ? Text(desc) : null,
                      trailing: Text(
                        '${isIncome ? '+' : '-'}¥${_fmt(amount.toDouble())}',
                        style: TextStyle(
                          color: isIncome
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsTab() {
    final count = _stats['totalProperties'] as int? ?? 0;
    final totalValue = _stats['totalValue'] as num? ?? 0;
    final totalIncome = _stats['totalIncome'] as num? ?? 0;
    final totalExpense = _stats['totalExpense'] as num? ?? 0;
    final netIncome = _stats['netIncome'] as num? ?? 0;
    final roi = _stats['roi'] as num? ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ポートフォリオ概要',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _statCard('物件数', '$count件', Icons.home_work, const Color(0xFF009688)),
          const SizedBox(height: 8),
          _statCard(
            '総資産評価額',
            '¥${_fmt(totalValue.toDouble())}',
            Icons.account_balance,
            const Color(0xFF3D5AFE),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総収入',
                  '¥${_fmt(totalIncome.toDouble())}',
                  Icons.trending_up,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  '総支出',
                  '¥${_fmt(totalExpense.toDouble())}',
                  Icons.trending_down,
                  const Color(0xFFE53935),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '純利益',
                  '¥${_fmt(netIncome.toDouble())}',
                  Icons.savings,
                  netIncome >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statCard(
                  'ROI',
                  '${roi.toStringAsFixed(2)}%',
                  Icons.percent,
                  const Color(0xFF3D5AFE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}億';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(1)}万';
    return v.toStringAsFixed(0);
  }
}
