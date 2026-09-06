import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/evernote_migration_ledger_service.dart';
import 'package:my_web_app/widgets/evernote_history_review_panel.dart';

void main() {
  testWidgets('reviews and imports history at narrow width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int? reviewedCount;
    EvernoteMigrationItem? importedItem;
    final item = _item(
      historyStatus: 'importing',
      sourceHistoryVersionCount: 2,
      importedHistoryVersionCount: 1,
      verifiedHistoryVersionCount: 1,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvernoteHistoryReviewPanel(
              items: <EvernoteMigrationItem>[item],
              isLoading: false,
              onRefresh: () async {},
              onReviewInventory: (selected, count) async {
                reviewedCount = count;
              },
              onImportRevision: (selected) async {
                importedItem = selected;
              },
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('evernote-history-item-narrow-19')),
      findsOneWidget,
    );
    expect(find.text('Imported note'), findsOneWidget);
    expect(find.text('履歴: 1/2 検証済み'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('evernote-history-count-19')),
      '3',
    );
    await tester.tap(
      find.byKey(const ValueKey('evernote-history-review-19')),
    );
    await tester.pump();
    expect(reviewedCount, 3);

    await tester.tap(
      find.byKey(const ValueKey('evernote-history-import-19')),
    );
    await tester.pump();
    expect(importedItem?.id, 19);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows verified deletion gate without overflow at wide width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvernoteHistoryReviewPanel(
              items: <EvernoteMigrationItem>[
                _item(
                  historyStatus: 'verified',
                  sourceHistoryVersionCount: 2,
                  importedHistoryVersionCount: 2,
                  verifiedHistoryVersionCount: 2,
                ),
              ],
              isLoading: false,
              onRefresh: () async {},
              onReviewInventory: (_, __) async {},
              onImportRevision: (_) async {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('evernote-history-item-wide-19')),
      findsOneWidget,
    );
    expect(find.text('履歴検証済み'), findsOneWidget);
    final importButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('evernote-history-import-19')),
    );
    expect(importButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires a non-negative inventory count', (tester) async {
    var reviewCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EvernoteHistoryReviewPanel(
              items: <EvernoteMigrationItem>[_item()],
              isLoading: false,
              onRefresh: () async {},
              onReviewInventory: (_, __) async {
                reviewCalls += 1;
              },
              onImportRevision: (_) async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('evernote-history-review-19')),
    );
    await tester.pump();

    expect(find.text('0以上の履歴件数を入力してください。'), findsOneWidget);
    expect(reviewCalls, 0);
  });
}

EvernoteMigrationItem _item({
  String historyStatus = 'pending',
  int sourceHistoryVersionCount = 0,
  int importedHistoryVersionCount = 0,
  int verifiedHistoryVersionCount = 0,
}) {
  return EvernoteMigrationItem(
    id: 19,
    batchId: 7,
    sourceItemKey: 'id:note-guid-1',
    sourceNoteId: 'note-guid-1',
    targetNoteId: 7001,
    status: 'verified',
    historyStatus: historyStatus,
    sourceHistoryVersionCount: sourceHistoryVersionCount,
    importedHistoryVersionCount: importedHistoryVersionCount,
    verifiedHistoryVersionCount: verifiedHistoryVersionCount,
    noteTitle: 'Imported note',
  );
}
