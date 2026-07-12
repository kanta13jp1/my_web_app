import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_summary.dart';

/// デジタルウォレットページ
/// social-commerce-hub Edge Function (wallet.balance) と連携して
/// 残高・取引履歴を管理する。
class DigitalWalletPage extends StatefulWidget {
  const DigitalWalletPage({super.key});

  @override
  State<DigitalWalletPage> createState() => _DigitalWalletPageState();
}

class _DigitalWalletPageState extends State<DigitalWalletPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isSignedIn = true;
  String? _errorMessage;
  WalletSummary _summary = WalletSummary.empty;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    if (_supabase.auth.currentUser == null) {
      setState(() {
        _isLoading = false;
        _isSignedIn = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isSignedIn = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'wallet.balance'},
      );
      final summary = WalletSummary.fromResponse(response.data);
      if (mounted) setState(() => _summary = summary);
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
      body: _buildBody(),
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isSignedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ログインすると残高と取引履歴が表示されます',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchTransactions,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTransactions,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 20),
          const Text(
            '取引履歴',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('取引履歴はありません')),
            )
          else
            ..._summary.transactions.map(_buildTransactionTile),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          ),
        ),
        child: Column(
          children: [
            const Text(
              '現在の残高',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '¥',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(width: 4),
                Text(
                  formatWalletYen(_summary.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransaction tx) {
    final createdAt = formatWalletTimestamp(tx.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color:
              tx.isCredit ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
        ),
        title: Text(
          tx.label,
          style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        ),
        subtitle: createdAt.isEmpty ? null : Text(createdAt),
        trailing: Text(
          '${tx.isCredit ? '+' : '-'}¥${formatWalletYen(tx.amount.abs())}',
          style: TextStyle(
            color:
                tx.isCredit ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
