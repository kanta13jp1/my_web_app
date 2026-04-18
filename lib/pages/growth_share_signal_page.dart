import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 共有シグナル確認ページ
/// 公開メモの共有・コピーシグナルの集計を表示
class GrowthShareSignalPage extends StatefulWidget {
  const GrowthShareSignalPage({super.key});

  @override
  State<GrowthShareSignalPage> createState() => _GrowthShareSignalPageState();
}

class _GrowthShareSignalPageState extends State<GrowthShareSignalPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // dateKey を今日の日付で渡してシグナル集計を取得
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await _supabase.functions.invoke(
        'growth-share-signal',
        body: {'dateKey': dateKey},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _data = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'シグナル取得に失敗しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('共有シグナル'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
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
                      const Text(
                        '公開メモの共有・コピーシグナル',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (d == null)
                        const Text(
                          'データがありません',
                          style: TextStyle(color: Color(0xFFB0B0B0)),
                        )
                      else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.share,
                                        color: Color(0xFFFF6B35),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        d['shareCount']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6B35),
                                        ),
                                      ),
                                      const Text('シェア数'),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.copy,
                                        color: Color(0xFF3D5AFE),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        d['copyCount']?.toString() ?? '0',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3D5AFE),
                                        ),
                                      ),
                                      const Text('コピー数'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (d['date'] != null)
                          Text(
                            '集計日: ${d['date']}',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
