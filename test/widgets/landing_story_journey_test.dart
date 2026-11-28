import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/landing_story_journey.dart';

void main() {
  Future<ScrollController> pumpJourney(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onPrimaryAction,
    VoidCallback? onSecondaryAction,
    bool disableAnimations = false,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: disableAnimations,
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: Column(
                  children: [
                    LandingStoryJourney(
                      scrollController: controller,
                      onPrimaryAction: onPrimaryAction ?? () {},
                      onSecondaryAction: onSecondaryAction ?? () {},
                    ),
                    const SizedBox(height: 900),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return controller;
  }

  testWidgets('desktop rail moves through the story and exposes final CTAs', (
    tester,
  ) async {
    var primaryTaps = 0;
    var secondaryTaps = 0;
    await pumpJourney(
      tester,
      size: const Size(1200, 900),
      onPrimaryAction: () => primaryTaps += 1,
      onSecondaryAction: () => secondaryTaps += 1,
    );

    expect(find.byKey(const Key('landing_story_journey')), findsOneWidget);
    expect(find.textContaining('情報が増えるほど'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_0')), findsOneWidget);
    expect(find.byKey(const Key('landing_story_media_1')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_2')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_3')), findsNothing);

    await tester.tap(find.byKey(const Key('landing_story_dot_3')));
    await tester.pumpAndSettle();

    expect(find.textContaining('いま動かす'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_story_secondary_cta')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing_story_media_0')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_1')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_2')), findsNothing);
    expect(find.byKey(const Key('landing_story_media_3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('landing_story_primary_cta')));
    await tester.tap(find.byKey(const Key('landing_story_secondary_cta')));
    await tester.pump();

    expect(primaryTaps, 1);
    expect(secondaryTaps, 1);
  });

  testWidgets(
    'immediate reduced-motion chapter switching never drops sequential taps',
    (tester) async {
      await pumpJourney(
        tester,
        size: const Size(1200, 900),
        disableAnimations: true,
      );

      for (final index in <int>[0, 1, 2, 3, 0]) {
        await tester.tap(find.byKey(Key('landing_story_dot_$index')));
        await tester.pump();
        expect(find.byKey(Key('landing_story_chapter_$index')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile layout keeps the final chapter usable without overflow', (
    tester,
  ) async {
    await pumpJourney(
      tester,
      size: const Size(390, 844),
      disableAnimations: true,
    );

    await tester.tap(find.byKey(const Key('landing_story_dot_3')));
    await tester.pump();

    expect(find.text('登録前に体験 · 無料登録時カード不要'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_story_secondary_cta')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing_story_media_3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ultra-short landscape, enlarged text, and rotation keep CTAs unclipped',
    (tester) async {
      await pumpJourney(
        tester,
        size: const Size(667, 375),
        disableAnimations: true,
      );
      await tester.tap(find.byKey(const Key('landing_story_dot_3')));
      await tester.pump();
      final shortPrimary = tester.getRect(
        find.byKey(const Key('landing_story_primary_cta')),
      );
      final shortSecondary = tester.getRect(
        find.byKey(const Key('landing_story_secondary_cta')),
      );
      final shortProgress = tester.getRect(
        find.byKey(const Key('landing_story_progress')),
      );
      expect(shortPrimary.height, greaterThanOrEqualTo(44));
      expect(shortSecondary.height, greaterThanOrEqualTo(44));
      expect(shortPrimary.bottom, lessThanOrEqualTo(shortProgress.top));
      expect(shortSecondary.bottom, lessThanOrEqualTo(shortProgress.top));
      expect(tester.takeException(), isNull);

      await pumpJourney(
        tester,
        size: const Size(390, 844),
        disableAnimations: true,
        textScale: 1.5,
      );
      await tester.tap(find.byKey(const Key('landing_story_dot_3')));
      await tester.pump();
      final scaledPrimary = tester.getRect(
        find.byKey(const Key('landing_story_primary_cta')),
      );
      final scaledSecondary = tester.getRect(
        find.byKey(const Key('landing_story_secondary_cta')),
      );
      final scaledProgress = tester.getRect(
        find.byKey(const Key('landing_story_progress')),
      );
      expect(scaledPrimary.top, greaterThanOrEqualTo(0));
      expect(scaledPrimary.height, greaterThanOrEqualTo(44));
      expect(scaledSecondary.height, greaterThanOrEqualTo(44));
      expect(scaledSecondary.bottom, lessThanOrEqualTo(scaledProgress.top));
      expect(scaledSecondary.bottom, lessThanOrEqualTo(844));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pump();
      await tester.pump();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const Key('landing_story_primary_cta')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard navigation moves through story chapters', (
    tester,
  ) async {
    await pumpJourney(
      tester,
      size: const Size(1200, 900),
      disableAnimations: true,
    );

    final firstDot = find.byKey(const Key('landing_story_dot_0'));
    await tester.tap(firstDot);
    await tester.pump();
    expect(find.byKey(const Key('landing_story_chapter_0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.byKey(const Key('landing_story_chapter_1')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(find.byKey(const Key('landing_story_chapter_3')), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(find.byKey(const Key('landing_story_chapter_0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outer page scroll updates the active chapter', (tester) async {
    final controller = await pumpJourney(
      tester,
      size: const Size(1200, 900),
      disableAnimations: true,
    );

    controller.jumpTo(controller.position.maxScrollExtent * 0.55);
    await tester.pump();

    expect(find.textContaining('複雑さを'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_chapter_2')), findsOneWidget);
  });

  testWidgets('story media exposes a designed missing-asset fallback', (
    tester,
  ) async {
    await pumpJourney(tester, size: const Size(1200, 900));

    final imageFinder = find.byKey(const Key('landing_story_media_image_0'));
    final image = tester.widget<Image>(imageFinder);
    expect(image.errorBuilder, isNotNull);

    final fallback = image.errorBuilder!(
      tester.element(imageFinder),
      StateError('missing test asset'),
      StackTrace.empty,
    );
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 800, height: 500, child: fallback)),
    );
    expect(
      find.byKey(const Key('landing_story_media_fallback')),
      findsOneWidget,
    );
  });
}
