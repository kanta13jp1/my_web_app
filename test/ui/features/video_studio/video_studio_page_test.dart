import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/video_studio/data/video_studio_gateway.dart';
import 'package:my_web_app/ui/features/video_studio/domain/video_studio_models.dart';
import 'package:my_web_app/ui/features/video_studio/video_studio_feature.dart';

void main() {
  testWidgets(
    'compact layout keeps generation controls and legal links visible',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('video-studio-compact')), findsOneWidget);
      expect(find.byKey(const Key('video-studio-prompt')), findsOneWidget);
      expect(find.byKey(const Key('video-studio-generate')), findsOneWidget);
      expect(find.textContaining('月額Pro/Teamとは別料金です。'), findsOneWidget);
    },
  );

  testWidgets('wide layout renders composer and prepaid balance side by side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-studio-wide')), findsOneWidget);
    expect(find.text('動画をつくる'), findsOneWidget);
    expect(find.text('動画クレジット'), findsOneWidget);
    expect(find.byKey(const Key('video-credit-pack-starter')), findsOneWidget);
  });

  testWidgets('completed history can request a fresh signed output link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        jobs: [
          VideoGenerationJob(
            id: '11111111-1111-4111-8111-111111111111',
            modelKey: 'studio-video-v1',
            prompt: 'A paper city wakes at sunrise',
            durationSeconds: 5,
            aspectRatio: '16:9',
            resolution: '720p',
            status: 'succeeded',
            quotedCredits: 300,
            chargedCredits: 300,
            createdAt: DateTime.utc(2026, 8, 20),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('動画を開く・保存'), findsOneWidget);
    expect(
      find.byKey(
        const Key('video-output-11111111-1111-4111-8111-111111111111'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('active history explains GPU latency and shows worker activity', (
    tester,
  ) async {
    final job = VideoGenerationJob(
      id: '11111111-1111-4111-8111-111111111111',
      modelKey: 'studio-video-v1',
      prompt: 'A paper city wakes at sunrise',
      durationSeconds: 5,
      aspectRatio: '16:9',
      resolution: '720p',
      status: 'in_progress',
      quotedCredits: 300,
      chargedCredits: 0,
      createdAt: DateTime.utc(2026, 8, 20, 10),
      startedAt: DateTime.utc(2026, 8, 20, 10, 3),
      updatedAt: DateTime.utc(2026, 8, 20, 10, 8),
    );

    await tester.pumpWidget(_app(jobs: [job]));
    await tester.pump();

    expect(
      find.byKey(
        const Key('video-progress-11111111-1111-4111-8111-111111111111'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('専用GPUで推論中です'), findsOneWidget);
    expect(find.textContaining('最終処理確認'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('authentication failure offers a direct login action', (
    tester,
  ) async {
    await tester.pumpWidget(_app(gateway: _AuthenticationRequiredGateway()));
    await tester.pumpAndSettle();

    expect(find.text('この機能を使うにはログインしてください。'), findsOneWidget);
    expect(find.byKey(const Key('video-studio-login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-studio-login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-studio-login-page')), findsOneWidget);
  });

  testWidgets('completed artifact is marked for reuse and opens its review', (
    tester,
  ) async {
    final artifact = VideoArtifact(
      id: '22222222-2222-4222-8222-222222222222',
      jobId: '11111111-1111-4111-8111-111111111111',
      title: 'Office scene',
      lifecycleStage: 'captured',
      rightsStatus: 'review_required',
      privacyStatus: 'review_required',
      commerceStatus: 'sale_candidate',
      intendedForSale: true,
      iteration: 1,
      createdAt: DateTime.utc(2026, 8, 20),
    );
    final job = VideoGenerationJob(
      id: '11111111-1111-4111-8111-111111111111',
      modelKey: 'studio-video-v1',
      prompt: 'Office scene',
      durationSeconds: 5,
      aspectRatio: '16:9',
      resolution: '720p',
      status: 'succeeded',
      quotedCredits: 300,
      chargedCredits: 300,
      createdAt: DateTime.utc(2026, 8, 20),
      artifact: artifact,
    );

    await tester.pumpWidget(_app(jobs: [job]));
    await tester.pumpAndSettle();

    expect(find.text('素材として保存済み'), findsOneWidget);
    expect(find.text('販売候補'), findsOneWidget);
    expect(find.text('権利・プライバシー確認待ち'), findsOneWidget);

    final reviewButton = find.byKey(
      const Key('video-review-11111111-1111-4111-8111-111111111111'),
    );
    await tester.ensureVisible(reviewButton);
    await tester.pumpAndSettle();
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('video-artifact-review-dialog')),
      findsOneWidget,
    );
    expect(find.text('保存して次回へ反映'), findsOneWidget);
  });

  testWidgets(
    'pending improvement exposes bounded authorization and immediate run',
    (tester) async {
      final review = VideoArtifactReview(
        id: '33333333-3333-4333-8333-333333333333',
        artifactId: '22222222-2222-4222-8222-222222222222',
        iteration: 1,
        qualityScore: 3,
        promptAlignmentScore: 4,
        motionQualityScore: 3,
        commercialValueScore: 3,
        decision: 'improve',
        strengths: '構図',
        improvementRequest: '動きを自然に',
        suggestedPrompt: 'Natural office motion',
        notes: '',
        createdAt: DateTime.utc(2026, 8, 20),
      );
      final artifact = VideoArtifact(
        id: review.artifactId,
        jobId: '11111111-1111-4111-8111-111111111111',
        title: 'Office scene',
        lifecycleStage: 'productizing',
        rightsStatus: 'allowed',
        privacyStatus: 'cleared',
        commerceStatus: 'sale_candidate',
        intendedForSale: true,
        iteration: 1,
        latestReview: review,
        createdAt: DateTime.utc(2026, 8, 20),
      );
      final job = VideoGenerationJob(
        id: artifact.jobId,
        modelKey: 'studio-video-v1',
        prompt: 'Office scene',
        durationSeconds: 5,
        aspectRatio: '16:9',
        resolution: '720p',
        status: 'succeeded',
        quotedCredits: 300,
        chargedCredits: 300,
        createdAt: DateTime.utc(2026, 8, 20),
        artifact: artifact,
      );

      await tester.pumpWidget(_app(jobs: [job]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('video-improvement-authorization')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('video-authorization-expiry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('video-authorization-iterations')),
        findsOneWidget,
      );
      expect(find.textContaining('総上限 600 credits・自動購入 0円'), findsOneWidget);
      expect(find.byKey(const Key('video-authorize-and-run')), findsOneWidget);
    },
  );

  testWidgets('stored pending authorization shows its resumable state', (
    tester,
  ) async {
    final authorization = VideoImprovementAuthorization(
      id: '44444444-4444-4444-8444-444444444444',
      status: 'pending_funding',
      validUntil: DateTime.now().add(const Duration(days: 7)),
      totalCreditLimit: 600,
      reservedCredits: 0,
      consumedCredits: 0,
      remainingCredits: 600,
      totalRegenerationLimit: 2,
      consumedRegenerations: 0,
      remainingRegenerations: 2,
      rootArtifactId: '22222222-2222-4222-8222-222222222222',
      initialReviewId: '33333333-3333-4333-8333-333333333333',
      allowCreditPurchase: false,
      pendingReasons: const ['insufficient_credits'],
    );

    await tester.pumpWidget(_app(authorizations: [authorization]));
    await tester.pumpAndSettle();

    expect(find.textContaining('状態 残高待ち'), findsOneWidget);
    expect(find.textContaining('残り 2回・600 credits'), findsOneWidget);
    expect(find.byKey(const Key('video-revoke-authorization')), findsOneWidget);
  });
}

Widget _app({
  List<VideoGenerationJob> jobs = const [],
  List<VideoImprovementAuthorization> authorizations = const [],
  VideoStudioGateway? gateway,
}) {
  return MaterialApp(
    routes: {
      '/login': (_) => const Scaffold(
            body: Text('Login page', key: Key('video-studio-login-page')),
          ),
      '/terms': (_) => const SizedBox(),
      '/privacy': (_) => const SizedBox(),
      '/tokusho': (_) => const SizedBox(),
    },
    home: VideoStudioFeature(
      gateway:
          gateway ?? _PageGateway(jobs: jobs, authorizations: authorizations),
      initialUri: Uri.parse('https://example.test/video-studio'),
    ),
  );
}

class _PageGateway implements VideoStudioGateway {
  _PageGateway({this.jobs = const [], this.authorizations = const []});

  final List<VideoGenerationJob> jobs;
  final List<VideoImprovementAuthorization> authorizations;

  @override
  Future<VideoStudioCatalog> loadCatalog() async => const VideoStudioCatalog(
        models: [
          VideoGenerationModelOption(
            key: 'studio-video-v1',
            name: 'Studio Video 1',
            description: '当サイト運営GPUによる動画生成',
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

  @override
  Future<VideoCreditBalance> loadBalance() async => const VideoCreditBalance(
        availableCredits: 500,
        reservedCredits: 0,
        creditDebt: 0,
      );

  @override
  Future<List<VideoGenerationJob>> listJobs() async => jobs;

  @override
  Future<List<VideoImprovementAuthorization>> loadAuthorizations() async =>
      authorizations;

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
  }) =>
      throw UnimplementedError();

  @override
  Future<VideoGenerationJob> refreshJob(String jobId) =>
      throw UnimplementedError();

  @override
  Future<VideoArtifactReviewResult> reviewArtifact({
    required String artifactId,
    required VideoArtifactReviewDraft review,
  }) =>
      throw UnimplementedError();

  @override
  Future<VideoAuthorizationCreateResult> authorizeImprovement({
    required String idempotencyKey,
    required String sourceArtifactId,
    required String sourceReviewId,
    required int validityHours,
    required int totalRegenerations,
  }) =>
      throw UnimplementedError();

  @override
  Future<VideoAuthorizationCreateResult> runAuthorizedImprovement({
    required String idempotencyKey,
    required String authorizationId,
    required String sourceArtifactId,
    required String sourceReviewId,
  }) =>
      throw UnimplementedError();

  @override
  Future<VideoImprovementAuthorization> revokeAuthorization(
    String authorizationId,
  ) =>
      throw UnimplementedError();

  @override
  Future<Uri> createCreditCheckout({
    required String packKey,
    required String returnUrl,
  }) async =>
      Uri.parse('https://checkout.stripe.test/session');
}

class _AuthenticationRequiredGateway extends _PageGateway {
  @override
  Future<VideoStudioCatalog> loadCatalog() =>
      Future.error(const VideoStudioException('authentication_required'));
}
