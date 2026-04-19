import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 法務・コンプライアンス管理ページ
/// 契約管理・コンプライアンスチェック・期限アラート。
/// legal-compliance-manager Edge Function と連携。
class LegalComplianceManagerPage extends StatefulWidget {
  const LegalComplianceManagerPage({super.key});

  @override
  State<LegalComplianceManagerPage> createState() =>
      _LegalComplianceManagerPageState();
}

class _LegalComplianceManagerPageState extends State<LegalComplianceManagerPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _contracts = [];
  List<Map<String, dynamic>> _checklist = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cRes = await _supabase.functions.invoke(
        'legal-compliance-manager',
        queryParameters: {'view': 'contracts'},
      );
      final chRes = await _supabase.functions.invoke(
        'legal-compliance-manager',
        queryParameters: {'view': 'checklist'},
      );
      setState(() {
        _contracts = _toList(cRes.data, 'contracts');
        _checklist = _toList(chRes.data, 'items');
      });
    } catch (e) {
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
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
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildContractsTab(), _buildChecklistTab()],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
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
              '契約書がありません',
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
          color: urgent ? Colors.red.shade50 : null,
          child: ListTile(
            leading: Icon(
              Icons.description,
              color: urgent ? Colors.red : const Color(0xFF3D5AFE),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
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
                          color: urgent ? Colors.red : const Color(0xFF9CA3AF),
                          fontWeight: urgent ? FontWeight.bold : null,
                          height: 1.5,
                        ),
                      ),
                      if (daysLeft != null)
                        Text(
                          '残$daysLeft日',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                urgent ? Colors.red : const Color(0xFF9CA3AF),
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
          'チェック項目がありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
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
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
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
                        color: Colors.red,
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
}
