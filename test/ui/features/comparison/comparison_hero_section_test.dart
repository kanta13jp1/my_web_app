import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_hero_section.dart';

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

  group('ComparisonHeroSection', () {
    testWidgets('renders loaded evidence metrics and fires CTAs @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var primaryTapped = 0;
      var secondaryTapped = 0;

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          ComparisonHeroSection(
            competitorName: 'Notion',
            emoji: '📝',
            searchKeyword: 'Notion 代替',
            accentColor: const Color(0xFF00C4CC),
            hasImportSupport: true,
            evidenceStatus: ComparisonEvidenceStatus.loaded,
            verifiedEvidenceCount: 3,
            withheldLegacyClaimCount: 5,
            primaryButton: FilledButton(
              onPressed: () => primaryTapped++,
              child: const Text('無料で始める（30秒）'),
            ),
            secondaryButton: OutlinedButton(
              onPressed: () => secondaryTapped++,
              child: const Text('Notion からインポート'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ComparisonHeroSection.sectionKey), findsOneWidget);
      expect(find.text('3件'), findsOneWidget);
      expect(find.text('5件'), findsOneWidget);
      expect(find.text('データ引継ぎ可'), findsOneWidget);

      await tester.ensureVisible(find.text('無料で始める（30秒）'));
      await tester.tap(find.text('無料で始める（30秒）'));
      await tester.ensureVisible(find.text('Notion からインポート'));
      await tester.tap(find.text('Notion からインポート'));
      await tester.pump();

      expect(primaryTapped, 1);
      expect(secondaryTapped, 1);
    });

    testWidgets(
        'renders non-import fallback state without overflow @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          ComparisonHeroSection(
            competitorName: 'Slack',
            emoji: '💬',
            searchKeyword: 'Slack 代替',
            accentColor: const Color(0xFF611F69),
            hasImportSupport: false,
            evidenceStatus: ComparisonEvidenceStatus.unavailable,
            verifiedEvidenceCount: 0,
            withheldLegacyClaimCount: 8,
            primaryButton: FilledButton(
              onPressed: () {},
              child: const Text('無料で始める（30秒）'),
            ),
            secondaryButton: OutlinedButton(
              onPressed: () {},
              child: const Text('ホームで全機能を見る'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0件'), findsOneWidget);
      expect(find.text('30秒で開始'), findsOneWidget);
    });

    testWidgets('renders desktop layout cleanly @ 900x800', (tester) async {
      await tester.binding.setSurfaceSize(desktopViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          desktopViewport,
          1.0,
          ComparisonHeroSection(
            competitorName: 'Evernote',
            emoji: '🐘',
            searchKeyword: 'Evernote 代替',
            accentColor: const Color(0xFF00A82D),
            hasImportSupport: true,
            evidenceStatus: ComparisonEvidenceStatus.loaded,
            verifiedEvidenceCount: 4,
            withheldLegacyClaimCount: 2,
            primaryButton: FilledButton(
              onPressed: () {},
              child: const Text('無料で始める（30秒）'),
            ),
            secondaryButton: OutlinedButton(
              onPressed: () {},
              child: const Text('Evernote からインポート'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4件'), findsOneWidget);
      expect(find.text('インポート対応'), findsOneWidget);
    });
  });
}
