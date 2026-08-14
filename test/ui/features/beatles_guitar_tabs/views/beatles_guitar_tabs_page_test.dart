import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/guitar_tab_repository.dart';
import 'package:my_web_app/data/services/guitar_tab_catalog_service.dart';
import 'package:my_web_app/data/services/guitar_lesson_link_service.dart';
import 'package:my_web_app/ui/features/beatles_guitar_tabs/beatles_guitar_tabs_feature.dart';
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
