import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/aleph_alpha_api_intro_service.dart';

final DateTime _verified = DateTime.utc(2026, 11, 20);

AlephAlphaApiIntroEvidenceContract _evidence({
  AlephAlphaApiIntroDestinationStatus status =
      AlephAlphaApiIntroDestinationStatus.verifiedFirstRequest,
  String? audience = 'アプリ開発者',
  String? url =
      'https://docs.aleph-alpha.com/docs/introduction/getting-started/',
}) {
  return AlephAlphaApiIntroEvidenceContract(
    targetAudience: audience,
    observableLearningOutcome: '最小リクエストで初回レスポンスを得られる',
    assessmentVerificationMethod: '固定fixtureの構造採点',
    evidenceSourceUrl: url,
    evidenceVerifiedAt: _verified,
    destinationStatus: status,
  );
}

AlephAlphaApiIntroAssessment _assessment({
  bool fixtureOnly = true,
  String endpoint = 'https://api.example.test/v1/complete',
  String method = 'POST',
  List<String> payloadKeys = const <String>['model', 'prompt'],
  String placeholder = '<ACCESS_VALUE>',
  List<String> responseKeys = const <String>['completions'],
  List<AlephAlphaApiErrorCase>? errorCases,
  String reason = '構造が揃っているため継続可',
}) {
  return AlephAlphaApiIntroAssessment(
    usesFixtureOnly: fixtureOnly,
    request: AlephAlphaApiRequestSpec(
      endpoint: endpoint,
      method: method,
      payloadKeys: payloadKeys,
      authHeaderPlaceholder: placeholder,
    ),
    responseSchema: AlephAlphaApiResponseSchema(requiredKeys: responseKeys),
    errorCases: errorCases ??
        const <AlephAlphaApiErrorCase>[
          AlephAlphaApiErrorCase(
            statusCode: 401,
            expectedHandling: '設定を確認して再試行しない',
          ),
          AlephAlphaApiErrorCase(
            statusCode: 429,
            expectedHandling: '待機後に間隔を空けて再試行',
          ),
          AlephAlphaApiErrorCase(
            statusCode: 503,
            expectedHandling: '利用者へ失敗を伝え成功扱いしない',
          ),
        ],
    continuationMemo: AlephAlphaApiContinuationMemo(
      decision: AlephAlphaApiIntroGoNoGo.go,
      reason: reason,
    ),
  );
}

void main() {
  const service = AlephAlphaApiIntroService();

  group('evidence contract', () {
    test('complete only when five fields exist and destination verifies', () {
      final complete = _evidence();
      expect(complete.destinationContainsFirstApiRequest, isTrue);
      expect(complete.evidenceComplete, isTrue);
      expect(complete.validate(), isEmpty);
    });

    test('current public row (all null) is never complete', () {
      const empty = AlephAlphaApiIntroEvidenceContract();
      expect(empty.evidenceComplete, isFalse);
      expect(
        empty.validate(),
        containsAll(<String>[
          'target_audience_required',
          'observable_learning_outcome_required',
          'assessment_verification_method_required',
          'evidence_source_https_url_required',
          'evidence_verified_at_required',
          'destination_not_verified',
        ]),
      );
    });

    test('redirect to product home blocks completeness', () {
      final redirected = _evidence(
        status: AlephAlphaApiIntroDestinationStatus.redirectedToProductHome,
      );
      expect(redirected.destinationContainsFirstApiRequest, isFalse);
      expect(redirected.evidenceComplete, isFalse);
      expect(
        redirected.validate(),
        contains('destination_lacks_first_api_request'),
      );
    });

    test('unreachable destination, blank audience, and http URL fail', () {
      final unreachable = _evidence(
        status: AlephAlphaApiIntroDestinationStatus.unreachable,
      );
      expect(unreachable.evidenceComplete, isFalse);
      expect(unreachable.validate(), contains('destination_unreachable'));

      final blank = _evidence(audience: '  ', url: 'http://docs.example.test/');
      expect(blank.evidenceComplete, isFalse);
      expect(
        blank.validate(),
        containsAll(<String>[
          'target_audience_required',
          'evidence_source_https_url_required',
        ]),
      );
    });
  });

  group('fixture-only assessment', () {
    test('accepts a well-formed fixture assessment', () {
      expect(service.validateAssessment(_assessment()).errors, isEmpty);
    });

    test('rejects live access input and non-fixture assessments', () {
      final live = _assessment(
        fixtureOnly: false,
        placeholder: 'abcd-1234-real-value',
      );
      final errors = service.validateAssessment(live).errors;
      expect(
        errors,
        containsAll(<String>[
          'fixture_only_required',
          'live_access_input_forbidden_use_placeholder',
        ]),
      );
    });

    test('validates request structure and response schema', () {
      final bad = _assessment(
        endpoint: 'http://api.example.test/v1',
        method: 'DELETE',
        payloadKeys: const <String>['model', 'model', ' '],
        responseKeys: const <String>[],
      );
      final errors = service.validateAssessment(bad).errors;
      expect(
        errors,
        containsAll(<String>[
          'endpoint_https_url_required',
          'method_must_be_get_or_post',
          'payload_key_must_not_be_blank',
          'payload_keys_must_be_unique',
          'response_schema_requires_non_blank_keys',
        ]),
      );

      final postWithoutPayload = _assessment(payloadKeys: const <String>[]);
      expect(
        service.validateAssessment(postWithoutPayload).errors,
        contains('post_requires_payload_keys'),
      );
    });

    test('requires representative error cases and a continuation reason', () {
      final missing = _assessment(
        errorCases: const <AlephAlphaApiErrorCase>[
          AlephAlphaApiErrorCase(statusCode: 404, expectedHandling: ' '),
          AlephAlphaApiErrorCase(statusCode: 404, expectedHandling: '確認'),
          AlephAlphaApiErrorCase(statusCode: 200, expectedHandling: '不正'),
        ],
        reason: ' ',
      );
      final errors = service.validateAssessment(missing).errors;
      expect(
        errors,
        containsAll(<String>[
          'error_case_missing_unauthorized_401',
          'error_case_missing_rate_limit_429',
          'error_case_missing_server_error_5xx',
          'error_case_status_codes_must_be_unique',
          'error_case_status_out_of_range:200',
          'error_case_handling_required:404',
          'continuation_reason_required',
        ]),
      );
    });
  });
}
