import 'package:flutter/material.dart';

/// Fixed educational examples, not a repository scanner.
class GitIgnoreExamplesCard extends StatefulWidget {
  const GitIgnoreExamplesCard({super.key});

  @override
  State<GitIgnoreExamplesCard> createState() => _GitIgnoreExamplesCardState();
}

class _GitIgnoreExamplesCardState extends State<GitIgnoreExamplesCard> {
  int selected = 0;

  static const labels = <String>[
    '未登録 .env',
    '未登録 .env.example',
    '登録後に変更',
    '一致の調べ方',
  ];
  static const results = <String>[
    '無視規則に一致する未登録の .env は通常の変更一覧に表示されません。',
    '.env.example はこの規則に一致せず、未登録ファイルとして表示されます。',
    'いったん登録した .env を変更すると、無視規則があっても変更一覧に表示されます。',
    '登録済みの .env は通常の check-ignore に表示されず、--no-index ではパターンの一致を確認できます。',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('git_ignore_examples'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gitの無視設定：登録前と登録後',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFFFAFAFA),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '無視するファイル名を指定しても、すでにGitの管理対象に入ったファイルは自動では外れません。架空の4例を切り替えて確認できます。',
            style: TextStyle(color: Color(0xFFCBD5E1), height: 1.6),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(labels.length, (index) {
              return ChoiceChip(
                label: Text(labels[index]),
                selected: selected == index,
                onSelected: (_) => setState(() => selected = index),
              );
            }),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              results[selected],
              key: const Key('git_ignore_example_result'),
              style: const TextStyle(color: Color(0xFFFAFAFA), height: 1.6),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'これは保存済みの合成例で、手元のファイルを調べたり秘密情報を検出したりしません。公開前に登録内容を自分で確認してください。',
            style: TextStyle(color: Color(0xFFCBD5E1), height: 1.6),
          ),
        ],
      ),
    );
  }
}
