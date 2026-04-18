import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// アフィリエイト・マーケティングページ
/// affiliate-marketing Edge Function と連携してアフィリエイト情報を管理
class AffiliateMarketingPage extends StatefulWidget {
  const AffiliateMarketingPage({super.key});

  @override
  State<AffiliateMarketingPage> createState() => _AffiliateMarketingPageState();
}

class _AffiliateMarketingPageState extends State<AffiliateMarketingPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _campaigns = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'affiliate-marketing',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _campaigns =
              (data['campaigns'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _summary = data['summary'] as Map<String, dynamic>?;
        });
      } else if (data is List) {
        setState(() => _campaigns = data.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'アフィリエイト情報の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummaryCard() {
    if (_summary == null) return const SizedBox.shrink();
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat(
              '総クリック数',
              _summary!['total_clicks']?.toString() ?? '0',
              Icons.touch_app,
              Colors.blue,
            ),
            _buildStat(
              'コンバージョン',
              _summary!['total_conversions']?.toString() ?? '0',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStat(
              '報酬合計',
              '¥${_summary!['total_earnings']?.toString() ?? '0'}',
              Icons.monetization_on,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('アフィリエイト・マーケティング'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _buildSummaryCard(),
                  if (_summary != null) const SizedBox(height: 16),
                  const Text(
                    'キャンペーン一覧',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_campaigns.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('キャンペーンはありません'),
                      ),
                    )
                  else
                    ..._campaigns.map((c) {
                      final name = c['name']?.toString() ?? 'キャンペーン';
                      final status = c['status']?.toString() ?? '';
                      final clicks = c['clicks']?.toString() ?? '0';
                      final earnings = c['earnings']?.toString() ?? '0';
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          leading:
                              const Icon(Icons.campaign, color: Colors.indigo),
                          title: Text(name),
                          subtitle: Text('クリック: $clicks  |  報酬: ¥$earnings'),
                          trailing: Chip(
                            label: Text(status),
                            backgroundColor: status == 'active'
                                ? Colors.green[100]
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
