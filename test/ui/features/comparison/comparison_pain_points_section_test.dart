import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_pain_points_section.dart';

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

  group('ComparisonPainPointsSection', () {
    testWidgets(
        'renders evidence-backed claims with source and verified date @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final claim = CompetitorClaimEvidence(
        competitorId: 'notion',
        claimKey: 'export-markdown-csv',
        claimType: CompetitorClaimType.other,
        claimText: 'Markdown と CSV のエクスポートに対応しています。',
        sourceUri: Uri.parse('https://www.notion.so/help/export-your-content'),
        verifiedAt: DateTime.utc(2026, 11, 27),
      );

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          ComparisonPainPointsSection(
            competitorName: 'Notion',
            painPoints: const ['検索が散らかりやすい', '通知が多すぎる'],
            showLegacyClaims: false,
            evidenceStatus: ComparisonEvidenceStatus.loaded,
            otherEvidence: [claim],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ComparisonPainPointsSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text('根拠確認済みの比較情報'), findsOneWidget);
      expect(
        find.text('Markdown と CSV のエクスポートに対応しています。'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-11-27'), findsOneWidget);
    });

    testWidgets(
        'renders stacked legacy pain points without overflow @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          const ComparisonPainPointsSection(
            competitorName: 'Notion',
            painPoints: ['階層が深くなりがち', '朝の1件が見えにくい'],
            showLegacyClaims: true,
            evidenceStatus: ComparisonEvidenceStatus.unavailable,
            otherEvidence: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notion を使っていて詰まりやすいポイント'), findsOneWidget);
      expect(find.text('1. 階層が深くなりがち'), findsOneWidget);
      expect(find.text('2. 朝の1件が見えにくい'), findsOneWidget);
    });

    testWidgets('renders desktop row layout @ 900x800', (tester) async {
      await tester.binding.setSurfaceSize(desktopViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          desktopViewport,
          1.0,
          const ComparisonPainPointsSection(
            competitorName: 'Evernote',
            painPoints: ['検索に時間がかかる', '管理コストが増える'],
            showLegacyClaims: true,
            evidenceStatus: ComparisonEvidenceStatus.unavailable,
            otherEvidence: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Row), findsOneWidget);
      expect(find.text('1. 検索に時間がかかる'), findsOneWidget);
      expect(find.text('2. 管理コストが増える'), findsOneWidget);
    });
  });
}
