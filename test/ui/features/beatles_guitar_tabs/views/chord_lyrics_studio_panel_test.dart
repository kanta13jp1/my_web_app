import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/views/widgets/chord_lyrics_studio_panel.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/views/widgets/structured_chord_diagram.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'renders horizontal chord diagrams above Japanese lyrics and converts Capo 3',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChordLyricsStudioPanel())),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chord_lyrics_sheet_light')), findsOneWidget);
      expect(
        find.text('楽譜タップで自動スクロール開始'),
        findsOneWidget,
      );
      expect(find.byType(HorizontalChordDiagramCard), findsWidgets);
      expect(find.text('D#'), findsWidgets);
      expect(find.text('Cm'), findsWidgets);
      expect(find.text('D#/D'), findsWidgets);
      expect(find.text('N.C.'), findsWidgets);
      expect(find.text('夜汽車の窓に映る'), findsOneWidget);

      final capoPlus = find.byKey(const Key('chord_lyrics_capo_plus'));
      for (var i = 0; i < 3; i++) {
        await tester.tap(capoPlus);
        await tester.pump();
      }

      expect(find.text('Capo 3'), findsOneWidget);
      expect(find.text('表示キー: C'), findsOneWidget);
      expect(find.text('C'), findsWidgets);
      expect(find.text('Am'), findsWidgets);
      expect(find.text('F'), findsWidgets);
      expect(find.text('C/B'), findsWidgets);
      expect(find.text('N.C.'), findsWidgets);

      // トグル操作（♭表記・コード図OFF・ダーク表示）
      await tester.tap(find.byKey(const Key('chord_lyrics_capo_minus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('chord_lyrics_accidental_toggle')));
      await tester.pump();
      expect(find.text('♭表記'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chord_lyrics_diagram_toggle')));
      await tester.pump();
      expect(find.byType(HorizontalChordDiagramCard), findsNothing);
      expect(find.text('コード図 OFF'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chord_lyrics_theme_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('chord_lyrics_sheet_dark')), findsOneWidget);
    },
  );

  testWidgets(
    'starts auto-scroll when score sheet is tapped and stops cleanly without timers',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(390, 620));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChordLyricsStudioPanel())),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byKey(const Key('chord_lyrics_studio_scroll'));
      final controller = tester.widget<ListView>(scrollFinder).controller!;
      expect(controller.offset, 0.0);

      final tapArea = find.byKey(const Key('chord_lyrics_score_tap_area'));
      await tester.tapAt(tester.getCenter(tapArea));
      await tester.pump();

      expect(find.text('自動スクロール中 — 楽譜タップで停止'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 220));
      expect(controller.offset, greaterThan(0.0));

      // 再度タップして自動スクロール停止（未解決タイマーが残らないことを確認）
      await tester.tapAt(tester.getCenter(tapArea));
      await tester.pump();
      expect(find.text('楽譜タップで自動スクロール開始'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'validates, imports, persists, and deletes local ChordPro sheet',
    (WidgetTester tester) async {
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChordLyricsStudioPanel())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chord_lyrics_import_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chord_lyrics_import_dialog')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('chord_lyrics_source_input')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('chord_lyrics_source_save')));
      await tester.pump();
      expect(
        find.byKey(const Key('chord_lyrics_import_error')),
        findsOneWidget,
      );

      const customSource = '''
{title: ローカル保存テスト曲}
{subtitle: Personal Note}
{key: G}
[G]朝の[D/F#]風と[Em]ギター
''';
      await tester.enterText(
        find.byKey(const Key('chord_lyrics_source_input')),
        customSource,
      );
      await tester.tap(find.byKey(const Key('chord_lyrics_source_save')));
      await tester.pumpAndSettle();

      expect(find.text('[マイ] ローカル保存テスト曲'), findsOneWidget);
      expect(find.text('朝の'), findsOneWidget);

      // 再マウント後も SharedPreferences から復元されること
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ChordLyricsStudioPanel())),
      );
      await tester.pumpAndSettle();
      expect(find.text('[マイ] ローカル保存テスト曲'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chord_lyrics_delete_button')));
      await tester.pumpAndSettle();
      expect(find.text('[マイ] ローカル保存テスト曲'), findsNothing);
    },
  );

  testWidgets(
    'passes accessibility guidelines and avoids overflow at 320x568 text scale 2.0',
    (WidgetTester tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _setSurfaceSize(tester, const Size(1200, 900));
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ChordLyricsStudioPanel())),
        );
        await tester.pumpAndSettle();

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      } finally {
        handle.dispose();
      }

      await _setSurfaceSize(tester, const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            );
          },
          home: const Scaffold(body: ChordLyricsStudioPanel()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
