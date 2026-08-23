import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// CRM 営業パイプラインページ
/// crm-sales-pipeline Edge Function と連携
/// Salesforce 競合 — リード管理・商談ステージ・活動ログ・AIリードスコア
class CrmSalesPipelinePage extends StatefulWidget {
  const CrmSalesPipelinePage({super.key});

  @override
  State<CrmSalesPipelinePage> createState() => _CrmSalesPipelinePageState();
}

class _CrmSalesPipelinePageState extends State<CrmSalesPipelinePage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['pipeline', 'leads', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _deals = [];
  final Map<String, Map<String, dynamic>> _pipeline = {};
  Map<String, dynamic>? _stats;

  // New lead form
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _selectedSource = 'web';

  static const _stageLabels = {
    'lead': 'リード',
    'qualified': '見込み確認',
    'proposal': '提案',
    'negotiation': '交渉',
    'closed_won': '受注',
    'closed_lost': '失注',
  };

  static const _stageColors = {
    'lead': Color(0xFF9CA3AF),
    'qualified': Color(0xFF3D5AFE),
    'proposal': Color(0xFFFF6B35),
    'negotiation': Color(0xFF3D5AFE),
    'closed_won': Color(0xFF4CAF50),
    'closed_lost': Color(0xFFE53935),
  };

  static const _sourceLabels = {
    'web': 'Web',
    'referral': '紹介',
    'advertisement': '広告',
    'social': 'SNS',
    'cold_call': '電話',
    'event': 'イベント',
    'partner': 'パートナー',
    'other': 'その他',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'crm.list_leads'}),
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'crm.list_leads'}),
        _supabase.functions
            .invoke('enterprise-hub', body: {'action': 'crm.list_leads'}),
      ]);

      final dealsData = results[0].data;
      if (dealsData is Map && dealsData['leads'] is List) {
        _deals = (dealsData['leads'] as List).cast<Map<String, dynamic>>();
      } else {
        _deals = [];
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'データの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLead() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名前は必須です')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'crm.add_lead',
          'name': name,
          'email':
              _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          'company': _companyCtrl.text.trim().isEmpty
              ? null
              : _companyCtrl.text.trim(),
          'phone':
              _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          'source': _selectedSource,
        },
      );
      _nameCtrl.clear();
      _emailCtrl.clear();
      _companyCtrl.clear();
      _phoneCtrl.clear();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リードを登録しました')),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('登録失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStage(String dealId, String newStage) async {
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'crm.update_stage', 'id': dealId, 'stage': newStage},
      );
      await _loadAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('更新失敗: $e')));
      }
    }
  }

  void _showAddLeadDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('新規リード登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名前 *'),
              ),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'メール'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextField(
                controller: _companyCtrl,
                decoration: const InputDecoration(labelText: '会社名'),
              ),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: '電話番号'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx2, setSt) => DropdownButtonFormField<String>(
                  initialValue: _selectedSource,
                  decoration: const InputDecoration(labelText: '流入元'),
                  items: _sourceLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setSt(() => _selectedSource = v);
                      setState(() => _selectedSource = v);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: _createLead,
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('CRM 営業パイプライン'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_kanban), text: 'パイプライン'),
            Tab(icon: Icon(Icons.people), text: 'リード'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: '更新',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLeadDialog,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('リード追加'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loadAll,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPipelineTab(),
                    _buildLeadsTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildPipelineTab() {
    final stages = _stageLabels.keys.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: stages.map((stage) {
          final info = _pipeline[stage];
          final count = (info?['count'] as num?)?.toInt() ?? 0;
          final value = (info?['value'] as num?)?.toInt() ?? 0;
          final stageDeals = _deals.where((d) => d['stage'] == stage).toList();
          final color = _stageColors[stage] ?? const Color(0xFF9CA3AF);
          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _stageLabels[stage] ?? stage,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '$count件',
                        style: TextStyle(
                          color: color,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      '¥${_formatYen(value)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                ...stageDeals.map(
                  (deal) => _buildDealCard(deal, color),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDealCard(Map<String, dynamic> deal, Color color) {
    final name = deal['name'] as String? ?? '名称未設定';
    final company = deal['company'] as String?;
    final score = (deal['score'] as num?)?.toInt() ?? 0;
    final dealId = deal['deal_id'] as String? ?? '';
    final stage = deal['stage'] as String? ?? 'lead';

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _scoreColor(score).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 11,
                      color: _scoreColor(score),
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (company != null && company.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  company,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'ステージ変更',
              onSelected: (s) => _updateStage(dealId, s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    'ステージ変更',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              itemBuilder: (_) => _stageLabels.entries
                  .where((e) => e.key != stage)
                  .map(
                    (e) => PopupMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadsTab() {
    if (_deals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text('リードがまだありません'),
            SizedBox(height: 4),
            Text(
              '「リード追加」からCRM管理を始めましょう',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deals.length,
      itemBuilder: (ctx, i) {
        final deal = _deals[i];
        final name = deal['name'] as String? ?? '名称未設定';
        final company = deal['company'] as String?;
        final email = deal['email'] as String?;
        final stage = deal['stage'] as String? ?? 'lead';
        final score = (deal['score'] as num?)?.toInt() ?? 0;
        final source = deal['lead_source'] as String? ?? 'web';
        final stageColor = _stageColors[stage] ?? const Color(0xFF9CA3AF);
        return Card(
          color: const Color(0xFF1E1E1E),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: stageColor.withValues(alpha: 0.2),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: stageColor,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company != null) Text(company),
                if (email != null)
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                Text(
                  '流入: ${_sourceLabels[source] ?? source}',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            isThreeLine: company != null || email != null,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _stageLabels[stage] ?? stage,
                    style: TextStyle(
                      fontSize: 12,
                      color: stageColor,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'スコア: $score',
                  style: TextStyle(
                    fontSize: 11,
                    color: _scoreColor(score),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(child: Text('統計データがありません'));
    }
    final total = (_stats!['totalDeals'] as num?)?.toInt() ?? 0;
    final won = (_stats!['wonCount'] as num?)?.toInt() ?? 0;
    final winRate = (_stats!['winRate'] as num?)?.toInt() ?? 0;
    final wonValue = (_stats!['wonValue'] as num?)?.toInt() ?? 0;
    final lostValue = (_stats!['lostValue'] as num?)?.toInt() ?? 0;
    final openValue = (_stats!['openValue'] as num?)?.toInt() ?? 0;
    final avgSize = (_stats!['avgDealSize'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '総案件数',
                  '$total件',
                  Icons.business_center,
                  const Color(0xFF3D5AFE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '受注数',
                  '$won件',
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statCard(
                  '勝率',
                  '$winRate%',
                  Icons.trending_up,
                  winRate >= 50
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF6B35),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  '平均案件規模',
                  '¥${_formatYen(avgSize)}',
                  Icons.attach_money,
                  const Color(0xFF3D5AFE),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '売上内訳',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _valueBar(
                    '受注',
                    wonValue,
                    wonValue + lostValue + openValue,
                    const Color(0xFF4CAF50),
                  ),
                  const SizedBox(height: 8),
                  _valueBar(
                    'パイプライン中',
                    openValue,
                    wonValue + lostValue + openValue,
                    const Color(0xFF3D5AFE),
                  ),
                  const SizedBox(height: 8),
                  _valueBar(
                    '失注',
                    lostValue,
                    wonValue + lostValue + openValue,
                    const Color(0xFFE53935),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valueBar(String label, int value, int total, Color color) {
    final pct = total > 0 ? value / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
            Text(
              '¥${_formatYen(value)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFF6B35);
    return const Color(0xFFE53935);
  }

  String _formatYen(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return '$value';
  }
}
