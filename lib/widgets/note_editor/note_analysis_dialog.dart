import 'package:flutter/material.dart';

class NoteAnalysisDialog extends StatelessWidget {
  final Map<String, dynamic> data;

  const NoteAnalysisDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final sentiment = data['sentiment'] as String? ?? 'neutral';
    final tags = List<String>.from(data['tags'] ?? []);
    final summary = data['summary'] as String? ?? '';
    final actionItems = List<String>.from(data['action_items'] ?? []);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.analytics, color: Colors.purple),
          SizedBox(width: 8),
          Text('AI分析レポート'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSectionHeader('感情分析'),
            Row(
              children: [
                Icon(_getSentimentIcon(sentiment),
                    color: _getSentimentColor(sentiment)),
                const SizedBox(width: 8),
                Text(sentiment.toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSentimentColor(sentiment))),
              ],
            ),
            const Divider(height: 24),
            _buildSectionHeader('タグ提案'),
            Wrap(
              spacing: 8,
              children: tags
                  .map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: const TextStyle(color: Colors.purple),
                      ))
                  .toList(),
            ),
            const Divider(height: 24),
            _buildSectionHeader('要約'),
            Text(summary, style: const TextStyle(height: 1.4)),
            const Divider(height: 24),
            _buildSectionHeader('アクションアイテム'),
            if (actionItems.isEmpty)
              const Text('検出されたアクションはありません',
                  style: TextStyle(color: Colors.grey))
            else
              ...actionItems.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_box_outline_blank,
                            size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  IconData _getSentimentIcon(String sentiment) {
    if (sentiment.contains('positive')) return Icons.sentiment_very_satisfied;
    if (sentiment.contains('negative'))
      return Icons.sentiment_very_dissatisfied;
    return Icons.sentiment_neutral;
  }

  Color _getSentimentColor(String sentiment) {
    if (sentiment.contains('positive')) return Colors.green;
    if (sentiment.contains('negative')) return Colors.red;
    return Colors.grey;
  }
}
