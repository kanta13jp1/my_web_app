import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 成長自動化コントローラーページ
/// growth-automation-controller Edge Function と連携
class GrowthAutomationControllerPage extends StatefulWidget {
  const GrowthAutomationControllerPage({super.key});

  @override
  State<GrowthAutomationControllerPage> createState() =>
      _GrowthAutomationControllerPageState();
}

class _GrowthAutomationControllerPageState
    extends State<GrowthAutomationControllerPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _items = [];

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
        'growth-hub',
        body: {'action': 'automation.analyze'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['campaigns'] is List) {
        setState(
          () => _items =
              (data['campaigns'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _items = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _items = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'データの取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長自動化コントローラー'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchData,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('キャンペーンデータはありません'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final name = item['name']?.toString() ?? 'キャンペーン ${index + 1}';
                final status = item['status']?.toString() ?? '不明';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.auto_graph,
                      color: Colors.indigo,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Chip(
                      label: Text(status, style: const TextStyle(fontSize: 12)),
                      backgroundColor: status == 'active'
                          ? Colors.green.shade100
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
