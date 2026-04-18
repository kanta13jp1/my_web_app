import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI タグ提案ページ
/// テキストを入力すると AI が関連タグを提案する
class AiSuggestTagsPage extends StatefulWidget {
  const AiSuggestTagsPage({super.key});

  @override
  State<AiSuggestTagsPage> createState() => _AiSuggestTagsPageState();
}

class _AiSuggestTagsPageState extends State<AiSuggestTagsPage> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<String> _suggestedTags = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _suggestTags() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedTags = [];
    });

    try {
      final response = await _supabase.functions.invoke(
        'ai-suggest-tags',
        body: {'text': text},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final tags = data['tags'];
        setState(() {
          _suggestedTags = tags is List
              ? List<String>.from(tags.map((e) => e.toString()))
              : [];
        });
      } else {
        setState(() => _suggestedTags = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'タグ提案に失敗しました: $e';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI タグ提案'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'テキストを入力してタグを自動提案',
              style: TextStyle(fontSize: 14, color: Color(0xFFB0B0B0)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'ノートの内容やメモを貼り付けてください...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _suggestTags,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('タグを提案する'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_suggestedTags.isNotEmpty) ...[
              const Text(
                '提案されたタグ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestedTags
                    .map(
                      (tag) => Chip(
                        label: Text(tag),
                        backgroundColor: Colors.deepPurple.shade50,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
