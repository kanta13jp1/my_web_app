import 'package:flutter/material.dart';

import '../data/diet_debate_notes.dart';

class DietDebateArticle extends StatefulWidget {
  const DietDebateArticle({
    super.key,
    required this.note,
    required this.fontSize,
    required this.source,
    required this.readButton,
  });

  final DietDebateNote note;
  final double fontSize;
  final Widget Function(String label, Uri uri) source;
  final Widget readButton;

  @override
  State<DietDebateArticle> createState() => _DietDebateArticleState();
}

class _DietDebateArticleState extends State<DietDebateArticle> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final needle = _query.trim();
    final pattern = needle.isEmpty
        ? null
        : RegExp(RegExp.escape(needle), caseSensitive: false);
    final fields = [
      note.topic,
      '質問　${note.questioner}',
      note.question,
      '答弁　${note.answerer}',
      note.answer,
    ];
    final count = pattern == null
        ? 0
        : fields.fold<int>(
            0, (total, field) => total + pattern.allMatches(field).length);
    final theme = Theme.of(context);
    final mark = TextStyle(
        backgroundColor: theme.colorScheme.tertiaryContainer,
        color: theme.colorScheme.onTertiaryContainer,
        fontWeight: FontWeight.bold);

    Widget highlighted(String value, {bool title = false}) {
      final spans = <TextSpan>[];
      var offset = 0;
      if (pattern != null) {
        for (final match in pattern.allMatches(value)) {
          spans.add(TextSpan(text: value.substring(offset, match.start)));
          spans.add(TextSpan(
              text: value.substring(match.start, match.end), style: mark));
          offset = match.end;
        }
      }
      spans.add(TextSpan(text: value.substring(offset)));
      final style = (title
              ? theme.textTheme.titleMedium
              : theme.textTheme.bodyMedium)
          ?.copyWith(fontSize: widget.fontSize + (title ? 2 : 0), height: 1.6);
      return Text.rich(TextSpan(children: spans), style: style);
    }

    return Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        highlighted(fields[0], title: true),
        const Text('${DietDebateNote.date}　${DietDebateNote.meeting}'),
        const Text('AIによる要約・発言当時'),
        widget.readButton,
        TextField(
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'この記事内を検索',
            hintText: '見出し・発言者・質問と答弁の要約',
            counterText: '',
            prefixIcon: Icon(Icons.find_in_page_outlined),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        if (pattern != null)
          Semantics(liveRegion: true, child: Text('この記事内の一致　${count}件')),
        const Divider(),
        highlighted(fields[1]),
        highlighted(fields[2]),
        widget.source('質問の原文', note.source(note.questionOrder)),
        highlighted(fields[3]),
        highlighted(fields[4]),
        widget.source('答弁の原文', note.source(note.answerOrder)),
      ]),
    ));
  }
}
