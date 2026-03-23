import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'gamification_service.dart';

class ImportedNoteDraft {
  final String title;
  final String content;
  final String source;
  final List<String> tags;

  const ImportedNoteDraft({
    required this.title,
    required this.content,
    required this.source,
    this.tags = const <String>[],
  });
}

class ImportPreviewResult {
  final String sourceLabel;
  final String fileName;
  final List<ImportedNoteDraft> notes;
  final List<String> warnings;

  const ImportPreviewResult({
    required this.sourceLabel,
    required this.fileName,
    required this.notes,
    this.warnings = const <String>[],
  });
}

class ImportService {
  final GamificationService _gamificationService;
  final SupabaseClient? _clientOverride;

  ImportService(
    this._gamificationService, {
    SupabaseClient? clientOverride,
  }) : _clientOverride = clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  Future<ImportPreviewResult> buildPreview({
    required String sourceType,
    required String fileName,
    required Uint8List bytes,
  }) async {
    switch (sourceType) {
      case 'notion':
        return ImportPreviewResult(
          sourceLabel: 'Notion',
          fileName: fileName,
          notes: parseNotionCsvBytes(bytes),
          warnings: const <String>[
            'Notion CSV は Title / Name / Content / Text 系の列を優先して解析します。',
          ],
        );
      case 'evernote':
        return ImportPreviewResult(
          sourceLabel: 'Evernote',
          fileName: fileName,
          notes: parseEvernoteEnexBytes(bytes),
          warnings: const <String>[
            'Evernote ENEX は本文の HTML を落としてプレーンテキストとして取り込みます。',
          ],
        );
      case 'markdown':
        return ImportPreviewResult(
          sourceLabel: 'Markdown',
          fileName: fileName,
          notes: <ImportedNoteDraft>[
            parseMarkdownBytes(bytes, fileName: fileName),
          ],
        );
      default:
        throw ArgumentError.value(sourceType, 'sourceType', 'Unsupported source');
    }
  }

  List<ImportedNoteDraft> parseNotionCsvBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return parseNotionCsvText(text);
  }

  List<ImportedNoteDraft> parseNotionCsvText(String csvText) {
    final rows = _parseCsv(csvText);
    if (rows.length <= 1) {
      return const <ImportedNoteDraft>[];
    }

    final header = rows.first.map((cell) => cell.trim().toLowerCase()).toList();
    final titleIndex = _findColumnIndex(
      header,
      const <String>['title', 'name', 'note', '繝壹・繧ｸ', '繧ｿ繧､繝医Ν'],
    );
    final contentIndex = _findColumnIndex(
      header,
      const <String>['content', 'text', 'body', 'plain text', '本文'],
    );
    final tagsIndex = _findColumnIndex(
      header,
      const <String>['tags', 'tag', 'labels'],
    );

    final drafts = <ImportedNoteDraft>[];
    for (final row in rows.skip(1)) {
      final title = _readCell(row, titleIndex).trim();
      final content = _readCell(row, contentIndex).trim();
      final tags = _readCell(row, tagsIndex)
          .split(RegExp(r'[,;]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (title.isEmpty && content.isEmpty) {
        continue;
      }

      drafts.add(
        ImportedNoteDraft(
          title: title.isEmpty ? 'Notion import' : title,
          content: content,
          source: 'notion',
          tags: tags,
        ),
      );
    }
    return drafts;
  }

  List<ImportedNoteDraft> parseEvernoteEnexBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return parseEvernoteEnexText(text);
  }

  List<ImportedNoteDraft> parseEvernoteEnexText(String enexText) {
    final noteMatches = RegExp(
      r'<note>([\s\S]*?)</note>',
      caseSensitive: false,
    ).allMatches(enexText);

    final drafts = <ImportedNoteDraft>[];
    for (final match in noteMatches) {
      final rawNote = match.group(1) ?? '';
      final title = _extractTag(rawNote, 'title').trim();
      final contentBlock = _extractTag(rawNote, 'content');
      final tagMatches = RegExp(
        r'<tag>([\s\S]*?)</tag>',
        caseSensitive: false,
      ).allMatches(rawNote);
      final tags = tagMatches
          .map((tagMatch) => (tagMatch.group(1) ?? '').trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final strippedContent = _normalizeWhitespace(
        _stripHtml(
          contentBlock
              .replaceAll(RegExp(r'<!\[CDATA\[|\]\]>', caseSensitive: false), '')
              .replaceAll('&nbsp;', ' ')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>'),
        ),
      );

      if (title.isEmpty && strippedContent.isEmpty) {
        continue;
      }

      drafts.add(
        ImportedNoteDraft(
          title: title.isEmpty ? 'Evernote import' : title,
          content: strippedContent,
          source: 'evernote',
          tags: tags,
        ),
      );
    }

    return drafts;
  }

  ImportedNoteDraft parseMarkdownBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final title = _deriveTitleFromMarkdown(text, fileName);
    return ImportedNoteDraft(
      title: title,
      content: text.trim(),
      source: 'markdown',
    );
  }

  Future<int> importNotes({
    required String userId,
    required List<ImportedNoteDraft> notes,
  }) async {
    if (notes.isEmpty) {
      return 0;
    }

    final rows = notes
        .map(
          (note) => <String, dynamic>{
            'user_id': userId,
            'title': note.title.trim(),
            'content': note.content.trim(),
            'is_archived': false,
            'is_pinned': false,
          },
        )
        .toList();

    const chunkSize = 50;
    var inserted = 0;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final chunk = rows.sublist(
        i,
        i + chunkSize > rows.length ? rows.length : i + chunkSize,
      );
      await _client.from('notes').insert(chunk);
      inserted += chunk.length;
    }

    await _gamificationService.awardPoints(
      inserted * 10,
      reason: 'Imported $inserted notes',
    );

    return inserted;
  }

  int _findColumnIndex(List<String> header, List<String> candidates) {
    for (var i = 0; i < header.length; i++) {
      final value = header[i];
      for (final candidate in candidates) {
        if (value == candidate || value.contains(candidate)) {
          return i;
        }
      }
    }
    return -1;
  }

  String _readCell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index];
  }

  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    final row = <String>[];
    var cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '"') {
        if (inQuotes && i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        row.add(cell.toString());
        cell = StringBuffer();
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) {
          rows.add(List<String>.from(row));
        }
        row.clear();
        continue;
      }

      cell.write(char);
    }

    row.add(cell.toString());
    if (row.any((value) => value.isNotEmpty)) {
      rows.add(List<String>.from(row));
    }

    return rows;
  }

  String _extractTag(String source, String tagName) {
    final match = RegExp(
      '<$tagName>([\\s\\S]*?)</$tagName>',
      caseSensitive: false,
    ).firstMatch(source);
    return match?.group(1) ?? '';
  }

  String _stripHtml(String source) {
    return source
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>|</p>|</li>|</h[1-6]>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _normalizeWhitespace(String source) {
    final lines = source
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return lines.join('\n');
  }

  String _deriveTitleFromMarkdown(String text, String fileName) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
    }

    final normalizedName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
    return normalizedName.isEmpty ? 'Markdown import' : normalizedName;
  }
}
