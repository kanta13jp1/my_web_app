import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/context_budget_service.dart';
import 'package:my_web_app/widgets/context_budget_and_sources_panel.dart';

class _FakeCustomDataSourceRepository implements CustomDataSourceRepository {
  _FakeCustomDataSourceRepository({
    this.maxSources = 1,
    this.maxContextUnits = 1000000,
    List<CustomDataSourceItem>? seed,
  }) : items = List<CustomDataSourceItem>.from(
          seed ?? const <CustomDataSourceItem>[],
        );

  final int maxSources;
  final int maxContextUnits;
  final List<CustomDataSourceItem> items;

  @override
  Future<CustomDataSourceLimitStatus> fetchStatus() async {
    return CustomDataSourceLimitStatus(
      plan: 'free',
      used: items.length,
      maxSources: maxSources,
      remaining: (maxSources - items.length).clamp(0, maxSources),
      maxContextUnits: maxContextUnits,
      limitReached: items.length >= maxSources,
      items: List<CustomDataSourceItem>.from(items),
    );
  }

  @override
  Future<CustomDataSourceLimitStatus> registerSource({
    required String name,
    required String sourceType,
    required String sampleText,
  }) async {
    if (items.length >= maxSources) {
      throw StateError('cap reached');
    }
    items.insert(
      0,
      CustomDataSourceItem(
        id: 'src-${items.length + 1}',
        name: name,
        sourceType: sourceType,
        estimatedUnits: ContextBudgetEstimator.estimateTextUnits(sampleText),
      ),
    );
    return fetchStatus();
  }
}

void main() {
  group('ContextBudgetEstimator & Panel (#2701)', () {
    test('estimates ASCII, CJK, and attached file bytes deterministically', () {
      expect(ContextBudgetEstimator.estimateTextUnits('abcd'), 1);
      expect(ContextBudgetEstimator.estimateTextUnits('あいう') >= 2, isTrue);
      expect(
        ContextBudgetEstimator.estimatePayloadUnits(
          text: 'hello',
          attachedFileByteSizes: const <int>[300],
        ),
        ContextBudgetEstimator.estimateTextUnits('hello') + 100,
      );
    });

    testWidgets(
      'updates live counter, blocks over-limit submit, and disables add at DB cap',
      (WidgetTester tester) async {
        final repo = _FakeCustomDataSourceRepository(
          maxSources: 1,
          maxContextUnits: 10,
        );
        var submitCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ContextBudgetAndSourcesPanel(
                  repository: repo,
                  maxContextUnits: 10,
                  onSubmitPrompt: (_, __) async {
                    submitCount += 1;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('登録済みデータソース: 0 / 1 (freeプラン)'), findsOneWidget);

        // Registering first source succeeds and disables the add button cleanly
        await tester.enterText(
          find.byKey(const ValueKey<String>('custom_source_name_input')),
          '社内仕様書',
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('custom_source_add_button')),
        );
        await tester.pumpAndSettle();

        expect(find.text('登録済みデータソース: 1 / 1 (freeプラン)'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('custom_source_cap_warning')),
          findsOneWidget,
        );
        final addButton = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey<String>('custom_source_add_button')),
        );
        expect(addButton.onPressed, isNull);

        // Entering oversized text updates badge and disables submit button
        await tester.enterText(
          find.byKey(const ValueKey<String>('context_budget_prompt_input')),
          'a' * 120,
        );
        await tester.pump();

        expect(find.textContaining('上限超過: 推定トークン数'), findsOneWidget);
        final submitButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('context_budget_submit_button')),
        );
        expect(submitButton.onPressed, isNull);
        expect(submitCount, 0);
      },
    );

    testWidgets(
      'meets light/dark responsive layout, 2.0x textScale, and a11y guidelines',
      (WidgetTester tester) async {
        const seededStatus = CustomDataSourceLimitStatus(
          plan: 'free',
          used: 20,
          maxSources: 20,
          remaining: 0,
          maxContextUnits: 1000000,
          limitReached: true,
          items: <CustomDataSourceItem>[],
        );

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
                key: ValueKey<String>('${viewport.width}_${theme.brightness}'),
                theme: theme,
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: const Scaffold(
                    body: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: ContextBudgetAndSourcesPanel(
                        initialStatus: seededStatus,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(
                const ValueKey<String>('context_budget_and_sources_panel'),
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
            await expectLater(tester, meetsGuideline(textContrastGuideline));
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
