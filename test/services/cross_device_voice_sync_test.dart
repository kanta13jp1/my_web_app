import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/cross_device_voice_sync_service.dart';
import 'package:my_web_app/widgets/pwa_voice_handoff_panel.dart';

void main() {
  group('evaluateVoiceEnvironment & CrossDeviceVoiceSyncService', () {
    test('activates manual fallback on iOS standalone PWA and WebView', () {
      final VoiceSpeechCapability iosPwa = evaluateVoiceEnvironment(
        const VoiceCapabilityProbeInput(
          platform: VoiceDevicePlatform.iosPwaStandalone,
          hasSpeechRecognition: false,
          hasWebkitSpeechRecognition: true,
          isStandalonePwa: true,
        ),
      );
      expect(iosPwa.speechRecognitionAvailable, isFalse);
      expect(iosPwa.isStandalonePwa, isTrue);
      expect(iosPwa.requiresManualFallback, isTrue);
      expect(iosPwa.warningMessage, isNotNull);

      final VoiceSpeechCapability webView = evaluateVoiceEnvironment(
        const VoiceCapabilityProbeInput(
          platform: VoiceDevicePlatform.mobileWebview,
          hasSpeechRecognition: false,
          hasWebkitSpeechRecognition: false,
          isStandalonePwa: false,
          isInAppWebView: true,
        ),
      );
      expect(webView.requiresManualFallback, isTrue);
      expect(webView.speechRecognitionAvailable, isFalse);

      final VoiceSpeechCapability desktop = evaluateVoiceEnvironment(
        const VoiceCapabilityProbeInput(
          platform: VoiceDevicePlatform.desktopWeb,
          hasSpeechRecognition: true,
          hasWebkitSpeechRecognition: false,
          isStandalonePwa: false,
        ),
      );
      expect(desktop.speechRecognitionAvailable, isTrue);
      expect(desktop.requiresManualFallback, isFalse);
      expect(desktop.warningMessage, isNull);
    });

    test('increments optimistic revision and resolves remote handoff safely',
        () async {
      final InMemoryVoiceSessionCacheStore cacheStore =
          InMemoryVoiceSessionCacheStore();
      final CrossDeviceVoiceSyncService service = CrossDeviceVoiceSyncService(
        cacheStore: cacheStore,
        capabilityProbe: () => evaluateVoiceEnvironment(
          const VoiceCapabilityProbeInput(
            platform: VoiceDevicePlatform.iosSafariTab,
            hasSpeechRecognition: false,
            hasWebkitSpeechRecognition: true,
            isStandalonePwa: false,
          ),
        ),
        remoteSync: (CrossDeviceVoiceSession session) async => session,
      );

      final bool ok = await service.captureAndSync(
        transcriptDraft: 'モバイル下書きプロンプト',
        fromVoiceInput: true,
        promptContextNote: '通勤中に録音',
      );

      expect(ok, isTrue);
      expect(service.session.revision, 2);
      expect(service.session.syncStatus, VoiceSyncStatus.synced);
      expect(await cacheStore.readSessionJson(), isNotNull);

      service.applyRemoteSnapshot(
        const CrossDeviceVoiceSession(
          sessionKey: 'default-pwa-handoff',
          sourceDevice: VoiceDevicePlatform.desktopWeb,
          browserEnvironment: 'デスクトップ Web',
          transcriptDraft: 'デスクトップで追記したプロンプト',
          revision: 4,
        ),
      );
      expect(service.session.revision, 4);
      expect(service.session.syncStatus, VoiceSyncStatus.handedOff);
      expect(service.session.transcriptDraft, 'デスクトップで追記したプロンプト');

      final CrossDeviceVoiceSession restored = CrossDeviceVoiceSession.fromJson(
        const <String, Object?>{
          'session_key': 'handoff-1',
          'source_device': 'ios_pwa_standalone',
          'browser_environment': 'iOS PWA',
          'transcript_draft': '保存済みプロンプト',
          'prompt_state_json': <String, Object?>{
            'capture_mode': 'manual_fallback',
          },
          'revision': 3,
          'sync_status': 'queued_offline',
        },
      );
      expect(restored.revision, 3);
      expect(restored.syncStatus, VoiceSyncStatus.queuedOffline);
    });

    test('queues offline failure to cache and recovers via retryPendingSync',
        () async {
      bool failNetwork = true;
      final InMemoryVoiceSessionCacheStore cacheStore =
          InMemoryVoiceSessionCacheStore();
      final CrossDeviceVoiceSyncService service = CrossDeviceVoiceSyncService(
        cacheStore: cacheStore,
        remoteSync: (CrossDeviceVoiceSession session) async {
          if (failNetwork) {
            throw StateError('network unavailable');
          }
          return session;
        },
      );

      final bool firstAttempt = await service.captureAndSync(
        transcriptDraft: 'オフライン下書きテキスト',
        fromVoiceInput: false,
      );
      expect(firstAttempt, isFalse);
      expect(service.hasPendingOfflineSync, isTrue);
      expect(service.session.syncStatus, VoiceSyncStatus.queuedOffline);

      failNetwork = false;
      final bool retried = await service.retryPendingSync();
      expect(retried, isTrue);
      expect(service.hasPendingOfflineSync, isFalse);
      expect(service.session.syncStatus, VoiceSyncStatus.synced);
    });

    test(
      'selectDevicePlatform preserves baseline Web Speech flags across switches',
      () {
        final CrossDeviceVoiceSyncService service = CrossDeviceVoiceSyncService(
          cacheStore: InMemoryVoiceSessionCacheStore(),
          capabilityProbe: () => evaluateVoiceEnvironment(
            const VoiceCapabilityProbeInput(
              platform: VoiceDevicePlatform.desktopWeb,
              hasSpeechRecognition: true,
              hasWebkitSpeechRecognition: false,
              isStandalonePwa: false,
            ),
          ),
        );

        expect(service.capability.speechRecognitionAvailable, isTrue);
        service.selectDevicePlatform(VoiceDevicePlatform.iosPwaStandalone);
        expect(service.capability.speechRecognitionAvailable, isFalse);
        expect(service.capability.requiresManualFallback, isTrue);

        service.selectDevicePlatform(VoiceDevicePlatform.desktopWeb);
        expect(service.capability.speechRecognitionAvailable, isTrue);
        expect(service.capability.requiresManualFallback, isFalse);
      },
    );
  });

  group('PwaVoiceHandoffPanel', () {
    testWidgets(
        'shows iOS PWA warning, supports manual fallback sync, and disposes cleanly',
        (
      WidgetTester tester,
    ) async {
      final CrossDeviceVoiceSyncService service = CrossDeviceVoiceSyncService(
        cacheStore: InMemoryVoiceSessionCacheStore(),
        capabilityProbe: () => evaluateVoiceEnvironment(
          const VoiceCapabilityProbeInput(
            platform: VoiceDevicePlatform.iosPwaStandalone,
            hasSpeechRecognition: false,
            hasWebkitSpeechRecognition: true,
            isStandalonePwa: true,
          ),
        ),
        remoteSync: (CrossDeviceVoiceSession session) async => session,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF1E40AF)),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PwaVoiceHandoffPanel(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('voice-capability-warning')),
        findsOneWidget,
      );
      expect(find.text('手動テキストフォールバック稼働中'), findsOneWidget);

      final Finder transcriptField = find.byKey(
        const ValueKey<String>('voice-transcript-field'),
      );
      await tester.ensureVisible(transcriptField);
      await tester.pumpAndSettle();
      await tester.enterText(
        transcriptField,
        'iPhone PWA からの引き継ぎ指示',
      );
      final Finder syncButton = find.byKey(
        const ValueKey<String>('voice-sync-button'),
      );
      await tester.ensureVisible(syncButton);
      await tester.pumpAndSettle();
      await tester.tap(syncButton);
      await tester.pumpAndSettle();

      expect(service.session.revision, 2);
      expect(find.text('Rev 2'), findsOneWidget);
      expect(find.text('同期済み'), findsOneWidget);

      // Verify clean controller disposal when unmounted.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'passes responsive and WCAG accessibility audit in light and dark modes at 2.0x textScale',
        (
      WidgetTester tester,
    ) async {
      const List<Size> viewports = <Size>[Size(390, 844), Size(1280, 800)];
      const List<Brightness> modes = <Brightness>[
        Brightness.light,
        Brightness.dark,
      ];

      for (final Size viewport in viewports) {
        for (final Brightness mode in modes) {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          final CrossDeviceVoiceSyncService service =
              CrossDeviceVoiceSyncService(
            cacheStore: InMemoryVoiceSessionCacheStore(),
            capabilityProbe: () => evaluateVoiceEnvironment(
              const VoiceCapabilityProbeInput(
                platform: VoiceDevicePlatform.iosPwaStandalone,
                hasSpeechRecognition: false,
                hasWebkitSpeechRecognition: true,
                isStandalonePwa: true,
              ),
            ),
            initialSession: const CrossDeviceVoiceSession(
              sessionKey: 'audit-handoff',
              sourceDevice: VoiceDevicePlatform.iosPwaStandalone,
              browserEnvironment: 'iOS ホーム画面追加 PWA（Standalone）',
              transcriptDraft: '同期検証サンプルプロンプト',
              revision: 2,
              syncStatus: VoiceSyncStatus.synced,
            ),
          );

          final SemanticsHandle semanticsHandle = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              MaterialApp(
                key: ValueKey<String>('${viewport.width}_${mode.name}'),
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: mode,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(0xFF1E40AF),
                    brightness: mode,
                  ),
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: viewport,
                    textScaler: const TextScaler.linear(2.0),
                  ),
                  child: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: PwaVoiceHandoffPanel(service: service),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          } finally {
            semanticsHandle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      }
    });
  });
}
