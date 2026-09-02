import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/video_studio_models.dart';

class VideoStudioException implements Exception {
  const VideoStudioException(this.code, [this.message]);

  factory VideoStudioException.fromFunctionException(FunctionException error) {
    final details = videoStudioMap(error.details);
    final code = details['error']?.toString().trim();
    final message = details['message']?.toString().trim();
    return VideoStudioException(
      code == null || code.isEmpty ? 'http_${error.status}' : code,
      message == null || message.isEmpty ? error.reasonPhrase : message,
    );
  }

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

abstract class VideoStudioGateway {
  Future<VideoStudioCatalog> loadCatalog();

  Future<VideoCreditBalance> loadBalance();

  Future<List<VideoGenerationJob>> listJobs();

  Future<List<VideoImprovementAuthorization>> loadAuthorizations();

  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
    String? parentArtifactId,
    String? appliedReviewId,
  });

  Future<VideoGenerationJob> refreshJob(String jobId);

  Future<VideoArtifactReviewResult> reviewArtifact({
    required String artifactId,
    required VideoArtifactReviewDraft review,
  });

  Future<VideoAuthorizationCreateResult> authorizeImprovement({
    required String idempotencyKey,
    required String sourceArtifactId,
    required String sourceReviewId,
    required int validityHours,
    required int totalRegenerations,
  });

  Future<VideoAuthorizationCreateResult> runAuthorizedImprovement({
    required String idempotencyKey,
    required String authorizationId,
    required String sourceArtifactId,
    required String sourceReviewId,
  });

  Future<VideoImprovementAuthorization> revokeAuthorization(
    String authorizationId,
  );

  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  });
}

class SupabaseVideoStudioGateway implements VideoStudioGateway {
  SupabaseVideoStudioGateway({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<VideoStudioCatalog> loadCatalog() async {
    final data = await _invokeVideo({'action': 'catalog'});
    return VideoStudioCatalog.fromJson(data);
  }

  @override
  Future<VideoCreditBalance> loadBalance() async {
    final data = await _invokeVideo({'action': 'balance'});
    return VideoCreditBalance.fromJson(videoStudioMap(data['balance']));
  }

  @override
  Future<List<VideoGenerationJob>> listJobs() async {
    final data = await _invokeVideo({'action': 'list'});
    return videoStudioList(data['jobs'])
        .map((value) => VideoGenerationJob.fromJson(videoStudioMap(value)))
        .toList(growable: false);
  }

  @override
  Future<VideoAuthorizationCreateResult> runAuthorizedImprovement({
    required String idempotencyKey,
    required String authorizationId,
    required String sourceArtifactId,
    required String sourceReviewId,
  }) async {
    final data = await _invokeVideo({
      'action': 'run_authorized_improvement',
      'idempotency_key': idempotencyKey,
      'authorization_id': authorizationId,
      'source_artifact_id': sourceArtifactId,
      'source_review_id': sourceReviewId,
    });
    return VideoAuthorizationCreateResult(
      authorization: VideoImprovementAuthorization.fromJson(
        videoStudioMap(data['authorization']),
      ),
      job: data['job'] == null
          ? null
          : VideoGenerationJob.fromJson(videoStudioMap(data['job'])),
      balance: VideoCreditBalance.fromJson(videoStudioMap(data['balance'])),
    );
  }

  @override
  Future<List<VideoImprovementAuthorization>> loadAuthorizations() async {
    final data = await _invokeVideo({'action': 'authorization_status'});
    return videoStudioList(data['authorizations'])
        .map(
          (value) =>
              VideoImprovementAuthorization.fromJson(videoStudioMap(value)),
        )
        .toList(growable: false);
  }

  @override
  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
    String? parentArtifactId,
    String? appliedReviewId,
  }) async {
    final data = await _invokeVideo({
      'action': 'create',
      'idempotency_key': idempotencyKey,
      'model_key': modelKey,
      'prompt': prompt,
      'duration_seconds': durationSeconds,
      'aspect_ratio': aspectRatio,
      'resolution': resolution,
      'rights_confirmed': true,
      'adult_confirmed': true,
      if (parentArtifactId != null) 'parent_artifact_id': parentArtifactId,
      if (appliedReviewId != null) 'applied_review_id': appliedReviewId,
    });
    return VideoCreateResult(
      job: VideoGenerationJob.fromJson(videoStudioMap(data['job'])),
      balance: VideoCreditBalance.fromJson(videoStudioMap(data['balance'])),
    );
  }

  @override
  Future<VideoGenerationJob> refreshJob(String jobId) async {
    final data = await _invokeVideo({'action': 'status', 'job_id': jobId});
    return VideoGenerationJob.fromJson(videoStudioMap(data['job']));
  }

  @override
  Future<VideoArtifactReviewResult> reviewArtifact({
    required String artifactId,
    required VideoArtifactReviewDraft review,
  }) async {
    final data = await _invokeVideo({
      'action': 'review_artifact',
      'artifact_id': artifactId,
      'quality_score': review.qualityScore,
      'prompt_alignment_score': review.promptAlignmentScore,
      'motion_quality_score': review.motionQualityScore,
      'commercial_value_score': review.commercialValueScore,
      'decision': review.decision,
      'strengths': review.strengths,
      'improvement_request': review.improvementRequest,
      'suggested_prompt': review.suggestedPrompt,
      'notes': review.notes,
      'rights_status': review.rightsStatus,
      'privacy_status': review.privacyStatus,
    });
    return VideoArtifactReviewResult(
      artifact: VideoArtifact.fromJson(videoStudioMap(data['artifact'])),
      review: VideoArtifactReview.fromJson(videoStudioMap(data['review'])),
    );
  }

  @override
  Future<VideoAuthorizationCreateResult> authorizeImprovement({
    required String idempotencyKey,
    required String sourceArtifactId,
    required String sourceReviewId,
    required int validityHours,
    required int totalRegenerations,
  }) async {
    final data = await _invokeVideo({
      'action': 'authorize_improvement',
      'idempotency_key': idempotencyKey,
      'source_artifact_id': sourceArtifactId,
      'source_review_id': sourceReviewId,
      'validity_hours': validityHours,
      'total_regenerations': totalRegenerations,
      'rights_confirmed': true,
      'adult_confirmed': true,
      'terms_confirmed': true,
      'prohibited_content_confirmed': true,
    });
    return VideoAuthorizationCreateResult(
      authorization: VideoImprovementAuthorization.fromJson(
        videoStudioMap(data['authorization']),
      ),
      job: data['job'] == null
          ? null
          : VideoGenerationJob.fromJson(videoStudioMap(data['job'])),
      balance: VideoCreditBalance.fromJson(videoStudioMap(data['balance'])),
    );
  }

  @override
  Future<VideoImprovementAuthorization> revokeAuthorization(
    String authorizationId,
  ) async {
    final data = await _invokeVideo({
      'action': 'revoke_authorization',
      'authorization_id': authorizationId,
    });
    return VideoImprovementAuthorization.fromJson(
      videoStudioMap(data['authorization']),
    );
  }

  @override
  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  }) async {
    final response = await _invokeFunction('schedule-hub', {
      'action': 'billing.create_video_credit_checkout_session',
      'pack_key': packKey,
      'return_url': returnUrl,
    });
    final data = videoStudioMap(response.data);
    _throwForResponse(response.status, data);
    final uri = Uri.tryParse(data['checkout_url']?.toString() ?? '');
    if (uri == null || !uri.hasScheme) {
      throw const VideoStudioException('checkout_url_missing');
    }
    return uri;
  }

  Future<Map<String, dynamic>> _invokeVideo(Map<String, dynamic> body) async {
    final response = await _invokeFunction('video-generation-hub', body);
    final data = videoStudioMap(response.data);
    _throwForResponse(response.status, data);
    return data;
  }

  Future<FunctionResponse> _invokeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _client.functions.invoke(functionName, body: body);
    } on FunctionException catch (error) {
      throw VideoStudioException.fromFunctionException(error);
    }
  }

  void _throwForResponse(int status, Map<String, dynamic> data) {
    if (status >= 200 && status < 300 && data['error'] == null) return;
    throw VideoStudioException(
      data['error']?.toString() ?? 'http_$status',
      data['message']?.toString(),
    );
  }
}
