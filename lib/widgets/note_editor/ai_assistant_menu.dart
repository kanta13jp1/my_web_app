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
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      offset: const Offset(0, -60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) => _handleAiAction(value),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'improve', child: Text('文章を洗練')),
        const PopupMenuItem(value: 'summarize', child: Text('要約')),
        const PopupMenuItem(value: 'analyze_note_text', child: Text('CSO分析')),
      ],
    );
  }

  Future<void> _handleAiAction(String action) async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-assistant', // Assuming the Edge Function name is 'ai-assistant'
        body: {
          'action': action,
          'content': widget.contentController.text,
        },
      );

      if (response.status == 200) {
        final result = response.data['result'] as String;
        widget.onApply(result); // Apply the AI-generated content
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AIが$actionを実行しました。')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI機能の呼び出しに失敗しました: ${response.data}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI機能でエラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
