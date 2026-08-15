import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/affiliate_link_stats.dart';

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
  List<AffiliateLinkStats> _campaigns = [];
  AffiliateSummary? _summary;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'affiliate.list_links'},
      );
      final links = AffiliateLinkStats.listFromResponse(response.data);
      setState(() {
        _campaigns = links;
        _summary = AffiliateSummary.fromLinks(links);
      });
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
              _summary!.totalClicks.toString(),
              Icons.touch_app,
              const Color(0xFF3D5AFE),
            ),
            _buildStat(
              'コンバージョン',
              _summary!.totalConversions.toString(),
              Icons.check_circle,
              const Color(0xFF4CAF50),
            ),
            _buildStat(
              'リンク数',
              _summary!.linkCount.toString(),
              Icons.link,
              const Color(0xFFFF6B35),
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFB0B0B0),
            height: 1.5,
          ),
        ),
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
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _buildSummaryCard(),
                  if (_summary != null) const SizedBox(height: 16),
                  const Text(
                    'キャンペーン一覧',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
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
                      final name = c.title.isNotEmpty ? c.title : 'キャンペーン';
                      final commission = c.commissionPct > 0
                          ? '  |  報酬率: ${c.commissionPct}%'
                          : '';
                      return Card(
                        color: const Color(0xFF1E1E1E),
                        child: ListTile(
                          leading: const Icon(
                            Icons.campaign,
                            color: Color(0xFF3D5AFE),
                          ),
                          title: Text(name),
                          subtitle: Text(
                            'クリック: ${c.clicks}  |  CV: ${c.conversions}$commission',
                          ),
                          trailing: c.code.isNotEmpty
                              ? Chip(
                                  label: Text(
                                    c.code,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
