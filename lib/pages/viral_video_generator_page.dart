import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// バイラル動画ジェネレーターページ
/// viral-video-generator Edge Function と連携
class ViralVideoGeneratorPage extends StatefulWidget {
  const ViralVideoGeneratorPage({super.key});

  @override
  State<ViralVideoGeneratorPage> createState() =>
      _ViralVideoGeneratorPageState();
}

class _ViralVideoGeneratorPageState extends State<ViralVideoGeneratorPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _videos = [];
  Map<String, dynamic>? _result;

  final _promptController = TextEditingController();
  String _selectedStyle = 'short_reel';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'viral-video-generator',
        method: HttpMethod.get,
        queryParameters: {'view': 'history'},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['videos'] is List) {
        setState(() {
          _videos =
              (data['videos'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _result = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'viral-video-generator',
        body: {'prompt': prompt, 'style': _selectedStyle},
      );
      setState(() => _result = res.data as Map<String, dynamic>?);
      await _loadHistory();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バイラル動画ジェネレーター'),
      ),
      body: _loading && _videos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('動画を生成',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _promptController,
                            decoration: const InputDecoration(
                              labelText: 'プロンプト',
                              border: OutlineInputBorder(),
                              hintText: '動画の内容を入力してください',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedStyle,
                            decoration: const InputDecoration(
                              labelText: 'スタイル',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'short_reel', child: Text('ショートリール')),
                              DropdownMenuItem(
                                  value: 'story', child: Text('ストーリー')),
                              DropdownMenuItem(
                                  value: 'tutorial', child: Text('チュートリアル')),
                              DropdownMenuItem(
                                  value: 'announcement',
                                  child: Text('アナウンスメント')),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedStyle = v!),
                          ),
                          const SizedBox(height: 12),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _generate,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.video_call),
                              label: Text(_loading ? '生成中...' : '生成する'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('生成結果',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(_result!['message']?.toString() ??
                                '生成が完了しました'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('生成履歴',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_videos.isEmpty)
                    const Text('まだ生成履歴がありません')
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _videos.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final v = _videos[index];
                        return ListTile(
                          leading: const Icon(Icons.video_library),
                          title: Text(v['title']?.toString() ??
                              v['prompt']?.toString() ??
                              '動画 ${index + 1}'),
                          subtitle: Text(
                            v['style']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            v['created_at']?.toString().substring(0, 10) ?? '',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
