import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/theme_service.dart';

class AiAssistantMenu extends StatefulWidget {
  final TextEditingController contentController;
  final Function(String) onApply;
  final SupabaseClient? supabaseClient;
  final String? model;
  final String? styleName;
  final String? styleInstruction;

  const AiAssistantMenu({
    super.key,
    required this.contentController,
    required this.onApply,
    this.supabaseClient,
    this.model,
    this.styleName,
    this.styleInstruction,
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
      onSelected: _handleAiAction,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'improve', child: Text('Improve Writing')),
        PopupMenuItem(value: 'summarize', child: Text('Summarize')),
        PopupMenuItem(value: 'expand', child: Text('Expand Ideas')),
      ],
    );
  }

  Future<void> _handleAiAction(String action) async {
    setState(() => _isLoading = true);
    try {
      final supabase = widget.supabaseClient ?? Supabase.instance.client;
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': action,
          'content': widget.contentController.text,
          if (widget.model != null && widget.model!.trim().isNotEmpty)
            'model': widget.model!.trim(),
          if (widget.styleInstruction != null &&
              widget.styleInstruction!.trim().isNotEmpty)
            'styleName': widget.styleName ?? 'custom',
          if (widget.styleInstruction != null &&
              widget.styleInstruction!.trim().isNotEmpty)
            'styleInstruction': widget.styleInstruction,
        },
      );

      if (!mounted) {
        return;
      }

      if (response.status == 200) {
        final result =
            (response.data as Map<String, dynamic>)['result'] as String;
        widget.onApply(result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI action completed.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI action failed: ${response.data}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI action errored: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
