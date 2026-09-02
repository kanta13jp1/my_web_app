class VideoGenerationModelOption {
  const VideoGenerationModelOption({
    required this.key,
    required this.name,
    required this.description,
    required this.durations,
    required this.aspectRatios,
    required this.resolutions,
    required this.creditsPerSecond,
  });

  final String key;
  final String name;
  final String description;
  final List<int> durations;
  final List<String> aspectRatios;
  final List<String> resolutions;
  final int creditsPerSecond;

  factory VideoGenerationModelOption.fromJson(Map<String, dynamic> json) {
    return VideoGenerationModelOption(
      key: _string(json['key']),
      name: _string(json['name']),
      description: _string(json['description']),
      durations: _list(json['durations']).map(_integer).toList(growable: false),
      aspectRatios: _list(
        json['aspect_ratios'],
      ).map(_string).toList(growable: false),
      resolutions: _list(
        json['resolutions'],
      ).map(_string).toList(growable: false),
      creditsPerSecond: _integer(json['credits_per_second']),
    );
  }
}

class VideoCreditPackOption {
  const VideoCreditPackOption({
    required this.key,
    required this.name,
    required this.credits,
    required this.amountJpy,
  });

  final String key;
  final String name;
  final int credits;
  final int amountJpy;

  factory VideoCreditPackOption.fromJson(Map<String, dynamic> json) {
    return VideoCreditPackOption(
      key: _string(json['key']),
      name: _string(json['name']),
      credits: _integer(json['credits']),
      amountJpy: _integer(json['amount_jpy']),
    );
  }
}

class VideoStudioCatalog {
  const VideoStudioCatalog({required this.models, required this.creditPacks});

  final List<VideoGenerationModelOption> models;
  final List<VideoCreditPackOption> creditPacks;

  factory VideoStudioCatalog.fromJson(Map<String, dynamic> json) {
    return VideoStudioCatalog(
      models: _list(json['models'])
          .map((value) => VideoGenerationModelOption.fromJson(_map(value)))
          .toList(growable: false),
      creditPacks: _list(json['credit_packs'])
          .map((value) => VideoCreditPackOption.fromJson(_map(value)))
          .toList(growable: false),
    );
  }
}

class VideoCreditBalance {
  const VideoCreditBalance({
    required this.availableCredits,
    required this.reservedCredits,
    required this.creditDebt,
  });

  static const zero = VideoCreditBalance(
    availableCredits: 0,
    reservedCredits: 0,
    creditDebt: 0,
  );

  final int availableCredits;
  final int reservedCredits;
  final int creditDebt;

  factory VideoCreditBalance.fromJson(Map<String, dynamic> json) {
    return VideoCreditBalance(
      availableCredits: _integer(json['available_credits']),
      reservedCredits: _integer(json['reserved_credits']),
      creditDebt: _integer(json['credit_debt']),
    );
  }
}

class VideoGenerationJob {
  const VideoGenerationJob({
    required this.id,
    required this.modelKey,
    required this.prompt,
    required this.durationSeconds,
    required this.aspectRatio,
    required this.resolution,
    required this.status,
    required this.quotedCredits,
    required this.chargedCredits,
    required this.createdAt,
    this.errorCode,
    this.outputUrl,
    this.outputExpiresAt,
    this.startedAt,
    this.updatedAt,
    this.completedAt,
    this.parentArtifactId,
    this.appliedReviewId,
    this.authorizationId,
    this.artifact,
  });

  final String id;
  final String modelKey;
  final String prompt;
  final int durationSeconds;
  final String aspectRatio;
  final String resolution;
  final String status;
  final int quotedCredits;
  final int chargedCredits;
  final String? errorCode;
  final Uri? outputUrl;
  final DateTime? outputExpiresAt;
  final DateTime? startedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? parentArtifactId;
  final String? appliedReviewId;
  final String? authorizationId;
  final VideoArtifact? artifact;

  bool get isTerminal =>
      status == 'succeeded' || status == 'failed' || status == 'cancelled';
  bool get isSuccessful => status == 'succeeded';

  factory VideoGenerationJob.fromJson(Map<String, dynamic> json) {
    return VideoGenerationJob(
      id: _string(json['id']),
      modelKey: _string(json['model_key']),
      prompt: _string(json['prompt']),
      durationSeconds: _integer(json['duration_seconds']),
      aspectRatio: _string(json['aspect_ratio']),
      resolution: _string(json['resolution']),
      status: _string(json['status']),
      quotedCredits: _integer(json['quoted_credits']),
      chargedCredits: _integer(json['charged_credits']),
      errorCode: _nullableString(json['error_code']),
      outputUrl: _uri(json['output_url']),
      outputExpiresAt: _date(json['output_expires_at']),
      startedAt: _date(json['started_at']),
      createdAt:
          _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _date(json['updated_at']),
      completedAt: _date(json['completed_at']),
      parentArtifactId: _nullableString(json['parent_artifact_id']),
      appliedReviewId: _nullableString(json['applied_review_id']),
      authorizationId: _nullableString(json['authorization_id']),
      artifact: json['artifact'] == null
          ? null
          : VideoArtifact.fromJson(_map(json['artifact'])),
    );
  }

  VideoGenerationJob withArtifact(VideoArtifact value) {
    return VideoGenerationJob(
      id: id,
      modelKey: modelKey,
      prompt: prompt,
      durationSeconds: durationSeconds,
      aspectRatio: aspectRatio,
      resolution: resolution,
      status: status,
      quotedCredits: quotedCredits,
      chargedCredits: chargedCredits,
      createdAt: createdAt,
      errorCode: errorCode,
      outputUrl: outputUrl,
      outputExpiresAt: outputExpiresAt,
      startedAt: startedAt,
      updatedAt: updatedAt,
      completedAt: completedAt,
      parentArtifactId: parentArtifactId,
      appliedReviewId: appliedReviewId,
      authorizationId: authorizationId,
      artifact: value,
    );
  }
}

class VideoArtifact {
  const VideoArtifact({
    required this.id,
    required this.jobId,
    required this.title,
    required this.lifecycleStage,
    required this.rightsStatus,
    required this.privacyStatus,
    required this.commerceStatus,
    required this.intendedForSale,
    required this.iteration,
    required this.createdAt,
    this.parentArtifactId,
    this.fileSizeBytes,
    this.sha256,
    this.shopProductId,
    this.latestReview,
    this.updatedAt,
  });

  final String id;
  final String jobId;
  final String? parentArtifactId;
  final String title;
  final int? fileSizeBytes;
  final String? sha256;
  final String lifecycleStage;
  final String rightsStatus;
  final String privacyStatus;
  final String commerceStatus;
  final bool intendedForSale;
  final String? shopProductId;
  final int iteration;
  final VideoArtifactReview? latestReview;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isSaleCandidate =>
      intendedForSale && commerceStatus == 'sale_candidate';
  bool get needsRightsReview =>
      rightsStatus == 'review_required' || privacyStatus == 'review_required';

  factory VideoArtifact.fromJson(Map<String, dynamic> json) {
    return VideoArtifact(
      id: _string(json['id']),
      jobId: _string(json['job_id']),
      parentArtifactId: _nullableString(json['parent_artifact_id']),
      title: _string(json['title']),
      fileSizeBytes: _nullableInteger(json['file_size_bytes']),
      sha256: _nullableString(json['sha256']),
      lifecycleStage: _string(json['lifecycle_stage']),
      rightsStatus: _string(json['rights_status']),
      privacyStatus: _string(json['privacy_status']),
      commerceStatus: _string(json['commerce_status']),
      intendedForSale: json['intended_for_sale'] == true,
      shopProductId: _nullableString(json['shop_product_id']),
      iteration: _integer(json['iteration']),
      latestReview: json['latest_review'] == null
          ? null
          : VideoArtifactReview.fromJson(_map(json['latest_review'])),
      createdAt:
          _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: _date(json['updated_at']),
    );
  }
}

class VideoArtifactReview {
  const VideoArtifactReview({
    required this.id,
    required this.artifactId,
    required this.iteration,
    required this.qualityScore,
    required this.promptAlignmentScore,
    required this.motionQualityScore,
    required this.commercialValueScore,
    required this.decision,
    required this.strengths,
    required this.improvementRequest,
    required this.suggestedPrompt,
    required this.notes,
    required this.createdAt,
  });

  final String id;
  final String artifactId;
  final int iteration;
  final int qualityScore;
  final int promptAlignmentScore;
  final int motionQualityScore;
  final int commercialValueScore;
  final String decision;
  final String strengths;
  final String improvementRequest;
  final String suggestedPrompt;
  final String notes;
  final DateTime createdAt;

  factory VideoArtifactReview.fromJson(Map<String, dynamic> json) {
    return VideoArtifactReview(
      id: _string(json['id']),
      artifactId: _string(json['artifact_id']),
      iteration: _integer(json['iteration']),
      qualityScore: _integer(json['quality_score']),
      promptAlignmentScore: _integer(json['prompt_alignment_score']),
      motionQualityScore: _integer(json['motion_quality_score']),
      commercialValueScore: _integer(json['commercial_value_score']),
      decision: _string(json['decision']),
      strengths: _string(json['strengths']),
      improvementRequest: _string(json['improvement_request']),
      suggestedPrompt: _string(json['suggested_prompt']),
      notes: _string(json['notes']),
      createdAt:
          _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class VideoArtifactReviewDraft {
  const VideoArtifactReviewDraft({
    required this.qualityScore,
    required this.promptAlignmentScore,
    required this.motionQualityScore,
    required this.commercialValueScore,
    required this.decision,
    required this.strengths,
    required this.improvementRequest,
    required this.suggestedPrompt,
    required this.notes,
    required this.rightsStatus,
    required this.privacyStatus,
  });

  final int qualityScore;
  final int promptAlignmentScore;
  final int motionQualityScore;
  final int commercialValueScore;
  final String decision;
  final String strengths;
  final String improvementRequest;
  final String suggestedPrompt;
  final String notes;
  final String rightsStatus;
  final String privacyStatus;
}

class VideoArtifactReviewResult {
  const VideoArtifactReviewResult({
    required this.artifact,
    required this.review,
  });

  final VideoArtifact artifact;
  final VideoArtifactReview review;
}

class VideoCreateResult {
  const VideoCreateResult({required this.job, required this.balance});

  final VideoGenerationJob job;
  final VideoCreditBalance balance;
}

class VideoImprovementAuthorization {
  const VideoImprovementAuthorization({
    required this.id,
    required this.status,
    required this.validUntil,
    required this.totalCreditLimit,
    required this.reservedCredits,
    required this.consumedCredits,
    required this.remainingCredits,
    required this.totalRegenerationLimit,
    required this.consumedRegenerations,
    required this.remainingRegenerations,
    required this.rootArtifactId,
    required this.initialReviewId,
    required this.allowCreditPurchase,
    this.pendingReasons = const [],
    this.lastReservationAttemptAt,
  });

  final String id;
  final String status;
  final DateTime validUntil;
  final int totalCreditLimit;
  final int reservedCredits;
  final int consumedCredits;
  final int remainingCredits;
  final int totalRegenerationLimit;
  final int consumedRegenerations;
  final int remainingRegenerations;
  final String rootArtifactId;
  final String initialReviewId;
  final bool allowCreditPurchase;
  final List<String> pendingReasons;
  final DateTime? lastReservationAttemptAt;

  bool get isActive =>
      const {
        'active',
        'pending_review',
        'pending_funding',
        'pending_execution',
      }.contains(status) &&
      validUntil.isAfter(DateTime.now()) &&
      remainingRegenerations > 0;

  bool get isPending => status.startsWith('pending_');

  factory VideoImprovementAuthorization.fromJson(Map<String, dynamic> json) {
    return VideoImprovementAuthorization(
      id: _string(json['id']),
      status: _string(json['status']),
      validUntil:
          _date(json['valid_until']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      totalCreditLimit: _integer(json['total_credit_limit']),
      reservedCredits: _integer(json['reserved_credits']),
      consumedCredits: _integer(json['consumed_credits']),
      remainingCredits: _integer(json['remaining_credits']),
      totalRegenerationLimit: _integer(json['total_regeneration_limit']),
      consumedRegenerations: _integer(json['consumed_regenerations']),
      remainingRegenerations: _integer(json['remaining_regenerations']),
      rootArtifactId: _string(json['root_artifact_id']),
      initialReviewId: _string(json['initial_review_id']),
      allowCreditPurchase: json['allow_credit_purchase'] == true,
      pendingReasons: _list(
        json['pending_reasons'],
      ).map(_string).where((value) => value.isNotEmpty).toList(growable: false),
      lastReservationAttemptAt: _date(json['last_reservation_attempt_at']),
    );
  }
}

class VideoAuthorizationCreateResult {
  const VideoAuthorizationCreateResult({
    required this.authorization,
    required this.job,
    required this.balance,
  });

  final VideoImprovementAuthorization authorization;
  final VideoGenerationJob? job;
  final VideoCreditBalance balance;
}

Map<String, dynamic> videoStudioMap(Object? value) => _map(value);

List<dynamic> videoStudioList(Object? value) => _list(value);

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String _string(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_string(value)) ?? 0;
}

int? _nullableInteger(Object? value) {
  if (value == null) return null;
  final parsed = _integer(value);
  return parsed > 0 ? parsed : null;
}

DateTime? _date(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : DateTime.tryParse(text);
}

Uri? _uri(Object? value) {
  final text = _string(value);
  final uri = text.isEmpty ? null : Uri.tryParse(text);
  return uri != null && uri.hasScheme ? uri : null;
}
