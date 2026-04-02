import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// フィットネス・健康トラッカーページ
/// fitness-health-tracker Edge Function と連携して健康データを管理する
class FitnessHealthTrackerPage extends StatefulWidget {
  const FitnessHealthTrackerPage({super.key});

  @override
  State<FitnessHealthTrackerPage> createState() => _FitnessHealthTrackerPageState();
}

class _FitnessHealthTrackerPageState extends State<FitnessHealthTrackerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'fitness-health-tracker',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['records'] is List) {
        setState(() => _records = (data['records'] as List).cast<Map<String, dynamic>>());
      } else if (data is List) {
        setState(() => _records = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _records = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '健康記録の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フィットネス・健康トラッカー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecords,
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
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _fetchRecords, child: const Text('再試行')),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? const Center(child: Text('健康記録がありません'))
                  : ListView.builder(
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return ListTile(
                          leading: const Icon(Icons.fitness_center),
                          title: Text(record['type']?.toString() ?? '記録 ${index + 1}'),
                          subtitle: Text(record['date']?.toString() ?? ''),
                          trailing: Text(record['value']?.toString() ?? ''),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: '健康データを記録',
        child: const Icon(Icons.add),
      ),
    );
  }
}
