import 'package:flutter/material.dart';

import 'ai_summarizer_page.dart';
import 'ai_writing_assistant_page.dart';

enum WritingCenterSection { writing, summaries }

/// 文章生成・改善と、履歴付きAI要約を1つの機能にまとめる入口。
class WritingCenterPage extends StatefulWidget {
  const WritingCenterPage({
    super.key,
    this.initialSection = WritingCenterSection.writing,
  });

  final WritingCenterSection initialSection;

  @override
  State<WritingCenterPage> createState() => _WritingCenterPageState();
}

class _WritingCenterPageState extends State<WritingCenterPage> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection.index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const <Widget>[AiWritingAssistantPage(), AiSummarizerPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.auto_fix_high_outlined),
            label: '文章作成・改善',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            label: 'AI要約・履歴',
          ),
        ],
      ),
    );
  }
}
