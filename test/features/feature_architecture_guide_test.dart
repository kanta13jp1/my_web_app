import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/feature_architecture_guide/application/feature_architecture_controller.dart';
import 'package:my_web_app/features/feature_architecture_guide/feature_architecture_container.dart';
import 'package:my_web_app/features/feature_architecture_guide/presentation/feature_architecture_view.dart';

void main() {
  group('FeatureArchitectureController unit tests (#2603)', () {
    test('filters rules, toggles checklist, resets, and guards after dispose',
        () {
      final controller = FeatureArchitectureController();
      expect(controller.state.filteredRules.length, 3);
      expect(controller.state.completedChecklistCount, 2);

      controller.selectFilter(ArchitectureLayerFilter.application);
      expect(controller.state.filteredRules.length, 1);
      expect(
        controller.state.filteredRules.first.id,
        'rule-application',
      );

      controller.setSearchQuery('non-existent-token');
      expect(controller.state.filteredRules, isEmpty);

      controller.resetDefaults();
      expect(controller.state.filteredRules.length, 3);
      expect(controller.state.searchQuery, isEmpty);

      controller.toggleChecklistItem('chk-shared-boundary');
      expect(controller.state.completedChecklistCount, 3);

      controller.dispose();
      expect(controller.isDisposed, isTrue);
      // Must remain safe if invoked after disposal
      controller.selectFilter(ArchitectureLayerFilter.shared);
      expect(controller.state.filter, ArchitectureLayerFilter.all);
    });
  });

  group('FeatureArchitectureView & Container widget tests (#2603)', () {
    testWidgets(
      'renders pure Presentational view from immutable state and forwards callbacks',
      (tester) async {
        final searchController = TextEditingController();
        addTearDown(searchController.dispose);
        ArchitectureLayerFilter? selectedFilter;
        String? toggledId;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FeatureArchitectureView(
                  state: FeatureArchitectureController.buildDefaultState(),
                  searchController: searchController,
                  onSelectFilter: (layer) => selectedFilter = layer,
                  onSelectRule: (_) {},
                  onToggleChecklist: (id) => toggledId = id,
                  onSearchChanged: (_) {},
                  onReset: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final presChip = find.byKey(
          const ValueKey<String>('arch_filter_presentation'),
        );
        await tester.ensureVisible(presChip);
        await tester.pumpAndSettle();
        await tester.tap(presChip);
        expect(selectedFilter, ArchitectureLayerFilter.presentation);

        final chk = find.byKey(
          const ValueKey<String>('arch_check_chk-shared-boundary'),
        );
        await tester.ensureVisible(chk);
        await tester.pumpAndSettle();
        await tester.tap(chk);
        expect(toggledId, 'chk-shared-boundary');
      },
    );

    testWidgets(
      'wires Container state, search filtering, checklist updates, and reset',
      (tester) async {
        final controller = FeatureArchitectureController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FeatureArchitectureContainer(controller: controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('arch_rule_rule-presentation')),
          findsOneWidget,
        );

        final searchInput = find.byKey(
          const ValueKey<String>('arch_search_input'),
        );
        await tester.ensureVisible(searchInput);
        await tester.pumpAndSettle();
        await tester.enterText(searchInput, 'Application');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('arch_rule_rule-application')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('arch_rule_rule-presentation')),
          findsNothing,
        );

        final resetBtn = find.byKey(const ValueKey<String>('arch_reset_btn'));
        await tester.ensureVisible(resetBtn);
        await tester.pumpAndSettle();
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('arch_rule_rule-presentation')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'meets light/dark 390x844 and 1280x800 layout with 2.0x textScale and accessibility guidelines',
      (tester) async {
        final configs = <(Size, ThemeData)>[
          (const Size(390, 844), ThemeData.light()),
          (const Size(1280, 800), ThemeData.dark()),
        ];

        for (final (viewport, theme) in configs) {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey<String>(
                  '${viewport.width}_${theme.brightness}',
                ),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: FeatureArchitectureContainer(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(
                const ValueKey<String>('feature_architecture_view_card'),
              ),
              findsOneWidget,
            );

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
            );
          } finally {
            handle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      },
    );
  });
}
