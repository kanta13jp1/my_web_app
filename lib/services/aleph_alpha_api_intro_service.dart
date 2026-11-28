/// Aleph Alpha API 入門講座の根拠完全性と、固定 fixture / sandbox 限定の
/// 初回リクエスト課題の契約を扱う純粋サービス（UI / ネットワーク非依存）。
///
/// 実際のアクセス情報の入力は受け付けない。評価は構造の検証のみで、
/// 実 API の動作や継続利用の妥当性を保証しない。
library;

/// 根拠 URL の遷移先の検証結果。
enum AlephAlphaApiIntroDestinationStatus {
  /// 遷移先に初回 API リクエストの手順がある。
  verifiedFirstRequest('verified_first_request'),

  /// 製品ホームへ転送され、初回 API リクエストの手順を確認できない。
  redirectedToProductHome('redirected_to_product_home'),

  /// 到達できない。
  unreachable('unreachable'),

  /// まだ検証していない。
  unverified('unverified');

  const AlephAlphaApiIntroDestinationStatus(this.wireName);

  final String wireName;
}

enum AlephAlphaApiIntroGoNoGo {
  go('go'),
  noGo('no_go');

  const AlephAlphaApiIntroGoNoGo(this.wireName);

  final String wireName;
}

/// 講座行の根拠完全性契約。
///
/// `evidenceComplete` は 5 項目と遷移先検証から厳密に導出され、
/// 遷移先が初回 API リクエストを含まない限り `true` にならない。
class AlephAlphaApiIntroEvidenceContract {
  const AlephAlphaApiIntroEvidenceContract({
    this.targetAudience,
    this.observableLearningOutcome,
    this.assessmentVerificationMethod,
    this.evidenceSourceUrl,
    this.evidenceVerifiedAt,
    this.destinationStatus = AlephAlphaApiIntroDestinationStatus.unverified,
  });

  final String? targetAudience;
  final String? observableLearningOutcome;
  final String? assessmentVerificationMethod;
  final String? evidenceSourceUrl;
  final DateTime? evidenceVerifiedAt;
  final AlephAlphaApiIntroDestinationStatus destinationStatus;

  bool get destinationContainsFirstApiRequest =>
      destinationStatus ==
      AlephAlphaApiIntroDestinationStatus.verifiedFirstRequest;

  bool get hasValidSourceUrl {
    final raw = (evidenceSourceUrl ?? '').trim();
    if (raw.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(raw);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  bool get evidenceComplete =>
      (targetAudience ?? '').trim().isNotEmpty &&
      (observableLearningOutcome ?? '').trim().isNotEmpty &&
      (assessmentVerificationMethod ?? '').trim().isNotEmpty &&
      hasValidSourceUrl &&
      evidenceVerifiedAt != null &&
      destinationContainsFirstApiRequest;

  List<String> validate() {
    final errors = <String>[];
    if ((targetAudience ?? '').trim().isEmpty) {
      errors.add('target_audience_required');
    }
    if ((observableLearningOutcome ?? '').trim().isEmpty) {
      errors.add('observable_learning_outcome_required');
    }
    if ((assessmentVerificationMethod ?? '').trim().isEmpty) {
      errors.add('assessment_verification_method_required');
    }
    if (!hasValidSourceUrl) {
      errors.add('evidence_source_https_url_required');
    }
    if (evidenceVerifiedAt == null) {
      errors.add('evidence_verified_at_required');
    }
    switch (destinationStatus) {
      case AlephAlphaApiIntroDestinationStatus.verifiedFirstRequest:
        break;
      case AlephAlphaApiIntroDestinationStatus.redirectedToProductHome:
        errors.add('destination_lacks_first_api_request');
        break;
      case AlephAlphaApiIntroDestinationStatus.unreachable:
        errors.add('destination_unreachable');
        break;
      case AlephAlphaApiIntroDestinationStatus.unverified:
        errors.add('destination_not_verified');
        break;
    }
    return List<String>.unmodifiable(errors);
  }
}

/// 固定 fixture 上のリクエスト構造。
class AlephAlphaApiRequestSpec {
  const AlephAlphaApiRequestSpec({
    required this.endpoint,
    required this.method,
    required this.payloadKeys,
    required this.authHeaderPlaceholder,
  });

  final String endpoint;
  final String method;
  final List<String> payloadKeys;

  /// 実際の値ではなくプレースホルダ（例: `<ACCESS_VALUE>`）のみ許可する。
  final String authHeaderPlaceholder;
}

/// 期待レスポンスのスキーマ（キー名のみ）。
class AlephAlphaApiResponseSchema {
  const AlephAlphaApiResponseSchema({
    required this.requiredKeys,
  });

  final List<String> requiredKeys;
}

/// 代表エラーケース 1 件。
class AlephAlphaApiErrorCase {
  const AlephAlphaApiErrorCase({
    required this.statusCode,
    required this.expectedHandling,
  });

  final int statusCode;
  final String expectedHandling;
}

/// 利用継続の go / no-go メモ。
class AlephAlphaApiContinuationMemo {
  const AlephAlphaApiContinuationMemo({
    required this.decision,
    required this.reason,
  });

  final AlephAlphaApiIntroGoNoGo decision;
  final String reason;
}

/// API 入門の fixture / sandbox 限定課題。
class AlephAlphaApiIntroAssessment {
  const AlephAlphaApiIntroAssessment({
    required this.usesFixtureOnly,
    required this.request,
    required this.responseSchema,
    required this.errorCases,
    required this.continuationMemo,
  });

  final bool usesFixtureOnly;
  final AlephAlphaApiRequestSpec request;
  final AlephAlphaApiResponseSchema responseSchema;
  final List<AlephAlphaApiErrorCase> errorCases;
  final AlephAlphaApiContinuationMemo continuationMemo;
}

class AlephAlphaApiIntroValidation {
  const AlephAlphaApiIntroValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class AlephAlphaApiIntroService {
  const AlephAlphaApiIntroService();

  static const Set<String> allowedMethods = <String>{'GET', 'POST'};

  static final RegExp _placeholderPattern = RegExp(r'^<[A-Z][A-Z_ ]*>$');

  /// 課題の構造を検証する。実際のアクセス情報の入力は拒否する。
  AlephAlphaApiIntroValidation validateAssessment(
    AlephAlphaApiIntroAssessment assessment,
  ) {
    final errors = <String>[];
    if (!assessment.usesFixtureOnly) {
      errors.add('fixture_only_required');
    }

    final request = assessment.request;
    final endpoint = Uri.tryParse(request.endpoint.trim());
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty) {
      errors.add('endpoint_https_url_required');
    }
    if (!allowedMethods.contains(request.method.trim().toUpperCase())) {
      errors.add('method_must_be_get_or_post');
    }
    final payloadKeys = request.payloadKeys.map((key) => key.trim()).toList();
    if (payloadKeys.any((key) => key.isEmpty)) {
      errors.add('payload_key_must_not_be_blank');
    }
    if (payloadKeys.toSet().length != payloadKeys.length) {
      errors.add('payload_keys_must_be_unique');
    }
    if (request.method.trim().toUpperCase() == 'POST' && payloadKeys.isEmpty) {
      errors.add('post_requires_payload_keys');
    }
    if (!_placeholderPattern.hasMatch(request.authHeaderPlaceholder.trim())) {
      errors.add('live_access_input_forbidden_use_placeholder');
    }

    final responseKeys = assessment.responseSchema.requiredKeys
        .map((key) => key.trim())
        .toList();
    if (responseKeys.isEmpty || responseKeys.any((key) => key.isEmpty)) {
      errors.add('response_schema_requires_non_blank_keys');
    }

    errors.addAll(_validateErrorCases(assessment.errorCases));

    if (assessment.continuationMemo.reason.trim().isEmpty) {
      errors.add('continuation_reason_required');
    }
    return AlephAlphaApiIntroValidation(List<String>.unmodifiable(errors));
  }

  List<String> _validateErrorCases(List<AlephAlphaApiErrorCase> cases) {
    final errors = <String>[];
    final codes = cases.map((item) => item.statusCode).toList();
    if (!codes.contains(401)) {
      errors.add('error_case_missing_unauthorized_401');
    }
    if (!codes.contains(429)) {
      errors.add('error_case_missing_rate_limit_429');
    }
    if (!codes.any((code) => code >= 500 && code <= 599)) {
      errors.add('error_case_missing_server_error_5xx');
    }
    if (codes.toSet().length != codes.length) {
      errors.add('error_case_status_codes_must_be_unique');
    }
    for (final item in cases) {
      if (item.statusCode < 400 || item.statusCode > 599) {
        errors.add('error_case_status_out_of_range:${item.statusCode}');
      }
      if (item.expectedHandling.trim().isEmpty) {
        errors.add('error_case_handling_required:${item.statusCode}');
      }
    }
    return errors;
  }
}
