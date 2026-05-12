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
    if (_supabase.auth.currentUser == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'viral_video.list_briefs'},
      );
      final data = res.data;
      if (data is Map<String, dynamic> && data['briefs'] is List) {
        setState(() {
          _videos = (data['briefs'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
        'media-hub',
        body: {
          'action': 'viral_video.create',
          'productSummary': prompt,
          'adStyle': _selectedStyle,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() => _result = data?['brief'] as Map<String, dynamic>?);
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
      setState(() => _loading = false);
    }
  }

  static String _shortDate(String? s) {
    if (s == null || s.length < 10) return '';
    return s.substring(0, 10);
  }

  Widget _buildBriefResultCard({required Map<String, dynamic> brief}) {
    final score = brief['viralScore'];
    final scoreInt = score is num ? score.toInt() : null;
    final hashtags = brief['hashtags'];
    final hashtagList = hashtags is List ? hashtags.cast<String>() : <String>[];
    final scenes = brief['scenes'];
    final sceneCount = scenes is List ? scenes.length : 0;

    return Builder(
      builder: (context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      brief['conceptName']?.toString() ?? '生成完了',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (scoreInt != null)
                    Chip(
                      label: Text(
                        'VS $scoreInt',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      backgroundColor:
                          scoreInt >= 80 ? const Color(0xFFF57C00) : null,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (brief['primaryHook'] != null) ...[
                Text(
                  'フック',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(brief['primaryHook'].toString()),
                const SizedBox(height: 8),
              ],
              if (brief['xPostText'] != null) ...[
                Text(
                  'X投稿文',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(brief['xPostText'].toString()),
                const SizedBox(height: 8),
              ],
              if (brief['cta'] != null) ...[
                Text(
                  'CTA',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(brief['cta'].toString()),
                const SizedBox(height: 8),
              ],
              if (hashtagList.isNotEmpty) ...[
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: hashtagList
                      .map(
                        (tag) => Chip(
                          label: Text(
                            tag.startsWith('#') ? tag : '#$tag',
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (sceneCount > 0)
                Text(
                  'シーン数: $sceneCount',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
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
                          Text(
                            '動画を生成',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
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
                            initialValue: _selectedStyle,
                            decoration: const InputDecoration(
                              labelText: 'スタイル',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'short_reel',
                                child: Text('ショートリール'),
                              ),
                              DropdownMenuItem(
                                value: 'story',
                                child: Text('ストーリー'),
                              ),
                              DropdownMenuItem(
                                value: 'tutorial',
                                child: Text('チュートリアル'),
                              ),
                              DropdownMenuItem(
                                value: 'announcement',
                                child: Text('アナウンスメント'),
                              ),
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
                                style: const TextStyle(
                                  color: Color(0xFFE53935),
                                  height: 1.5,
                                ),
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
                                        strokeWidth: 2,
                                      ),
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
                    _buildBriefResultCard(brief: _result!),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '生成履歴',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
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
                        final score = v['viralScore'];
                        final scoreInt = score is num ? score.toInt() : null;
                        return ListTile(
                          leading: const Icon(Icons.video_library),
                          title: Text(
                            v['conceptName']?.toString() ?? '動画 ${index + 1}',
                          ),
                          subtitle: Text(
                            v['primaryHook']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (scoreInt != null)
                                Text(
                                  'VS $scoreInt',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: scoreInt >= 80
                                        ? const Color(0xFFFF6B35)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    height: 1.5,
                                  ),
                                ),
                              Text(
                                _shortDate(v['createdAt']?.toString()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ],
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
