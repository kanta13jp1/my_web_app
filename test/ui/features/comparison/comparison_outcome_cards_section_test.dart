import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_outcome_cards_section.dart';

void main() {
  const mobileViewport = Size(360, 800);
  const desktopViewport = Size(900, 800);

  Widget wrapViewport(Size viewport, double textScale, Widget child) {
    return MediaQuery(
      data: MediaQueryData(
        size: viewport,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('ComparisonOutcomeCardsSection', () {
    testWidgets(
        'renders 3 stacked outcome cards without overflow @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          const ComparisonOutcomeCardsSection(
            accentColor: Color(0xFF00C4CC),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ComparisonOutcomeCardsSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text('日常の作業をひとつに集約'), findsOneWidget);
      expect(find.text('まず無料で始めて、必要になってから広げる'), findsOneWidget);
      expect(find.text('AI が「今日やること」を1件に絞る'), findsOneWidget);
    });

    testWidgets('renders 3-column desktop row layout @ 900x800',
        (tester) async {
      await tester.binding.setSurfaceSize(desktopViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          desktopViewport,
          1.0,
          const ComparisonOutcomeCardsSection(
            accentColor: Color(0xFF00C4CC),
            items: [
              ComparisonOutcomeCardItem(
                icon: Icons.verified_outlined,
                title: '公式根拠付きの比較 (2026-11-28)',
                body: '料金と移行手順を公式ページで確認できます。',
                accent: Color(0xFF00C4CC),
              ),
              ComparisonOutcomeCardItem(
                icon: Icons.upload_file_rounded,
                title: '段階的なインポート',
                body: '既存データを壊さず少しずつ試せます。',
                accent: Color(0xFFFF6B35),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsOneWidget);
      expect(find.text('公式根拠付きの比較 (2026-11-28)'), findsOneWidget);
      expect(find.text('段階的なインポート'), findsOneWidget);
    });
  });
}
