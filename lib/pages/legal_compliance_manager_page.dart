import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/paddle_approval_readiness_card.dart';
import '../widgets/legal_term_tooltip_text.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// Legal / compliance manager page
/// - contracts and checklist come from legal-compliance-manager EF
/// - Harvey review runs through tools-hub: legal.harvey.complete
class LegalComplianceManagerPage extends StatefulWidget {
  const LegalComplianceManagerPage({super.key});

  @override
  State<LegalComplianceManagerPage> createState() =>
      _LegalComplianceManagerPageState();
}

class _LegalComplianceManagerPageState extends State<LegalComplianceManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['contracts', 'checklist', 'saas-review', 'harvey'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  final _harveyPromptCtrl = TextEditingController();
  final _harveyMatterCtrl = TextEditingController();
  final _harveyModelCtrl = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _checklist = [];

  bool _isRunningHarvey = false;
  bool _harveyIncludeCitations = true;
  bool _harveyUseWeb = false;
  String _harveyMode = 'draft';
  String? _harveyError;
  String? _harveyResponse;
  String? _harveyCitationsResponse;
  List<Map<String, dynamic>> _harveySources = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _harveyPromptCtrl.dispose();
    _harveyMatterCtrl.dispose();
    _harveyModelCtrl.dispose();
    super.dispose();
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
      final cRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'legal.list'},
      );
      final chRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'compliance.list'},
      );
      setState(() {
        _contracts = _toList(cRes.data, 'contracts');
        _checklist = _toList(chRes.data, 'items');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  Future<void> _runHarveyReview() async {
    final prompt = _harveyPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _harveyError = '質問やレビューしたい文章を入力してください。';
      });
      return;
    }

    setState(() {
      _isRunningHarvey = true;
      _harveyError = null;
    });

    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'legal-assistant.harvey.complete',
          'prompt': prompt,
          'mode': _harveyMode,
          'include_citations': _harveyIncludeCitations,
          'use_web': _harveyUseWeb,
          if (_harveyMatterCtrl.text.trim().isNotEmpty)
            'client_matter_id': _harveyMatterCtrl.text.trim(),
          if (_harveyModelCtrl.text.trim().isNotEmpty)
            'model': _harveyModelCtrl.text.trim(),
        },
      );

      final data = response.data;
      if (data is! Map) {
        setState(() {
          _harveyError = 'Harvey の応答形式を解釈できませんでした。';
          _harveyResponse = null;
          _harveyCitationsResponse = null;
          _harveySources = [];
        });
        return;
      }

      final map = Map<String, dynamic>.from(data);
      if (map['success'] != true) {
        setState(() {
          _harveyError = map['error']?.toString() ?? 'Harvey の呼び出しに失敗しました。';
          _harveyResponse = null;
          _harveyCitationsResponse = null;
          _harveySources = [];
        });
        return;
      }

      final sources = (map['sources'] as List?)
              ?.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList() ??
          <Map<String, dynamic>>[];

      setState(() {
        _harveyResponse = map['response']?.toString().trim();
        _harveyCitationsResponse =
            map['response_with_citations']?.toString().trim();
        _harveySources = sources;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _harveyError = '$e';
        _harveyResponse = null;
        _harveyCitationsResponse = null;
        _harveySources = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunningHarvey = false;
        });
      }
    }
  }

  String _sourceSummary(Map<String, dynamic> source) {
    final title = source['title']?.toString().trim();
    final kind = source['type']?.toString().trim();
    final url = source['url']?.toString().trim();
    final fragments = <String>[
      if (title != null && title.isNotEmpty) title,
      if (kind != null && kind.isNotEmpty) kind,
      if (url != null && url.isNotEmpty) url,
    ];
    return fragments.isEmpty ? source.toString() : fragments.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('法務・コンプライアンス'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.description), text: '契約'),
            Tab(icon: Icon(Icons.checklist), text: 'チェック'),
            Tab(icon: Icon(Icons.verified_user_outlined), text: 'SaaS審査'),
            Tab(icon: Icon(Icons.gavel), text: 'Harvey'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildContractsTab(),
                    _buildChecklistTab(),
                    _buildSaasReviewTab(),
                    _buildHarveyTab(),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再読み込み')),
        ],
      ),
    );
  }

  Widget _buildContractsTab() {
    if (_contracts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '契約データがまだありません',
              style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _contracts.length,
      itemBuilder: (ctx, i) {
        final c = _contracts[i];
        final title = c['title'] as String? ?? '契約 ${i + 1}';
        final party = c['counterparty'] as String? ?? '';
        final expiry = c['expiryDate'] as String? ?? '';
        final status = c['status'] as String? ?? 'active';
        final daysLeft = c['daysUntilExpiry'] as int?;
        final urgent = daysLeft != null && daysLeft <= 30;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: urgent ? const Color(0xFFFFEBEE) : null,
          child: ListTile(
            leading: Icon(
              Icons.description,
              color: urgent ? const Color(0xFFE53935) : const Color(0xFF3D5AFE),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            subtitle: Text(party.isNotEmpty ? party : status),
            trailing: expiry.isNotEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        expiry.length >= 10 ? expiry.substring(0, 10) : expiry,
                        style: TextStyle(
                          fontSize: 11,
                          color: urgent
                              ? const Color(0xFFE53935)
                              : const Color(0xFF9CA3AF),
                          fontWeight: urgent ? FontWeight.bold : null,
                          height: 1.5,
                        ),
                      ),
                      if (daysLeft != null)
                        Text(
                          'あと $daysLeft 日',
                          style: TextStyle(
                            fontSize: 10,
                            color: urgent
                                ? const Color(0xFFE53935)
                                : const Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildChecklistTab() {
    if (_checklist.isEmpty) {
      return const Center(
        child: Text(
          'チェック項目がまだありません',
          style: TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
        ),
      );
    }
    final completed = _checklist.where((c) => c['done'] == true).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LinearProgressIndicator(
            value: _checklist.isNotEmpty ? completed / _checklist.length : 0,
            minHeight: 8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$completed / ${_checklist.length} 完了',
            style: const TextStyle(color: Color(0xFF9CA3AF), height: 1.5),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _checklist.length,
            itemBuilder: (ctx, i) {
              final item = _checklist[i];
              final text = item['text'] as String? ?? '';
              final done = item['done'] as bool? ?? false;
              final priority = item['priority'] as String? ?? 'normal';
              return CheckboxListTile(
                value: done,
                onChanged: (_) {},
                title: Text(
                  text,
                  style: TextStyle(
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? const Color(0xFF9CA3AF) : null,
                    height: 1.5,
                  ),
                ),
                secondary: priority == 'high'
                    ? const Icon(
                        Icons.priority_high,
                        color: Color(0xFFE53935),
                        size: 18,
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaasReviewTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: const [PaddleApprovalReadinessCard(touchesRegulatedData: true)],
    );
  }

  Widget _buildHarveyTab() {
    final answer = (_harveyCitationsResponse != null &&
            _harveyCitationsResponse!.isNotEmpty)
        ? _harveyCitationsResponse!
        : (_harveyResponse ?? '');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_outlined, color: Color(0xFF3D5AFE)),
                    SizedBox(width: 8),
                    Text(
                      'Harvey backend review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '法務管理のバックエンドとして Harvey を使い、契約レビューや法務メモの草案を Edge Function 経由で実行できます。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF7C3AED)),
                    SizedBox(width: 8),
                    Text(
                      '専門用語のインライン解説',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                LegalTermTooltipText(
                  text:
                      '憲法審査会では、参議院の緊急集会、緊急政令、繰延投票、国民投票法附則4条、国家緊急権などを横断して論点整理します。',
                  style: TextStyle(height: 1.6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _harveyPromptCtrl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '質問 / レビューしたい本文',
                    hintText: '例: この業務委託契約の解除条項に偏りがないか、発注者側のリスクも含めて確認してください。',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _harveyMatterCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Matter ID (任意)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _harveyModelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model (任意)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _harveyMode,
                  decoration: const InputDecoration(
                    labelText: 'Mode',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'draft', child: Text('draft')),
                    DropdownMenuItem(value: 'assist', child: Text('assist')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _harveyMode = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('引用つき回答を優先'),
                  subtitle: const Text('response_with_citations を優先表示します。'),
                  value: _harveyIncludeCitations,
                  onChanged: (value) {
                    setState(() {
                      _harveyIncludeCitations = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Web knowledge を使う'),
                  subtitle: const Text('必要に応じて Web を knowledge source に追加します。'),
                  value: _harveyUseWeb,
                  onChanged: (value) {
                    setState(() {
                      _harveyUseWeb = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRunningHarvey ? null : _runHarveyReview,
                    icon: _isRunningHarvey
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isRunningHarvey ? 'Harvey 実行中...' : 'Harvey でレビュー',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_harveyError != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF3A1010)
                : const Color(0xFFFFEBEE),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _harveyError!,
                style: const TextStyle(color: Color(0xFFC62828), height: 1.5),
              ),
            ),
          ),
        ],
        if (answer.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Harvey 回答',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  LegalTermTooltipText(
                    text: answer,
                    style: const TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_harveySources.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sources',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._harveySources.map(
                    (source) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.link,
                              size: 16,
                              color: Color(0xFF3D5AFE),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _sourceSummary(source),
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
