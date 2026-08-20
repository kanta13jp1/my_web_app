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
      expect(
        find.textContaining('月額Pro/Teamとは別料金です。'),
        findsOneWidget,
      );
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
        const Key(
          'video-output-11111111-1111-4111-8111-111111111111',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('authentication failure offers a direct login action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        gateway: _AuthenticationRequiredGateway(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('この機能を使うにはログインしてください。'), findsOneWidget);
    expect(find.byKey(const Key('video-studio-login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-studio-login')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-studio-login-page')), findsOneWidget);
  });
}

Widget _app({
  List<VideoGenerationJob> jobs = const [],
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
      gateway: gateway ?? _PageGateway(jobs: jobs),
      initialUri: Uri.parse('https://example.test/video-studio'),
    ),
  );
}

class _PageGateway implements VideoStudioGateway {
  _PageGateway({this.jobs = const []});

  final List<VideoGenerationJob> jobs;

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
  Future<VideoCreateResult> createJob({
    required String idempotencyKey,
    required String modelKey,
    required String prompt,
    required int durationSeconds,
    required String aspectRatio,
    required String resolution,
  }) =>
      throw UnimplementedError();

  @override
  Future<VideoGenerationJob> refreshJob(String jobId) =>
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
  Future<VideoStudioCatalog> loadCatalog() => Future.error(
        const VideoStudioException('authentication_required'),
      );
}
