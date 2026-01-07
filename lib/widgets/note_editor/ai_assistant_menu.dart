import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/theme_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiAssistantMenu extends StatefulWidget {
  final TextEditingController contentController;
  final Function(String) onApply;

  const AiAssistantMenu({
    super.key,
    required this.contentController,
    required this.onApply,
  });

  @override
  State<AiAssistantMenu> createState() => _AiAssistantMenuState();
}

class _AiAssistantMenuState extends State<AiAssistantMenu> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: themeService.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      offset: const Offset(0, -60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) => _handleAiAction(value),
      itemBuilder: (context) => [
        _buildMenuItem('improve', '文章を洗練させる', Icons.brush),
        _buildMenuItem('summarize', '要約する', Icons.short_text),
        _buildMenuItem('expand', '内容を膨らませる', Icons.aspect_ratio),
        _buildMenuItem('translate', '英語に翻訳', Icons.translate),
        _buildMenuItem('suggest_title', 'タイトル案を生成', Icons.title),
        const PopupMenuDivider(),
        _buildMenuItem('analyze_note_text', 'CSOによる分析', Icons.analytics, color: Colors.orange),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, String label, IconData icon, {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey[700], size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Future<void> _handleAiAction(String action) async {
    final text = widget.contentController.text;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('テキストを入力してください')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': action,
          'content': text,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        if (action == 'analyze_note_text') {
          _showAnalysisResult(data['result']);
        } else {
          // テキスト置換/追記系のアクション
          final resultText = data['result'] as String;
          // 結果をダイアログで確認してから適用
          if (mounted) _showResultDialog(resultText);
        }
      } else {
        throw Exception(data?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AIエラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResultDialog(String newText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI生成結果'),
        content: SingleChildScrollView(child: Text(newText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              widget.onApply(newText);
              Navigator.pop(context);
            },
            child: const Text('適用する'),
          ),
        ],
      ),
    );
  }

  void _showAnalysisResult(dynamic result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSO分析レポート'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('感情: ${result['sentiment']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('要約:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(result['summary'] ?? ''),
              const SizedBox(height: 8),
              const Text('タグ:', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: (result['tags'] as List? ?? []).map((t) => Chip(label: Text(t.toString()))).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる')),
        ],
      ),
    );
  }
}