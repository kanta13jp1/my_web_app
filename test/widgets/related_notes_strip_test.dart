import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_semantic_search_service.dart';
import 'package:my_web_app/widgets/related_notes_strip.dart';

void main() {
  testWidgets('renders related notes and opens the selected note', (
    WidgetTester tester,
  ) async {
    NoteSearchResult? selected;
    const notes = <NoteSearchResult>[
      NoteSearchResult(
        id: '2',
        title: 'Launch checklist',
        content: 'Confirm the release owner.',
        score: 0.92,
        matchReason: 'hybrid',
      ),
      NoteSearchResult(
        id: '3',
        title: 'Release retrospective',
        content: 'Follow up on monitoring.',
        score: 0.81,
        matchReason: 'vector',
      ),
      NoteSearchResult(
        id: '4',
        title: 'QA notes',
        content: 'Verify the public flow.',
        score: 0.75,
        matchReason: 'text',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelatedNotesStrip(
            notes: notes,
            isLoading: false,
            onNoteTap: (note) => selected = note,
          ),
        ),
      ),
    );

    expect(find.text('関連するメモ'), findsOneWidget);
    expect(find.text('Launch checklist'), findsOneWidget);
    expect(find.byKey(const Key('related_notes_list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('related_note_2')));
    expect(selected?.id, '2');
  });

  testWidgets('offers retry after loading fails', (WidgetTester tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelatedNotesStrip(
            notes: const <NoteSearchResult>[],
            isLoading: false,
            hasError: true,
            onRetry: () => retried = true,
            onNoteTap: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('related_notes_retry')));
    expect(retried, isTrue);
  });

  testWidgets('uses a compact row when editor height is constrained', (
    WidgetTester tester,
  ) async {
    const note = NoteSearchResult(
      id: 'compact',
      title: 'Compact related note',
      content: 'This content stays available from the compact row.',
      score: 0.88,
      matchReason: 'hybrid',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelatedNotesStrip(
            notes: const <NoteSearchResult>[note],
            isLoading: false,
            compact: true,
            onNoteTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('related_notes_strip'))).height,
      76,
    );
    expect(find.text('Compact related note'), findsOneWidget);
  });
}
