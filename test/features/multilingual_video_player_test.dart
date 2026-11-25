import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/multilingual_video_player/application/multilingual_video_player_controller.dart';
import 'package:my_web_app/features/multilingual_video_player/data/supabase_multilingual_video_repository.dart';
import 'package:my_web_app/features/multilingual_video_player/domain/multilingual_video_player_models.dart';
import 'package:my_web_app/features/multilingual_video_player/multilingual_video_player_container.dart';

class _FakeMultilingualVideoRepository implements MultilingualVideoRepository {
  _FakeMultilingualVideoRepository(this.seed);

  final List<VideoTranslationTrack> seed;
  final List<QueueVideoTranslationInput> queued =
      <QueueVideoTranslationInput>[];
  bool shouldThrowOnFetch = false;
  Completer<List<VideoTranslationTrack>>? fetchCompleter;
  Completer<VideoTranslationTrack>? queueCompleter;

  @override
  Future<List<VideoTranslationTrack>> fetchTranslations({
    final String? sourceVideoId,
    final int limit = 50,
  }) async {
    if (fetchCompleter != null) {
      return fetchCompleter!.future;
    }
    if (shouldThrowOnFetch) {
      throw StateError('network offline');
    }
    return List<VideoTranslationTrack>.from(seed);
  }

  @override
  Future<VideoTranslationTrack> queueTranslation(
    final QueueVideoTranslationInput input,
  ) async {
    if (queueCompleter != null) {
      return queueCompleter!.future;
    }
    queued.add(input);
    return VideoTranslationTrack(
      id: 'queued-${queued.length}',
      sourceVideoId: input.sourceVideoId,
      sourceVideoUrl: input.sourceVideoUrl,
      languageCode: input.languageCode,
      didLanguageName: resolveDidLanguageName(input.languageCode) ?? 'English',
      status: VideoTranslationStatus.queued,
      durationSeconds: input.durationSeconds,
      maxDurationCapSeconds: input.maxDurationCapSeconds,
      estimatedCostUsd: input.estimatedCostUsd,
      maxCostCapUsd: input.maxCostCapUsd,
      createdAt: DateTime.utc(2026, 11, 24),
    );
  }
}

List<VideoTranslationTrack> _buildSeedTracks() {
  return <VideoTranslationTrack>[
    VideoTranslationTrack(
      id: 'trk-ja',
      sourceVideoId: 'intro_philosophy_01',
      sourceVideoUrl: 'https://cdn.example.com/intro.mp4',
      languageCode: 'ja',
      didLanguageName: 'Japanese',
      status: VideoTranslationStatus.done,
      durationSeconds: 45,
      maxDurationCapSeconds: 120,
      estimatedCostUsd: 1.575,
      maxCostCapUsd: 5.0,
      createdAt: DateTime.utc(2026, 11, 24, 10),
      providerJobId: 'trs_ja_01',
      resultUrl: 'https://results.example.com/intro_ja.mp4',
      subtitlesUrl: 'https://results.example.com/intro_ja.vtt',
      resultExpiresAt: DateTime.utc(2026, 11, 25, 10),
    ),
    VideoTranslationTrack(
      id: 'trk-en',
      sourceVideoId: 'intro_philosophy_01',
      sourceVideoUrl: 'https://cdn.example.com/intro.mp4',
      languageCode: 'en',
      didLanguageName: 'English',
      status: VideoTranslationStatus.done,
      durationSeconds: 45,
      maxDurationCapSeconds: 120,
      estimatedCostUsd: 1.575,
      maxCostCapUsd: 5.0,
      createdAt: DateTime.utc(2026, 11, 24, 10),
      providerJobId: 'trs_en_01',
      resultUrl: 'https://results.example.com/intro_en.mp4',
      resultExpiresAt: DateTime.utc(2026, 11, 25, 10),
    ),
    VideoTranslationTrack(
      id: 'trk-es',
      sourceVideoId: 'intro_philosophy_01',
      sourceVideoUrl: 'https://cdn.example.com/intro.mp4',
      languageCode: 'es',
      didLanguageName: 'Spanish',
      status: VideoTranslationStatus.processing,
      durationSeconds: 45,
      maxDurationCapSeconds: 120,
      estimatedCostUsd: 1.575,
      maxCostCapUsd: 5.0,
      createdAt: DateTime.utc(2026, 11, 24, 10),
      providerJobId: 'trs_es_01',
    ),
  ];
}

void main() {
  group('MultilingualVideoPlayer domain & controller (#2660)', () {
    test('resolves exact locale, user override, and fallback cleanly', () {
      final List<VideoTranslationTrack> tracks = _buildSeedTracks();
      final DateTime now = DateTime.utc(2026, 11, 24, 12);

      final ResolvedMultilingualPlayback jaMatch = resolveBestLocalizedTrack(
        tracks: tracks,
        deviceLocale: const Locale('ja', 'JP'),
        nowUtc: now,
      );
      expect(jaMatch.resolvedLanguageCode, 'ja');
      expect(jaMatch.reason, MultilingualMatchReason.baseLanguage);
      expect(jaMatch.track?.id, 'trk-ja');

      final ResolvedMultilingualPlayback fallbackEn = resolveBestLocalizedTrack(
        tracks: tracks,
        deviceLocale: const Locale('fr', 'FR'),
        nowUtc: now,
      );
      expect(fallbackEn.resolvedLanguageCode, 'en');
      expect(fallbackEn.reason, MultilingualMatchReason.fallbackLanguage);

      final ResolvedMultilingualPlayback overrideMatch =
          resolveBestLocalizedTrack(
        tracks: tracks,
        deviceLocale: const Locale('ja'),
        preferredLanguageCode: 'en',
        nowUtc: now,
      );
      expect(overrideMatch.resolvedLanguageCode, 'en');
      expect(overrideMatch.reason, MultilingualMatchReason.userPreference);
    });

    test('fails closed on duration/cost cap and clears stale errors', () async {
      final _FakeMultilingualVideoRepository repo =
          _FakeMultilingualVideoRepository(_buildSeedTracks());
      final MultilingualVideoPlayerController ctrl =
          MultilingualVideoPlayerController(
        repository: repo,
        nowProvider: () => DateTime.utc(2026, 11, 24, 12),
      );
      addTearDown(ctrl.dispose);

      await ctrl.loadTranslations();
      expect(ctrl.tracks.length, 3);

      final bool rejected = await ctrl.queueTranslation(
        const QueueVideoTranslationInput(
          sourceVideoId: 'too-long',
          sourceVideoUrl: 'https://cdn.example.com/long.mp4',
          languageCode: 'ja',
          durationSeconds: 300,
        ),
      );
      expect(rejected, isFalse);
      expect(ctrl.errorMessage, contains('上限'));
      expect(repo.queued, isEmpty);

      // clearError on locale preference change
      ctrl.updatePreferredLanguageCode('en');
      expect(ctrl.errorMessage, isNull);

      final bool accepted = await ctrl.queueTranslation(
        const QueueVideoTranslationInput(
          sourceVideoId: 'clip_02',
          sourceVideoUrl: 'https://cdn.example.com/clip02.mp4',
          languageCode: 'fr',
          durationSeconds: 30,
        ),
      );
      expect(accepted, isTrue);
      expect(repo.queued.length, 1);
      expect(ctrl.tracks.length, 4);
    });

    test('safely ignores completions after dispose during pending requests',
        () async {
      final Completer<List<VideoTranslationTrack>> fetchPending =
          Completer<List<VideoTranslationTrack>>();
      final Completer<VideoTranslationTrack> queuePending =
          Completer<VideoTranslationTrack>();
      final _FakeMultilingualVideoRepository repo =
          _FakeMultilingualVideoRepository(_buildSeedTracks())
            ..fetchCompleter = fetchPending
            ..queueCompleter = queuePending;

      final MultilingualVideoPlayerController ctrl =
          MultilingualVideoPlayerController(
        repository: repo,
        nowProvider: () => DateTime.utc(2026, 11, 24, 12),
      );
      int listenerCalls = 0;
      ctrl.addListener(() {
        listenerCalls += 1;
      });

      final Future<void> loadFuture = ctrl.loadTranslations();
      final Future<bool> queueFuture = ctrl.queueTranslation(
        const QueueVideoTranslationInput(
          sourceVideoId: 'pending_vid',
          sourceVideoUrl: 'https://cdn.example.com/pending.mp4',
          languageCode: 'ja',
          durationSeconds: 30,
        ),
      );
      final int callsBeforeDispose = listenerCalls;
      ctrl.dispose();

      fetchPending.complete(_buildSeedTracks());
      queuePending.complete(_buildSeedTracks().first);

      await loadFuture;
      final bool queuedResult = await queueFuture;
      expect(queuedResult, isFalse);
      expect(listenerCalls, callsBeforeDispose);
    });
  });

  group('MultilingualVideoPlayerContainer widget & a11y (#2660)', () {
    Future<void> pumpViewport(
      final WidgetTester tester, {
      required final Size size,
      required final Brightness brightness,
      required final MultilingualVideoPlayerController controller,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1D4ED8),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: MultilingualVideoPlayerContainer(
                  controller: controller,
                  autoLoad: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'switches languages, enforces duration cap, and passes Light/Dark a11y',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        try {
          final _FakeMultilingualVideoRepository repo =
              _FakeMultilingualVideoRepository(_buildSeedTracks());
          final MultilingualVideoPlayerController controller =
              MultilingualVideoPlayerController(
            repository: repo,
            initialDeviceLocale: const Locale('ja'),
            nowProvider: () => DateTime.utc(2026, 11, 24, 12),
          );
          addTearDown(controller.dispose);
          await controller.loadTranslations();

          await pumpViewport(
            tester,
            size: const Size(360, 800),
            brightness: Brightness.light,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          final Finder resolvedCard = find.byKey(
            const ValueKey<String>('multilingual-video-resolved-card'),
          );
          await tester.ensureVisible(resolvedCard);
          expect(resolvedCard, findsOneWidget);
          expect(find.textContaining('AI 生成'), findsWidgets);

          final Finder enChoice = find.byKey(
            const ValueKey<String>('locale-choice-en'),
          );
          await tester.ensureVisible(enChoice);
          await tester.tap(enChoice);
          await tester.pumpAndSettle();
          expect(controller.preferredLanguageCode, 'en');
          expect(controller.resolvedPlayback.track?.id, 'trk-en');

          final Finder durationInput = find.byKey(
            const ValueKey<String>('did-duration-seconds-input'),
          );
          await tester.ensureVisible(durationInput);
          await tester.enterText(durationInput, '500');
          await tester.ensureVisible(
            find.byKey(const ValueKey<String>('did-queue-submit-button')),
          );
          await tester.tap(
            find.byKey(const ValueKey<String>('did-queue-submit-button')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              const ValueKey<String>('multilingual-video-error-banner'),
            ),
            findsOneWidget,
          );

          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
          );

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.dark,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
          );
        } finally {
          semanticsHandle.dispose();
        }
      },
    );
  });
}
