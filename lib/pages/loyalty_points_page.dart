import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/loyalty_points_summary.dart';

/// ロイヤルティポイントページ
/// social-commerce-hub Edge Function (loyalty.balance) と連携して
/// ポイント残高・履歴を管理する。
class LoyaltyPointsPage extends StatefulWidget {
  const LoyaltyPointsPage({super.key});

  @override
  State<LoyaltyPointsPage> createState() => _LoyaltyPointsPageState();
}

class _LoyaltyPointsPageState extends State<LoyaltyPointsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isSignedIn = true;
  String? _errorMessage;
  LoyaltyPointsSummary _summary = LoyaltyPointsSummary.empty;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
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
        body: {'action': 'loyalty.balance'},
      );
      final summary = LoyaltyPointsSummary.fromResponse(response.data);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ポイント履歴の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ロイヤルティポイント'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ポイント交換機能は準備中です')),
          );
        },
        icon: const Icon(Icons.redeem),
        label: const Text('交換'),
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
            'ログインするとポイント残高と履歴が表示されます',
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
              onPressed: _fetchHistory,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchHistory,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBalanceCard(),
          const SizedBox(height: 20),
          const Text(
            '獲得・利用履歴',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_summary.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('ポイント履歴はありません')),
            )
          else
            ..._summary.entries.map(_buildHistoryTile),
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
            colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
          ),
        ),
        child: Column(
          children: [
            const Text(
              '現在のポイント残高',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formatLoyaltyPoints(_summary.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'pt',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTile(LoyaltyPointEntry entry) {
    final createdAt = formatLoyaltyTimestamp(entry.createdAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          entry.isEarn ? Icons.stars : Icons.redeem,
          color:
              entry.isEarn ? const Color(0xFFFFC107) : const Color(0xFF757575),
        ),
        title: Text(
          entry.reason,
          style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        ),
        subtitle: createdAt.isEmpty ? null : Text(createdAt),
        trailing: Text(
          '${entry.isEarn ? '+' : '-'}${formatLoyaltyPoints(entry.amount.abs())} pt',
          style: TextStyle(
            color: entry.isEarn
                ? const Color(0xFF4CAF50)
                : const Color(0xFFE53935),
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
