import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_wiki_link_service.dart';
import 'package:my_web_app/widgets/note_hierarchy_tree_view.dart';

void main() {
  testWidgets(
    'NoteHierarchyTreeView expands, navigates, and keeps 390px overflow-free',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<NoteSummary> notes = List<NoteSummary>.generate(
        9,
        (int i) => NoteSummary(
          id: '${i + 1}',
          title: '階層ノード ${i + 1}',
          content: '',
          parentNoteId: i == 0 ? null : '$i',
        ),
      );

      final Set<String> expanded = <String>{'1', '2', '3', '4', '5', '6', '7'};
      NoteSummary? opened;
      NoteSummary? addParent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NoteHierarchyTreeView(
                  notes: notes,
                  expandedIds: expanded,
                  onToggleExpand: (id) {
                    setState(() {
                      if (!expanded.remove(id)) {
                        expanded.add(id);
                      }
                    });
                  },
                  onOpenNote: (note) => opened = note,
                  onAddSubpage: (note) => addParent = note,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(NoteHierarchyTreeView.treeKey), findsOneWidget);
      expect(find.text('L7'), findsOneWidget);
      expect(find.text('L8'), findsOneWidget);
      expect(find.text('階層ノード 9'), findsNothing);

      await tester.tap(find.byKey(const Key('note_tree_toggle_8')));
      await tester.pumpAndSettle();
      expect(find.text('階層ノード 9'), findsOneWidget);

      await tester.tap(find.byKey(const Key('note_tree_add_subpage_1')));
      expect(addParent?.id, '1');

      await tester.tap(find.text('階層ノード 1'));
      expect(opened?.id, '1');
      expect(tester.takeException(), isNull);
    },
  );
}
