import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/note_navigation_page.dart';
import 'package:my_web_app/services/note_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders owner navigation state on a narrow layout',
      (tester) async {
    await _setSurface(tester, const Size(430, 900));
    final repository = _FakeNoteNavigationRepository.seeded(
      migrationState: const EvernoteNavigationMigrationState(
        status: 'verified',
        savedSearchCount: 1,
        verifiedSavedSearchCount: 1,
        shortcutCount: 1,
        verifiedShortcutCount: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteNavigationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note_navigation_page')), findsOneWidget);
    expect(
      find.byKey(const Key('note_navigation_collections')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('navigation_migration_card')), findsOneWidget);
    expect(find.text('Evernoteアカウント棚卸し: verified'), findsOneWidget);
    expect(find.byKey(const Key('shortcut_shortcut-1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('saved_search_section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('saved_search_search-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a native saved search from the management dialog',
      (tester) async {
    await _setSurface(tester, const Size(1100, 800));
    final repository = _FakeNoteNavigationRepository.empty();

    await tester.pumpWidget(
      MaterialApp(
        home: NoteNavigationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_saved_search_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('saved_search_name_field')),
      '今週の計画',
    );
    await tester.enterText(
      find.byKey(const Key('saved_search_query_field')),
      'tag:project updated:week',
    );
    await tester.tap(find.byKey(const Key('save_saved_search_button')));
    await tester.pumpAndSettle();

    expect(repository.createdSavedSearches, hasLength(1));
    expect(repository.createdSavedSearches.single.$1, '今週の計画');
    expect(
      repository.createdSavedSearches.single.$2,
      'tag:project updated:week',
    );
    expect(find.text('今週の計画'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('records and verifies an explicit zero-item inventory',
      (tester) async {
    await _setSurface(tester, const Size(1100, 800));
    final repository = _FakeNoteNavigationRepository.empty();

    await tester.pumpWidget(
      MaterialApp(
        home: NoteNavigationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('open_navigation_inventory_button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('navigation_inventory_json_field')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('import_navigation_inventory_button')),
    );
    await tester.pumpAndSettle();

    expect(repository.importedManifest, contains('"saved_searches": []'));
    expect(find.text('Evernoteアカウント棚卸し: imported'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('open_navigation_verify_button')),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 5; index++) {
      await tester.tap(
        find.byKey(Key('navigation_verify_check_$index')),
      );
      await tester.pump();
    }
    await tester.tap(
      find.byKey(const Key('verify_navigation_inventory_button')),
    );
    await tester.pumpAndSettle();

    expect(repository.verifyCalls, 1);
    expect(find.text('Evernoteアカウント棚卸し: verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout keeps both management sections visible',
      (tester) async {
    await _setSurface(tester, const Size(1400, 900));
    final repository = _FakeNoteNavigationRepository.seeded();

    await tester.pumpWidget(
      MaterialApp(
        home: NoteNavigationPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shortcut_section')), findsOneWidget);
    expect(find.byKey(const Key('saved_search_section')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _FakeNoteNavigationRepository implements NoteNavigationRepository {
  _FakeNoteNavigationRepository({
    required List<NoteSavedSearch> savedSearches,
    required List<NoteShortcut> shortcuts,
    this.migrationState,
  })  : savedSearches = List<NoteSavedSearch>.from(savedSearches),
        shortcuts = List<NoteShortcut>.from(shortcuts);

  factory _FakeNoteNavigationRepository.empty() {
    return _FakeNoteNavigationRepository(
      savedSearches: const [],
      shortcuts: const [],
    );
  }

  factory _FakeNoteNavigationRepository.seeded({
    EvernoteNavigationMigrationState? migrationState,
  }) {
    return _FakeNoteNavigationRepository(
      savedSearches: const [
        NoteSavedSearch(
          id: 'search-1',
          name: 'Project notes',
          query: 'tag:project',
          sourceSystem: 'evernote',
          sourceKey: 'saved:project',
        ),
      ],
      shortcuts: const [
        NoteShortcut(
          id: 'shortcut-1',
          position: 1,
          targetType: NoteShortcutTargetType.savedSearch,
          label: 'Project notes',
          sourceSystem: 'evernote',
          targetSavedSearchId: 'search-1',
          sourceKey: 'shortcut:project',
        ),
      ],
      migrationState: migrationState,
    );
  }

  final List<NoteSavedSearch> savedSearches;
  final List<NoteShortcut> shortcuts;
  EvernoteNavigationMigrationState? migrationState;
  final List<(String, String)> createdSavedSearches = [];
  String? importedManifest;
  int verifyCalls = 0;

  @override
  Future<NoteNavigationSnapshot> load() async {
    return NoteNavigationSnapshot(
      savedSearches: List.unmodifiable(savedSearches),
      shortcuts: List.unmodifiable(shortcuts),
      migrationState: migrationState,
    );
  }

  @override
  Future<void> createSavedSearch({
    required String name,
    required String query,
  }) async {
    createdSavedSearches.add((name, query));
    savedSearches.add(
      NoteSavedSearch(
        id: 'search-${savedSearches.length + 1}',
        name: name,
        query: query,
        sourceSystem: 'native',
      ),
    );
  }

  @override
  Future<void> updateSavedSearch({
    required NoteSavedSearch savedSearch,
    required String name,
    required String query,
  }) async {
    final index = savedSearches.indexWhere((item) => item.id == savedSearch.id);
    savedSearches[index] = NoteSavedSearch(
      id: savedSearch.id,
      name: name,
      query: query,
      sourceSystem: savedSearch.sourceSystem,
      sourceKey: savedSearch.sourceKey,
      verifiedAt: savedSearch.verifiedAt,
    );
  }

  @override
  Future<void> deleteSavedSearch(NoteSavedSearch savedSearch) async {
    savedSearches.removeWhere((item) => item.id == savedSearch.id);
  }

  @override
  Future<void> createShortcut(NoteShortcutDraft draft) async {
    shortcuts.add(
      NoteShortcut(
        id: 'shortcut-${shortcuts.length + 1}',
        position: shortcuts.length + 1,
        targetType: draft.targetType,
        label: draft.label,
        sourceSystem: 'native',
        targetNoteId: draft.targetNoteId,
        targetCollectionId: draft.targetCollectionId,
        targetTag: draft.targetTag,
        targetSavedSearchId: draft.targetSavedSearchId,
      ),
    );
  }

  @override
  Future<void> moveShortcut({
    required NoteShortcut shortcut,
    required int position,
  }) async {
    final ordered = List<NoteShortcut>.from(shortcuts)
      ..sort((a, b) => a.position.compareTo(b.position));
    final currentIndex = ordered.indexWhere((item) => item.id == shortcut.id);
    final item = ordered.removeAt(currentIndex);
    ordered.insert(position - 1, item);
    shortcuts
      ..clear()
      ..addAll(
        [
          for (var index = 0; index < ordered.length; index++)
            NoteShortcut(
              id: ordered[index].id,
              position: index + 1,
              targetType: ordered[index].targetType,
              label: ordered[index].label,
              sourceSystem: ordered[index].sourceSystem,
              targetNoteId: ordered[index].targetNoteId,
              targetCollectionId: ordered[index].targetCollectionId,
              targetTag: ordered[index].targetTag,
              targetSavedSearchId: ordered[index].targetSavedSearchId,
              sourceTargetKey: ordered[index].sourceTargetKey,
              sourceKey: ordered[index].sourceKey,
              verifiedAt: ordered[index].verifiedAt,
            ),
        ],
      );
  }

  @override
  Future<void> deleteShortcut(NoteShortcut shortcut) async {
    shortcuts.removeWhere((item) => item.id == shortcut.id);
  }

  @override
  Future<EvernoteNavigationMigrationState> importEvernoteInventory(
    String manifestJson,
  ) async {
    importedManifest = manifestJson;
    migrationState = const EvernoteNavigationMigrationState(
      status: 'imported',
      savedSearchCount: 0,
      verifiedSavedSearchCount: 0,
      shortcutCount: 0,
      verifiedShortcutCount: 0,
    );
    return migrationState!;
  }

  @override
  Future<EvernoteNavigationMigrationState> verifyEvernoteInventory() async {
    verifyCalls++;
    final current = migrationState;
    migrationState = EvernoteNavigationMigrationState(
      status: 'verified',
      savedSearchCount: current?.savedSearchCount ?? 0,
      verifiedSavedSearchCount: current?.savedSearchCount ?? 0,
      shortcutCount: current?.shortcutCount ?? 0,
      verifiedShortcutCount: current?.shortcutCount ?? 0,
    );
    return migrationState!;
  }
}
