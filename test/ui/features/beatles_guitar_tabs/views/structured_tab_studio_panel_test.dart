import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/data/services/structured_tab_pdf_service.dart';
import 'package:my_web_app/domain/models/structured_guitar_tab.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';
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
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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
