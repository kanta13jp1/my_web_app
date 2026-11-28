import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_wiki_link_service.dart';
import 'package:my_web_app/widgets/note_editor/note_hierarchy_bar.dart';

void main() {
  const List<NoteSummary> sampleNotes = <NoteSummary>[
    NoteSummary(id: '1', title: '戦略メモ', content: ''),
    NoteSummary(id: '2', title: '製品ロードマップ', content: '', parentNoteId: '1'),
    NoteSummary(id: '3', title: 'サブ仕様A', content: '', parentNoteId: '2'),
  ];

  testWidgets(
    'NoteHierarchyBar displays breadcrumbs and subpages on 390px viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      NoteSummary? opened;
      bool addedSubpage = false;
      bool changedParent = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: NoteHierarchyBar(
                currentNoteId: '2',
                parentNoteId: '1',
                currentTitle: '製品ロードマップ',
                allNotes: sampleNotes,
                onOpenNote: (n) => opened = n,
                onAddSubpage: () => addedSubpage = true,
                onChangeParent: () => changedParent = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(NoteHierarchyBar.barKey), findsOneWidget);
      expect(find.text('戦略メモ'), findsOneWidget);
      expect(find.text('サブ仕様A'), findsOneWidget);

      await tester.tap(find.text('戦略メモ'));
      expect(opened?.id, '1');

      await tester.tap(find.byKey(NoteHierarchyBar.addSubpageButtonKey));
      expect(addedSubpage, isTrue);

      await tester.tap(find.byKey(NoteHierarchyBar.changeParentButtonKey));
      expect(changedParent, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showParentNotePickerSheet excludes self and descendants',
    (tester) async {
      const notes = <NoteSummary>[
        NoteSummary(id: '1', title: '親候補', content: ''),
        NoteSummary(id: '2', title: '編集中', content: '', parentNoteId: '1'),
        NoteSummary(id: '3', title: '子ノート', content: '', parentNoteId: '2'),
        NoteSummary(id: '4', title: '別ルート', content: ''),
      ];
      String? picked;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  picked = await showParentNotePickerSheet(
                    context,
                    currentNoteId: '2',
                    currentParentId: '1',
                    allNotes: notes,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('note_editor_parent_picker_sheet')),
        findsOneWidget,
      );
      expect(find.text('子ノート'), findsNothing);
      expect(find.text('別ルート'), findsOneWidget);

      await tester.tap(find.text('別ルート'));
      await tester.pumpAndSettle();
      expect(picked, '4');
    },
  );
}
