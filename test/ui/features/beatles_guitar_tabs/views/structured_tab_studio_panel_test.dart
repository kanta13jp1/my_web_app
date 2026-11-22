import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_metronome_audio_service.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/data/services/structured_tab_catalog_service.dart';
import 'package:my_web_app/data/services/structured_tab_pdf_service.dart';
import 'package:my_web_app/data/services/user_structured_tab_storage_service.dart';
import 'package:my_web_app/domain/models/structured_guitar_tab.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/views/widgets/structured_tab_studio_panel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = LocalGuitarTabRepository(
    catalogService: GuitarTabCatalogService(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'renders structured chord diagrams, TAB score, and theme toggle on wide screen',
    (WidgetTester tester) async {
      final pdfService = _RecordingPdfService();
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: BeatlesGuitarTabsFeature(
            repository: repository,
            pdfService: pdfService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guitar_mode_structured_score')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('structured_tab_selected_title')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('structured_chord_strip')), findsOneWidget);
      expect(find.byKey(const Key('structured_chord_F')), findsOneWidget);
      expect(
        find.byKey(const Key('structured_tab_score_canvas')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('structured_tab_sheet_light')),
        findsOneWidget,
      );

      final themeToggle = find.byKey(const Key('structured_tab_theme_toggle'));
      await tester.ensureVisible(themeToggle);
      await tester.pumpAndSettle();
      await tester.tap(themeToggle);
      await tester.pump();

      expect(
        find.byKey(const Key('structured_tab_sheet_dark')),
        findsOneWidget,
      );

      final pdfButton = find.byKey(const Key('structured_tab_pdf_button'));
      await tester.ensureVisible(pdfButton);
      await tester.pumpAndSettle();
      await tester.tap(pdfButton);
      await tester.pump();

      expect(pdfService.printedIds, <String>['offbeat-pop-stroke-etude']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plays metronome cursor and handles compact 390px layout cleanly',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guitar_mode_structured_score')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('structured_tab_cursor_label')),
        findsOneWidget,
      );
      final initialCursor = tester.widget<Text>(
        find.byKey(const Key('structured_tab_cursor_label')),
      );
      expect(initialCursor.data, contains('(1/'));

      final playButton = find.byKey(const Key('structured_tab_play_toggle'));
      await tester.ensureVisible(playButton);
      await tester.pumpAndSettle();
      await tester.tap(playButton);
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 520));
      final advancedCursor = tester.widget<Text>(
        find.byKey(const Key('structured_tab_cursor_label')),
      );
      expect(advancedCursor.data, contains('(2/'));

      // 停止してタイマーを残さないことを確認する
      await tester.tap(playButton);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validates invalid JSON, imports local custom score, persists, and deletes',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('guitar_mode_structured_score')));
      await tester.pumpAndSettle();

      final importButton =
          find.byKey(const Key('structured_tab_import_button'));
      await tester.ensureVisible(importButton);
      await tester.pumpAndSettle();
      await tester.tap(importButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('structured_tab_import_dialog')),
        findsOneWidget,
      );

      // エラー系: 不正JSONで日本語エラーが表示される
      await tester.enterText(
        find.byKey(const Key('structured_tab_json_input')),
        '{broken-json',
      );
      await tester.tap(find.byKey(const Key('structured_tab_json_save')));
      await tester.pump();

      expect(
        find.byKey(const Key('structured_tab_json_error')),
        findsOneWidget,
      );

      // 正常系: 有効なローカル専用JSONを保存して表示
      const validJson = '''
{
  "id": "custom-local-etude",
  "title": "マイローカル練習譜",
  "artist": "個人メモ",
  "tuning": "Standard tuning",
  "capo": "Capo fret 2",
  "bpm": 120,
  "chords": [
    {"name": "C", "frets": [-1, 3, 2, 0, 1, 0]}
  ],
  "measures": [
    {
      "number": 1,
      "chordSymbol": "C",
      "beats": [
        {"kind": "rest", "duration": "quarter"},
        {"kind": "chordStack", "duration": "quarter", "frets": [null, 3, 2, 0, 1, 0], "staccato": true},
        {"kind": "rest", "duration": "eighth"},
        {"kind": "rhythmSlash", "duration": "eighth"}
      ]
    }
  ]
}
''';
      await tester.enterText(
        find.byKey(const Key('structured_tab_json_input')),
        validJson,
      );
      await tester.tap(find.byKey(const Key('structured_tab_json_save')));
      await tester.pumpAndSettle();

      final selectedTitle = tester.widget<Text>(
        find.byKey(const Key('structured_tab_selected_title')),
      );
      expect(selectedTitle.data, 'マイローカル練習譜');
      expect(
        find.byKey(const Key('structured_score_chip_custom-local-etude')),
        findsOneWidget,
      );

      // 再起動後もローカル保存から復元されること
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guitar_mode_structured_score')));
      await tester.pumpAndSettle();

      final persistedChip =
          find.byKey(const Key('structured_score_chip_custom-local-etude'));
      expect(persistedChip, findsOneWidget);
      await tester.ensureVisible(persistedChip);
      await tester.pumpAndSettle();
      await tester.tap(persistedChip);
      await tester.pumpAndSettle();

      // 削除後にバンドル曲へ安全復帰する
      final deleteButton =
          find.byKey(const Key('structured_tab_delete_user_score'));
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('structured_score_chip_custom-local-etude')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('structured_score_chip_offbeat-pop-stroke-etude')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'handles empty catalog cleanly without throwing StateError',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(800, 700));
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StructuredTabStudioPanel(
              catalogService: _EmptyCatalogService(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('structured_tab_score_canvas')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'rejects oversized file, invalid UTF-8 file, and bundled ID collisions',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(1200, 900));
      FilePickerResult? nextPickResult = FilePickerResult(<PlatformFile>[
        PlatformFile(
          name: 'too_big.json',
          size: StructuredGuitarTabScore.maxJsonLength + 1,
          bytes: Uint8List(0),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StructuredTabStudioPanel(
              jsonFilePicker: () async => nextPickResult,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('structured_tab_import_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('structured_tab_pick_file')));
      await tester.pumpAndSettle();
      final sizeError = tester.widget<Text>(
        find.byKey(const Key('structured_tab_json_error')),
      );
      expect(sizeError.data, contains('256KB以下'));

      nextPickResult = FilePickerResult(<PlatformFile>[
        PlatformFile(
          name: 'invalid_utf8.json',
          size: 3,
          bytes: Uint8List.fromList(const <int>[0xFF, 0xFE, 0xFD]),
        ),
      ]);
      await tester.tap(find.byKey(const Key('structured_tab_pick_file')));
      await tester.pumpAndSettle();
      final utf8Error = tester.widget<Text>(
        find.byKey(const Key('structured_tab_json_error')),
      );
      expect(utf8Error.data, contains('UTF-8'));

      const collidingJson = '''
{
  "id": "offbeat-pop-stroke-etude",
  "title": "衝突テスト",
  "bpm": 120,
  "measures": [{"number": 1, "beats": [{"kind": "rest", "duration": "quarter"}]}]
}
''';
      await tester.enterText(
        find.byKey(const Key('structured_tab_json_input')),
        collidingJson,
      );
      await tester.tap(find.byKey(const Key('structured_tab_json_save')));
      await tester.pump();

      final idError = tester.widget<Text>(
        find.byKey(const Key('structured_tab_json_error')),
      );
      expect(idError.data, contains('同梱譜面と同じid'));
    },
  );

  testWidgets(
    'surfaces SnackBar on storage save and delete failures',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(1200, 900));
      final existingUserScore = StructuredGuitarTabScore(
        id: 'existing-user-score',
        title: '既存ユーザー譜面',
        artist: 'Test',
        tuning: 'Standard tuning',
        capo: 'なし',
        bpm: 120,
        isOriginalPractice: false,
        isUserImported: true,
        chords: const <StructuredChordDiagram>[],
        measures: <StructuredTabMeasure>[
          StructuredTabMeasure(
            number: 1,
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.quarter,
              ),
            ],
          ),
        ],
      );

      final failingStorage = _FailingUserStorageService(
        <StructuredGuitarTabScore>[existingUserScore],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StructuredTabStudioPanel(
              userStorageService: failingStorage,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('structured_tab_import_button')));
      await tester.pumpAndSettle();

      const newValidJson = '''
{
  "id": "save-fail-test",
  "title": "保存失敗テスト",
  "bpm": 120,
  "measures": [{"number": 1, "beats": [{"kind": "rest", "duration": "quarter"}]}]
}
''';
      await tester.enterText(
        find.byKey(const Key('structured_tab_json_input')),
        newValidJson,
      );
      await tester.tap(find.byKey(const Key('structured_tab_json_save')));
      await tester.pumpAndSettle();

      expect(find.textContaining('端末ローカルへの保存に失敗しました'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final userChip =
          find.byKey(const Key('structured_score_chip_existing-user-score'));
      await tester.ensureVisible(userChip);
      await tester.pumpAndSettle();
      await tester.tap(userChip);
      await tester.pumpAndSettle();

      final deleteButton =
          find.byKey(const Key('structured_tab_delete_user_score'));
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('マイ譜面の削除に失敗しました。'), findsOneWidget);
    },
  );

  test(
    'SharedPreferencesUserStructuredTabStorageService throws when setString fails',
    () async {
      final service = SharedPreferencesUserStructuredTabStorageService(
        preferencesProvider: () async => _FailingSetStringPrefs(),
      );
      final score = StructuredGuitarTabScore(
        id: 'fail-persist',
        title: 'Persist Fail',
        artist: 'Test',
        tuning: 'Standard',
        capo: 'なし',
        bpm: 120,
        chords: const <StructuredChordDiagram>[],
        measures: <StructuredTabMeasure>[
          StructuredTabMeasure(
            number: 1,
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.quarter,
              ),
            ],
          ),
        ],
      );

      await expectLater(service.saveScore(score), throwsStateError);
    },
  );

  testWidgets(
    'renders duplicate chord names and long titles on 390px without overflow',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(390, 844));
      final score = StructuredGuitarTabScore(
        id: 'dup-chord-long-title',
        title: '非常に長いオリジナル練習譜タイトルが390px画面でもオーバーフローしない確認テスト',
        artist: 'Test',
        tuning: 'Standard tuning',
        capo: 'なし',
        bpm: 45,
        chords: const <StructuredChordDiagram>[
          StructuredChordDiagram(name: 'C', frets: <int>[-1, 3, 2, 0, 1, 0]),
          StructuredChordDiagram(
            name: 'C',
            frets: <int>[-1, 3, 5, 5, 5, 3],
            baseFret: 3,
          ),
        ],
        measures: <StructuredTabMeasure>[
          StructuredTabMeasure(
            number: 1,
            beats: <StructuredTabBeat>[
              StructuredTabBeat(
                kind: StructuredTabBeatKind.rest,
                duration: StructuredTabDuration.whole,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StructuredTabStudioPanel(
              catalogService: _SingleScoreCatalogService(score),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('structured_chord_C')), findsOneWidget);
      expect(find.byKey(const Key('structured_chord_C_1')), findsOneWidget);
      expect(find.text('45 BPM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'plays click audio per beat and supports mute toggle and narrow layout cleanly (D6/D7)',
    (WidgetTester tester) async {
      final audioService = _RecordingMetronomeAudioService();
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StructuredTabStudioPanel(
              metronomeAudioService: audioService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final playToggle = find.byKey(const Key('structured_tab_play_toggle'));
      await tester.ensureVisible(playToggle);
      await tester.pumpAndSettle();
      await tester.tap(playToggle);
      await tester.pump();
      expect(audioService.accents.length, 1);

      await tester.pump(const Duration(milliseconds: 520));
      expect(audioService.accents.length, 2);

      final audioToggle = find.byKey(const Key('structured_tab_audio_toggle'));
      await tester.ensureVisible(audioToggle);
      await tester.pumpAndSettle();
      await tester.tap(audioToggle);
      await tester.pump();
      expect(find.text('クリック音 OFF'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 520));
      expect(audioService.accents.length, 2);

      await tester.tap(playToggle);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await _setSurfaceSize(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('structured_tab_score_canvas')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _RecordingMetronomeAudioService implements GuitarMetronomeAudioService {
  final List<bool> accents = <bool>[];

  @override
  bool get isAudioSupported => true;

  @override
  void playClick({required bool accent}) {
    accents.add(accent);
  }

  @override
  void dispose() {}
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _EmptyCatalogService extends StructuredTabCatalogService {
  const _EmptyCatalogService();

  @override
  Future<List<StructuredGuitarTabScore>> loadCatalog() async {
    return const <StructuredGuitarTabScore>[];
  }
}

class _SingleScoreCatalogService extends StructuredTabCatalogService {
  const _SingleScoreCatalogService(this.score);

  final StructuredGuitarTabScore score;

  @override
  Future<List<StructuredGuitarTabScore>> loadCatalog() async {
    return <StructuredGuitarTabScore>[score];
  }
}

class _FailingUserStorageService implements UserStructuredTabStorageService {
  _FailingUserStorageService(this.scores);

  final List<StructuredGuitarTabScore> scores;

  @override
  Future<List<StructuredGuitarTabScore>> loadScores() async => scores;

  @override
  Future<void> saveScore(StructuredGuitarTabScore score) async {
    throw StateError('save failed');
  }

  @override
  Future<void> deleteScore(String id) async {
    throw StateError('delete failed');
  }
}

class _FailingSetStringPrefs extends Fake implements SharedPreferences {
  @override
  String? getString(String key) => null;

  @override
  Future<bool> setString(String key, String value) async => false;
}

class _RecordingPdfService implements StructuredTabPdfService {
  final List<String> printedIds = <String>[];

  @override
  Future<Uint8List> buildScorePdf(
    StructuredGuitarTabScore score, {
    pw.Font? fontOverride,
  }) async {
    return Uint8List.fromList(const <int>[0x25, 0x50, 0x44, 0x46, 0x2D]);
  }

  @override
  Future<bool> printScore(StructuredGuitarTabScore score) async {
    printedIds.add(score.id);
    return true;
  }
}
