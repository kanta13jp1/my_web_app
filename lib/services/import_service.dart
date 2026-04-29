import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  factory ImportedNoteDraft.fromJson(Map<String, dynamic> json) {
    return ImportedNoteDraft(
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      source: json['source']?.toString() ?? 'import',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'source': source,
      'tags': tags,
    };
  }
}

class ImportPreviewResult {
  final String sourceType;
  final String sourceLabel;
  final String fileName;
  final List<ImportedNoteDraft> notes;
  final List<String> warnings;
  final String previewMode;

  const ImportPreviewResult({
    required this.sourceType,
    required this.sourceLabel,
    required this.fileName,
    required this.notes,
    this.warnings = const <String>[],
    this.previewMode = 'edge-function',
  });

  factory ImportPreviewResult.fromJson(Map<String, dynamic> json) {
    return ImportPreviewResult(
      sourceType: json['sourceType']?.toString() ?? 'import',
      sourceLabel: json['sourceLabel']?.toString() ?? 'Import',
      fileName: json['fileName']?.toString() ?? '',
      notes: (json['notes'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (note) => ImportedNoteDraft.fromJson(
              Map<String, dynamic>.from(note),
            ),
          )
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? const <dynamic>[])
          .map((warning) => warning.toString())
          .where((warning) => warning.trim().isNotEmpty)
          .toList(),
      previewMode: json['previewMode']?.toString() ?? 'edge-function',
    );
  }

  bool get usedEdgeFunction => previewMode == 'edge-function';

  String get previewModeLabel =>
      usedEdgeFunction ? 'Edge Function preview' : 'Local fallback preview';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceType': sourceType,
      'sourceLabel': sourceLabel,
      'fileName': fileName,
      'notes': notes.map((note) => note.toJson()).toList(),
      'warnings': warnings,
      'previewMode': previewMode,
    };
  }
}

class ImportExecutionResult {
  final int insertedCount;
  final String importMode;

  const ImportExecutionResult({
    required this.insertedCount,
    this.importMode = 'edge-function',
  });

  factory ImportExecutionResult.fromJson(Map<String, dynamic> json) {
    return ImportExecutionResult(
      insertedCount: ImportService._toIntValue(json['insertedCount']),
      importMode: json['importMode']?.toString() ?? 'edge-function',
    );
  }

  bool get usedEdgeFunction => importMode == 'edge-function';

  String get importModeLabel =>
      usedEdgeFunction ? 'Edge Function import' : 'Local fallback import';
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
    try {
      return await _buildPreviewViaEdgeFunction(
        sourceType: sourceType,
        fileName: fileName,
        bytes: bytes,
      );
    } catch (error, stackTrace) {
      debugPrint('Edge import preview failed. Falling back locally: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _buildPreviewLocally(
        sourceType: sourceType,
        fileName: fileName,
        bytes: bytes,
        fallbackWarning:
            'Edge Function preview is unavailable right now, so a local preview was used.',
      );
    }
  }

  /// Notion API トークンを使って直接ページ一覧をプレビュー取得する。
  Future<ImportPreviewResult> buildNotionApiPreview({
    required String notionToken,
    int pageLimit = 10,
  }) async {
    final response = await _client.functions.invoke(
      'growth-hub',
      body: <String, dynamic>{
        'action': 'import.preview',
        'sourceType': 'notion_api',
        'notionToken': notionToken,
        'pageLimit': pageLimit,
      },
    );
    final data = _asMap(response.data);
    if (data['success'] != true) {
      throw Exception(
        data['error']?.toString() ?? 'Notion API preview failed.',
      );
    }
    return ImportPreviewResult.fromJson(_asMap(data['preview']));
  }

  Future<ImportPreviewResult> _buildPreviewViaEdgeFunction({
    required String sourceType,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final response = await _client.functions.invoke(
      'growth-hub',
      body: <String, dynamic>{
        'action': 'import.preview',
        'sourceType': sourceType,
        'fileName': fileName,
        'contentBase64': base64Encode(bytes),
      },
    );

    final data = _asMap(response.data);
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Import preview failed.');
    }

    final previewJson = _asMap(data['preview']);
    return ImportPreviewResult.fromJson(previewJson);
  }

  ImportPreviewResult _buildPreviewLocally({
    required String sourceType,
    required String fileName,
    required Uint8List bytes,
    String? fallbackWarning,
  }) {
    switch (sourceType) {
      case 'notion':
        return ImportPreviewResult(
          sourceType: 'notion',
          sourceLabel: 'Notion',
          fileName: fileName,
          notes: parseNotionCsvBytes(bytes),
          warnings: <String>[
            'The preview checks Title / Name / Content / Text columns when available.',
            if (fallbackWarning != null) fallbackWarning,
          ],
          previewMode: 'local-fallback',
        );
      case 'evernote':
        return ImportPreviewResult(
          sourceType: 'evernote',
          sourceLabel: 'Evernote',
          fileName: fileName,
          notes: parseEvernoteEnexBytes(bytes),
          warnings: <String>[
            'The preview strips ENEX markup and imports the plain text body plus tags.',
            if (fallbackWarning != null) fallbackWarning,
          ],
          previewMode: 'local-fallback',
        );
      case 'markdown':
        return ImportPreviewResult(
          sourceType: 'markdown',
          sourceLabel: 'Markdown',
          fileName: fileName,
          notes: <ImportedNoteDraft>[
            parseMarkdownBytes(bytes, fileName: fileName),
          ],
          warnings: fallbackWarning == null
              ? const <String>[]
              : <String>[fallbackWarning],
          previewMode: 'local-fallback',
        );
      default:
        throw ArgumentError.value(
          sourceType,
          'sourceType',
          'Unsupported source',
        );
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
      const <String>['title', 'name', 'note', 'ページ', 'タイトル'],
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
              .replaceAll(
                RegExp(r'<!\[CDATA\[|\]\]>', caseSensitive: false),
                '',
              )
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

  Future<ImportExecutionResult> importNotes({
    required String userId,
    required List<ImportedNoteDraft> notes,
  }) async {
    if (notes.isEmpty) {
      return const ImportExecutionResult(
        insertedCount: 0,
        importMode: 'edge-function',
      );
    }

    try {
      return await _importNotesViaEdgeFunction(
        userId: userId,
        notes: notes,
      );
    } catch (error, stackTrace) {
      debugPrint('Edge import commit failed. Falling back locally: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _importNotesLocally(
        userId: userId,
        notes: notes,
      );
    }
  }

  Future<ImportExecutionResult> _importNotesViaEdgeFunction({
    required String userId,
    required List<ImportedNoteDraft> notes,
  }) async {
    final response = await _client.functions.invoke(
      'growth-hub',
      body: <String, dynamic>{
        'action': 'import.commit',
        'userId': userId,
        'notes': notes.map((note) => note.toJson()).toList(),
      },
    );

    final data = _asMap(response.data);
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Import commit failed.');
    }

    final result = ImportExecutionResult.fromJson(data);
    await _awardImportPoints(result.insertedCount);
    return result;
  }

  Future<ImportExecutionResult> _importNotesLocally({
    required String userId,
    required List<ImportedNoteDraft> notes,
  }) async {
    if (notes.isEmpty) {
      return const ImportExecutionResult(
        insertedCount: 0,
        importMode: 'local-fallback',
      );
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

    await _awardImportPoints(inserted);

    return ImportExecutionResult(
      insertedCount: inserted,
      importMode: 'local-fallback',
    );
  }

  Future<void> _awardImportPoints(int insertedCount) async {
    if (insertedCount <= 0) {
      return;
    }
    await _gamificationService.awardPoints(
      insertedCount * 10,
      reason: 'Imported $insertedCount notes',
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    throw Exception('Expected a JSON object response.');
  }

  static int _toIntValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : null;

      if (char == '"') {
        if (inQuotes && next == '"') {
          currentCell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') {
          i++;
        }
        currentRow.add(currentCell.toString());
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        currentCell.clear();
        continue;
      }

      currentCell.write(char);
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(List<String>.from(currentRow));
    }

    return rows;
  }

  int _findColumnIndex(List<String> header, List<String> candidates) {
    for (final candidate in candidates) {
      final index = header.indexOf(candidate);
      if (index != -1) {
        return index;
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

  String _extractTag(String source, String tagName) {
    final match = RegExp(
      '<$tagName[^>]*>([\\s\\S]*?)</$tagName>',
      caseSensitive: false,
    ).firstMatch(source);
    return match?.group(1) ?? '';
  }

  String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
  }

  String _normalizeWhitespace(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }

  String _deriveTitleFromMarkdown(String text, String fileName) {
    final lines = const LineSplitter().convert(text);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        return trimmed.substring(2).trim();
      }
      if (trimmed.isNotEmpty) {
        break;
      }
    }

    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex > 0) {
      return fileName.substring(0, dotIndex);
    }
    return fileName;
  }
}
