import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/note.dart';
import 'package:my_web_app/services/note_hierarchy_service.dart';
import 'package:my_web_app/services/note_wiki_link_service.dart';

void main() {
  group('NoteHierarchyService', () {
    const List<NoteSummary> treeNotes = <NoteSummary>[
      NoteSummary(id: '1', title: '会社全体', content: ''),
      NoteSummary(id: '2', title: 'プロダクト', content: '', parentNoteId: '1'),
      NoteSummary(id: '3', title: '設計書', content: '', parentNoteId: '2'),
      NoteSummary(id: '4', title: '別部門', content: '', parentNoteId: '1'),
    ];

    test('buildBreadcrumbs returns root-to-current ancestor order', () {
      final crumbs = NoteHierarchyService.buildBreadcrumbs(
        noteId: '3',
        allNotes: treeNotes,
      );
      expect(crumbs.map((n) => n.id).toList(), <String>['1', '2', '3']);
    });

    test('buildBreadcrumbs terminates cleanly on cyclic data', () {
      const cyclic = <NoteSummary>[
        NoteSummary(id: 'a', title: 'A', content: '', parentNoteId: 'b'),
        NoteSummary(id: 'b', title: 'B', content: '', parentNoteId: 'a'),
      ];
      final crumbs = NoteHierarchyService.buildBreadcrumbs(
        noteId: 'a',
        allNotes: cyclic,
      );
      expect(crumbs.map((n) => n.id).toList(), <String>['b', 'a']);
    });

    test('canSetParent rejects self, descendants, and depth over maxDepth', () {
      expect(
        NoteHierarchyService.canSetParent(
          noteId: '1',
          newParentNoteId: '1',
          allNotes: treeNotes,
        ),
        isFalse,
      );
      expect(
        NoteHierarchyService.canSetParent(
          noteId: '1',
          newParentNoteId: '3',
          allNotes: treeNotes,
        ),
        isFalse,
      );
      expect(
        NoteHierarchyService.canSetParent(
          noteId: '3',
          newParentNoteId: '4',
          allNotes: treeNotes,
        ),
        isTrue,
      );
      expect(
        NoteHierarchyService.canSetParent(
          noteId: '3',
          newParentNoteId: null,
          allNotes: treeNotes,
        ),
        isTrue,
      );

      final List<NoteSummary> deepChain = List<NoteSummary>.generate(
        NoteHierarchyService.maxDepth + 1,
        (int idx) => NoteSummary(
          id: 'n$idx',
          title: 'Depth $idx',
          content: '',
          parentNoteId: idx == 0 ? null : 'n${idx - 1}',
        ),
      )..add(const NoteSummary(id: 'extra', title: 'Extra', content: ''));

      expect(
        NoteHierarchyService.canSetParent(
          noteId: 'extra',
          newParentNoteId: 'n${NoteHierarchyService.maxDepth}',
          allNotes: deepChain,
        ),
        isFalse,
      );
    });

    test('flattenTree promotes orphans and respects expandedIds', () {
      const notes = <NoteSummary>[
        NoteSummary(id: '1', title: 'Root', content: ''),
        NoteSummary(id: '2', title: 'Child', content: '', parentNoteId: '1'),
        NoteSummary(
          id: '3',
          title: 'Orphan',
          content: '',
          parentNoteId: 'missing-parent',
        ),
      ];

      final collapsed = NoteHierarchyService.flattenTree(
        allNotes: notes,
        expandedIds: const <String>{},
      );
      expect(collapsed.map((n) => n.note.id).toList(), <String>['1', '3']);
      expect(collapsed.first.childCount, 1);

      final expanded = NoteHierarchyService.flattenTree(
        allNotes: notes,
        expandedIds: const <String>{'1'},
      );
      expect(
        expanded.map((n) => '${n.note.id}:${n.depth}').toList(),
        <String>['1:0', '2:1', '3:0'],
      );

      const cyclic = <NoteSummary>[
        NoteSummary(id: 'a', title: 'Cycle A', content: '', parentNoteId: 'b'),
        NoteSummary(id: 'b', title: 'Cycle B', content: '', parentNoteId: 'a'),
      ];
      final cyclicCollapsed = NoteHierarchyService.flattenTree(
        allNotes: cyclic,
        expandedIds: const <String>{},
      );
      expect(cyclicCollapsed.map((n) => n.note.id).toList(), <String>['a']);
    });

    test(
        'Note.fromJson/toJson round-trips int, String, and null parent_note_id',
        () {
      final Map<String, dynamic> baseJson = <String, dynamic>{
        'id': 10,
        'user_id': 'user-1',
        'title': '子ノート',
        'content': '本文',
        'created_at': '2026-11-27T00:00:00.000Z',
        'updated_at': '2026-11-27T00:00:00.000Z',
      };

      final Note fromInt = Note.fromJson(<String, dynamic>{
        ...baseJson,
        'parent_note_id': 42,
      });
      expect(fromInt.parentNoteId, 42);
      expect(fromInt.toJson()['parent_note_id'], 42);

      final Note fromString = Note.fromJson(<String, dynamic>{
        ...baseJson,
        'parent_note_id': '42',
      });
      expect(fromString.parentNoteId, 42);
      expect(fromString.toJson()['parent_note_id'], 42);

      final Note cleared = Note.fromJson(<String, dynamic>{
        ...baseJson,
        'parent_note_id': null,
      });
      expect(cleared.parentNoteId, isNull);
      final Map<String, dynamic> clearedJson = cleared.toJson();
      expect(clearedJson.containsKey('parent_note_id'), isTrue);
      expect(clearedJson['parent_note_id'], isNull);
    });
  });
}
