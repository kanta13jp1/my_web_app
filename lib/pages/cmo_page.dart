import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';

class CmoPage extends StatefulWidget {
  const CmoPage({super.key});

  @override
  State<CmoPage> createState() => _CmoPageState();
}

class _CmoPageState extends State<CmoPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _pressRelease;

  // Colors
  final Color _purple = const Color(0xFF7C3AED);
  final Color _bg = const Color(0xFFF8FAFC);

  Future<void> _generatePressRelease() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Fetch recent data to feed the AI
      final stats = await supabase
          .from('user_stats')
          .select()
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();
      final notes = await supabase
          .from('notes')
          .select('title')
          .eq('user_id', userId)
          .eq('is_archived', false)
          .limit(3);

      final boardData = {
        'userStats': stats,
        'recentNotes': notes,
      };

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'draft_press_release',
          'boardData': boardData,
        },
      );

      if (response.status != 200) {
        throw Exception('AI Error: ${response.status}');
      }
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? 'Unknown error from AI function');
      }

      if (mounted) {
        setState(() {
          _pressRelease = data['result'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('発行エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sharePressRelease() {
    if (_pressRelease == null) return;
    final title = _pressRelease!['title'];
    final body = _pressRelease!['body'];
    final tags = (_pressRelease!['hashtags'] as List).join(' ');

    SharePlus.instance.share(
      ShareParams(
        text: '$title\n\n$body\n\n$tags\n#自分株式会社',
        subject: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('広報室 (CMO)'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.campaign, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'あなたの実績を世界へ発信しましょう。\nAIが魅力的なプレスリリースを自動生成します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_pressRelease == null)
              ElevatedButton.icon(
                onPressed: _generatePressRelease,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('プレスリリースを起案する'),
              ),
            if (_pressRelease != null) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRESS RELEASE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _pressRelease!['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 32),
                      Text(
                        _pressRelease!['body'] ?? '',
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        (_pressRelease!['hashtags'] as List).join(' '),
                        style: TextStyle(
                          color: _purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generatePressRelease, // Retry
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('再生成'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _sharePressRelease,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: const Icon(Icons.share),
                      label: const Text('全世界へ配信'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
