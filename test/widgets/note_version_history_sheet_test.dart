import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_version_history_service.dart';
import 'package:my_web_app/widgets/note_version_history_sheet.dart';

NoteVersionSummary version(
  int index, {
  bool evernote = false,
  bool verified = false,
}) =>
    NoteVersionSummary(
      cursor: NoteVersionCursor(
        id: '22222222-2222-4222-8222-${index.toString().padLeft(12, '0')}',
        savedAt: '2026-09-12T00:00:00Z',
      ),
      title: 'History $index',
      sourceSystem: evernote ? 'evernote' : 'native',
      sourceVerified: verified,
    );

class _Repository implements NoteVersionHistoryRepository {
  List<NoteVersionSummary> items = [];
  NoteVersionDetail? detail;
  int pageCalls = 0;
  int detailCalls = 0;
  bool failPage = false;
  bool failDetail = false;
  Completer<NoteVersionPage>? pageGate;

  @override
  Future<NoteVersionPage> loadPage(
    String noteId, {
    NoteVersionCursor? before,
  }) async {
    pageCalls++;
    if (pageGate != null) return pageGate!.future;
    if (failPage) throw StateError('private source must not be shown');
    final offset =
        before == null ? 0 : items.indexWhere((v) => v.id == before.id) + 1;
    return NoteVersionPage(
      items: items.skip(offset).take(30),
      hasMore: offset + 30 < items.length,
    );
  }

  @override
  Future<NoteVersionDetail> loadDetail(String noteId, String versionId) async {
    detailCalls++;
    if (failDetail) throw StateError('private source must not be shown');
    return detail ??
        NoteVersionDetail(
          summary: items.firstWhere((v) => v.id == versionId),
          content: 'Selected historical body',
        );
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  _Repository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<NoteVersionDetail>(
              context: context,
              isScrollControlled: true,
              builder: (_) => NoteVersionHistorySheet(
                repository: repository,
                noteId: '42',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('31st version is reachable without loading every body',
      (tester) async {
    final repository = _Repository()..items = List.generate(31, version);
    await _openSheet(tester, repository);
    final scrollable = find.descendant(
      of: find.byType(NoteVersionHistorySheet),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('さらに古い履歴を読み込む'),
      500,
      scrollable: scrollable,
    );
    await tester.tap(find.text('さらに古い履歴を読み込む'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('History 30'),
      300,
      scrollable: scrollable,
    );
    expect(repository.detailCalls, 0);
    await tester.tap(find.text('History 30'));
    await tester.pumpAndSettle();
    expect(find.text('Selected historical body'), findsOneWidget);
    expect(repository.detailCalls, 1);
  });

  testWidgets('empty and retry states stay distinct', (tester) async {
    final repository = _Repository()..failPage = true;
    await _openSheet(tester, repository);
    expect(find.text('保存済みバージョンがありません'), findsNothing);
    expect(find.textContaining('private source'), findsNothing);
    repository.failPage = false;
    await tester.tap(find.text('履歴の読み込みを再試行'));
    await tester.pumpAndSettle();
    expect(find.text('保存済みバージョンがありません'), findsOneWidget);
  });

  testWidgets('failed preview retries without restoring or hiding the error',
      (tester) async {
    final repository = _Repository()
      ..items = [version(1)]
      ..failDetail = true;
    await _openSheet(tester, repository);
    await tester.tap(find.text('History 1'));
    await tester.pumpAndSettle();
    expect(find.text('このタイトル・本文を復元'), findsNothing);
    repository.failDetail = false;
    await tester.tap(find.text('本文・添付情報の読み込みを再試行'));
    await tester.pumpAndSettle();
    expect(find.text('Selected historical body'), findsOneWidget);
    expect(find.text('このタイトル・本文を復元'), findsOneWidget);
  });

  for (final verified in [false, true]) {
    testWidgets('Evernote preview is read-only, verified=$verified',
        (tester) async {
      final item = version(1, evernote: true, verified: verified);
      final repository = _Repository()
        ..items = [item]
        ..detail = NoteVersionDetail(
          summary: item,
          content: '![tracking](https://example.invalid/private.png)',
          tags: ['retained-tag'],
          attachments: [
            const NoteVersionAttachment(
              fileName: 'original.pdf',
              mimeType: 'application/pdf',
              fileSize: 123,
            ),
          ],
        );
      await _openSheet(tester, repository);
      await tester.tap(find.text('History 1'));
      await tester.pumpAndSettle();
      expect(find.text('retained-tag'), findsOneWidget);
      expect(find.text('履歴に保存された添付：1件'), findsOneWidget);
      expect(find.text('original.pdf'), findsOneWidget);
      expect(find.text('このタイトル・本文を復元'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(
        find.text(verified ? 'Evernote履歴：検証済み' : 'Evernote履歴：未検証'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('履歴一覧に戻る'));
      await tester.pumpAndSettle();
      expect(find.text('履歴に保存された添付：1件'), findsNothing);
    });
  }

  for (final width in [320.0, 1280.0]) {
    testWidgets('preview remains scrollable at width $width and large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = version(1, evernote: true);
      final repository = _Repository()
        ..items = [item]
        ..detail = NoteVersionDetail(
          summary: item,
          content: List.filled(50, 'Long historical body').join('\n'),
        );
      await _openSheet(tester, repository, textScale: 2);
      await tester.tap(find.text('History 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(SelectableText), findsNWidgets(2));
    });
  }
}
