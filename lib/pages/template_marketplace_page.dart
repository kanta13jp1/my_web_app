import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/gamification_service.dart';
import 'note_editor_page.dart';

class TemplateMarketplacePage extends StatelessWidget {
  const TemplateMarketplacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('テンプレート広場')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('日報テンプレート'),
            onTap: () => _useTemplate(context, '日報', '今日やったこと:\n\n明日やること:'),
          ),
        ],
      ),
    );
  }

  void _useTemplate(BuildContext context, String title, String content) {
    Provider.of<GamificationService>(context, listen: false)
        .awardPoints(10, reason: "Used Template: $title");

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorPage(
          initialTitle: title,
          initialContent: content,
        ),
      ),
    );
  }
}
