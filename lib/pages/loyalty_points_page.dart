import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ロイヤルティポイントページ
/// loyalty-points Edge Function と連携してポイント残高・履歴を管理
class LoyaltyPointsPage extends StatefulWidget {
  const LoyaltyPointsPage({super.key});

  @override
  State<LoyaltyPointsPage> createState() => _LoyaltyPointsPageState();
}

class _LoyaltyPointsPageState extends State<LoyaltyPointsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'loyalty-points',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['history'] is List) {
        setState(
          () =>
              _history = (data['history'] as List).cast<Map<String, dynamic>>(),
        );
      } else if (data is List) {
        setState(() => _history = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _history = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ポイント履歴の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ロイヤルティポイント'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
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
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _history.isEmpty
                  ? const Center(child: Text('ポイント履歴はありません'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final item = _history[index];
                        final description = item['description']?.toString() ??
                            'ポイント ${index + 1}';
                        final points = item['points']?.toString() ?? '0';
                        final type = item['type']?.toString() ?? 'earn';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(
                              Icons.stars,
                              color: Color(0xFFFFC107),
                            ),
                            title: Text(
                              description,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                            subtitle:
                                Text(item['created_at']?.toString() ?? ''),
                            trailing: Text(
                              '${type == 'earn' ? '+' : '-'}$points pt',
                              style: TextStyle(
                                color:
                                    type == 'earn' ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                height: 1.5,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ポイント交換機能は準備中です')),
          );
        },
        icon: const Icon(Icons.redeem),
        label: const Text('交換'),
      ),
    );
  }
}
