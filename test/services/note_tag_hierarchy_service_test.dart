import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_tag_hierarchy_service.dart';

void main() {
  group('NoteTagHierarchySnapshot', () {
    const snapshot = NoteTagHierarchySnapshot(
      tags: <NoteTagRecord>[
        NoteTagRecord(
          id: 1,
          name: 'Work',
          sourceSystem: 'evernote',
          noteCount: 1,
        ),
        NoteTagRecord(
          id: 2,
          parentId: 1,
          name: 'Project',
          sourceSystem: 'evernote',
          noteCount: 1,
        ),
        NoteTagRecord(
          id: 3,
          parentId: 2,
          name: 'Release',
          sourceSystem: 'native',
          noteCount: 1,
        ),
      ],
      noteIdsByTagId: <int, Set<int>>{
        1: <int>{10},
        2: <int>{20},
        3: <int>{30},
      },
      evernoteSourceDeleted: false,
    );

    test('resolves every descendant without duplicating the root', () {
      expect(snapshot.descendantIds(1), <int>{1, 2, 3});
      expect(snapshot.descendantIds(1, includeRoot: false), <int>{2, 3});
    });

    test('can include or exclude child-tag note assignments', () {
      expect(
        snapshot.noteIdsForTag(1, includeDescendants: false),
        <int>{10},
      );
      expect(
        snapshot.noteIdsForTag(1, includeDescendants: true),
        <int>{10, 20, 30},
      );
    });

    test('locks imported hierarchy until source deletion is recorded', () {
      expect(snapshot.isLocked(snapshot.tags.first), isTrue);
      expect(snapshot.isLocked(snapshot.tags.last), isFalse);

      final released = NoteTagHierarchySnapshot(
        tags: snapshot.tags,
        noteIdsByTagId: snapshot.noteIdsByTagId,
        evernoteSourceDeleted: true,
      );
      expect(released.isLocked(released.tags.first), isFalse);
    });
  });
}
