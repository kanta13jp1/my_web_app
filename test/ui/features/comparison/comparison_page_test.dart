import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/pages/comparison_page.dart';
import 'package:my_web_app/services/competitor_claim_evidence_repository.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_cta_panel.dart';

void main() {
  testWidgets('Notion route displays evidence and records one arrival', (
    tester,
  ) async {
    final touches = <String>[];
    final repository = _EvidenceRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonPage(
          competitorKey: 'notion',
          evidenceRepository: repository,
          touchRecorder: (key) async => touches.add(key),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.requestedKeys, ['notion']);
    expect(touches, ['notion']);
    expect(find.textContaining('Notion の代わりに'), findsOneWidget);
    expect(find.text('根拠確認済みの機能比較'), findsOneWidget);
    expect(find.text('両サービスの共有機能について確認した記録'), findsOneWidget);
    expect(find.text('Notionの無料プランはページ数に制限がある'), findsNothing);
    await tester.pump();
    expect(touches, ['notion']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown route keeps fallback and withholds failed evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonPage(
          competitorKey: 'unknown-service',
          evidenceRepository: _EvidenceRepository(fail: true),
          touchRecorder: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('競合サービス の代わりに'), findsOneWidget);
    expect(find.byKey(const Key('comparison-evidence-unavailable')),
        findsNWidgets(2));
    expect(find.text('複数サービスへのログインが面倒'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final hasImport in [true, false]) {
    testWidgets('secondary CTA routes correctly with import=$hasImport', (
      tester,
    ) async {
      await tester.pumpWidget(_ctaApp(hasImport: hasImport));
      await tester.tap(find.byKey(ComparisonCtaPanel.secondaryButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(hasImport ? 'import destination' : 'home destination'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('primary CTA returns home and removes comparison route', (
    tester,
  ) async {
    await tester.pumpWidget(_ctaApp(hasImport: true));
    await tester.tap(find.byKey(ComparisonCtaPanel.primaryButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('home destination'), findsOneWidget);
    expect(find.byType(ComparisonCtaPanel), findsNothing);
    expect(Navigator.of(tester.element(find.text('home destination'))).canPop(),
        isFalse);
  });
}

Widget _ctaApp({required bool hasImport}) => MaterialApp(
      initialRoute: '/comparison',
      routes: {
        '/': (_) => const Scaffold(body: Text('home destination')),
        '/import': (_) => const Scaffold(body: Text('import destination')),
        '/comparison': (_) => Scaffold(
              body: SingleChildScrollView(
                child: ComparisonCtaPanel(
                  competitorName: hasImport ? 'Notion' : 'Slack',
                  accentColor: Colors.indigo,
                  hasImportSupport: hasImport,
                ),
              ),
            ),
      },
    );

class _EvidenceRepository implements CompetitorClaimEvidenceRepository {
  _EvidenceRepository({this.fail = false});

  final bool fail;
  final requestedKeys = <String>[];

  @override
  Future<List<CompetitorClaimEvidence>> fetchForCompetitor(String key) async {
    requestedKeys.add(key);
    if (fail) throw Exception('offline fixture');
    return [
      CompetitorClaimEvidence(
        competitorId: key,
        claimKey: 'shared-feature',
        claimType: CompetitorClaimType.feature,
        claimText: '両サービスの共有機能について確認した記録',
        sourceUri: Uri.parse('https://example.com/evidence'),
        verifiedAt: DateTime.utc(2026, 9, 1),
      ),
    ];
  }
}
