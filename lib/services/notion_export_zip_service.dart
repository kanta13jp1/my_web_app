import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import 'import_service.dart';
import 'storage_quota_service.dart';

class NotionZipAttachment {
  const NotionZipAttachment({
    required this.relativePath,
    required this.normalizedKey,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sizeBytes,
    required this.contentSha256,
  });

  final String relativePath;
  final String normalizedKey;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final int sizeBytes;
  final String contentSha256;

  String get fileType {
    if (mimeType.startsWith('image/')) {
      return 'image';
    }
    if (mimeType == 'application/pdf') {
      return 'pdf';
    }
    return 'other';
  }
}

class NotionZipAttachmentLink {
  const NotionZipAttachmentLink({
    required this.rawTarget,
    required this.attachmentKey,
  });

  final String rawTarget;
  final String attachmentKey;
}

class NotionZipParsedBundle {
  const NotionZipParsedBundle({
    required this.fileName,
    required this.archiveSizeBytes,
    required this.archiveSha256,
    required this.notes,
    required this.attachments,
    required this.noteAttachmentLinks,
    required this.folderPaths,
    required this.pageCount,
    required this.databaseCount,
    required this.totalAttachmentBytes,
    required this.oversizedAttachmentCount,
    required this.skippedDuplicateCsvCount,
    required this.nestedZipCount,
    required this.warnings,
  });

  final String fileName;
  final int archiveSizeBytes;
  final String archiveSha256;
  final List<ImportedNoteDraft> notes;
  final Map<String, NotionZipAttachment> attachments;
  final Map<String, List<NotionZipAttachmentLink>> noteAttachmentLinks;
  final Set<String> folderPaths;
  final int pageCount;
  final int databaseCount;
  final int totalAttachmentBytes;
  final int oversizedAttachmentCount;
  final int skippedDuplicateCsvCount;
  final int nestedZipCount;
  final List<String> warnings;

  int get attachmentCount => attachments.length;

  int get folderCount => folderPaths.length;

  /// 指定されたノート群から参照されているユニークな添付ファイル一覧を返す。
  /// もしリンク解決で見つからない添付がある場合は、参照されたもののみを返す。
  List<NotionZipAttachment> attachmentsForNotes(
    final Iterable<ImportedNoteDraft> targetNotes,
  ) {
    final collected = <String, NotionZipAttachment>{};
    for (final note in targetNotes) {
      final sourceId = note.sourceId;
      if (sourceId == null) {
        continue;
      }
      final links =
          noteAttachmentLinks[sourceId] ?? const <NotionZipAttachmentLink>[];
      for (final link in links) {
        final attachment = attachments[link.attachmentKey];
        if (attachment != null) {
          collected[attachment.normalizedKey] = attachment;
        }
      }
    }
    return List<NotionZipAttachment>.unmodifiable(collected.values);
  }
}

class MigrationDiagnosticReport {
  const MigrationDiagnosticReport({
    required this.sourceSystem,
    required this.fileName,
    required this.archiveSizeBytes,
    required this.noteCount,
    required this.databaseCount,
    required this.folderCount,
    required this.attachmentCount,
    required this.totalAttachmentBytes,
    required this.oversizedAttachmentCount,
    required this.fitsFreeStorageQuota,
    required this.freeQuotaBytes,
    required this.estimatedAnnualSavingsMinJpy,
    required this.estimatedAnnualSavingsMaxJpy,
    required this.warnings,
  });

  factory MigrationDiagnosticReport.fromNotionZipBundle(
    final NotionZipParsedBundle bundle, {
    final int freeQuotaBytes = StorageQuotaPolicy.freeQuotaBytes,
  }) {
    final fits = bundle.totalAttachmentBytes <= freeQuotaBytes &&
        bundle.oversizedAttachmentCount == 0;
    return MigrationDiagnosticReport(
      sourceSystem: 'notion',
      fileName: bundle.fileName,
      archiveSizeBytes: bundle.archiveSizeBytes,
      noteCount: bundle.notes.length,
      databaseCount: bundle.databaseCount,
      folderCount: bundle.folderCount,
      attachmentCount: bundle.attachmentCount,
      totalAttachmentBytes: bundle.totalAttachmentBytes,
      oversizedAttachmentCount: bundle.oversizedAttachmentCount,
      fitsFreeStorageQuota: fits,
      freeQuotaBytes: freeQuotaBytes,
      estimatedAnnualSavingsMinJpy: 21600,
      estimatedAnnualSavingsMaxJpy: 43200,
      warnings: bundle.warnings,
    );
  }

  factory MigrationDiagnosticReport.fromImportPreview({
    required final ImportPreviewResult preview,
    final int archiveSizeBytes = 0,
    final int totalAttachmentBytes = 0,
    final int freeQuotaBytes = StorageQuotaPolicy.freeQuotaBytes,
  }) {
    final source = preview.sourceType == 'evernote' ? 'evernote' : 'notion';
    final effectiveBytes =
        totalAttachmentBytes > 0 ? totalAttachmentBytes : archiveSizeBytes;
    final folders = <String>{};
    var databaseCount = 0;
    for (final note in preview.notes) {
      if (note.source == 'notion_database') {
        databaseCount += 1;
      }
      final hierarchy =
          note.sourceMetadata['notion_hierarchy_path']?.toString() ?? '';
      if (hierarchy.isNotEmpty) {
        folders.add(hierarchy);
      }
    }
    return MigrationDiagnosticReport(
      sourceSystem: source,
      fileName: preview.fileName,
      archiveSizeBytes: archiveSizeBytes,
      noteCount: preview.notes.length,
      databaseCount: databaseCount,
      folderCount: folders.length,
      attachmentCount: preview.resourceCount,
      totalAttachmentBytes: effectiveBytes,
      oversizedAttachmentCount: 0,
      fitsFreeStorageQuota: effectiveBytes <= freeQuotaBytes,
      freeQuotaBytes: freeQuotaBytes,
      estimatedAnnualSavingsMinJpy: source == 'evernote' ? 9300 : 21600,
      estimatedAnnualSavingsMaxJpy: source == 'evernote' ? 17900 : 43200,
      warnings: preview.warnings,
    );
  }

  final String sourceSystem;
  final String fileName;
  final int archiveSizeBytes;
  final int noteCount;
  final int databaseCount;
  final int folderCount;
  final int attachmentCount;
  final int totalAttachmentBytes;
  final int oversizedAttachmentCount;
  final bool fitsFreeStorageQuota;
  final int freeQuotaBytes;
  final int estimatedAnnualSavingsMinJpy;
  final int estimatedAnnualSavingsMaxJpy;
  final List<String> warnings;

  String get sourceDisplayName =>
      sourceSystem == 'evernote' ? 'Evernote' : 'Notion';

  String get estimatedAnnualSavingsLabel =>
      '約 ${_formatJpyNumber(estimatedAnnualSavingsMinJpy)}〜'
      '${_formatJpyNumber(estimatedAnnualSavingsMaxJpy)} 円/年';

  static String _formatJpyNumber(final int amount) {
    final absDigits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < absDigits.length; i += 1) {
      if (i > 0 && (absDigits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(absDigits[i]);
    }
    return amount < 0 ? '-$buffer' : buffer.toString();
  }

  /// 個人情報・ノートタイトル・本文・ファイル名を含まない共有用サマリー文を返す。
  String buildShareableSummaryText() {
    final quotaStatus = fitsFreeStorageQuota
        ? '無料ストレージ枠 (${formatStorageBytes(freeQuotaBytes)}) 内に収容可能'
        : '添付ファイルのみ整理/上位枠推奨 (本文・表は全件移行可能)';
    return '$sourceDisplayName 移行事前診断結果: '
        'ノート $noteCount 件 (DB $databaseCount 件 / フォルダ $folderCount 階層) / '
        '添付 $attachmentCount 件 (${formatStorageBytes(totalAttachmentBytes)}) / '
        '$quotaStatus / '
        '年間固定費の参考見直し目安: $estimatedAnnualSavingsLabel (プラン条件により異なります) '
        '#自分株式会社 #個人開発';
  }
}

class _RawZipEntry {
  const _RawZipEntry({
    required this.rawPath,
    required this.bytes,
  });

  final String rawPath;
  final Uint8List bytes;
}

class NotionExportZipService {
  const NotionExportZipService();

  static const int maxNestedZipDepth = 3;
  static const int maxEntryCount = 20000;
  static const int maxTotalUncompressedBytes = 512 * 1024 * 1024;
  static const int maxRenderedCsvRows = 500;

  static final RegExp _notionIdSuffixPattern = RegExp(
    r'\s+[0-9a-fA-F]{32}$',
  );
  static final RegExp _exportWrapperSegmentPattern = RegExp(
    r'^export(?:block)?-[0-9a-fA-F-]+(?:-part-\d+)?$',
    caseSensitive: false,
  );
  static final RegExp _markdownLinkPattern = RegExp(
    r'!?\[[^\]]*\]\(([^)\r\n]+)\)',
  );

  NotionZipParsedBundle parseZipBytes({
    required final String fileName,
    required final Uint8List bytes,
  }) {
    final archiveSha256 = sha256.convert(bytes).toString();
    final warnings = <String>[];
    final state = _ExtractionState();

    _extractZipRecursive(
      bytes: bytes,
      parentPrefix: '',
      depth: 0,
      state: state,
      warnings: warnings,
    );

    if (state.skippedUnsafePathCount > 0) {
      warnings.add(
        '安全でないパス (${state.skippedUnsafePathCount} 件) をスキップしました。',
      );
    }

    final normalizedEntries = state.entries;
    final pathSet = <String>{
      for (final entry in normalizedEntries) entry.rawPath,
    };

    final attachmentsByKey = <String, NotionZipAttachment>{};
    final decodedPathLookup = <String, String>{};
    final basenameLookup = <String, List<String>>{};
    var totalAttachmentBytes = 0;
    var oversizedAttachmentCount = 0;
    var htmlCount = 0;

    final markdownEntries = <_RawZipEntry>[];
    final csvEntries = <_RawZipEntry>[];

    for (final entry in normalizedEntries) {
      final lower = entry.rawPath.toLowerCase();
      if (lower.endsWith('.md') || lower.endsWith('.markdown')) {
        markdownEntries.add(entry);
        continue;
      }
      if (lower.endsWith('.csv')) {
        csvEntries.add(entry);
        continue;
      }
      if (lower.endsWith('.html') || lower.endsWith('.htm')) {
        htmlCount += 1;
        continue;
      }
      if (lower.endsWith('.zip')) {
        continue;
      }

      final normalizedKey = _normalizeLookupKey(entry.rawPath);
      final attachmentName = p.posix.basename(entry.rawPath);
      final mimeType =
          lookupMimeType(attachmentName) ?? 'application/octet-stream';
      final contentSha = sha256.convert(entry.bytes).toString();
      final attachment = NotionZipAttachment(
        relativePath: entry.rawPath,
        normalizedKey: normalizedKey,
        fileName: attachmentName,
        mimeType: mimeType,
        bytes: entry.bytes,
        sizeBytes: entry.bytes.length,
        contentSha256: contentSha,
      );
      attachmentsByKey[normalizedKey] = attachment;
      decodedPathLookup[_normalizeLookupKey(_safeDecodeUri(entry.rawPath))] =
          normalizedKey;
      final baseLower = attachmentName.toLowerCase();
      basenameLookup
          .putIfAbsent(baseLower, () => <String>[])
          .add(normalizedKey);

      totalAttachmentBytes += entry.bytes.length;
      if (entry.bytes.length > StorageQuotaPolicy.freeSingleFileMaxBytes) {
        oversizedAttachmentCount += 1;
      }
    }

    final notes = <ImportedNoteDraft>[];
    final noteAttachmentLinks = <String, List<NotionZipAttachmentLink>>{};
    final folderPaths = <String>{};
    var pageCount = 0;
    var databaseCount = 0;
    var skippedDuplicateCsvCount = 0;

    for (final entry in markdownEntries) {
      final parsed = _parseMarkdownEntry(
        entry: entry,
        attachmentsByKey: attachmentsByKey,
        decodedPathLookup: decodedPathLookup,
        basenameLookup: basenameLookup,
      );
      final hierarchy =
          parsed.draft.sourceMetadata['notion_hierarchy_path']?.toString() ??
              '';
      if (hierarchy.isNotEmpty) {
        folderPaths.add(hierarchy);
      }
      if (parsed.draft.sourceId != null && parsed.links.isNotEmpty) {
        noteAttachmentLinks[parsed.draft.sourceId!] = parsed.links;
      }
      notes.add(parsed.draft);
      pageCount += 1;
    }

    for (final entry in csvEntries) {
      if (_hasCompanionAllCsv(entry.rawPath, pathSet)) {
        skippedDuplicateCsvCount += 1;
        continue;
      }
      final draft = _parseCsvEntry(entry: entry, warnings: warnings);
      if (draft == null) {
        continue;
      }
      final hierarchy =
          draft.sourceMetadata['notion_hierarchy_path']?.toString() ?? '';
      if (hierarchy.isNotEmpty) {
        folderPaths.add(hierarchy);
      }
      notes.add(draft);
      databaseCount += 1;
    }

    if (skippedDuplicateCsvCount > 0) {
      warnings.add(
        '同一ディレクトリの `_all.csv` を優先し、重複する部分ビュー CSV ($skippedDuplicateCsvCount 件) をスキップしました。',
      );
    }
    if (oversizedAttachmentCount > 0) {
      warnings.add(
        'Free プランの 1 ファイル上限 (${formatStorageBytes(StorageQuotaPolicy.freeSingleFileMaxBytes)}) を超える添付ファイルが '
        '$oversizedAttachmentCount 件検出されました。',
      );
    }
    if (htmlCount > 0 && notes.isEmpty) {
      warnings.add(
        'HTML エクスポート ($htmlCount 件) のみ検出されました。Notion から「Markdown & CSV」形式でエクスポートした ZIP を選択してください。',
      );
    }
    if (notes.isEmpty && attachmentsByKey.isEmpty) {
      warnings.add('ZIP 内にインポート可能な Markdown (.md) または CSV (.csv) が見つかりませんでした。');
    }

    return NotionZipParsedBundle(
      fileName: fileName,
      archiveSizeBytes: bytes.length,
      archiveSha256: archiveSha256,
      notes: List<ImportedNoteDraft>.unmodifiable(notes),
      attachments: Map<String, NotionZipAttachment>.unmodifiable(
        attachmentsByKey,
      ),
      noteAttachmentLinks:
          Map<String, List<NotionZipAttachmentLink>>.unmodifiable(
        noteAttachmentLinks,
      ),
      folderPaths: Set<String>.unmodifiable(folderPaths),
      pageCount: pageCount,
      databaseCount: databaseCount,
      totalAttachmentBytes: totalAttachmentBytes,
      oversizedAttachmentCount: oversizedAttachmentCount,
      skippedDuplicateCsvCount: skippedDuplicateCsvCount,
      nestedZipCount: state.nestedZipCount,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  void _extractZipRecursive({
    required final Uint8List bytes,
    required final String parentPrefix,
    required final int depth,
    required final _ExtractionState state,
    required final List<String> warnings,
  }) {
    if (depth > maxNestedZipDepth) {
      warnings.add('入れ子 ZIP の深度上限 ($maxNestedZipDepth) を超えたアーカイブをスキップしました。');
      return;
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (error) {
      warnings.add('ZIP アーカイブを展開できませんでした: $error');
      return;
    }

    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      if (state.entryCount >= maxEntryCount) {
        if (!state.hitEntryCapWarning) {
          state.hitEntryCapWarning = true;
          warnings.add('ZIP 内エントリ数が上限 ($maxEntryCount 件) に達したため残りをスキップしました。');
        }
        break;
      }

      var sanitized = _sanitizeArchiveEntryPath(file.name);
      if (sanitized == null) {
        state.skippedUnsafePathCount += 1;
        continue;
      }
      if (_shouldSkipSystemFile(sanitized)) {
        continue;
      }
      sanitized = _stripLeadingWrapperFolders(sanitized);

      final combinedPath = parentPrefix.isEmpty
          ? sanitized
          : p.posix.normalize('$parentPrefix/$sanitized');
      if (combinedPath.split('/').contains('..')) {
        state.skippedUnsafePathCount += 1;
        continue;
      }

      final entryBytes = Uint8List.fromList(file.content);
      if (combinedPath.toLowerCase().endsWith('.zip')) {
        if (depth >= maxNestedZipDepth) {
          warnings.add(
            '入れ子 ZIP の深度上限 ($maxNestedZipDepth) を超えたため $combinedPath をスキップしました。',
          );
          continue;
        }
        state.nestedZipCount += 1;
        final nestedPrefix = p.posix.dirname(combinedPath);
        _extractZipRecursive(
          bytes: entryBytes,
          parentPrefix: nestedPrefix == '.' ? '' : nestedPrefix,
          depth: depth + 1,
          state: state,
          warnings: warnings,
        );
        continue;
      }

      state.totalUncompressedBytes += entryBytes.length;
      if (state.totalUncompressedBytes > maxTotalUncompressedBytes) {
        if (!state.hitByteCapWarning) {
          state.hitByteCapWarning = true;
          warnings.add(
            '展開合計サイズが上限 (${formatStorageBytes(maxTotalUncompressedBytes)}) に達したため残りをスキップしました。',
          );
        }
        break;
      }

      state.entryCount += 1;
      state.entries.add(
        _RawZipEntry(
          rawPath: combinedPath,
          bytes: entryBytes,
        ),
      );
    }
  }

  String _stripLeadingWrapperFolders(final String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    while (segments.length > 1 &&
        _exportWrapperSegmentPattern.hasMatch(segments.first)) {
      segments.removeAt(0);
    }
    return segments.join('/');
  }

  String? _sanitizeArchiveEntryPath(final String rawName) {
    final normalizedSlashes = rawName.replaceAll('\\', '/').trim();
    if (normalizedSlashes.isEmpty || normalizedSlashes.startsWith('/')) {
      return null;
    }
    final segments = normalizedSlashes
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();
    if (segments.isEmpty) {
      return null;
    }
    for (final segment in segments) {
      if (segment == '..' || segment.contains(':')) {
        return null;
      }
    }
    return segments.join('/');
  }

  bool _shouldSkipSystemFile(final String path) {
    final lower = path.toLowerCase();
    final base = p.posix.basename(lower);
    if (lower.startsWith('__macosx/') || lower.contains('/__macosx/')) {
      return true;
    }
    if (base == '.ds_store' || base == 'thumbs.db' || base == 'desktop.ini') {
      return true;
    }
    return false;
  }

  ({
    ImportedNoteDraft draft,
    List<NotionZipAttachmentLink> links,
  }) _parseMarkdownEntry({
    required final _RawZipEntry entry,
    required final Map<String, NotionZipAttachment> attachmentsByKey,
    required final Map<String, String> decodedPathLookup,
    required final Map<String, List<String>> basenameLookup,
  }) {
    final decoded = _stripBom(utf8.decode(entry.bytes, allowMalformed: true));
    final trimmedContent = decoded.trim();
    final stemClean = _cleanNotionName(
      _stripExtension(p.posix.basename(entry.rawPath)),
    );
    final title = _extractMarkdownTitle(
      trimmedContent,
      fallback: stemClean.isEmpty ? 'Untitled Notion Page' : stemClean,
    );

    final hierarchy = _buildHierarchyContext(
      entry.rawPath,
      extraTags: const <String>[],
    );
    final noteDir = p.posix.dirname(entry.rawPath);
    final rawDir = noteDir == '.' ? '' : noteDir;

    final matchedLinks = <NotionZipAttachmentLink>[];
    final seenTargets = <String>{};
    final matchedAttachmentKeys = <String>{};

    for (final match in _markdownLinkPattern.allMatches(trimmedContent)) {
      final inner = (match.group(1) ?? '').trim();
      final rawTarget = _extractLinkTarget(inner);
      if (rawTarget.isEmpty || _isExternalLink(rawTarget)) {
        continue;
      }
      final resolvedKey = _resolveAttachmentKey(
        rawTarget: rawTarget,
        noteDir: rawDir,
        attachmentsByKey: attachmentsByKey,
        decodedPathLookup: decodedPathLookup,
        basenameLookup: basenameLookup,
      );
      if (resolvedKey == null) {
        continue;
      }
      matchedAttachmentKeys.add(resolvedKey);
      if (seenTargets.add(rawTarget)) {
        matchedLinks.add(
          NotionZipAttachmentLink(
            rawTarget: rawTarget,
            attachmentKey: resolvedKey,
          ),
        );
      }
    }

    final hashInput = '${entry.rawPath}\n$title\n$trimmedContent';
    final contentSha = sha256.convert(utf8.encode(trimmedContent)).toString();
    final sourceId = 'notion-zip:${sha256.convert(utf8.encode(hashInput))}';

    final draft = ImportedNoteDraft(
      title: title,
      content: trimmedContent,
      source: 'notion_page',
      tags: hierarchy.tags,
      sourceId: sourceId,
      sourceContentSha256: contentSha,
      sourceResourceCount: matchedAttachmentKeys.length,
      sourceMetadata: <String, dynamic>{
        'notion_relative_path': hierarchy.cleanRelativePath,
        'notion_hierarchy_path': hierarchy.hierarchyPath,
        'space_name': hierarchy.spaceName,
        'notebook_name': hierarchy.notebookName,
        'attachment_links': matchedLinks
            .map(
              (link) => <String, String>{
                'target': link.rawTarget,
                'attachmentKey': link.attachmentKey,
              },
            )
            .toList(growable: false),
      },
    );

    return (draft: draft, links: matchedLinks);
  }

  ImportedNoteDraft? _parseCsvEntry({
    required final _RawZipEntry entry,
    required final List<String> warnings,
  }) {
    final csvText = _stripBom(utf8.decode(entry.bytes, allowMalformed: true));
    final rows = parseCsv(csvText);
    if (rows.isEmpty) {
      return null;
    }

    final rawHeader = rows.first;
    final dataRows = rows.skip(1).toList(growable: false);
    var columnCount = rawHeader.length;
    for (final row in dataRows) {
      if (row.length > columnCount) {
        columnCount = row.length;
      }
    }
    if (columnCount == 0) {
      return null;
    }

    final headerCells = <String>[
      for (var i = 0; i < columnCount; i += 1)
        _formatCsvHeaderCell(
          i < rawHeader.length ? rawHeader[i] : '',
          i,
        ),
    ];

    final baseName = _stripExtension(p.posix.basename(entry.rawPath));
    final withoutAll = baseName.endsWith('_all')
        ? baseName.substring(0, baseName.length - 4)
        : baseName;
    final cleanTitle = _cleanNotionName(withoutAll);
    final title = cleanTitle.isEmpty ? 'Notion Database' : cleanTitle;

    final hierarchy = _buildHierarchyContext(
      entry.rawPath,
      extraTags: const <String>['notion-database'],
    );

    final buffer = StringBuffer();
    buffer.writeln(
      '**データベース概要**: 行数: ${dataRows.length} 件 / 列数: $columnCount 列',
    );
    buffer.writeln('**プロパティ列**: ${headerCells.join(', ')}');
    buffer.writeln();
    buffer.writeln('| ${headerCells.map(_escapeMarkdownCell).join(' | ')} |');
    buffer.writeln(
      '| ${List<String>.filled(columnCount, ':---').join(' | ')} |',
    );

    final renderLimit = dataRows.length > maxRenderedCsvRows
        ? maxRenderedCsvRows
        : dataRows.length;
    for (var rowIdx = 0; rowIdx < renderLimit; rowIdx += 1) {
      final row = dataRows[rowIdx];
      final cells = <String>[
        for (var colIdx = 0; colIdx < columnCount; colIdx += 1)
          _escapeMarkdownCell(colIdx < row.length ? row[colIdx] : ''),
      ];
      buffer.writeln('| ${cells.join(' | ')} |');
    }

    if (dataRows.length > maxRenderedCsvRows) {
      final omitted = dataRows.length - maxRenderedCsvRows;
      buffer.writeln();
      buffer.writeln(
        '> ※ $maxRenderedCsvRows 件を超えた $omitted 件の行は表示高速化のため省略しました。',
      );
      warnings.add(
        'Notion DB "$title" (${dataRows.length} 行) の Markdown 表プレビューは先頭 $maxRenderedCsvRows 行を表示しています。',
      );
    }

    final content = buffer.toString().trim();
    final contentSha = sha256.convert(utf8.encode(content)).toString();
    final sourceId = 'notion-zip-db:'
        '${sha256.convert(utf8.encode('${entry.rawPath}\n$title\n${entry.bytes.length}'))}';

    return ImportedNoteDraft(
      title: title,
      content: content,
      source: 'notion_database',
      tags: hierarchy.tags,
      sourceId: sourceId,
      sourceContentSha256: contentSha,
      sourceMetadata: <String, dynamic>{
        'notion_database_columns': headerCells,
        'notion_database_row_count': dataRows.length,
        'notion_relative_path': hierarchy.cleanRelativePath,
        'notion_hierarchy_path': hierarchy.hierarchyPath,
        'space_name': hierarchy.spaceName,
        'notebook_name': hierarchy.notebookName,
      },
    );
  }

  bool _hasCompanionAllCsv(
    final String rawPath,
    final Set<String> allPaths,
  ) {
    final lower = rawPath.toLowerCase();
    if (!lower.endsWith('.csv') || lower.endsWith('_all.csv')) {
      return false;
    }
    final dir = p.posix.dirname(rawPath);
    final stem = _stripExtension(p.posix.basename(rawPath));
    final expectedAll = dir == '.' ? '${stem}_all.csv' : '$dir/${stem}_all.csv';
    if (allPaths.contains(expectedAll)) {
      return true;
    }
    final expectedLower = expectedAll.toLowerCase();
    for (final candidate in allPaths) {
      if (candidate.toLowerCase() == expectedLower) {
        return true;
      }
    }
    return false;
  }

  ({
    String cleanRelativePath,
    String hierarchyPath,
    String spaceName,
    String notebookName,
    List<String> tags,
  }) _buildHierarchyContext(
    final String rawPath, {
    required final List<String> extraTags,
  }) {
    final segments = rawPath.split('/').where((s) => s.isNotEmpty).toList();
    final rawDirSegments = segments.length > 1
        ? segments.sublist(0, segments.length - 1)
        : <String>[];
    final cleanDirs = rawDirSegments
        .map(_cleanNotionName)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    final rawFile = segments.isNotEmpty ? segments.last : rawPath;
    final ext = p.posix.extension(rawFile);
    final stem = _stripExtension(rawFile);
    final stemBase =
        stem.endsWith('_all') ? stem.substring(0, stem.length - 4) : stem;
    final cleanFile = _cleanNotionName(stemBase);
    final cleanFileWithExt = ext.isEmpty ? cleanFile : '$cleanFile$ext';
    final cleanRelativePath = <String>[
      ...cleanDirs,
      if (cleanFileWithExt.isNotEmpty) cleanFileWithExt,
    ].join('/');

    final hierarchyPath = cleanDirs.join(' / ');
    final spaceName = cleanDirs.isNotEmpty ? cleanDirs.first : 'Notion';
    final notebookName = cleanDirs.length >= 2
        ? cleanDirs.last
        : (cleanDirs.isNotEmpty ? cleanDirs.first : 'Notion Import');

    final tagSet = <String>{'notion', ...extraTags};
    var folderTagsAdded = 0;
    for (final folder in cleanDirs) {
      if (folderTagsAdded >= 6) {
        break;
      }
      if (tagSet.add(folder)) {
        folderTagsAdded += 1;
      }
    }

    return (
      cleanRelativePath: cleanRelativePath,
      hierarchyPath: hierarchyPath,
      spaceName: spaceName,
      notebookName: notebookName,
      tags: List<String>.unmodifiable(tagSet),
    );
  }

  String _cleanNotionName(final String value) {
    var cleaned = value.trim();
    cleaned = cleaned.replaceFirst(_notionIdSuffixPattern, '').trim();
    return cleaned;
  }

  String _stripExtension(final String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  String _stripBom(final String text) {
    if (text.startsWith('\uFEFF')) {
      return text.substring(1);
    }
    return text;
  }

  String _extractMarkdownTitle(
    final String content, {
    required final String fallback,
  }) {
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (trimmed.startsWith('# ')) {
        final heading = trimmed.substring(2).trim();
        if (heading.isNotEmpty) {
          return heading;
        }
      }
      break;
    }
    return fallback;
  }

  String _extractLinkTarget(final String rawInner) {
    final trimmed = rawInner.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.startsWith('<')) {
      final closing = trimmed.indexOf('>');
      if (closing > 1) {
        return trimmed.substring(1, closing).trim();
      }
    }
    final titleQuoteIdx = trimmed.indexOf(' "');
    if (titleQuoteIdx > 0) {
      return trimmed.substring(0, titleQuoteIdx).trim();
    }
    return trimmed;
  }

  bool _isExternalLink(final String target) {
    final lower = target.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:') ||
        lower.startsWith('#') ||
        lower.startsWith('data:') ||
        lower.startsWith('attachment:');
  }

  String? _resolveAttachmentKey({
    required final String rawTarget,
    required final String noteDir,
    required final Map<String, NotionZipAttachment> attachmentsByKey,
    required final Map<String, String> decodedPathLookup,
    required final Map<String, List<String>> basenameLookup,
  }) {
    final targetNoQuery = rawTarget.split('?').first.split('#').first.trim();
    if (targetNoQuery.isEmpty) {
      return null;
    }

    final candidates = <String>[
      targetNoQuery,
      _safeDecodeUri(targetNoQuery),
    ];

    for (final candidate in candidates) {
      final joined = noteDir.isEmpty
          ? candidate
          : p.posix.normalize(p.posix.join(noteDir, candidate));
      final normalizedJoined = _normalizeLookupKey(joined);
      if (attachmentsByKey.containsKey(normalizedJoined)) {
        return normalizedJoined;
      }
      final fromDecoded = decodedPathLookup[normalizedJoined];
      if (fromDecoded != null) {
        return fromDecoded;
      }
      final rootNormalized = _normalizeLookupKey(candidate);
      if (attachmentsByKey.containsKey(rootNormalized)) {
        return rootNormalized;
      }
      final rootDecoded = decodedPathLookup[rootNormalized];
      if (rootDecoded != null) {
        return rootDecoded;
      }
    }

    // 同一ディレクトリ配下の basename 一致、またはユニーク basename 一致をフォールバック。
    final targetBase =
        p.posix.basename(_safeDecodeUri(targetNoQuery)).toLowerCase();
    final matches = basenameLookup[targetBase];
    if (matches == null || matches.isEmpty) {
      return null;
    }
    if (noteDir.isNotEmpty) {
      final dirPrefix = '${_normalizeLookupKey(noteDir)}/';
      final sameDirMatches = matches
          .where((key) => key.startsWith(dirPrefix))
          .toList(growable: false);
      if (sameDirMatches.length == 1) {
        return sameDirMatches.single;
      }
    }
    if (matches.length == 1) {
      return matches.single;
    }
    return null;
  }

  String _normalizeLookupKey(final String path) {
    final normalized =
        p.posix.normalize(path.replaceAll('\\', '/').trim()).toLowerCase();
    if (normalized.startsWith('./')) {
      return normalized.substring(2);
    }
    return normalized;
  }

  String _safeDecodeUri(final String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  String _formatCsvHeaderCell(final String raw, final int index) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return 'Column ${index + 1}';
    }
    return trimmed;
  }

  String _escapeMarkdownCell(final String value) {
    return value
        .trim()
        .replaceAll('\r\n', '<br>')
        .replaceAll('\r', '<br>')
        .replaceAll('\n', '<br>')
        .replaceAll('|', r'\|');
  }

  List<List<String>> parseCsv(final String input) {
    final cleanInput = _stripBom(input);
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < cleanInput.length; i += 1) {
      final char = cleanInput[i];
      final next = i + 1 < cleanInput.length ? cleanInput[i + 1] : null;

      if (char == '"') {
        if (inQuotes && next == '"') {
          currentCell.write('"');
          i += 1;
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
          i += 1;
        }
        currentRow.add(currentCell.toString());
        if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
        currentCell.clear();
        continue;
      }

      currentCell.write(char);
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      if (currentRow.any((cell) => cell.trim().isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
    }

    return rows;
  }
}

class _ExtractionState {
  final List<_RawZipEntry> entries = <_RawZipEntry>[];
  int entryCount = 0;
  int totalUncompressedBytes = 0;
  int nestedZipCount = 0;
  int skippedUnsafePathCount = 0;
  bool hitEntryCapWarning = false;
  bool hitByteCapWarning = false;
}
