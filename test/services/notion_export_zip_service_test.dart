import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:my_web_app/services/notion_export_zip_service.dart';

Uint8List _buildZip({
  final Map<String, String> textFiles = const <String, String>{},
  final Map<String, List<int>> binaryFiles = const <String, List<int>>{},
}) {
  final archive = Archive();
  textFiles.forEach((final name, final content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  binaryFiles.forEach((final name, final bytes) {
    archive.addFile(ArchiveFile.bytes(name, bytes));
  });
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  const service = NotionExportZipService();

  group('NotionExportZipService', () {
    test(
      'extracts nested ZIPs, strips Notion 32-hex IDs, deduplicates _all CSV, '
      'skips unsafe paths, and resolves attachments',
      () {
        const innerWrapper =
            'ExportBlock-11112222-3333-4444-5555-666677778888-Part-1';
        const folderId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1';
        const pageId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2';
        const dbId = 'ccccccccccccccccccccccccccccccc3';

        final innerZip = _buildZip(
          textFiles: <String, String>{
            '$innerWrapper/Personal $folderId/Architecture $pageId.md':
                '# Architecture Spec\n\nSee ![diagram](diagram%20v1.png).\n',
            '$innerWrapper/Personal $folderId/Tasks $dbId.csv':
                'Name,Status\nFiltered Row,Todo\n',
            '$innerWrapper/Personal $folderId/Tasks ${dbId}_all.csv':
                'Name,Status,Notes\nLaunch Feature,Done,"Line 1\nLine | 2"\n',
            '$innerWrapper/__MACOSX/._ghost.md': 'ignored',
            '$innerWrapper/.DS_Store': 'ignored',
            '../../escape.md': 'blocked',
          },
          binaryFiles: <String, List<int>>{
            '$innerWrapper/Personal $folderId/diagram v1.png': const <int>[
              137,
              80,
              78,
              71,
            ],
          },
        );

        final outerZip = _buildZip(
          binaryFiles: <String, List<int>>{
            'Export-99998888-7777-6666-5555-444433332222/ExportPart-1.zip':
                innerZip,
          },
        );

        final bundle = service.parseZipBytes(
          fileName: 'notion-export.zip',
          bytes: outerZip,
        );

        expect(bundle.nestedZipCount, 1);
        expect(bundle.pageCount, 1);
        expect(bundle.databaseCount, 1);
        expect(bundle.skippedDuplicateCsvCount, 1);
        expect(bundle.attachmentCount, 1);
        expect(bundle.totalAttachmentBytes, 4);
        expect(bundle.folderPaths, <String>{'Personal'});
        expect(bundle.warnings, contains(contains('安全でないパス (1 件)')));
        expect(bundle.warnings, contains(contains('_all.csv')));

        final pageDraft =
            bundle.notes.firstWhere((final n) => n.source == 'notion_page');
        expect(pageDraft.title, 'Architecture Spec');
        expect(pageDraft.sourceId, startsWith('notion-zip:'));
        expect(pageDraft.sourceResourceCount, 1);
        expect(pageDraft.tags, containsAll(<String>['notion', 'Personal']));
        expect(pageDraft.sourceMetadata['space_name'], 'Personal');
        expect(pageDraft.sourceMetadata['notebook_name'], 'Personal');
        expect(
          pageDraft.sourceMetadata['notion_relative_path'],
          'Personal/Architecture.md',
        );

        final pageAttachments = bundle.attachmentsForNotes(
          <ImportedNoteDraft>[pageDraft],
        );
        expect(pageAttachments, hasLength(1));
        expect(pageAttachments.single.fileName, 'diagram v1.png');
        expect(pageAttachments.single.mimeType, 'image/png');
        expect(pageAttachments.single.contentSha256, hasLength(64));

        final dbDraft = bundle.notes.firstWhere(
          (final n) => n.source == 'notion_database',
        );
        expect(dbDraft.title, 'Tasks');
        expect(dbDraft.sourceId, startsWith('notion-zip-db:'));
        expect(
          dbDraft.tags,
          containsAll(<String>['notion', 'notion-database', 'Personal']),
        );
        expect(dbDraft.content, contains('**データベース概要**: 行数: 1 件 / 列数: 3 列'));
        expect(dbDraft.content, contains('| Launch Feature | Done |'));
        expect(dbDraft.content, contains(r'Line 1<br>Line \| 2'));
        expect(
          dbDraft.content.contains('Filtered Row'),
          isFalse,
        );

        // 同一入力からは決定論的な sourceId が生成されること
        final bundleSecondRun = service.parseZipBytes(
          fileName: 'notion-export.zip',
          bytes: outerZip,
        );
        expect(
          bundleSecondRun.notes.first.sourceId,
          bundle.notes.first.sourceId,
        );
      },
    );

    test(
      'MigrationDiagnosticReport formats exact savings without leaking secrets',
      () {
        const folderId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa1';
        const pageId = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb2';
        final zipBytes = _buildZip(
          textFiles: <String, String>{
            'Finance $folderId/TopSecretSalaryNote $pageId.md':
                '# Confidential Income 99999999\n\nSecret bank memo payload.',
          },
          binaryFiles: <String, List<int>>{
            'Finance $folderId/secret-receipt-file.pdf': List<int>.filled(
              2048,
              7,
            ),
          },
        );

        final bundle = service.parseZipBytes(
          fileName: 'private-workspace.zip',
          bytes: zipBytes,
        );
        final notionReport = MigrationDiagnosticReport.fromNotionZipBundle(
          bundle,
        );

        expect(notionReport.sourceDisplayName, 'Notion');
        expect(notionReport.noteCount, 1);
        expect(notionReport.attachmentCount, 1);
        expect(notionReport.fitsFreeStorageQuota, isTrue);
        expect(notionReport.estimatedAnnualSavingsLabel, '約 21,600〜43,200 円/年');

        final shareText = notionReport.buildShareableSummaryText();
        expect(shareText, contains('約 21,600〜43,200 円/年'));
        expect(shareText, contains('ノート 1 件'));
        expect(shareText, isNot(contains('TopSecretSalaryNote')));
        expect(shareText, isNot(contains('Confidential Income')));
        expect(shareText, isNot(contains('Secret bank memo')));
        expect(shareText, isNot(contains('private-workspace.zip')));

        const evernotePreview = ImportPreviewResult(
          sourceType: 'evernote',
          sourceLabel: 'Evernote',
          fileName: 'my-evernote.enex',
          notes: <ImportedNoteDraft>[
            ImportedNoteDraft(
              title: 'Secret ENEX Note',
              content: 'Private Body',
              source: 'evernote',
            ),
          ],
          resourceCount: 3,
        );
        final evernoteReport = MigrationDiagnosticReport.fromImportPreview(
          preview: evernotePreview,
          archiveSizeBytes: 5 * 1024 * 1024,
        );
        expect(evernoteReport.sourceDisplayName, 'Evernote');
        expect(
          evernoteReport.estimatedAnnualSavingsLabel,
          '約 9,300〜17,900 円/年',
        );
        final enexShare = evernoteReport.buildShareableSummaryText();
        expect(enexShare, contains('約 9,300〜17,900 円/年'));
        expect(enexShare, isNot(contains('Secret ENEX Note')));
        expect(enexShare, isNot(contains('my-evernote.enex')));
      },
    );

    test(
      'rejects zip bomb header declaring oversized uncompressedSize before decode',
      () {
        final rawZip = _buildZip(
          textFiles: <String, String>{
            'note.md': '# Safe Payload\n\nTiny compressed content',
          },
        );
        final patched = Uint8List.fromList(rawZip);
        final view = ByteData.sublistView(patched);
        var eocdOffset = -1;
        for (var i = patched.length - 22; i >= 0; i -= 1) {
          if (view.getUint32(i, Endian.little) == 0x06054b50) {
            eocdOffset = i;
            break;
          }
        }
        expect(eocdOffset, greaterThanOrEqualTo(0));
        final cdOffset = view.getUint32(eocdOffset + 16, Endian.little);
        expect(view.getUint32(cdOffset, Endian.little), 0x02014b50);

        // 展開前に 600 MiB を主張する Zip Bomb ヘッダーへ書き換える
        view.setUint32(cdOffset + 24, 600 * 1024 * 1024, Endian.little);

        final bundle = service.parseZipBytes(
          fileName: 'zip-bomb.zip',
          bytes: patched,
        );
        expect(bundle.notes, isEmpty);
        expect(bundle.attachments, isEmpty);
        expect(bundle.warnings, contains(contains('Zip Bomb')));
      },
    );
  });
}
