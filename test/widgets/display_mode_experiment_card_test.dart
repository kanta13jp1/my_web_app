import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/display_mode_experiment_card.dart';

void main() {
  group('DisplayModeExperimentCard', () {
    testWidgets('expand opens dialog with line + area charts', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayModeExperimentCard(
                debugWeekly: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'week_start': '2026-06-08',
                    'initials': 5,
                    'initial_standard': 4,
                    'switches': 2,
                  },
                  <String, dynamic>{
                    'week_start': '2026-06-01',
                    'initials': 3,
                    'initial_standard': 1,
                    'switches': 1,
                  },
                ],
                debugWeeklyRetention: <Map<String, dynamic>>[
                  <String, dynamic>{'week_start': '2026-06-08', 'rate': 80},
                  <String, dynamic>{'week_start': '2026-06-01', 'rate': null},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expandButton = find.byKey(
        const Key('display_mode_experiment_expand'),
      );
      expect(expandButton, findsOneWidget);
      expect(tester.widget<IconButton>(expandButton).onPressed, isNotNull);

      await tester.tap(expandButton);
      await tester.pumpAndSettle();

      expect(find.text('表示モード実験 詳細グラフ'), findsOneWidget);
      expect(
        find.byKey(const Key('display_mode_retention_line_chart')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('display_mode_trend_area_chart')),
        findsOneWidget,
      );
      // 週次の数値表も併記される。
      expect(find.textContaining('維持率'), findsWidgets);
    });

    testWidgets('expand button is disabled without data', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DisplayModeExperimentCard(
              debugWeekly: <Map<String, dynamic>>[],
              debugWeeklyRetention: <Map<String, dynamic>>[],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expandButton = find.byKey(
        const Key('display_mode_experiment_expand'),
      );
      expect(tester.widget<IconButton>(expandButton).onPressed, isNull);
    });

    testWidgets('tapping the retention chart shows a value tooltip', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayModeExperimentCard(
                debugWeekly: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'week_start': '2026-06-08',
                    'initials': 5,
                    'initial_standard': 4,
                    'switches': 2,
                  },
                ],
                debugWeeklyRetention: <Map<String, dynamic>>[
                  <String, dynamic>{'week_start': '2026-06-08', 'rate': 80},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('display_mode_experiment_expand')));
      await tester.pumpAndSettle();

      // 初期状態ではツールチップ非表示。
      expect(
        find.byKey(const Key('display_mode_chart_tooltip')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('display_mode_retention_line_chart')),
      );
      await tester.pumpAndSettle();

      final tooltip = find.byKey(const Key('display_mode_chart_tooltip'));
      expect(tooltip, findsOneWidget);
      expect(
        find.descendant(of: tooltip, matching: find.textContaining('%')),
        findsOneWidget,
      );
    });

    testWidgets('arrow keys move the selected point (keyboard a11y)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayModeExperimentCard(
                debugWeekly: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'week_start': '2026-06-15',
                    'initials': 6,
                    'initial_standard': 5,
                    'switches': 3,
                  },
                  <String, dynamic>{
                    'week_start': '2026-06-08',
                    'initials': 5,
                    'initial_standard': 4,
                    'switches': 2,
                  },
                  <String, dynamic>{
                    'week_start': '2026-06-01',
                    'initials': 3,
                    'initial_standard': 1,
                    'switches': 1,
                  },
                ],
                debugWeeklyRetention: <Map<String, dynamic>>[
                  <String, dynamic>{'week_start': '2026-06-15', 'rate': 90},
                  <String, dynamic>{'week_start': '2026-06-08', 'rate': 80},
                  <String, dynamic>{'week_start': '2026-06-01', 'rate': 70},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('display_mode_experiment_expand')));
      await tester.pumpAndSettle();

      // タップでフォーカス+選択。週は時系列昇順 (06-01,06-08,06-15)。
      await tester.tap(
        find.byKey(const Key('display_mode_retention_line_chart')),
      );
      await tester.pumpAndSettle();

      // 右矢印2回で必ず末尾 (06-15 / 90%) に到達する (clamp)。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      final tooltip = find.byKey(const Key('display_mode_chart_tooltip'));
      expect(
        find.descendant(of: tooltip, matching: find.textContaining('90%')),
        findsOneWidget,
      );

      // 左矢印2回で先頭 (06-01 / 70%) へ。
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: tooltip, matching: find.textContaining('70%')),
        findsOneWidget,
      );
    });

    testWidgets('selected point is announced via Semantics value', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(900, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayModeExperimentCard(
                debugWeekly: <Map<String, dynamic>>[
                  <String, dynamic>{
                    'week_start': '2026-06-08',
                    'initials': 5,
                    'initial_standard': 4,
                    'switches': 2,
                  },
                ],
                debugWeeklyRetention: <Map<String, dynamic>>[
                  <String, dynamic>{'week_start': '2026-06-08', 'rate': 80},
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('display_mode_experiment_expand')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('display_mode_retention_line_chart')),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('標準維持率の推移グラフ')),
      );
      expect(node.value, contains('パーセント'));

      handle.dispose();
    });
  });
}
