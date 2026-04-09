import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// グロース司令部ページ
/// KPI 指標を入力し AI が戦略ブリーフを生成する
class GrowthCommandCenterPage extends StatefulWidget {
  const GrowthCommandCenterPage({super.key});

  @override
  State<GrowthCommandCenterPage> createState() =>
      _GrowthCommandCenterPageState();
}

class _GrowthCommandCenterPageState extends State<GrowthCommandCenterPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final response =
          await _supabase.functions.invoke('growth-command-center');

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _result = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'コマンドセンター取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildBriefCard(Map<String, dynamic> brief) {
    final priorityColor = switch (brief['priority']?.toString()) {
      'critical' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.yellow.shade700,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    brief['label']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  brief['owner']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(brief['objective']?.toString() ?? ''),
            if (brief['nextAction'] != null) ...[
              const SizedBox(height: 4),
              Text(
                '→ ${brief['nextAction']}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final briefs = _result != null && _result!['departments'] is List
        ? List<Map<String, dynamic>>.from(
            (_result!['departments'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('グロース司令部'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _result == null && !_isLoading
          ? Center(
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.rocket_launch),
                label: const Text('コマンドセンターを起動'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_result!['summary'] != null) ...[
                            Text(
                              _result!['summary'].toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (briefs.isNotEmpty) ...[
                            const Text(
                              '部門ブリーフィング',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...briefs.map(_buildBriefCard),
                          ] else
                            const Text(
                              'データがありません',
                              style: TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
