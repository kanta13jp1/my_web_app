import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_tags_page.dart';
import 'package:my_web_app/services/note_tag_hierarchy_service.dart';

void main() {
  testWidgets('shows nested tags and protects imported hierarchy', (
    tester,
  ) async {
    final source = _FakeTags();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: NoteTagsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_tags_page')), findsOneWidget);
    expect(find.text('タグ移行'), findsOneWidget);
    expect(find.text('Evernote原本: 1'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('このタグのみ'), findsNWidgets(2));
    expect(find.text('子タグも含む'), findsNWidgets(2));

    final importedCard = find.byKey(const ValueKey<String>('note_tag_1'));
    final importedRename = find.descendant(
      of: importedCard,
      matching: find.widgetWithText(TextButton, '名前'),
    );
    expect(tester.widget<TextButton>(importedRename).onPressed, isNull);

    final nativeCard = find.byKey(const ValueKey<String>('note_tag_2'));
    final nativeRename = find.descendant(
      of: nativeCard,
      matching: find.widgetWithText(TextButton, '名前'),
    );
    expect(tester.widget<TextButton>(nativeRename).onPressed, isNotNull);
  });

  testWidgets('creates a root tag through the data source', (tester) async {
    final source = _FakeTags();
    await tester.pumpWidget(
      MaterialApp(home: NoteTagsPage(dataSource: source)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note_tags_add_root')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note_tag_name_field')),
      'Ideas',
    );
    await tester.tap(find.byKey(const Key('note_tag_name_save')));
    await tester.pumpAndSettle();

    expect(source.created, <String>['Ideas']);
  });
}

class _FakeTags implements NoteTagHierarchyDataSource {
  final List<String> created = <String>[];

  @override
  Future<NoteTagHierarchySnapshot> load() async {
    return const NoteTagHierarchySnapshot(
      tags: <NoteTagRecord>[
        NoteTagRecord(
          id: 1,
          name: 'Work',
          sourceSystem: 'evernote',
          noteCount: 2,
        ),
        NoteTagRecord(
          id: 2,
          parentId: 1,
          name: 'Project',
          sourceSystem: 'native',
          noteCount: 1,
        ),
      ],
      noteIdsByTagId: <int, Set<int>>{
        1: <int>{10, 20},
        2: <int>{20},
      },
      evernoteSourceDeleted: false,
    );
  }

  @override
  Future<void> createTag({required String name, int? parentId}) async {
    created.add(name);
  }

  @override
  Future<void> deleteTag(int id) async {}

  @override
  Future<void> moveTag({required int id, int? parentId}) async {}

  @override
  Future<void> renameTag({required int id, required String name}) async {}
}
