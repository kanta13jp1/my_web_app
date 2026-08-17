import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/landing_story_journey.dart';

void main() {
  Future<ScrollController> pumpJourney(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onPrimaryAction,
    VoidCallback? onSecondaryAction,
    bool disableAnimations = false,
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
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
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

    await tester.tap(find.byKey(const Key('landing_story_dot_3')));
    await tester.pumpAndSettle();

    expect(find.textContaining('いま動かす'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_story_secondary_cta')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('landing_story_primary_cta')));
    await tester.tap(find.byKey(const Key('landing_story_secondary_cta')));
    await tester.pump();

    expect(primaryTaps, 1);
    expect(secondaryTaps, 1);
  });

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

    expect(find.text('試すのは無料 · カード不要'), findsOneWidget);
    expect(find.byKey(const Key('landing_story_primary_cta')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_story_secondary_cta')),
      findsOneWidget,
    );
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
}
