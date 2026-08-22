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

  test('completed history refreshes an expired or missing signed URL',
      () async {
    final completedWithoutUrl = _job(status: 'succeeded', includeOutput: false);
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
  });

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
}

class _FakeVideoStudioGateway implements VideoStudioGateway {
  _FakeVideoStudioGateway({
    required this.balance,
    this.initialJobs = const [],
    this.refreshedJob,
    this.loadError,
    this.checkoutError,
  });

  VideoCreditBalance balance;
  final List<VideoGenerationJob> initialJobs;
  final VideoGenerationJob? refreshedJob;
  final Exception? loadError;
  final Exception? checkoutError;
  String? createdIdempotencyKey;
  int refreshCount = 0;

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
  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
  }) async {
    createdIdempotencyKey = idempotencyKey;
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
  );
}
