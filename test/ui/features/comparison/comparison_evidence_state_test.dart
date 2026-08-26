import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/services/competitor_claim_evidence_repository.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_evidence_section.dart';

void main() {
  group('CompetitorClaimEvidence', () {
    test('accepts complete auditable evidence', () {
      final evidence = CompetitorClaimEvidence.tryFromJson({
        'competitor_id': 'notion',
        'claim_key': 'pricing-free-plan',
        'claim_type': 'pricing',
        'claim_text': '無料プランの公開条件は公式料金ページで確認できます。',
        'source_url': 'https://www.notion.com/pricing',
        'verified_at': '2026-08-25T12:00:00+09:00',
      });

      expect(evidence, isNotNull);
      expect(evidence!.claimType, CompetitorClaimType.pricing);
      expect(evidence.sourceUri.host, 'www.notion.com');
      expect(evidence.verifiedAt.isUtc, isTrue);
    });

    test('withholds incomplete or non-http evidence', () {
      expect(
        CompetitorClaimEvidence.tryFromJson({
          'competitor_id': 'notion',
          'claim_key': 'pricing',
          'claim_type': 'pricing',
          'claim_text': 'claim',
          'source_url': 'javascript:alert(1)',
          'verified_at': '2026-08-25T00:00:00Z',
        }),
        isNull,
      );
      expect(
        CompetitorClaimEvidence.tryFromJson({
          'competitor_id': 'notion',
          'claim_key': 'pricing',
          'claim_type': 'pricing',
          'claim_text': 'claim',
          'source_url': 'https://example.com',
        }),
        isNull,
      );
    });
  });

  group('ComparisonEvidenceViewModel', () {
    test('loads verified rows and normalizes repository state', () async {
      final evidence = _evidence();
      final viewModel = ComparisonEvidenceViewModel(
        repository: _FakeEvidenceRepository(result: [evidence]),
      );

      await viewModel.load('notion');

      expect(viewModel.status, ComparisonEvidenceStatus.loaded);
      expect(viewModel.claims, [evidence]);
      viewModel.dispose();
    });

    test('fails closed without retaining fallback claims', () async {
      final viewModel = ComparisonEvidenceViewModel(
        repository: _FakeEvidenceRepository(error: Exception('offline')),
      );

      await viewModel.load('notion');

      expect(viewModel.status, ComparisonEvidenceStatus.unavailable);
      expect(viewModel.claims, isEmpty);
      viewModel.dispose();
    });
  });

  group('ComparisonEvidenceSection', () {
    testWidgets('explains that unavailable evidence is publicly withheld', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFF080812),
            body: ComparisonEvidenceSection(
              title: '比較情報',
              status: ComparisonEvidenceStatus.unavailable,
              claims: [],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('comparison-evidence-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('公開保留'), findsOneWidget);
    });

    testWidgets('renders claim, verification date, and source action', (
      tester,
    ) async {
      Uri? launched;
      final evidence = _evidence();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF080812),
            body: ComparisonEvidenceSection(
              title: '比較情報',
              status: ComparisonEvidenceStatus.loaded,
              claims: [evidence],
              sourceLauncher: (uri) async {
                launched = uri;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.text(evidence.claimText), findsOneWidget);
      expect(find.text('確認日: 2026-08-25'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('comparison-evidence-source-pricing')),
      );
      await tester.pump();
      expect(launched, evidence.sourceUri);
    });
  });

  test('migration requires evidence metadata without seeding claims', () {
    final migration = File(
      'supabase/migrations/'
      '20260826090000_create_competitor_claim_evidence.sql',
    ).readAsStringSync();

    expect(migration, contains('source_url text not null'));
    expect(migration, contains('verified_at timestamptz not null'));
    expect(migration, contains('enable row level security'));
    expect(migration.toLowerCase(), isNot(contains('insert into')));
  });
}

CompetitorClaimEvidence _evidence() => CompetitorClaimEvidence(
      competitorId: 'notion',
      claimKey: 'pricing',
      claimType: CompetitorClaimType.pricing,
      claimText: '公式料金ページで確認した比較情報です。',
      sourceUri: Uri.parse('https://www.notion.com/pricing'),
      verifiedAt: DateTime.utc(2026, 8, 25),
    );

class _FakeEvidenceRepository implements CompetitorClaimEvidenceRepository {
  const _FakeEvidenceRepository({this.result = const [], this.error});

  final List<CompetitorClaimEvidence> result;
  final Exception? error;

  @override
  Future<List<CompetitorClaimEvidence>> fetchForCompetitor(
    String competitorId,
  ) async {
    if (error != null) {
      throw error!;
    }
    return result;
  }
}
