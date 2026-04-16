import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// カーボンフットプリントトラッカーページ
/// carbon-footprint-tracker Edge Function と連携してCO2排出量を記録・可視化
class CarbonFootprintTrackerPage extends StatefulWidget {
  const CarbonFootprintTrackerPage({super.key});

  @override
  State<CarbonFootprintTrackerPage> createState() =>
      _CarbonFootprintTrackerPageState();
}

class _CarbonFootprintTrackerPageState
    extends State<CarbonFootprintTrackerPage> {
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
        'carbon-footprint-tracker',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['records'] is List) {
        setState(
          () =>
              _records = (data['records'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _records = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _records = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データ取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カーボンフットプリント'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchRecords,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _records.isEmpty
                  ? const Center(child: Text('記録がありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _records.length,
                      itemBuilder: (context, index) {
                        final record = _records[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              Icons.eco,
                              color: Colors.green,
                            ),
                            title: Text(
                              record['category']?.toString() ?? 'カテゴリ不明',
                            ),
                            subtitle: Text(
                              record['description']?.toString() ?? '',
                            ),
                            trailing: Text(
                              '${record['co2_kg']?.toString() ?? '?'} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
