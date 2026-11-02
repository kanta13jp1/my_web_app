import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/video_studio/data/video_studio_gateway.dart';
import 'package:my_web_app/ui/features/video_studio/domain/video_studio_models.dart';
import 'package:my_web_app/ui/features/video_studio/view_models/video_studio_view_model.dart';

void main() {
  test(
    'load derives the server-owned quote and generation eligibility',
    () async {
      final gateway = _FakeVideoStudioGateway(balance: _balance(500));
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      expect(viewModel.loadStatus, VideoStudioLoadStatus.ready);
      expect(viewModel.requiredCredits, 300);
      expect(viewModel.canGenerate, isFalse);

      viewModel
        ..setPrompt('A paper city wakes at sunrise')
        ..setRightsConfirmed(true)
        ..setAdultConfirmed(true);
      expect(viewModel.canGenerate, isTrue);

      expect(viewModel.durationSeconds, 5);
    },
  );

  test(
    'generation passes a stable idempotency key and updates balance',
    () async {
      final gateway = _FakeVideoStudioGateway(balance: _balance(500));
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      viewModel
        ..setPrompt('A paper city wakes at sunrise')
        ..setRightsConfirmed(true)
        ..setAdultConfirmed(true);

      expect(await viewModel.generate(), isTrue);
      expect(gateway.createdIdempotencyKey, hasLength(32));
      expect(viewModel.balance.availableCredits, 200);
      expect(viewModel.jobs.single.status, 'succeeded');
    },
  );

  test('insufficient credits prevents queue admission', () async {
    final gateway = _FakeVideoStudioGateway(balance: _balance(100));
    final viewModel = VideoStudioViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    viewModel
      ..setPrompt('A paper city wakes at sunrise')
      ..setRightsConfirmed(true)
      ..setAdultConfirmed(true);

    expect(viewModel.canGenerate, isFalse);
    expect(await viewModel.generate(), isFalse);
    expect(gateway.createdIdempotencyKey, isNull);
  });

  test('an active job prevents a second credit reservation', () async {
    final gateway = _FakeVideoStudioGateway(
      balance: _balance(500),
      initialJobs: [_job()],
    );
    final viewModel = VideoStudioViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    viewModel
      ..setPrompt('A second paper city wakes at sunrise')
      ..setRightsConfirmed(true)
      ..setAdultConfirmed(true);

    expect(viewModel.canGenerate, isFalse);
    expect(await viewModel.generate(), isFalse);
    expect(gateway.createdIdempotencyKey, isNull);
  });

  test('authentication failures expose a login-specific load state', () async {
    final gateway = _FakeVideoStudioGateway(
      balance: _balance(0),
      loadError: const VideoStudioException('authentication_required'),
    );
    final viewModel = VideoStudioViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);

    await viewModel.load();

    expect(viewModel.loadStatus, VideoStudioLoadStatus.failure);
    expect(viewModel.authenticationRequired, isTrue);
    expect(viewModel.errorMessage, 'この機能を使うにはログインしてください。');
  });

  test(
    'completed history refreshes an expired or missing signed URL',
    () async {
      final completedWithoutUrl = _job(
        status: 'succeeded',
        includeOutput: false,
      );
      final gateway = _FakeVideoStudioGateway(
        balance: _balance(500),
        initialJobs: [completedWithoutUrl],
        refreshedJob: _job(status: 'succeeded'),
      );
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final output = await viewModel.loadOutputUrl(completedWithoutUrl);

      expect(output, Uri.parse('https://example.test/signed.mp4'));
      expect(gateway.refreshCount, 1);
      expect(viewModel.jobs.single.outputUrl, output);
    },
  );

  test('checkout failures use a purchase-specific error message', () async {
    final gateway = _FakeVideoStudioGateway(
      balance: _balance(0),
      checkoutError: const VideoStudioException(
        'video_credit_checkout_unavailable',
      ),
    );
    final viewModel = VideoStudioViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    final checkout = await viewModel.createCheckout(
      'starter',
      'https://example.test/video-studio',
    );

    expect(checkout, isNull);
    expect(viewModel.errorMessage, '購入画面を開けませんでした。時間をおいて再度お試しください。');
  });

  test(
    'an improve review is visibly applied to the next paid generation',
    () async {
      final gateway = _FakeVideoStudioGateway(
        balance: _balance(500),
        initialJobs: [_job(status: 'succeeded', artifact: _artifact())],
      );
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final reviewed = await viewModel.reviewArtifact(
        viewModel.jobs.single,
        const VideoArtifactReviewDraft(
          qualityScore: 4,
          promptAlignmentScore: 3,
          motionQualityScore: 3,
          commercialValueScore: 4,
          decision: 'improve',
          strengths: '構図が明快',
          improvementRequest: '手元の動きを自然にする',
          suggestedPrompt: 'Natural hand movement in a bright office',
          notes: '',
          rightsStatus: 'confirmed',
          privacyStatus: 'confirmed',
        ),
      );

      expect(reviewed, isTrue);
      expect(viewModel.prompt, 'Natural hand movement in a bright office');
      expect(viewModel.hasAppliedImprovement, isTrue);
      viewModel
        ..setRightsConfirmed(true)
        ..setAdultConfirmed(true);

      expect(await viewModel.generate(), isTrue);
      expect(gateway.createdParentArtifactId, _artifactId);
      expect(gateway.createdAppliedReviewId, _reviewId);
      expect(viewModel.hasAppliedImprovement, isFalse);
    },
  );

  test(
    'load restores an unconsumed improve review after a later session',
    () async {
      final gateway = _FakeVideoStudioGateway(
        balance: _balance(400),
        initialJobs: [
          _job(
            status: 'succeeded',
            artifact: _artifact(latestReview: _review()),
          ),
        ],
      );
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasAppliedImprovement, isTrue);
      expect(viewModel.appliedReviewId, _reviewId);
      expect(viewModel.prompt, 'Natural hand movement in a bright office');
    },
  );

  test(
    'authorization registration atomically starts the first 300 credit run',
    () async {
      final gateway = _FakeVideoStudioGateway(
        balance: _balance(400),
        initialJobs: [
          _job(
            status: 'succeeded',
            artifact: _artifact(latestReview: _review()),
          ),
        ],
      );
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      viewModel
        ..setRightsConfirmed(true)
        ..setAdultConfirmed(true)
        ..setAuthorizationValidityHours(168)
        ..setAuthorizationRegenerations(2);

      expect(await viewModel.authorizeAndGenerateImprovement(), isTrue);

      expect(gateway.authorizedSourceArtifactId, _artifactId);
      expect(gateway.authorizedSourceReviewId, _reviewId);
      expect(gateway.authorizedValidityHours, 168);
      expect(gateway.authorizedRegenerations, 2);
      expect(viewModel.balance.availableCredits, 100);
      expect(viewModel.authorizations.single.id, _authorizationId);
      expect(viewModel.hasAppliedImprovement, isFalse);
    },
  );

  test(
    'authorization persists as pending when the first reservation lacks funds',
    () async {
      final gateway = _FakeVideoStudioGateway(
        balance: _balance(100),
        initialJobs: [
          _job(
            status: 'succeeded',
            artifact: _artifact(latestReview: _review()),
          ),
        ],
      );
      final viewModel = VideoStudioViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();
      viewModel
        ..setRightsConfirmed(true)
        ..setAdultConfirmed(true)
        ..setAuthorizationValidityHours(168)
        ..setAuthorizationRegenerations(2);

      expect(viewModel.canAuthorizeImprovement, isTrue);
      expect(await viewModel.authorizeAndGenerateImprovement(), isTrue);

      expect(viewModel.balance.availableCredits, 100);
      expect(viewModel.authorizations.single.status, 'pending_funding');
      expect(viewModel.authorizations.single.pendingReasons, [
        'insufficient_credits',
      ]);
      expect(viewModel.activeJob, isNull);
      expect(viewModel.hasAppliedImprovement, isTrue);
      expect(viewModel.noticeMessage, contains('同じ承認IDで再開'));
    },
  );

  test('an active envelope is reused for the next improve review', () async {
    final gateway = _FakeVideoStudioGateway(
      balance: _balance(400),
      initialAuthorizations: [_authorization(reservedCredits: 0)],
      initialJobs: [
        _job(
          status: 'succeeded',
          artifact: _artifact(latestReview: _review()),
        ),
      ],
    );
    final viewModel = VideoStudioViewModel(gateway: gateway);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    viewModel
      ..setRightsConfirmed(true)
      ..setAdultConfirmed(true);

    expect(viewModel.matchingActiveAuthorization?.id, _authorizationId);
    expect(await viewModel.runAuthorizedImprovement(), isTrue);
    expect(gateway.ranAuthorizationId, _authorizationId);
    expect(gateway.authorizedSourceReviewId, _reviewId);
    expect(viewModel.balance.availableCredits, 100);
  });
}

class _FakeVideoStudioGateway implements VideoStudioGateway {
  _FakeVideoStudioGateway({
    required this.balance,
    this.initialJobs = const [],
    this.refreshedJob,
    this.loadError,
    this.checkoutError,
    this.initialAuthorizations = const [],
  });

  VideoCreditBalance balance;
  final List<VideoGenerationJob> initialJobs;
  final VideoGenerationJob? refreshedJob;
  final Exception? loadError;
  final Exception? checkoutError;
  final List<VideoImprovementAuthorization> initialAuthorizations;
  String? createdIdempotencyKey;
  String? createdParentArtifactId;
  String? createdAppliedReviewId;
  int refreshCount = 0;
  String? authorizedSourceArtifactId;
  String? authorizedSourceReviewId;
  int? authorizedValidityHours;
  int? authorizedRegenerations;
  String? ranAuthorizationId;

  @override
  Future<VideoStudioCatalog> loadCatalog() async {
    if (loadError case final error?) throw error;
    return _catalog;
  }

  @override
  Future<VideoCreditBalance> loadBalance() async {
    return balance;
  }

  @override
  Future<List<VideoGenerationJob>> listJobs() async {
    return initialJobs;
  }

  @override
  Future<List<VideoImprovementAuthorization>> loadAuthorizations() async {
    return initialAuthorizations;
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
    createdIdempotencyKey = idempotencyKey;
    createdParentArtifactId = parentArtifactId;
    createdAppliedReviewId = appliedReviewId;
    balance = _balance(balance.availableCredits - durationSeconds * 60);
    return VideoCreateResult(
      job: _job(status: 'succeeded', prompt: prompt),
      balance: balance,
    );
  }

  @override
  Future<VideoGenerationJob> refreshJob(String jobId) async {
    refreshCount += 1;
    return refreshedJob ?? _job(status: 'succeeded');
  }

  @override
  Future<VideoArtifactReviewResult> reviewArtifact({
    required String artifactId,
    required VideoArtifactReviewDraft review,
  }) async {
    final savedReview = _review(suggestedPrompt: review.suggestedPrompt);
    return VideoArtifactReviewResult(
      artifact: _artifact(latestReview: savedReview),
      review: savedReview,
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
    createdIdempotencyKey = idempotencyKey;
    authorizedSourceArtifactId = sourceArtifactId;
    authorizedSourceReviewId = sourceReviewId;
    authorizedValidityHours = validityHours;
    authorizedRegenerations = totalRegenerations;
    if (balance.availableCredits < 300) {
      return VideoAuthorizationCreateResult(
        authorization: _authorization(
          status: 'pending_funding',
          reservedCredits: 0,
          remainingCredits: 300 * totalRegenerations,
          remainingRegenerations: totalRegenerations,
          pendingReasons: const ['insufficient_credits'],
        ),
        job: null,
        balance: balance,
      );
    }
    balance = _balance(balance.availableCredits - 300);
    return VideoAuthorizationCreateResult(
      authorization: _authorization(
        remainingCredits: 300 * totalRegenerations - 300,
        remainingRegenerations: totalRegenerations - 1,
      ),
      job: _job(status: 'queued'),
      balance: balance,
    );
  }

  @override
  Future<VideoAuthorizationCreateResult> runAuthorizedImprovement({
    required String idempotencyKey,
    required String authorizationId,
    required String sourceArtifactId,
    required String sourceReviewId,
  }) async {
    createdIdempotencyKey = idempotencyKey;
    ranAuthorizationId = authorizationId;
    authorizedSourceArtifactId = sourceArtifactId;
    authorizedSourceReviewId = sourceReviewId;
    balance = _balance(balance.availableCredits - 300);
    return VideoAuthorizationCreateResult(
      authorization: _authorization(
        reservedCredits: 300,
        remainingCredits: 0,
        remainingRegenerations: 0,
      ),
      job: _job(status: 'queued'),
      balance: balance,
    );
  }

  @override
  Future<VideoImprovementAuthorization> revokeAuthorization(
    String authorizationId,
  ) async =>
      _authorization(status: 'revoked');

  @override
  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  }) async {
    if (checkoutError case final error?) throw error;
    return Uri.parse('https://checkout.stripe.test/session');
  }
}

const _catalog = VideoStudioCatalog(
  models: [
    VideoGenerationModelOption(
      key: 'studio-video-v1',
      name: 'Studio Video 1',
      description: 'Text to video',
      durations: [5],
      aspectRatios: ['16:9', '9:16'],
      resolutions: ['720p'],
      creditsPerSecond: 60,
    ),
  ],
  creditPacks: [
    VideoCreditPackOption(
      key: 'starter',
      name: 'Starter',
      credits: 500,
      amountJpy: 500,
    ),
  ],
);

VideoCreditBalance _balance(int available) => VideoCreditBalance(
      availableCredits: available,
      reservedCredits: 0,
      creditDebt: 0,
    );

VideoGenerationJob _job({
  String status = 'queued',
  String prompt = 'paper city',
  bool includeOutput = true,
  VideoArtifact? artifact,
}) {
  return VideoGenerationJob(
    id: '11111111-1111-4111-8111-111111111111',
    modelKey: 'studio-video-v1',
    prompt: prompt,
    durationSeconds: 5,
    aspectRatio: '16:9',
    resolution: '720p',
    status: status,
    quotedCredits: 300,
    chargedCredits: status == 'succeeded' ? 300 : 0,
    createdAt: DateTime.utc(2026, 8, 20),
    outputUrl: status == 'succeeded' && includeOutput
        ? Uri.parse('https://example.test/signed.mp4')
        : null,
    outputExpiresAt: status == 'succeeded' && includeOutput
        ? DateTime.now().add(const Duration(hours: 1))
        : null,
    artifact: artifact,
  );
}

const _artifactId = '22222222-2222-4222-8222-222222222222';
const _reviewId = '33333333-3333-4333-8333-333333333333';
const _authorizationId = '44444444-4444-4444-8444-444444444444';

VideoArtifact _artifact({VideoArtifactReview? latestReview}) => VideoArtifact(
      id: _artifactId,
      jobId: '11111111-1111-4111-8111-111111111111',
      title: 'paper city',
      lifecycleStage: latestReview == null ? 'captured' : 'productizing',
      rightsStatus: latestReview == null ? 'review_required' : 'allowed',
      privacyStatus: latestReview == null ? 'review_required' : 'cleared',
      commerceStatus: 'sale_candidate',
      intendedForSale: true,
      iteration: 1,
      latestReview: latestReview,
      createdAt: DateTime.utc(2026, 8, 20),
    );

VideoArtifactReview _review({
  String suggestedPrompt = 'Natural hand movement in a bright office',
}) =>
    VideoArtifactReview(
      id: _reviewId,
      artifactId: _artifactId,
      iteration: 1,
      qualityScore: 4,
      promptAlignmentScore: 3,
      motionQualityScore: 3,
      commercialValueScore: 4,
      decision: 'improve',
      strengths: '構図が明快',
      improvementRequest: '手元の動きを自然にする',
      suggestedPrompt: suggestedPrompt,
      notes: '',
      createdAt: DateTime.utc(2026, 8, 20, 1),
    );

VideoImprovementAuthorization _authorization({
  String status = 'active',
  int reservedCredits = 300,
  int remainingCredits = 300,
  int remainingRegenerations = 1,
  List<String> pendingReasons = const [],
}) =>
    VideoImprovementAuthorization(
      id: _authorizationId,
      status: status,
      validUntil: DateTime.now().add(const Duration(days: 7)),
      totalCreditLimit: 600,
      reservedCredits: reservedCredits,
      consumedCredits: 0,
      remainingCredits: remainingCredits,
      totalRegenerationLimit: 2,
      consumedRegenerations: 1,
      remainingRegenerations: remainingRegenerations,
      rootArtifactId: _artifactId,
      initialReviewId: _reviewId,
      allowCreditPurchase: false,
      pendingReasons: pendingReasons,
    );
