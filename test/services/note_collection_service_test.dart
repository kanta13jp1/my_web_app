import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/note_collection_service.dart';

void main() {
  test('sorts pinned collections and resolves notebook parent choices', () {
    const space = NoteCollectionRecord(
      id: 1,
      type: NoteCollectionType.space,
      name: 'Work',
      sourceSystem: 'evernote',
      noteCount: 2,
      sortOrder: 20,
      isDefault: false,
      isPinned: false,
    );
    const stack = NoteCollectionRecord(
      id: 2,
      type: NoteCollectionType.stack,
      name: 'Projects',
      sourceSystem: 'native',
      noteCount: 1,
      sortOrder: 30,
      isDefault: false,
      isPinned: true,
    );
    const notebook = NoteCollectionRecord(
      id: 3,
      parentId: 2,
      type: NoteCollectionType.notebook,
      name: 'Launch',
      sourceSystem: 'native',
      noteCount: 1,
      sortOrder: 10,
      isDefault: true,
      isPinned: false,
    );
    const snapshot = NoteCollectionSnapshot(
      collections: <NoteCollectionRecord>[space, stack, notebook],
      evernoteSourceDeleted: false,
    );

    expect(snapshot.collectionsByParent[null], <NoteCollectionRecord>[
      stack,
      space,
    ]);
    expect(snapshot.descendantIds(stack.id), <int>{notebook.id});
    expect(
      snapshot.validParentsFor(notebook).map((item) => item.id),
      <int>[stack.id, space.id],
    );
    expect(snapshot.isLocked(space), isTrue);
    expect(snapshot.isLocked(stack), isFalse);
  });

  test('source deletion unlocks imported collections', () {
    const imported = NoteCollectionRecord(
      id: 7,
      type: NoteCollectionType.notebook,
      name: 'Imported',
      sourceSystem: 'evernote',
      noteCount: 0,
      sortOrder: 0,
      isDefault: false,
      isPinned: false,
    );
    const snapshot = NoteCollectionSnapshot(
      collections: <NoteCollectionRecord>[imported],
      evernoteSourceDeleted: true,
    );

    expect(snapshot.isLocked(imported), isFalse);
  });
}
