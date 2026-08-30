import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_collections_page.dart';
import 'package:my_web_app/services/note_collection_service.dart';

void main() {
  testWidgets('shows responsive hierarchy and locks imported evidence', (
    tester,
  ) async {
    final source = _FakeCollections();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: NoteCollectionsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_collections_page')), findsOneWidget);
    expect(find.text('コレクション移行'), findsOneWidget);
    expect(find.text('Space: 1'), findsOneWidget);
    expect(find.text('スタック: 1'), findsOneWidget);
    expect(find.text('ノートブック: 2'), findsOneWidget);
    expect(find.text('Evernote原本: 1'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('既定'), findsOneWidget);

    final importedCard =
        find.byKey(const ValueKey<String>('note_collection_1'));
    final importedEdit = find.descendant(
      of: importedCard,
      matching: find.widgetWithText(TextButton, '編集'),
    );
    expect(tester.widget<TextButton>(importedEdit).onPressed, isNull);

    final nativeCard =
        find.byKey(const ValueKey<String>('note_collection_4'));
    final makeDefault = find.descendant(
      of: nativeCard,
      matching: find.widgetWithText(TextButton, '既定にする'),
    );
    expect(tester.widget<TextButton>(makeDefault).onPressed, isNotNull);
  });

  testWidgets('creates a root Space through the data source', (tester) async {
    final source = _FakeCollections();
    await tester.pumpWidget(
      MaterialApp(home: NoteCollectionsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note_collections_add_root')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('note_collection_type_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Space').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_collection_name_field')),
      'Clients',
    );
    await tester.tap(find.byKey(const Key('note_collection_create_save')));
    await tester.pumpAndSettle();

    expect(source.createdTypes, <NoteCollectionType>[NoteCollectionType.space]);
    expect(source.createdNames, <String>['Clients']);
  });
}

class _FakeCollections implements NoteCollectionDataSource {
  final List<NoteCollectionType> createdTypes = <NoteCollectionType>[];
  final List<String> createdNames = <String>[];

  @override
  Future<NoteCollectionSnapshot> load() async {
    return const NoteCollectionSnapshot(
      collections: <NoteCollectionRecord>[
        NoteCollectionRecord(
          id: 1,
          type: NoteCollectionType.space,
          name: 'Imported Space',
          sourceSystem: 'evernote',
          noteCount: 2,
          sortOrder: 0,
          isDefault: false,
          isPinned: true,
        ),
        NoteCollectionRecord(
          id: 2,
          type: NoteCollectionType.stack,
          name: 'Projects',
          sourceSystem: 'native',
          noteCount: 1,
          sortOrder: 0,
          isDefault: false,
          isPinned: false,
        ),
        NoteCollectionRecord(
          id: 3,
          parentId: 2,
          type: NoteCollectionType.notebook,
          name: 'Primary',
          sourceSystem: 'native',
          noteCount: 1,
          sortOrder: 0,
          isDefault: true,
          isPinned: false,
        ),
        NoteCollectionRecord(
          id: 4,
          type: NoteCollectionType.notebook,
          name: 'Ideas',
          sourceSystem: 'native',
          noteCount: 0,
          sortOrder: 10,
          isDefault: false,
          isPinned: false,
        ),
      ],
      evernoteSourceDeleted: false,
    );
  }

  @override
  Future<void> createCollection({
    required NoteCollectionType type,
    required String name,
    int? parentId,
    String description = '',
  }) async {
    createdTypes.add(type);
    createdNames.add(name);
  }

  @override
  Future<void> deleteCollection(int id) async {}

  @override
  Future<void> moveCollection({required int id, int? parentId}) async {}

  @override
  Future<void> setDefaultNotebook(int id) async {}

  @override
  Future<void> setPinned({required int id, required bool pinned}) async {}

  @override
  Future<void> setSortOrder({
    required int id,
    required int sortOrder,
  }) async {}

  @override
  Future<void> updateCollection({
    required int id,
    required String name,
    required String description,
  }) async {}
}
