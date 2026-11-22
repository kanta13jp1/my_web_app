import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'attachment_service.dart';
import 'direct_storage_upload_service.dart';
import 'evernote_enex_parser.dart';
import 'gamification_service.dart';
import 'notion_export_zip_service.dart';
import 'office_document_parser.dart';
import 'storage_quota_service.dart';

class ImportedNoteDraft {
  final String title;
  final String content;
  final String source;
  final List<String> tags;
  final String? sourceId;
  final DateTime? sourceCreatedAt;
  final DateTime? sourceUpdatedAt;
  final String? sourceContentSha256;
  final int sourceResourceCount;
  final Map<String, dynamic> sourceMetadata;

  const ImportedNoteDraft({
    required this.title,
    required this.content,
    required this.source,
    this.tags = const <String>[],
    this.sourceId,
    this.sourceCreatedAt,
    this.sourceUpdatedAt,
    this.sourceContentSha256,
    this.sourceResourceCount = 0,
    this.sourceMetadata = const <String, dynamic>{},
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
      sourceId: json['sourceId']?.toString(),
      sourceCreatedAt: DateTime.tryParse(
        json['sourceCreatedAt']?.toString() ?? '',
      ),
      sourceUpdatedAt: DateTime.tryParse(
        json['sourceUpdatedAt']?.toString() ?? '',
      ),
      sourceContentSha256: json['sourceContentSha256']?.toString(),
      sourceResourceCount: ImportService._toIntValue(
        json['sourceResourceCount'],
      ),
      sourceMetadata: json['sourceMetadata'] is Map
          ? Map<String, dynamic>.from(json['sourceMetadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'source': source,
      'tags': tags,
      'sourceId': sourceId,
      'sourceCreatedAt': sourceCreatedAt?.toUtc().toIso8601String(),
      'sourceUpdatedAt': sourceUpdatedAt?.toUtc().toIso8601String(),
      'sourceContentSha256': sourceContentSha256,
      'sourceResourceCount': sourceResourceCount,
      'sourceMetadata': sourceMetadata,
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
  final String? sourceExportSha256;
  final int resourceCount;
  final String? commitBlockedReason;

  const ImportPreviewResult({
    required this.sourceType,
    required this.sourceLabel,
    required this.fileName,
    required this.notes,
    this.warnings = const <String>[],
    this.previewMode = 'edge-function',
    this.sourceExportSha256,
    this.resourceCount = 0,
    this.commitBlockedReason,
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
      sourceExportSha256: json['sourceExportSha256']?.toString(),
      resourceCount: ImportService._toIntValue(json['resourceCount']),
      commitBlockedReason: json['commitBlockedReason']?.toString(),
    );
  }

  bool get usedEdgeFunction => previewMode == 'edge-function';

  String get previewModeLabel => switch (previewMode) {
        'edge-function' => 'Edge Function preview',
        'local-streaming' => 'Memory-bounded streaming preview',
        'local-notion-zip' => 'Notion ZIP archive preview',
        _ => 'Local fallback preview',
      };

  bool get canCommit => commitBlockedReason == null;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceType': sourceType,
      'sourceLabel': sourceLabel,
      'fileName': fileName,
      'notes': notes.map((note) => note.toJson()).toList(),
      'warnings': warnings,
      'previewMode': previewMode,
      'sourceExportSha256': sourceExportSha256,
      'resourceCount': resourceCount,
      'commitBlockedReason': commitBlockedReason,
    };
  }
}

class ImportExecutionResult {
  final int insertedCount;
  final int skippedDuplicateCount;
  final int uploadedAttachmentCount;
  final int skippedAttachmentCount;
  final String importMode;

  const ImportExecutionResult({
    required this.insertedCount,
    this.skippedDuplicateCount = 0,
    this.uploadedAttachmentCount = 0,
    this.skippedAttachmentCount = 0,
    this.importMode = 'edge-function',
  });

  factory ImportExecutionResult.fromJson(Map<String, dynamic> json) {
    return ImportExecutionResult(
      insertedCount: ImportService._toIntValue(json['insertedCount']),
      skippedDuplicateCount:
          ImportService._toIntValue(json['skippedDuplicateCount']),
      uploadedAttachmentCount:
          ImportService._toIntValue(json['uploadedAttachmentCount']),
      skippedAttachmentCount:
          ImportService._toIntValue(json['skippedAttachmentCount']),
      importMode: json['importMode']?.toString() ?? 'edge-function',
    );
  }

  bool get usedEdgeFunction => importMode == 'edge-function';

  String get importModeLabel => switch (importMode) {
        'edge-function' => 'Edge Function import',
        'evernote-lossless' => 'Lossless Evernote import + verification',
        'notion-zip-lossless' => 'Notion ZIP archive import + attachments',
        _ => 'Local fallback import',
      };
}

class ImportService {
  final GamificationService _gamificationService;
  final SupabaseClient? _clientOverride;

  ImportService(
    this._gamificationService, {
    SupabaseClient? clientOverride,
  }) : _clientOverride = clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const NotionExportZipService _notionZipParser =
      NotionExportZipService();

  NotionZipParsedBundle parseNotionZipBytes({
    required String fileName,
    required Uint8List bytes,
  }) {
    return _notionZipParser.parseZipBytes(
      fileName: fileName,
      bytes: bytes,
    );
  }

  ImportPreviewResult buildNotionZipPreviewFromBundle(
    NotionZipParsedBundle bundle,
  ) {
    return ImportPreviewResult(
      sourceType: 'notion_zip',
      sourceLabel: 'Notion (ZIP)',
      fileName: bundle.fileName,
      notes: bundle.notes,
      warnings: <String>[
        'Notion ZIP からページ ${bundle.pageCount} 件・データベース '
            '${bundle.databaseCount} 件・添付 ${bundle.attachmentCount} 件 '
            '(${formatStorageBytes(bundle.totalAttachmentBytes)}) を解析しました。',
        ...bundle.warnings,
      ],
      previewMode: 'local-notion-zip',
      sourceExportSha256: bundle.archiveSha256,
      resourceCount: bundle.attachmentCount,
    );
  }

  Future<ImportPreviewResult> buildPreview({
    required String sourceType,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (sourceType == 'notion_zip' ||
        (sourceType == 'notion' && fileName.toLowerCase().endsWith('.zip'))) {
      final bundle = parseNotionZipBytes(
        fileName: fileName,
        bytes: bytes,
      );
      return buildNotionZipPreviewFromBundle(bundle);
    }
    // XLSX/DOCX はバイナリ (ZIP) のため、テキスト前提の Edge Function を経由せず
    // クライアントで直接解析する (無駄な base64 アップロードを避ける)。
    if (sourceType == 'evernote' ||
        sourceType == 'xlsx' ||
        sourceType == 'docx') {
      return _buildPreviewLocally(
        sourceType: sourceType,
        fileName: fileName,
        bytes: bytes,
      );
    }
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

  Future<ImportPreviewResult> buildEvernoteStreamingPreview({
    required String fileName,
    required Stream<List<int>> source,
    int? totalBytes,
    void Function(int processedBytes, int? totalBytes)? onProgress,
  }) async {
    final notes = <ImportedNoteDraft>[];
    var hasEmptyResource = false;
    final summary = await _evernoteEnexParser.parseStream(
      source,
      totalBytes: totalBytes,
      onProgress: onProgress,
      onNote: (note) {
        if (note.resources.any((resource) => resource.data.isEmpty)) {
          hasEmptyResource = true;
        }
        notes.add(
          _toStreamingEvernotePreviewDraft(
            note,
            includeContentSample: notes.length < 12,
          ),
        );
      },
    );
    final commitBlockedReason = summary.warnings.isNotEmpty || hasEmptyResource
        ? 'Evernote commit remains paused because at least one attachment '
            'could not be decoded without warnings.'
        : null;

    return ImportPreviewResult(
      sourceType: 'evernote',
      sourceLabel: 'Evernote',
      fileName: fileName,
      notes: List<ImportedNoteDraft>.unmodifiable(notes),
      warnings: <String>[
        'Memory-bounded streaming preview parsed ${summary.noteCount} note(s).',
        'Only the first 12 note previews retain up to 2,000 characters; all note ids and hashes remain available for verification.',
        '${summary.resourceCount} attachment resource(s) were detected.',
        ...summary.warnings,
      ],
      previewMode: 'local-streaming',
      sourceExportSha256: summary.exportSha256,
      resourceCount: summary.resourceCount,
      commitBlockedReason: commitBlockedReason,
    );
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
      case 'notion_zip':
        return buildNotionZipPreviewFromBundle(
          parseNotionZipBytes(fileName: fileName, bytes: bytes),
        );
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
        return _buildEvernotePreview(
          fileName: fileName,
          bytes: bytes,
          fallbackWarning: fallbackWarning,
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
      case 'xlsx':
        return ImportPreviewResult(
          sourceType: 'xlsx',
          sourceLabel: 'Excel (XLSX)',
          fileName: fileName,
          notes: parseXlsxBytes(bytes),
          warnings: <String>[
            'Title / Content / Tags 列があれば利用し、無ければ各行を1つのノートに変換します。',
            if (fallbackWarning != null) fallbackWarning,
          ],
          previewMode: 'local-fallback',
        );
      case 'docx':
        return ImportPreviewResult(
          sourceType: 'docx',
          sourceLabel: 'Word (DOCX)',
          fileName: fileName,
          notes: <ImportedNoteDraft>[
            parseDocxBytes(bytes, fileName: fileName),
          ],
          warnings: <String>[
            '段落を改行で連結したプレーンテキストとして取り込みます。',
            if (fallbackWarning != null) fallbackWarning,
          ],
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
    return parseEvernoteEnexExportBytes(bytes)
        .notes
        .map(_toImportedEvernoteDraft)
        .toList(growable: false);
  }

  List<ImportedNoteDraft> parseEvernoteEnexText(String enexText) {
    return parseEvernoteEnexExportText(enexText)
        .notes
        .map(_toImportedEvernoteDraft)
        .toList(growable: false);
  }

  EvernoteEnexExport parseEvernoteEnexExportBytes(Uint8List bytes) =>
      _evernoteEnexParser.parseBytes(bytes);

  EvernoteEnexExport parseEvernoteEnexExportText(String enexText) =>
      _evernoteEnexParser.parseText(enexText);

  ImportPreviewResult _buildEvernotePreview({
    required String fileName,
    required Uint8List bytes,
    String? fallbackWarning,
  }) {
    final export = parseEvernoteEnexExportBytes(bytes);
    final hasEmptyResource = export.notes.any(
      (note) => note.resources.any((resource) => resource.data.isEmpty),
    );
    final commitBlockedReason = export.warnings.isNotEmpty || hasEmptyResource
        ? 'Evernote commit remains paused because at least one attachment '
            'could not be decoded without warnings.'
        : null;
    return ImportPreviewResult(
      sourceType: 'evernote',
      sourceLabel: 'Evernote',
      fileName: fileName,
      notes: export.notes.map(_toImportedEvernoteDraft).toList(growable: false),
      warnings: <String>[
        'ENML, timestamps, note attributes, links, and attachment manifests were preserved for verification.',
        '${export.resourceCount} attachment resource(s) were detected.',
        ...export.warnings,
        if (fallbackWarning != null) fallbackWarning,
      ],
      previewMode: 'local-fallback',
      sourceExportSha256: export.exportSha256,
      resourceCount: export.resourceCount,
      commitBlockedReason: commitBlockedReason,
    );
  }

  ImportedNoteDraft _toImportedEvernoteDraft(EvernoteEnexNote note) {
    return ImportedNoteDraft(
      title: note.title,
      content: note.markdownText,
      source: 'evernote',
      tags: note.tags,
      sourceId: note.sourceId,
      sourceCreatedAt: note.createdAt,
      sourceUpdatedAt: note.updatedAt,
      sourceContentSha256: note.contentSha256,
      sourceResourceCount: note.resources.length,
      sourceMetadata: note.toImportMetadata(),
    );
  }

  ImportedNoteDraft _toStreamingEvernotePreviewDraft(
    EvernoteEnexNote note, {
    required bool includeContentSample,
  }) {
    final contentSample = includeContentSample
        ? String.fromCharCodes(note.markdownText.runes.take(2000))
        : '';
    return ImportedNoteDraft(
      title: note.title,
      content: contentSample,
      source: 'evernote',
      tags: note.tags,
      sourceId: note.sourceId,
      sourceCreatedAt: note.createdAt,
      sourceUpdatedAt: note.updatedAt,
      sourceContentSha256: note.contentSha256,
      sourceResourceCount: note.resources.length,
      sourceMetadata: <String, dynamic>{
        'streaming_preview': true,
        'preview_sample': includeContentSample,
        'preview_content_truncated': contentSample != note.markdownText,
      },
    );
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

  static const OfficeDocumentParser _officeParser = OfficeDocumentParser();

  /// XLSX (Excel) をノート群に変換する。ヘッダ行に Title/Content/Tags 相当の
  /// 列があればそれを尊重し、無ければ各行を1ノート化する。
  List<ImportedNoteDraft> parseXlsxBytes(Uint8List bytes) {
    final rows = _officeParser.parseXlsxToRows(bytes);
    return _rowsToNotes(rows, source: 'xlsx', fallbackTitle: 'Spreadsheet row');
  }

  /// DOCX (Word) を単一ノートに変換する。段落を改行結合し、先頭の非空行を
  /// タイトルに採用する (無ければファイル名)。
  ImportedNoteDraft parseDocxBytes(
    Uint8List bytes, {
    required String fileName,
  }) {
    final text = _officeParser.parseDocxToText(bytes);
    final firstLine = const LineSplitter()
        .convert(text)
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final title = firstLine.isNotEmpty
        ? (firstLine.length > 200 ? firstLine.substring(0, 200) : firstLine)
        : _fileNameStem(fileName);
    return ImportedNoteDraft(
      title: title,
      content: text.trim(),
      source: 'docx',
    );
  }

  String _fileNameStem(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
  }

  /// 2次元セル配列をノート群に変換する共通ロジック。
  List<ImportedNoteDraft> _rowsToNotes(
    List<List<String>> rows, {
    required String source,
    required String fallbackTitle,
  }) {
    final nonEmpty = <List<String>>[
      for (final row in rows)
        if (row.any((cell) => cell.trim().isNotEmpty)) row,
    ];
    if (nonEmpty.isEmpty) {
      return const <ImportedNoteDraft>[];
    }

    final header =
        nonEmpty.first.map((cell) => cell.trim().toLowerCase()).toList();
    final titleIndex = _findColumnIndex(
      header,
      const <String>['title', 'name', 'note', 'ページ', 'タイトル', '件名'],
    );
    final contentIndex = _findColumnIndex(
      header,
      const <String>['content', 'text', 'body', 'plain text', '本文', '内容', 'メモ'],
    );
    final tagsIndex = _findColumnIndex(
      header,
      const <String>['tags', 'tag', 'labels', 'タグ', 'ラベル'],
    );

    if (titleIndex >= 0 || contentIndex >= 0) {
      final drafts = <ImportedNoteDraft>[];
      for (final row in nonEmpty.skip(1)) {
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
            title: title.isEmpty ? fallbackTitle : title,
            content: content,
            source: source,
            tags: tags,
          ),
        );
      }
      return drafts;
    }

    // ヘッダを検出できないシート: 各行を1ノート化 (先頭セル=タイトル / 全セル=本文)。
    final drafts = <ImportedNoteDraft>[];
    for (final row in nonEmpty) {
      final cells = row
          .map((cell) => cell.trim())
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.isEmpty) {
        continue;
      }
      drafts.add(
        ImportedNoteDraft(
          title: cells.first,
          content: cells.join('\n'),
          source: source,
        ),
      );
    }
    return drafts;
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
    if (notes.any((note) => note.source == 'evernote')) {
      throw StateError(
        'Evernote import requires the lossless migration commit pipeline.',
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
    if (!data.containsKey('insertedCount')) {
      throw StateError(
        'Edge Function import.commit did not confirm inserted rows.',
      );
    }

    final result = ImportExecutionResult.fromJson(data);
    if (notes.isNotEmpty && result.insertedCount <= 0) {
      throw StateError(
        'Edge Function import.commit reported 0 inserted rows.',
      );
    }
    await _awardImportPoints(result.insertedCount);
    return result;
  }

  Future<Set<String>> _loadExistingSourceKeys({
    required String userId,
    required Iterable<ImportedNoteDraft> notes,
  }) async {
    final keys = notes
        .map((note) => note.sourceId?.trim() ?? '')
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (keys.isEmpty) {
      return const <String>{};
    }

    final existing = <String>{};
    const chunkSize = 50;
    try {
      for (var i = 0; i < keys.length; i += chunkSize) {
        final chunk = keys.sublist(
          i,
          i + chunkSize > keys.length ? keys.length : i + chunkSize,
        );
        final rows = await _client
            .from('notes')
            .select('source_key')
            .eq('user_id', userId)
            .inFilter('source_key', chunk);
        for (final row in rows) {
          final key = row['source_key']?.toString().trim() ?? '';
          if (key.isNotEmpty) {
            existing.add(key);
          }
        }
      }
    } catch (error) {
      debugPrint('Skipping source_key preflight dedup: $error');
    }
    return existing;
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

    final existingKeys = await _loadExistingSourceKeys(
      userId: userId,
      notes: notes,
    );
    final filtered = <ImportedNoteDraft>[];
    var skippedDuplicates = 0;
    for (final note in notes) {
      final sourceKey = note.sourceId?.trim() ?? '';
      if (sourceKey.isNotEmpty && existingKeys.contains(sourceKey)) {
        skippedDuplicates += 1;
        continue;
      }
      filtered.add(note);
    }
    if (filtered.isEmpty) {
      return ImportExecutionResult(
        insertedCount: 0,
        skippedDuplicateCount: skippedDuplicates,
        importMode: 'local-fallback',
      );
    }

    final rows = filtered.map((note) {
      final sourceKey = note.sourceId?.trim();
      return <String, dynamic>{
        'user_id': userId,
        'created_by': userId,
        'title': note.title.trim(),
        'content': note.content.trim(),
        'tags': note.tags,
        'capture_source': note.source,
        'is_archived': false,
        'is_pinned': false,
        if (sourceKey != null && sourceKey.isNotEmpty) 'source_key': sourceKey,
      };
    }).toList();

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
      skippedDuplicateCount: skippedDuplicates,
      importMode: 'local-fallback',
    );
  }

  Future<ImportExecutionResult> importNotionZipBundle({
    required String userId,
    required NotionZipParsedBundle bundle,
    bool uploadAttachments = true,
    bool skipAttachmentsOnQuotaExceeded = false,
    StorageQuotaService? quotaService,
    DirectStorageUploadService? uploadService,
  }) async {
    if (bundle.notes.isEmpty) {
      return const ImportExecutionResult(
        insertedCount: 0,
        importMode: 'notion-zip-lossless',
      );
    }

    final existingKeys = await _loadExistingSourceKeys(
      userId: userId,
      notes: bundle.notes,
    );
    final notesToInsert = <ImportedNoteDraft>[];
    var skippedDuplicates = 0;
    for (final note in bundle.notes) {
      final sourceKey = note.sourceId?.trim() ?? '';
      if (sourceKey.isNotEmpty && existingKeys.contains(sourceKey)) {
        skippedDuplicates += 1;
        continue;
      }
      notesToInsert.add(note);
    }
    if (notesToInsert.isEmpty) {
      return ImportExecutionResult(
        insertedCount: 0,
        skippedDuplicateCount: skippedDuplicates,
        importMode: 'notion-zip-lossless',
      );
    }

    final referencedAttachments = bundle.attachmentsForNotes(notesToInsert);
    var shouldUploadAttachments =
        uploadAttachments && referencedAttachments.isNotEmpty;
    var skippedAttachments =
        !uploadAttachments ? referencedAttachments.length : 0;

    if (shouldUploadAttachments) {
      final resolvedQuotaService =
          quotaService ?? StorageQuotaService.supabase(_client);
      var totalBytes = 0;
      var maxFileBytes = 0;
      for (final attachment in referencedAttachments) {
        if (attachment.sizeBytes <= 0) {
          continue;
        }
        totalBytes += attachment.sizeBytes;
        if (attachment.sizeBytes > maxFileBytes) {
          maxFileBytes = attachment.sizeBytes;
        }
      }
      if (totalBytes > 0) {
        final evaluation = await resolvedQuotaService.evaluateUpload(
          userId: userId,
          incomingBytes: totalBytes,
          singleFileBytes: maxFileBytes,
        );
        if (!evaluation.allowed) {
          if (skipAttachmentsOnQuotaExceeded) {
            shouldUploadAttachments = false;
            skippedAttachments = referencedAttachments.length;
          } else {
            throw StorageQuotaException(
              evaluation.reason,
              evaluation: evaluation,
            );
          }
        }
      }
    }

    final collections = _NotionCollectionResolver(client: _client);
    await collections.preload(userId);

    final resolvedUploadService =
        uploadService ?? DirectStorageUploadService.supabase(_client);

    const chunkSize = 50;
    var insertedCount = 0;
    var uploadedAttachmentCount = 0;

    for (var i = 0; i < notesToInsert.length; i += chunkSize) {
      final draftChunk = notesToInsert.sublist(
        i,
        i + chunkSize > notesToInsert.length
            ? notesToInsert.length
            : i + chunkSize,
      );
      final rows = <Map<String, dynamic>>[];
      for (final draft in draftChunk) {
        final collectionIds = await collections.resolveForDraft(
          userId: userId,
          draft: draft,
        );
        final sourceKey = draft.sourceId?.trim();
        rows.add(<String, dynamic>{
          'user_id': userId,
          'created_by': userId,
          'title': draft.title.trim(),
          'content': draft.content.trim(),
          'tags': draft.tags,
          'capture_source': draft.source,
          'is_archived': false,
          'is_pinned': false,
          if (sourceKey != null && sourceKey.isNotEmpty)
            'source_key': sourceKey,
          if (collectionIds.spaceId != null)
            'space_collection_id': collectionIds.spaceId,
          if (collectionIds.notebookId != null)
            'notebook_collection_id': collectionIds.notebookId,
        });
      }

      final insertedRows =
          await _client.from('notes').insert(rows).select('id, source_key');
      final idBySourceKey = <String, int>{};
      final fallbackIds = <int>[];
      for (final row in insertedRows) {
        final id = _toIntValue(row['id']);
        fallbackIds.add(id);
        final key = row['source_key']?.toString().trim() ?? '';
        if (key.isNotEmpty && id > 0) {
          idBySourceKey[key] = id;
        }
      }
      insertedCount += insertedRows.length;

      if (!shouldUploadAttachments) {
        continue;
      }

      for (var j = 0; j < draftChunk.length; j += 1) {
        final draft = draftChunk[j];
        final sourceKey = draft.sourceId?.trim() ?? '';
        final noteId = idBySourceKey[sourceKey] ??
            (j < fallbackIds.length ? fallbackIds[j] : 0);
        if (noteId <= 0 || sourceKey.isEmpty) {
          continue;
        }
        final links = bundle.noteAttachmentLinks[sourceKey] ??
            const <NotionZipAttachmentLink>[];
        if (links.isEmpty) {
          continue;
        }

        var updatedContent = draft.content.trim();
        var contentChanged = false;
        final uploadedByAttachmentKey = <String, String>{};

        for (final link in links) {
          final attachment = bundle.attachments[link.attachmentKey];
          if (attachment == null) {
            continue;
          }
          if (attachment.bytes.isEmpty) {
            skippedAttachments += 1;
            continue;
          }

          var storagePath = uploadedByAttachmentKey[attachment.normalizedKey];
          if (storagePath == null) {
            final uploadResult =
                await resolvedUploadService.uploadAndInsertMetadata(
              bucketId: 'attachments',
              tableName: 'attachments',
              userId: userId,
              bytes: attachment.bytes,
              originalFileName: attachment.fileName,
              contentType: attachment.mimeType,
              ownerPathSegments: <String>[noteId.toString()],
              metadataBuilder: (final object) {
                return <String, dynamic>{
                  'note_id': noteId,
                  'user_id': object.userId,
                  'file_name': attachment.fileName,
                  'file_path': object.storagePath,
                  'file_size': object.sizeBytes,
                  'file_type': attachment.fileType,
                  'mime_type': object.contentType,
                  'content_sha256': attachment.contentSha256,
                  'source_system': 'notion',
                  'source_metadata': <String, dynamic>{
                    'notion_relative_path': attachment.relativePath,
                    'source_key': sourceKey,
                  },
                };
              },
            );
            storagePath = uploadResult.storagePath;
            uploadedByAttachmentKey[attachment.normalizedKey] = storagePath;
            uploadedAttachmentCount += 1;
          }

          final replacementUrl = AttachmentService.getMarkdownUrl(storagePath);
          final escapedTarget = RegExp.escape(link.rawTarget);
          final linkPattern = RegExp(
            '(!?\\[[^\\]]*\\])\\((?:<$escapedTarget>|$escapedTarget)(?:\\s+"[^"]*")?\\)',
          );
          final nextContent = updatedContent.replaceAllMapped(
            linkPattern,
            (final match) {
              final prefix = match.group(1) ?? '';
              return '$prefix($replacementUrl)';
            },
          );
          if (nextContent != updatedContent) {
            updatedContent = nextContent;
            contentChanged = true;
          }
        }

        if (contentChanged) {
          await _client
              .from('notes')
              .update(<String, dynamic>{'content': updatedContent})
              .eq('id', noteId)
              .eq('user_id', userId);
        }
      }
    }

    await _awardImportPoints(insertedCount);

    return ImportExecutionResult(
      insertedCount: insertedCount,
      skippedDuplicateCount: skippedDuplicates,
      uploadedAttachmentCount: uploadedAttachmentCount,
      skippedAttachmentCount: skippedAttachments,
      importMode: 'notion-zip-lossless',
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

const EvernoteEnexParser _evernoteEnexParser = EvernoteEnexParser();

class _NotionCollectionResolver {
  _NotionCollectionResolver({
    required SupabaseClient client,
  }) : _client = client;

  final SupabaseClient _client;
  final Map<String, int> _spaceIds = <String, int>{};
  final Map<String, int> _notebookIds = <String, int>{};

  Future<void> preload(final String userId) async {
    try {
      final rows = await _client
          .from('note_collections')
          .select('id, collection_type, parent_id, name')
          .eq('user_id', userId);
      for (final row in rows) {
        final id = ImportService._toIntValue(row['id']);
        if (id <= 0) {
          continue;
        }
        final type = row['collection_type']?.toString() ?? '';
        final name = (row['name']?.toString() ?? '').trim().toLowerCase();
        if (name.isEmpty) {
          continue;
        }
        if (type == 'space') {
          _spaceIds[name] = id;
        } else if (type == 'notebook') {
          final parentId = ImportService._toIntValue(row['parent_id']);
          _notebookIds['$parentId::$name'] = id;
        }
      }
    } catch (error) {
      debugPrint('Skipping note_collections preload: $error');
    }
  }

  Future<({int? spaceId, int? notebookId})> resolveForDraft({
    required final String userId,
    required final ImportedNoteDraft draft,
  }) async {
    final spaceName = _clampName(
      draft.sourceMetadata['space_name']?.toString(),
      fallback: 'Notion',
    );
    final notebookName = _clampName(
      draft.sourceMetadata['notebook_name']?.toString(),
      fallback: 'Notion Import',
    );
    final spaceId = await _ensureCollection(
      userId: userId,
      type: 'space',
      name: spaceName,
      parentId: null,
    );
    final notebookId = await _ensureCollection(
      userId: userId,
      type: 'notebook',
      name: notebookName,
      parentId: spaceId,
    );
    return (spaceId: spaceId, notebookId: notebookId);
  }

  Future<int?> _ensureCollection({
    required final String userId,
    required final String type,
    required final String name,
    required final int? parentId,
  }) async {
    final normalizedKey = name.toLowerCase();
    if (type == 'space') {
      final cached = _spaceIds[normalizedKey];
      if (cached != null) {
        return cached;
      }
    } else {
      final key = '${parentId ?? 0}::$normalizedKey';
      final cached = _notebookIds[key];
      if (cached != null) {
        return cached;
      }
    }

    try {
      final inserted = await _client
          .from('note_collections')
          .insert(<String, dynamic>{
            'user_id': userId,
            'collection_type': type,
            'parent_id': parentId,
            'name': name,
            'source_system': 'native',
          })
          .select('id')
          .single();
      final id = ImportService._toIntValue(inserted['id']);
      if (id > 0) {
        if (type == 'space') {
          _spaceIds[normalizedKey] = id;
        } else {
          _notebookIds['${parentId ?? 0}::$normalizedKey'] = id;
        }
        return id;
      }
    } catch (error) {
      debugPrint('Collection ensure skipped ($type/$name): $error');
    }
    return null;
  }

  String _clampName(
    final String? raw, {
    required final String fallback,
  }) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return fallback;
    }
    if (trimmed.length > 200) {
      return trimmed.substring(0, 200);
    }
    return trimmed;
  }
}
