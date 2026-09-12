import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/corporate_site_readiness_page.dart';
import 'package:my_web_app/services/corporate_site_readiness_service.dart';

void main() {
  testWidgets('shows missing required company information after review',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      MaterialApp(home: CorporateSiteReadinessPage(gateway: gateway)),
    );

    await _fillRequiredFields(tester);
    final reviewButton = find.byKey(const Key('corporate-review-button'));
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(gateway.reviewed?.companyName, '株式会社テスト');
    expect(find.byKey(const Key('corporate-readiness-report')), findsOneWidget);
    expect(find.text('不足している必須記載があります'), findsOneWidget);
    expect(find.textContaining('代表者名 — 不足'), findsOneWidget);
    expect(find.textContaining('審査通過を保証しません'), findsWidgets);
  });

  testWidgets('generates selectable HTML from business plan and WBS',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();
    await tester.pumpWidget(
      MaterialApp(home: CorporateSiteReadinessPage(gateway: gateway)),
    );

    await _fillRequiredFields(tester);
    await tester.enterText(
      find.byKey(const Key('corporate-wbs')),
      'β版公開\n初回顧客へ納品',
    );
    await tester.enterText(
      find.byKey(const Key('corporate-contact')),
      'hello@example.com',
    );
    final button = find.byKey(const Key('corporate-generate-button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(gateway.generated?.wbsMilestones, <String>['β版公開', '初回顧客へ納品']);
    expect(find.byKey(const Key('corporate-generated-html')), findsOneWidget);
    expect(find.textContaining('<!doctype html>'), findsOneWidget);
  });
}

Future<void> _fillRequiredFields(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('corporate-site-url')),
    'https://example.com/company',
  );
  await tester.enterText(
    find.byKey(const Key('corporate-company-name')),
    '株式会社テスト',
  );
  await tester.enterText(
    find.byKey(const Key('corporate-representative-name')),
    '山田 太郎',
  );
  await tester.enterText(
    find.byKey(const Key('corporate-registered-address')),
    '東京都千代田区1-1-1',
  );
  await tester.enterText(
    find.byKey(const Key('corporate-business-plan')),
    '中小企業向けにWeb制作サービスを月額で提供します。',
  );
}

class _FakeGateway implements CorporateSiteReadinessGateway {
  CorporateSiteReadinessInput? reviewed;
  CorporateSiteReadinessInput? generated;

  @override
  Future<String> generateHtml(CorporateSiteReadinessInput input) async {
    generated = input;
    return '<!doctype html><html><body>株式会社テスト</body></html>';
  }

  @override
  Future<CorporateSiteReadinessReport> review(
    CorporateSiteReadinessInput input,
  ) async {
    reviewed = input;
    return const CorporateSiteReadinessReport(
      readyForDocumentReview: false,
      score: 75,
      checks: <CorporateSiteReadinessCheck>[
        CorporateSiteReadinessCheck(
          id: 'company_name',
          label: '登記上の法人名',
          status: 'present',
          required: true,
          evidence: '法人名 株式会社テスト',
          guidance: '',
        ),
        CorporateSiteReadinessCheck(
          id: 'representative_name',
          label: '代表者名',
          status: 'missing',
          required: true,
          guidance: '代表者名を掲載してください。',
        ),
      ],
      missingRequiredItems: <String>['representative_name'],
      manualReviewItems: <String>['operating_evidence'],
      disclaimer: 'この結果は審査通過を保証しません。',
      canonicalUrl: 'https://example.com/company',
      sourceTitle: '会社概要',
    );
  }
}
