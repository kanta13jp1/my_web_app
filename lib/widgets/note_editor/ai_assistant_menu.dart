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
                    color: Colors.white, strokeWidth: 2),
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
    // 簡易実装: 実際のAI呼び出しは省略し、UIの動作確認を優先
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('AI機能は現在準備中です')));
      setState(() => _isLoading = false);
    }
  }
}
