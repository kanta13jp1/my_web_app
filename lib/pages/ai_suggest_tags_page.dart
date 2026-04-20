import 'package:flutter/material.dart';

import '../services/ai_service.dart';

/// AI タグ提案ページ
/// テキストを入力すると AI が関連タグ・カテゴリ・理由を提案する
///
/// Win版#117: 旧 ai-suggest-tags EF (実体は SVG quote generator) は本番から削除済み。
/// 代わりに AIService.suggestTags() = ai-hub:provider.chat (Groq llama-3.3-70b 無料枠) を呼ぶ。
class AiSuggestTagsPage extends StatefulWidget {
  const AiSuggestTagsPage({super.key});

  @override
  State<AiSuggestTagsPage> createState() => _AiSuggestTagsPageState();
}

class _AiSuggestTagsPageState extends State<AiSuggestTagsPage> {
  final _aiService = AIService();
  final _controller = TextEditingController();
  final _titleController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  TagSuggestion? _suggestion;

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _suggestTags() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestion = null;
    });

    try {
      final result = await _aiService.suggestTags(
        content: text,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
      );
      if (mounted) {
        setState(() => _suggestion = result);
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
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'テキストを入力してタグ・カテゴリを自動提案 (Groq llama-3.3-70b・無料・超高速)',
              style: TextStyle(
                fontSize: 12,
                color: const Color(0xFFB0B0B0),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'タイトル (任意)',
                hintText: '例: 競馬AI予想の振り返り',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: '本文',
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
                  backgroundColor: const Color(0xFF3D5AFE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: const Color(0xFFE53935),
                    height: 1.5,
                  ),
                ),
              ),
            if (_suggestion != null) ...[
              if (_suggestion!.tags.isNotEmpty) ...[
                const Text(
                  '提案されたタグ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestion!.tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          backgroundColor: const Color(0xFFEDE7F6),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (_suggestion!.category.isNotEmpty) ...[
                const Text(
                  'メインカテゴリ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3D5AFE).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _suggestion!.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3D5AFE),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_suggestion!.reason.isNotEmpty) ...[
                const Text(
                  'なぜこのタグ?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _suggestion!.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: const Color(0xFFB0B0B0),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
