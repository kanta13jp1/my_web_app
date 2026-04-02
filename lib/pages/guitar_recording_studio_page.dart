import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ギターレコーディングスタジオページ
/// guitar-recording-studio Edge Function と連携してチューニング・コード情報を取得
class GuitarRecordingStudioPage extends StatefulWidget {
  const GuitarRecordingStudioPage({super.key});

  @override
  State<GuitarRecordingStudioPage> createState() =>
      _GuitarRecordingStudioPageState();
}

class _GuitarRecordingStudioPageState
    extends State<GuitarRecordingStudioPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _studioData;

  @override
  void initState() {
    super.initState();
    _fetchStudioData();
  }

  Future<void> _fetchStudioData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'info'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _studioData = data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'スタジオ情報の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tunings = _studioData?['tunings'] as Map<String, dynamic>?;
    final chords = _studioData?['chords'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ギターレコーディングスタジオ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStudioData,
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
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_errorMessage!),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchStudioData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (tunings != null) ...[
                      const Text(
                        'チューニング',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...tunings.entries.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            leading: const Icon(Icons.music_note),
                            title: Text(e.key),
                            subtitle: Text(e.value.toString()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (chords != null) ...[
                      const Text(
                        'コード一覧',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: chords.entries
                            .map(
                              (e) => Chip(
                                avatar: const Icon(Icons.queue_music, size: 16),
                                label: Text(e.key),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (_studioData == null)
                      const Center(child: Text('データがありません')),
                  ],
                ),
    );
  }
}
