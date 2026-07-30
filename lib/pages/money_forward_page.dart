import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'asset_management_page.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// MoneyForward 連携ページ
/// moneyforward-sync Edge Function と連携して家計簿・資産データを取り込む
class MoneyForwardPage extends StatefulWidget {
  const MoneyForwardPage({super.key});

  @override
  State<MoneyForwardPage> createState() => _MoneyForwardPageState();
}

class _MoneyForwardPageState extends State<MoneyForwardPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['accounts', 'transactions'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _connected = false;
  dynamic _totalAssets;
  String? _lastSyncAt;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _transactions = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'mf.status'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _connected = data['connected'] == true;
          _totalAssets = data['total_assets'];
          _lastSyncAt = data['last_sync_at']?.toString();
          if (data['accounts'] is List) {
            _accounts = List<Map<String, dynamic>>.from(
              (data['accounts'] as List).whereType<Map>(),
            );
          }
          if (data['transactions'] is List) {
            _transactions = List<Map<String, dynamic>>.from(
              (data['transactions'] as List).whereType<Map>(),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '状態の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'mf.sync'},
      );
      final data = res.data;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map && data['message'] != null
                  ? data['message'].toString()
                  : 'データを取得しました',
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '同期に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'mf.connect_url'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'MoneyForward認証URLを取得しました。ブラウザで連携を完了してください。',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '接続URLの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '—';
    final n = (amount is num) ? amount.toInt() : int.tryParse('$amount') ?? 0;
    final abs = n.abs();
    final formatted = abs.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${n < 0 ? '-' : ''}¥$formatted';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyForward 連携'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '資産管理へ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: '/asset-management'),
                  builder: (_) => const AssetManagementPage(
                    initialFocus: AssetManagementInitialFocus.assets,
                    entryLabel: 'MoneyForward連携',
                    entryDescription:
                        '口座・証券・家計の確認は資産管理に統合しました。資産残高、収支、固定費、借金ロックダウン、浪費抑制AIを一つの画面で見られます。',
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _fetchStatus,
            ),
        ],
        bottom: _connected
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '口座・資産'),
                  Tab(text: '取引履歴'),
                ],
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: _connected
            ? TabBarView(
                controller: _tabController,
                children: [
                  _AccountsTab(
                    accounts: _accounts,
                    totalAssets: _totalAssets,
                    lastSyncAt: _lastSyncAt,
                    isSyncing: _isSyncing,
                    onSync: _sync,
                    formatAmount: _formatAmount,
                    errorMessage: _errorMessage,
                  ),
                  _TransactionsTab(
                    transactions: _transactions,
                    formatAmount: _formatAmount,
                  ),
                ],
              )
            : _DisconnectedView(
                isLoading: _isLoading,
                errorMessage: _errorMessage,
                onConnect: _connect,
              ),
      ),
    );
  }
}

class _DisconnectedView extends StatelessWidget {
  const _DisconnectedView({
    required this.isLoading,
    required this.errorMessage,
    required this.onConnect,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A1010)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF5A2020)
                      : const Color(0xFFEF9A9A),
                ),
              ),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFC62828),
                  height: 1.5,
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
        const Center(
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Color(0xFF00B900),
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'MoneyForward と連携する',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            '銀行・証券・クレジットカードの残高・取引を\n自動取り込みして資産を一元管理',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onConnect,
          icon: const Icon(Icons.link),
          label: const Text('MoneyForward に接続する'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B900),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            textStyle: const TextStyle(
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        const Card(
          color: Color(0xFFF0FDF4),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF16A34A),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '連携できるもの',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _BulletItem(text: '銀行口座・残高（三菱UFJ・三井住友・ゆうちょ等）'),
                _BulletItem(text: '証券・投資信託・株式ポートフォリオ'),
                _BulletItem(text: 'クレジットカード利用明細'),
                _BulletItem(text: '電子マネー・ポイント残高'),
                _BulletItem(text: '年金・保険積立金'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.accounts,
    required this.totalAssets,
    required this.lastSyncAt,
    required this.isSyncing,
    required this.onSync,
    required this.formatAmount,
    required this.errorMessage,
  });

  final List<Map<String, dynamic>> accounts;
  final dynamic totalAssets;
  final String? lastSyncAt;
  final bool isSyncing;
  final VoidCallback onSync;
  final String Function(dynamic) formatAmount;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF3A1010)
                    : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF5A2020)
                      : const Color(0xFFEF9A9A),
                ),
              ),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEF9A9A)
                      : const Color(0xFFC62828),
                  height: 1.5,
                ),
              ),
            ),
          ),
        Card(
          color: const Color(0xFF00B900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  '総資産',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formatAmount(totalAssets),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                if (lastSyncAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '最終更新: $lastSyncAt',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: isSyncing ? null : onSync,
                  icon: isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00B900),
                          ),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(isSyncing ? '取得中...' : '今すぐ更新'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00B900),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '口座・資産内訳',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ...accounts.map(
            (acc) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      const Color(0xFF00B900).withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.account_balance,
                    color: Color(0xFF00B900),
                    size: 20,
                  ),
                ),
                title: Text(acc['name']?.toString() ?? '口座'),
                subtitle: Text(
                  acc['institution']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                trailing: Text(
                  formatAmount(acc['balance']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                '口座情報がありません\n上の「今すぐ更新」を押してデータを取得してください',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black45,
                  height: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TransactionsTab extends StatelessWidget {
  const _TransactionsTab({
    required this.transactions,
    required this.formatAmount,
  });

  final List<Map<String, dynamic>> transactions;
  final String Function(dynamic) formatAmount;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text(
          '取引履歴がありません\n口座タブから「今すぐ更新」を押してください',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black45,
            height: 1.5,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final amount = tx['amount'];
        final isExpense =
            amount is num ? amount < 0 : (int.tryParse('$amount') ?? 0) < 0;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isExpense ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
              child: Icon(
                isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: isExpense
                    ? const Color(0xFFE53935)
                    : const Color(0xFF4CAF50),
                size: 18,
              ),
            ),
            title: Text(tx['description']?.toString() ?? '取引'),
            subtitle: Text(
              tx['date']?.toString() ?? '',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
              ),
            ),
            trailing: Text(
              formatAmount(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isExpense
                    ? const Color(0xFFE53935)
                    : const Color(0xFF4CAF50),
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFF16A34A),
              height: 1.5,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
