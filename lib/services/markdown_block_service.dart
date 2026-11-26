import 'package:flutter/services.dart';

enum MarkdownBlockType {
  heading1,
  heading2,
  heading3,
  paragraph,
  checklist,
  bulletList,
  numberedList,
  callout,
  toggle,
  codeBlock,
  table,
  divider,
}

class MarkdownBlock {
  final MarkdownBlockType type;
  final String rawMarkdown;
  final String previewLabel;
  final String previewSnippet;

  const MarkdownBlock({
    required this.type,
    required this.rawMarkdown,
    required this.previewLabel,
    required this.previewSnippet,
  });
}

class InlineSlashMatch {
  final int startOffset;
  final int endOffset;
  final String query;

  const InlineSlashMatch({
    required this.startOffset,
    required this.endOffset,
    required this.query,
  });
}

class SlashBlockTemplate {
  final String id;
  final String command;
  final String label;
  final String description;
  final List<String> keywords;
  final String snippet;
  final int cursorOffset;

  const SlashBlockTemplate({
    required this.id,
    required this.command,
    required this.label,
    required this.description,
    required this.keywords,
    required this.snippet,
    required this.cursorOffset,
  });
}

enum PreviewSegmentKind {
  markdown,
  callout,
  toggle,
}

class PreviewSegment {
  final PreviewSegmentKind kind;
  final String title;
  final String body;

  const PreviewSegment({
    required this.kind,
    required this.title,
    required this.body,
  });
}

/// Pure Markdown-SSOT helpers for inline `/` block insertion, lossless block
/// splitting/reordering, and callout/toggle segment extraction.
class MarkdownBlockService {
  MarkdownBlockService._();

  static const List<SlashBlockTemplate> blockTemplates = <SlashBlockTemplate>[
    SlashBlockTemplate(
      id: 'h1',
      command: '/h1',
      label: '見出し 1',
      description: '大見出し (# )',
      keywords: <String>['h1', 'heading', '見出し', 'title'],
      snippet: '# ',
      cursorOffset: 2,
    ),
    SlashBlockTemplate(
      id: 'h2',
      command: '/h2',
      label: '見出し 2',
      description: '中見出し (## )',
      keywords: <String>['h2', 'heading', '見出し', 'section'],
      snippet: '## ',
      cursorOffset: 3,
    ),
    SlashBlockTemplate(
      id: 'h3',
      command: '/h3',
      label: '見出し 3',
      description: '小見出し (### )',
      keywords: <String>['h3', 'heading', '見出し', 'subsection'],
      snippet: '### ',
      cursorOffset: 4,
    ),
    SlashBlockTemplate(
      id: 'todo',
      command: '/todo',
      label: 'チェックリスト',
      description: '完了チェック付きタスク (- [ ] )',
      keywords: <String>['todo', 'checkbox', 'task', 'チェック', 'タスク'],
      snippet: '- [ ] ',
      cursorOffset: 6,
    ),
    SlashBlockTemplate(
      id: 'bullet',
      command: '/bullet',
      label: '箇条書きリスト',
      description: 'シンプルな箇条書き (- )',
      keywords: <String>['bullet', 'list', '箇条書き', 'リスト'],
      snippet: '- ',
      cursorOffset: 2,
    ),
    SlashBlockTemplate(
      id: 'callout',
      command: '/callout',
      label: 'コールアウト',
      description: '強調ボックス (> [!NOTE])',
      keywords: <String>['callout', 'note', 'alert', 'コールアウト', '注記'],
      snippet: '> [!NOTE]\n> ',
      cursorOffset: 12,
    ),
    SlashBlockTemplate(
      id: 'toggle',
      command: '/toggle',
      label: 'トグル（折りたたみ）',
      description: '開閉できる詳細ブロック (<details>)',
      keywords: <String>['toggle', 'details', 'collapse', 'トグル', '折りたたみ'],
      snippet: '<details>\n<summary>タイトル</summary>\n\n内容\n</details>',
      cursorOffset: 19,
    ),
    SlashBlockTemplate(
      id: 'code',
      command: '/code',
      label: 'コードブロック',
      description: 'シンタックス付きコード枠 (```)',
      keywords: <String>['code', 'snippet', 'コード'],
      snippet: '```\n\n```',
      cursorOffset: 4,
    ),
    SlashBlockTemplate(
      id: 'table',
      command: '/table',
      label: 'テーブル',
      description: 'Markdown 表テンプレート',
      keywords: <String>['table', 'grid', '表', 'テーブル'],
      snippet: '| 項目 | 内容 |\n| --- | --- |\n|  |  |',
      cursorOffset: 2,
    ),
    SlashBlockTemplate(
      id: 'divider',
      command: '/divider',
      label: '区切り線',
      description: 'セクション区切り (---)',
      keywords: <String>['divider', 'hr', 'line', '区切り線'],
      snippet: '---',
      cursorOffset: 3,
    ),
    SlashBlockTemplate(
      id: 'link',
      command: '/link',
      label: 'ページリンク',
      description: '[[ページ名]] で別ノートへ接続',
      keywords: <String>['link', 'wiki', 'page', 'リンク', '内部リンク'],
      snippet: '[[]]',
      cursorOffset: 2,
    ),
  ];

  static InlineSlashMatch? detectInlineSlashTrigger(
    String text,
    int cursorOffset,
  ) {
    if (cursorOffset <= 0 || cursorOffset > text.length) {
      return null;
    }

    int scan = cursorOffset - 1;
    int queryLength = 0;
    while (scan >= 0) {
      final int codeUnit = text.codeUnitAt(scan);
      final String ch = String.fromCharCode(codeUnit);
      if (ch == '/') {
        final bool validBoundary = scan == 0 ||
            text.codeUnitAt(scan - 1) == 0x0A ||
            text.codeUnitAt(scan - 1) == 0x0D ||
            text.codeUnitAt(scan - 1) == 0x20 ||
            text.codeUnitAt(scan - 1) == 0x09;
        if (!validBoundary) {
          return null;
        }
        final String query = text.substring(scan + 1, cursorOffset);
        return InlineSlashMatch(
          startOffset: scan,
          endOffset: cursorOffset,
          query: query,
        );
      }
      if (ch == '\n' || ch == '\r' || ch == ' ' || ch == '\t') {
        return null;
      }
      queryLength += 1;
      if (queryLength > 24) {
        return null;
      }
      scan -= 1;
    }
    return null;
  }

  static List<SlashBlockTemplate> filterTemplates(String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return blockTemplates;
    }
    return blockTemplates.where((SlashBlockTemplate template) {
      if (template.command.toLowerCase().contains(normalized)) return true;
      if (template.label.toLowerCase().contains(normalized)) return true;
      return template.keywords.any(
        (String kw) => kw.toLowerCase().contains(normalized),
      );
    }).toList(growable: false);
  }

  static TextEditingValue applySlashTemplate(
    TextEditingValue current,
    InlineSlashMatch match,
    SlashBlockTemplate template,
  ) {
    final int start = match.startOffset.clamp(0, current.text.length);
    final int end = match.endOffset.clamp(start, current.text.length);
    final String updated =
        current.text.replaceRange(start, end, template.snippet);
    final int nextCursor =
        (start + template.cursorOffset).clamp(0, updated.length);
    return TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }

  static TextEditingValue insertTemplateAtSelection(
    TextEditingValue current,
    SlashBlockTemplate template,
  ) {
    final String text = current.text;
    final int rawStart = current.selection.isValid
        ? current.selection.start.clamp(0, text.length)
        : text.length;
    final int rawEnd = current.selection.isValid
        ? current.selection.end.clamp(rawStart, text.length)
        : text.length;

    final String prefix =
        rawStart > 0 && !text.substring(0, rawStart).endsWith('\n') ? '\n' : '';
    final String replacement = '$prefix${template.snippet}';
    final String updated = text.replaceRange(rawStart, rawEnd, replacement);
    final int nextCursor =
        (rawStart + prefix.length + template.cursorOffset).clamp(
      0,
      updated.length,
    );
    return TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }

  static List<MarkdownBlock> parseBlocks(String markdown) {
    final String normalized = markdown.replaceAll('\r\n', '\n');
    if (normalized.trim().isEmpty) {
      return const <MarkdownBlock>[];
    }

    final List<String> lines = normalized.split('\n');
    final List<MarkdownBlock> blocks = <MarkdownBlock>[];
    int i = 0;

    while (i < lines.length) {
      final String line = lines[i];
      if (line.trim().isEmpty) {
        i += 1;
        continue;
      }

      final String trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length) {
          buf.add(lines[i]);
          if (lines[i].trim().startsWith('```')) {
            i += 1;
            break;
          }
          i += 1;
        }
        blocks.add(
          _buildBlock(
            MarkdownBlockType.codeBlock,
            buf.join('\n'),
          ),
        );
        continue;
      }

      if (trimmed.toLowerCase().startsWith('<details')) {
        final List<String> buf = <String>[line];
        if (!trimmed.toLowerCase().contains('</details>')) {
          i += 1;
          while (i < lines.length) {
            buf.add(lines[i]);
            if (lines[i].toLowerCase().contains('</details>')) {
              i += 1;
              break;
            }
            i += 1;
          }
        } else {
          i += 1;
        }
        blocks.add(
          _buildBlock(
            MarkdownBlockType.toggle,
            buf.join('\n'),
          ),
        );
        continue;
      }

      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        blocks.add(_buildBlock(MarkdownBlockType.divider, line));
        i += 1;
        continue;
      }

      if (trimmed.startsWith('# ')) {
        blocks.add(_buildBlock(MarkdownBlockType.heading1, line));
        i += 1;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        blocks.add(_buildBlock(MarkdownBlockType.heading2, line));
        i += 1;
        continue;
      }
      if (trimmed.startsWith('### ')) {
        blocks.add(_buildBlock(MarkdownBlockType.heading3, line));
        i += 1;
        continue;
      }

      if (trimmed.startsWith('>')) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          buf.add(lines[i]);
          i += 1;
        }
        blocks.add(_buildBlock(MarkdownBlockType.callout, buf.join('\n')));
        continue;
      }

      if (_isChecklistLine(trimmed)) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length && _isChecklistLine(lines[i].trim())) {
          buf.add(lines[i]);
          i += 1;
        }
        blocks.add(_buildBlock(MarkdownBlockType.checklist, buf.join('\n')));
        continue;
      }

      if (_isBulletLine(trimmed)) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length &&
            _isBulletLine(lines[i].trim()) &&
            !_isChecklistLine(lines[i].trim())) {
          buf.add(lines[i]);
          i += 1;
        }
        blocks.add(_buildBlock(MarkdownBlockType.bulletList, buf.join('\n')));
        continue;
      }

      if (_isNumberedLine(trimmed)) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length && _isNumberedLine(lines[i].trim())) {
          buf.add(lines[i]);
          i += 1;
        }
        blocks.add(_buildBlock(MarkdownBlockType.numberedList, buf.join('\n')));
        continue;
      }

      if (trimmed.startsWith('|')) {
        final List<String> buf = <String>[line];
        i += 1;
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          buf.add(lines[i]);
          i += 1;
        }
        blocks.add(_buildBlock(MarkdownBlockType.table, buf.join('\n')));
        continue;
      }

      final List<String> buf = <String>[line];
      i += 1;
      while (i < lines.length && !_startsSpecialBlock(lines[i].trim())) {
        buf.add(lines[i]);
        i += 1;
      }
      blocks.add(_buildBlock(MarkdownBlockType.paragraph, buf.join('\n')));
    }

    return blocks;
  }

  static String serializeBlocks(List<MarkdownBlock> blocks) {
    return blocks
        .map((MarkdownBlock b) => b.rawMarkdown.trimRight())
        .where((String raw) => raw.isNotEmpty)
        .join('\n\n');
  }

  static String reorderBlock(String markdown, int oldIndex, int newIndex) {
    final List<MarkdownBlock> blocks = List<MarkdownBlock>.from(
      parseBlocks(markdown),
    );
    if (oldIndex < 0 || oldIndex >= blocks.length) {
      return markdown;
    }
    int targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    targetIndex = targetIndex.clamp(0, blocks.length - 1);
    if (oldIndex == targetIndex) {
      return serializeBlocks(blocks);
    }
    final MarkdownBlock moved = blocks.removeAt(oldIndex);
    blocks.insert(targetIndex, moved);
    return serializeBlocks(blocks);
  }

  static List<PreviewSegment> splitPreviewSegments(String markdown) {
    final String normalized = markdown.replaceAll('\r\n', '\n');
    if (normalized.trim().isEmpty) {
      return const <PreviewSegment>[];
    }

    final List<String> lines = normalized.split('\n');
    final List<PreviewSegment> segments = <PreviewSegment>[];
    final List<String> mdBuffer = <String>[];

    void flushMarkdown() {
      final String joined = mdBuffer.join('\n').trim();
      mdBuffer.clear();
      if (joined.isNotEmpty) {
        segments.add(
          PreviewSegment(
            kind: PreviewSegmentKind.markdown,
            title: '',
            body: joined,
          ),
        );
      }
    }

    int i = 0;
    while (i < lines.length) {
      final String line = lines[i];
      final String trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        mdBuffer.add(line);
        i += 1;
        while (i < lines.length) {
          mdBuffer.add(lines[i]);
          if (lines[i].trim().startsWith('```')) {
            i += 1;
            break;
          }
          i += 1;
        }
        continue;
      }

      if (trimmed.toLowerCase().startsWith('<details')) {
        final int startIndex = i;
        final List<String> rawLines = <String>[line];
        bool closed = trimmed.toLowerCase().contains('</details>');
        i += 1;
        while (!closed && i < lines.length) {
          rawLines.add(lines[i]);
          if (lines[i].toLowerCase().contains('</details>')) {
            closed = true;
            i += 1;
            break;
          }
          i += 1;
        }
        final PreviewSegment? toggleSegment = _tryParseToggle(
          rawLines.join('\n'),
        );
        if (toggleSegment != null) {
          flushMarkdown();
          segments.add(toggleSegment);
        } else {
          mdBuffer.addAll(lines.sublist(startIndex, i));
        }
        continue;
      }

      final RegExpMatch? calloutMatch = RegExp(
        r'^>\s*\[!(NOTE|TIP|WARNING|IMPORTANT|CAUTION)\]\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (calloutMatch != null) {
        flushMarkdown();
        final String kindLabel = calloutMatch.group(1)!.toUpperCase();
        final String firstLineExtra = (calloutMatch.group(2) ?? '').trim();
        final List<String> bodyLines = <String>[
          if (firstLineExtra.isNotEmpty) firstLineExtra,
        ];
        i += 1;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          final String contentLine =
              lines[i].trimLeft().replaceFirst(RegExp(r'^>\s?'), '');
          bodyLines.add(contentLine);
          i += 1;
        }
        segments.add(
          PreviewSegment(
            kind: PreviewSegmentKind.callout,
            title: kindLabel,
            body: bodyLines.join('\n').trim(),
          ),
        );
        continue;
      }

      mdBuffer.add(line);
      i += 1;
    }

    flushMarkdown();
    return segments;
  }

  static PreviewSegment? _tryParseToggle(String raw) {
    final RegExp pattern = RegExp(
      r'<details[^>]*>\s*<summary>(.*?)</summary>([\s\S]*?)</details>',
      caseSensitive: false,
    );
    final RegExpMatch? match = pattern.firstMatch(raw);
    if (match == null) {
      return null;
    }
    final String title = (match.group(1) ?? '').trim();
    final String body = (match.group(2) ?? '').trim();
    return PreviewSegment(
      kind: PreviewSegmentKind.toggle,
      title: title.isEmpty ? '詳細' : title,
      body: body,
    );
  }

  static bool _isChecklistLine(String trimmed) =>
      RegExp(r'^[-*+]\s+\[[ xX]\](\s|$)').hasMatch(trimmed);

  static bool _isBulletLine(String trimmed) =>
      RegExp(r'^[-*+]\s+').hasMatch(trimmed);

  static bool _isNumberedLine(String trimmed) =>
      RegExp(r'^\d+\.\s+').hasMatch(trimmed);

  static bool _startsSpecialBlock(String trimmed) {
    if (trimmed.isEmpty) return true;
    return trimmed.startsWith('```') ||
        trimmed.toLowerCase().startsWith('<details') ||
        trimmed == '---' ||
        trimmed == '***' ||
        trimmed == '___' ||
        trimmed.startsWith('# ') ||
        trimmed.startsWith('## ') ||
        trimmed.startsWith('### ') ||
        trimmed.startsWith('>') ||
        _isChecklistLine(trimmed) ||
        _isBulletLine(trimmed) ||
        _isNumberedLine(trimmed) ||
        trimmed.startsWith('|');
  }

  static MarkdownBlock _buildBlock(MarkdownBlockType type, String raw) {
    final String label;
    switch (type) {
      case MarkdownBlockType.heading1:
        label = '見出し 1';
        break;
      case MarkdownBlockType.heading2:
        label = '見出し 2';
        break;
      case MarkdownBlockType.heading3:
        label = '見出し 3';
        break;
      case MarkdownBlockType.paragraph:
        label = '段落';
        break;
      case MarkdownBlockType.checklist:
        label = 'チェックリスト';
        break;
      case MarkdownBlockType.bulletList:
        label = '箇条書き';
        break;
      case MarkdownBlockType.numberedList:
        label = '番号付きリスト';
        break;
      case MarkdownBlockType.callout:
        label = 'コールアウト / 引用';
        break;
      case MarkdownBlockType.toggle:
        label = 'トグル';
        break;
      case MarkdownBlockType.codeBlock:
        label = 'コードブロック';
        break;
      case MarkdownBlockType.table:
        label = 'テーブル';
        break;
      case MarkdownBlockType.divider:
        label = '区切り線';
        break;
    }

    final String singleLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    final String snippet =
        singleLine.length > 72 ? '${singleLine.substring(0, 71)}…' : singleLine;
    return MarkdownBlock(
      type: type,
      rawMarkdown: raw,
      previewLabel: label,
      previewSnippet: snippet,
    );
  }
}
