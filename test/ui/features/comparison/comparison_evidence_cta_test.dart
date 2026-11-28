import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_cta_panel.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_evidence_section.dart';

void main() {
  test('CompetitorClaimEvidence.tryFromJson filters uncited or undated claims',
      () {
    final valid = CompetitorClaimEvidence.tryFromJson({
      'competitor_id': 'notion',
      'claim_key': 'free-tier',
      'claim_type': 'pricing',
      'claim_text': '公式料金ページで無料プラン条件を確認',
      'source_url': 'https://www.notion.so/pricing',
      'verified_at': '2026-11-26T00:00:00Z',
    });
    expect(valid, isNotNull);

    final missingSource = CompetitorClaimEvidence.tryFromJson({
      'competitor_id': 'notion',
      'claim_key': 'unverified-1',
      'claim_type': 'pricing',
      'claim_text': '根拠なし主張',
      'source_url': '',
      'verified_at': '2026-11-26T00:00:00Z',
    });
    expect(missingSource, isNull);

    final missingDate = CompetitorClaimEvidence.tryFromJson({
      'competitor_id': 'notion',
      'claim_key': 'unverified-2',
      'claim_type': 'pricing',
      'claim_text': '確認日なし主張',
      'source_url': 'https://www.notion.so/pricing',
      'verified_at': '',
    });
    expect(missingDate, isNull);
  });

  testWidgets(
    'ComparisonEvidenceSection and ComparisonCtaPanel render at 360x800 @ 2.0x and fire CTA callback',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var ctaRecorded = false;
      final claim = CompetitorClaimEvidence(
        competitorId: 'notion',
        claimKey: 'pricing-check',
        claimType: CompetitorClaimType.pricing,
        claimText: '公式料金ページで無料プラン条件を確認済み',
        sourceUri: Uri.parse('https://www.notion.so/pricing'),
        verifiedAt: DateTime.utc(2026, 11, 26),
      );

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/comparison',
          routes: {
            '/': (_) => const Scaffold(body: Text('home destination')),
            '/comparison': (_) => MediaQuery(
                  data:
                      const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                  child: Scaffold(
                    backgroundColor: const Color(0xFF0B1120),
                    body: SingleChildScrollView(
                      child: Column(
                        children: [
                          ComparisonEvidenceSection(
                            title: '根拠確認済みの機能比較',
                            status: ComparisonEvidenceStatus.loaded,
                            claims: [claim],
                          ),
                          ComparisonCtaPanel(
                            competitorName: 'Notion',
                            accentColor: const Color(0xFF3D5AFE),
                            hasImportSupport: true,
                            onPrimaryCtaTap: () async {
                              ctaRecorded = true;
                              throw StateError(
                                'non-blocking telemetry failure',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('公式料金ページで無料プラン条件を確認済み'), findsOneWidget);
      expect(find.textContaining('2026-11-26'), findsOneWidget);
      expect(find.textContaining('notion.so'), findsOneWidget);

      final ctaFinder = find.byKey(ComparisonCtaPanel.primaryButtonKey);
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      expect(ctaRecorded, isTrue);
      expect(find.text('home destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
