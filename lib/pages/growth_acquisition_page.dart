import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 成長獲得統合ページ
/// Signal記録 + レポート生成 (growth-acquisition EF)
class GrowthAcquisitionPage extends StatefulWidget {
  const GrowthAcquisitionPage({super.key});

  @override
  State<GrowthAcquisitionPage> createState() => _GrowthAcquisitionPageState();
}

class _GrowthAcquisitionPageState extends State<GrowthAcquisitionPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'growth-acquisition',
        queryParameters: {'action': 'report', 'windowDays': '30'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _reportData = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'レポート取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _recordSignal(String signalKey) async {
    try {
      await _supabase.functions.invoke(
        'growth-acquisition',
        body: {'action': 'signal', 'signalKey': signalKey},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('シグナル記録: $signalKey')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('シグナル記録失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長獲得ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReport,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final touchpoints = _reportData?['touchpoints'] as List<dynamic>? ?? [];
    final summary = _reportData?['summary'] as Map<String, dynamic>? ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // サマリーカード
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '獲得サマリー (30日)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                _summaryRow('総タッチ数', '${summary['totalTouches'] ?? 0}'),
                _summaryRow('総登録数', '${summary['totalSignups'] ?? 0}'),
                _summaryRow(
                  'コンバージョン率',
                  '${summary['conversionRate'] ?? '0.0'}%',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'タッチポイント別',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (touchpoints.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('データがありません'),
            ),
          )
        else
          ...touchpoints.map((tp) {
            final item = tp as Map<String, dynamic>;
            return Card(
              child: ListTile(
                title: Text(item['touchpoint']?.toString() ?? ''),
                subtitle: Text(
                  'タッチ: ${item['touches'] ?? 0}  登録: ${item['signups'] ?? 0}',
                ),
                trailing: Text(
                  '${item['rate'] ?? '0.0'}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
        const Text(
          'シグナル記録',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'touch_landing',
            'touch_import',
            'touch_public_memo',
            'touch_referral',
          ]
              .map(
                (key) => OutlinedButton(
                  onPressed: () => _recordSignal(key),
                  child: Text(key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
