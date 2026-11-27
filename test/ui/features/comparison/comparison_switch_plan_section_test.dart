import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_switch_plan_section.dart';

void main() {
  const mobileViewport = Size(360, 800);
  const desktopViewport = Size(900, 800);

  Widget buildSubject({
    required Size viewport,
    required double textScale,
    required VoidCallback onPrimary,
    required VoidCallback onSecondary,
    String? verifiedNote,
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: viewport,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ComparisonSwitchPlanSection(
              accentColor: const Color(0xFF00C4CC),
              stepOneTitle: 'Notion から主要ページだけ試す',
              stepOneBody: 'Markdown と CSV をそのまま取り込んで、手元の導線を崩さず移行できます。',
              verifiedNote: verifiedNote,
              primaryButton: FilledButton(
                onPressed: onPrimary,
                child: const Text('無料で始める（30秒）'),
              ),
              secondaryButton: OutlinedButton(
                onPressed: onSecondary,
                child: const Text('Notion からインポート'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('ComparisonSwitchPlanSection', () {
    testWidgets(
        'renders 3 steps, verified note, and triggers CTAs @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var primaryTapped = 0;
      var secondaryTapped = 0;

      await tester.pumpWidget(
        buildSubject(
          viewport: mobileViewport,
          textScale: 2.0,
          verifiedNote: '確認日: 2026-11-27 / 公式ドキュメント根拠に基づく移行手順',
          onPrimary: () => primaryTapped++,
          onSecondary: () => secondaryTapped++,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ComparisonSwitchPlanSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text('乗り換えの進め方'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('Notion から主要ページだけ試す'), findsOneWidget);
      expect(
        find.text('確認日: 2026-11-27 / 公式ドキュメント根拠に基づく移行手順'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('無料で始める（30秒）'));
      await tester.tap(find.text('無料で始める（30秒）'));
      await tester.ensureVisible(find.text('Notion からインポート'));
      await tester.tap(find.text('Notion からインポート'));
      await tester.pump();

      expect(primaryTapped, 1);
      expect(secondaryTapped, 1);
    });

    testWidgets('renders 3-column desktop row layout cleanly @ 900x800',
        (tester) async {
      await tester.binding.setSurfaceSize(desktopViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(
          viewport: desktopViewport,
          textScale: 1.0,
          onPrimary: () {},
          onSecondary: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsOneWidget);
      expect(find.text('今日の最重要タスクを AI に任せる'), findsOneWidget);
      expect(find.text('必要になった機能だけ横に増やす'), findsOneWidget);
    });
  });
}
