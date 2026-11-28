import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_feature_table_section.dart';

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

  group('ComparisonFeatureTableSection', () {
    testWidgets(
        'renders evidence-backed feature claims with verified date @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final claim = CompetitorClaimEvidence(
        competitorId: 'notion',
        claimKey: 'feature-ai-assistant',
        claimType: CompetitorClaimType.feature,
        claimText: 'AI によるタスク整理と要約機能を提供しています。',
        sourceUri: Uri.parse('https://www.notion.so/product/ai'),
        verifiedAt: DateTime.utc(2026, 11, 28),
      );

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          ComparisonFeatureTableSection(
            competitorName: 'Notion',
            accentColor: const Color(0xFF00C4CC),
            features: const [],
            showLegacyClaims: false,
            evidenceStatus: ComparisonEvidenceStatus.loaded,
            featureEvidence: [claim],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ComparisonFeatureTableSection.sectionKey),
        findsOneWidget,
      );
      expect(find.text('根拠確認済みの機能比較'), findsOneWidget);
      expect(find.text('AI によるタスク整理と要約機能を提供しています。'), findsOneWidget);
      expect(find.textContaining('2026-11-28'), findsOneWidget);
    });

    testWidgets(
        'renders compact feature comparison cards without overflow @ 360x800 2.0x',
        (tester) async {
      await tester.binding.setSurfaceSize(mobileViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          mobileViewport,
          2.0,
          const ComparisonFeatureTableSection(
            competitorName: 'Notion',
            accentColor: Color(0xFF00C4CC),
            features: [
              ComparisonFeatureRowItem(
                feature: 'Markdown ノート管理',
                competitorHas: true,
                weHave: true,
              ),
              ComparisonFeatureRowItem(
                feature: '家計・資産との統合管理',
                competitorHas: false,
                weHave: true,
              ),
            ],
            showLegacyClaims: true,
            evidenceStatus: ComparisonEvidenceStatus.unavailable,
            featureEvidence: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('機能比較'), findsOneWidget);
      expect(find.text('Markdown ノート管理'), findsOneWidget);
      expect(find.text('家計・資産との統合管理'), findsOneWidget);
    });

    testWidgets('renders desktop table rows @ 900x800', (tester) async {
      await tester.binding.setSurfaceSize(desktopViewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        wrapViewport(
          desktopViewport,
          1.0,
          const ComparisonFeatureTableSection(
            competitorName: 'Evernote',
            accentColor: Color(0xFF00A82D),
            features: [
              ComparisonFeatureRowItem(
                feature: '公開メモ共有',
                competitorHas: true,
                weHave: true,
              ),
            ],
            showLegacyClaims: true,
            evidenceStatus: ComparisonEvidenceStatus.unavailable,
            featureEvidence: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('比較項目'), findsOneWidget);
      expect(find.text('公開メモ共有'), findsOneWidget);
    });
  });
}
