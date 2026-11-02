import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/corporate_site_readiness_service.dart';

void main() {
  const input = CorporateSiteReadinessInput(
    url: 'https://example.com/company',
    companyName: '株式会社テスト',
    representativeName: '山田 太郎',
    registeredAddress: '東京都千代田区1-1-1',
    businessPlanSummary: '中小企業向けにWeb制作を月額で提供します。',
    contact: 'hello@example.com',
    wbsMilestones: <String>['β版公開', '初回納品'],
    virtualOffice: true,
  );

  test('review sends the authenticated AI Hub action and parses missing items',
      () async {
    Map<String, dynamic>? request;
    final service = CorporateSiteReadinessService(
      invoker: (body) async {
        request = body;
        return <String, dynamic>{
          'success': true,
          'source': <String, dynamic>{
            'canonical_url': 'https://example.com/company',
            'title': '会社概要',
          },
          'result': <String, dynamic>{
            'ready_for_document_review': false,
            'score': 50,
            'missing_required_items': <String>['representative_name'],
            'manual_review_items': <String>['operating_evidence'],
            'disclaimer': '審査通過を保証しません。',
            'checks': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'representative_name',
                'label': '代表者名',
                'status': 'missing',
                'required': true,
                'evidence': null,
                'guidance': '代表者名を掲載してください。',
              },
            ],
          },
        };
      },
    );

    final report = await service.review(input);

    expect(request?['action'], 'corporate_site.readiness');
    expect(request?['mode'], 'review');
    expect(request?['virtual_office'], isTrue);
    expect(request?['wbs_milestones'], <String>['β版公開', '初回納品']);
    expect(report.readyForDocumentReview, isFalse);
    expect(report.missingRequiredItems, <String>['representative_name']);
    expect(report.checks.single.isMissing, isTrue);
  });

  test('generateHtml returns generated markup and rejects an empty response',
      () async {
    final service = CorporateSiteReadinessService(
      invoker: (body) async => <String, dynamic>{
        'success': true,
        'html': body['mode'] == 'generate' ? '<!doctype html>' : '',
      },
    );
    expect(await service.generateHtml(input), '<!doctype html>');

    final emptyService = CorporateSiteReadinessService(
      invoker: (_) async => <String, dynamic>{'success': true, 'html': ''},
    );
    await expectLater(
      emptyService.generateHtml(input),
      throwsFormatException,
    );
  });

  test('failed AI Hub payload surfaces its safe error message', () async {
    final service = CorporateSiteReadinessService(
      invoker: (_) async => <String, dynamic>{
        'success': false,
        'message': 'Source URL is invalid',
      },
    );
    await expectLater(
      service.review(input),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Source URL is invalid',
        ),
      ),
    );
  });
}
