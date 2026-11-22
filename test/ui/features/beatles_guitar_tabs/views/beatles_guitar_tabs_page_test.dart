import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_lesson_link_service.dart';
import 'package:my_web_app/data/services/guitar_metronome_audio_service.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/theme/design_tokens.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/views/widgets/guitar_tab_staff.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const repository = LocalGuitarTabRepository(
    catalogService: GuitarTabCatalogService(),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'compact layout filters songs and updates the selected practice',
    (tester) async {
      await _setSurfaceSize(tester, const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beatles_tabs_compact_layout')),
        findsOneWidget,
      );
      await _dragUntilBuilt(
        tester,
        scrollable: find.byKey(const Key('beatles_tabs_compact_layout')),
        target: find.byKey(const Key('beatles_song_blackbird-fingerstyle')),
      );
      expect(
        find.byKey(const Key('beatles_song_blackbird-fingerstyle')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('beatles_tabs_search')),
        'sun',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('beatles_song_blackbird-fingerstyle')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('beatles_song_here-comes-the-sun-arpeggio')),
        findsOneWidget,
      );
      await _dragUntilBuilt(
        tester,
        scrollable: find.byKey(const Key('beatles_tabs_compact_layout')),
        target: find.byKey(const Key('beatles_selected_song_title')),
      );
      final selectedTitle = tester.widget<Text>(
        find.byKey(const Key('beatles_selected_song_title')),
      );
      expect(selectedTitle.data, 'Here Comes the Sun');
    },
  );

  testWidgets('wide layout uses a vertical library and changes song on tap', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 900));
    await tester.pumpWidget(
      const MaterialApp(home: BeatlesGuitarTabsFeature(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('beatles_song_list')), findsOneWidget);
    expect(find.byKey(const Key('beatles_tabs_compact_layout')), findsNothing);

    await tester.tap(find.byKey(const Key('beatles_song_day-tripper-riff')));
    await tester.pump();

    final selectedTitle = tester.widget<Text>(
      find.byKey(const Key('beatles_selected_song_title')),
    );
    expect(selectedTitle.data, 'Day Tripper');
    expect(find.byKey(const Key('beatles_tab_notation')), findsOneWidget);
  });

  testWidgets('Blackbird lesson changes steps and opens a reference', (
    tester,
  ) async {
    final linkService = _RecordingLinkService();
    await _setSurfaceSize(tester, const Size(1200, 1100));
    await tester.pumpWidget(
      MaterialApp(
        home: BeatlesGuitarTabsFeature(
          repository: repository,
          linkService: linkService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今日の3ステップ'), findsOneWidget);
    expect(find.text('参考資料で深掘りする'), findsOneWidget);

    final tempoStep = find.byKey(const Key('blackbird_practice_step_tempo'));
    await tester.ensureVisible(tempoStep);
    await tester.pumpAndSettle();
    await tester.tap(tempoStep);
    await tester.pump();
    expect(find.text('84 BPM'), findsWidgets);

    final resource = find.byKey(const Key('blackbird_resource_musescore'));
    await tester.ensureVisible(resource);
    await tester.pumpAndSettle();
    tester.widget<OutlinedButton>(resource).onPressed!();
    await tester.pump();

    expect(
      linkService.opened.single,
      Uri.parse('https://ja.musescore.com/user/6375061/scores/7758575'),
    );
  });

  testWidgets('daily course completes tasks and unlocks the next day', (
    tester,
  ) async {
    await _setSurfaceSize(tester, const Size(1200, 1400));
    await tester.pumpWidget(
      const MaterialApp(home: BeatlesGuitarTabsFeature(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('guitar_daily_course_panel')), findsOneWidget);
    expect(find.text('ギターを正しく構える'), findsOneWidget);

    for (final taskId in <String>['d01-posture', 'd01-tune', 'd01-pulse']) {
      await tester.tap(find.byKey(Key('guitar_daily_task_$taskId')));
      await tester.pumpAndSettle();
    }

    final completeButton = tester.widget<FilledButton>(
      find.byKey(const Key('guitar_complete_course_day')),
    );
    expect(completeButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('guitar_complete_course_day')));
    await tester.pumpAndSettle();

    expect(find.text('右手で弦を選ぶ'), findsOneWidget);
    final dayLabel = tester.widget<Text>(
      find.byKey(const Key('guitar_current_course_day')),
    );
    expect(dayLabel.data, 'DAY 2');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const MaterialApp(home: BeatlesGuitarTabsFeature(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('右手で弦を選ぶ'), findsOneWidget);
  });

  testWidgets(
    'enforces WCAG 2.1 AA contrast for disabled course CTA, search hint, and reset button (D1/D5)',
    (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('今日の3課題をすべてチェックすると完了できます'),
        findsOneWidget,
      );

      final completeButton = tester.widget<FilledButton>(
        find.byKey(const Key('guitar_complete_course_day')),
      );
      expect(completeButton.onPressed, isNull);
      final disabledBg = completeButton.style?.backgroundColor?.resolve(
        <WidgetState>{WidgetState.disabled},
      );
      final disabledFg = completeButton.style?.foregroundColor?.resolve(
        <WidgetState>{WidgetState.disabled},
      );
      expect(disabledBg, isNotNull);
      expect(disabledFg, isNotNull);
      expect(
        _contrastRatio(disabledFg!, disabledBg!),
        greaterThanOrEqualTo(4.5),
      );

      final openTabButton = tester.widget<OutlinedButton>(
        find.byKey(const Key('guitar_open_course_practice')),
      );
      final openTabFg = openTabButton.style?.foregroundColor?.resolve(
        <WidgetState>{},
      );
      expect(openTabFg, isNotNull);
      expect(
        _contrastRatio(openTabFg!, DesignTokens.surface1),
        greaterThanOrEqualTo(4.5),
      );

      final searchField = tester.widget<TextField>(
        find.byKey(const Key('beatles_tabs_search')),
      );
      final hintColor = searchField.decoration?.hintStyle?.color;
      final fillColor =
          searchField.decoration?.fillColor ?? DesignTokens.surface3;
      expect(hintColor, isNotNull);
      expect(
        _contrastRatio(hintColor!, fillColor),
        greaterThanOrEqualTo(4.5),
      );

      final resetFinder = find.widgetWithText(TextButton, '推奨 60 BPM に戻す');
      expect(resetFinder, findsOneWidget);
      final resetButton = tester.widget<TextButton>(resetFinder);
      final resetDisabledFg = resetButton.style?.foregroundColor?.resolve(
        <WidgetState>{WidgetState.disabled},
      );
      expect(resetDisabledFg, isNotNull);
      expect(
        _contrastRatio(resetDisabledFg!, DesignTokens.surface2),
        greaterThanOrEqualTo(4.5),
      );
    },
  );

  testWidgets(
    'uses 3-column desktop task row, left-sidebar search, and collapsible course panel (D2/D3)',
    (tester) async {
      await _setSurfaceSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final searchRect =
          tester.getRect(find.byKey(const Key('beatles_tabs_search')));
      expect(searchRect.right, lessThanOrEqualTo(320.0));

      final y0 = tester
          .getTopLeft(find.byKey(const Key('guitar_daily_task_d01-posture')))
          .dy;
      final y1 = tester
          .getTopLeft(find.byKey(const Key('guitar_daily_task_d01-tune')))
          .dy;
      final y2 = tester
          .getTopLeft(find.byKey(const Key('guitar_daily_task_d01-pulse')))
          .dy;
      expect((y0 - y1).abs(), lessThan(1.0));
      expect((y0 - y2).abs(), lessThan(1.0));

      await tester.tap(find.byKey(const Key('guitar_course_collapse_toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('guitar_daily_task_d01-posture')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('guitar_course_collapse_toggle')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('guitar_daily_task_d01-posture')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders uniform-column CustomPainter TAB staff and copies TAB text (D4)',
    (tester) async {
      String? copiedClipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData' &&
              call.arguments is Map<Object?, Object?>) {
            final args = call.arguments as Map<Object?, Object?>;
            copiedClipboardText = args['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await _setSurfaceSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        const MaterialApp(
          home: BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('beatles_song_day-tripper-riff')));
      await tester.pumpAndSettle();

      final notationFinder = find.byKey(const Key('beatles_tab_notation'));
      expect(notationFinder, findsOneWidget);
      final customPaint = tester.widget<CustomPaint>(notationFinder);
      expect(customPaint.size.width, greaterThanOrEqualTo(240.0));
      expect(customPaint.size.height, greaterThanOrEqualTo(120.0));
      expect(
        computeGuitarTabColumnCount(const <String>[
          'e|----------------|',
          'A|--2-4-------4-2-|',
          'E|0---------------|',
        ]),
        19,
      );

      final copyButton = find.byKey(const Key('guitar_tab_copy_button'));
      await tester.ensureVisible(copyButton);
      await tester.pumpAndSettle();
      await tester.tap(copyButton);
      await tester.pumpAndSettle();

      expect(copiedClipboardText, contains('e|----------------|'));
      expect(copiedClipboardText, contains('A|--2-4-------4-2-|'));
      expect(find.text('TAB譜テキストをクリップボードへコピーしました。'), findsOneWidget);
    },
  );

  testWidgets(
    'plays audible metronome clicks and stops cleanly without pending timers (D6)',
    (tester) async {
      final audioService = _RecordingMetronomeAudioService();
      await _setSurfaceSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: BeatlesGuitarTabsFeature(
            repository: repository,
            metronomeAudioService: audioService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleButton = find.byKey(const Key('beatles_metronome_toggle'));
      await tester.ensureVisible(toggleButton);
      await tester.pumpAndSettle();
      await tester.tap(toggleButton);
      await tester.pump();

      expect(audioService.accents, <bool>[true]);
      expect(find.text('1/4拍'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1050));
      expect(audioService.accents, <bool>[true, false]);
      expect(find.text('2/4拍'), findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pump();
      expect(find.text('待機中'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'passes accessibility guidelines and avoids overflow at 320x568 text scale 2.0',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await _setSurfaceSize(tester, const Size(1200, 900));
        await tester.pumpWidget(
          const MaterialApp(
            home: BeatlesGuitarTabsFeature(repository: repository),
          ),
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
          home: const BeatlesGuitarTabsFeature(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

double _channelLuminance(int channel8Bit) {
  final c = channel8Bit / 255.0;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _contrastRatio(Color a, Color b) {
  final la = 0.2126 * _channelLuminance((a.r * 255.0).round()) +
      0.7152 * _channelLuminance((a.g * 255.0).round()) +
      0.0722 * _channelLuminance((a.b * 255.0).round());
  final lb = 0.2126 * _channelLuminance((b.r * 255.0).round()) +
      0.7152 * _channelLuminance((b.g * 255.0).round()) +
      0.0722 * _channelLuminance((b.b * 255.0).round());
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

class _RecordingMetronomeAudioService implements GuitarMetronomeAudioService {
  final List<bool> accents = <bool>[];
  bool disposed = false;

  @override
  bool get isAudioSupported => true;

  @override
  void playClick({required bool accent}) {
    accents.add(accent);
  }

  @override
  void dispose() {
    disposed = true;
  }
}

Future<void> _setSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _dragUntilBuilt(
  WidgetTester tester, {
  required Finder scrollable,
  required Finder target,
}) async {
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

class _RecordingLinkService implements GuitarLessonLinkService {
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> openExternal(Uri uri) async {
    opened.add(uri);
    return true;
  }
}
