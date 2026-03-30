import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ElectionManagementDashboard extends StatefulWidget {
  const ElectionManagementDashboard({super.key});

  @override
  State<ElectionManagementDashboard> createState() => _ElectionManagementDashboardState();
}

class _ElectionManagementDashboardState extends State<ElectionManagementDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _politicians = [];
  Map<String, dynamic>? _monthlyKpi;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchElectionData();
  }

  Future<void> _fetchElectionData() async {
    try {
      // Edge Function経由でAI検索・整形された最新の実データを取得
      final response = await Supabase.instance.client.functions.invoke(
        'fetch-local-politicians',
      );
      final data = response.data;
      if (mounted && data != null) {
        final raw = data as Map<String, dynamic>;
        setState(() {
          _politicians = (raw['politicians'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .toList();
          _monthlyKpi = raw['monthlyKpi'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching election data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統一地方選 700人倍増 KPI管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: '月次工程管理 (KPI)'),
            Tab(icon: Icon(Icons.people), text: '最新実データ (AI取得)'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildKpiTab(),
                _buildPoliticiansTab(),
              ],
            ),
    );
  }

  Widget _buildKpiTab() {
    if (_monthlyKpi == null) return const Center(child: Text('データがありません'));
    
    final regions = (_monthlyKpi!['regions'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.red.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('党全体必達目標', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                  const SizedBox(height: 12),
                  Text('現在の現職数: ${_monthlyKpi!['currentTotal']}人', style: const TextStyle(fontSize: 16)),
                  Text('必達目標数: ${_monthlyKpi!['targetTotal']}人', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  Text('必要な純増数: ${_monthlyKpi!['requiredAddition']}人', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  Text(
                    _monthlyKpi!['message'], 
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text('※万が一達成できなければ解党の覚悟で臨む“工程管理”の勝負です。', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('都道府県連ごとの月次KPI配分', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) => Colors.grey.shade100),
              columns: const [
                DataColumn(label: Text('都道府県', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('現職維持目標', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('必達目標', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('新人擁立数', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('接戦区支援回数', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('公認内定時期', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: regions.map((region) {
                return DataRow(
                  cells: [
                    DataCell(Text(region['name']?.toString() ?? '')),
                    DataCell(Text(region['current']?.toString() ?? '')),
                    DataCell(Text(region['target']?.toString() ?? '')),
                    DataCell(Text(region['newCandidates']?.toString() ?? '')),
                    DataCell(Text(region['supportCount']?.toString() ?? '')),
                    DataCell(Text(region['expectedEndorsement']?.toString() ?? '')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliticiansTab() {
    if (_politicians.isEmpty) return const Center(child: Text('議員データがありません'));

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _politicians.length,
      itemBuilder: (context, index) {
        final p = _politicians[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p['gender'] == '女性' ? Colors.pink.shade100 : Colors.blue.shade100,
              child: Text(p['gender'] == '女性' ? '👩' : '👨', style: const TextStyle(fontSize: 20)),
            ),
            title: Text('${p['name']} (${p['age']}歳) - ${p['gender']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text('${p['region']} ${p['municipality']} / ${p['type']}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                const SizedBox(height: 4),
                Text(p['profile']?.toString() ?? '', style: const TextStyle(height: 1.3)),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}