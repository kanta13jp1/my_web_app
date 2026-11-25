import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/video_preflight/domain/video_preflight_models.dart';
import 'package:my_web_app/features/video_preflight/video_preflight_container.dart';

class _FakeVideoPreflightProbe implements VideoPreflightProbe {
  _FakeVideoPreflightProbe({required final VideoSystemSnapshot initial})
      : current = initial;

  VideoSystemSnapshot current;
  bool throwOnCollect = false;
  Completer<VideoSystemSnapshot>? pendingCollect;

  @override
  Future<VideoSystemSnapshot> collectSnapshot() async {
    if (pendingCollect != null) {
      return pendingCollect!.future;
    }
    if (throwOnCollect) {
      throw StateError('preflight probe unavailable');
    }
    return current;
  }

  @override
  Future<VideoSystemSnapshot> verifyPermission({
    required final String capability,
  }) async {
    current = VideoSystemSnapshot(
      isWebRuntime: current.isWebRuntime,
      isSecureContext: current.isSecureContext,
      userAgent: current.userAgent,
      browserName: current.browserName,
      engine: current.engine,
      webGlAvailable: current.webGlAvailable,
      hardwareAccelerated: current.hardwareAccelerated,
      gpuRenderer: current.gpuRenderer,
      deviceMemoryGb: current.deviceMemoryGb,
      hardwareConcurrency: current.hardwareConcurrency,
      supportsMediaDevices: current.supportsMediaDevices,
      supportsDisplayMedia: current.supportsDisplayMedia,
      microphonePermission: capability == 'microphone' || capability == 'all'
          ? MediaPermissionState.granted
          : current.microphonePermission,
      cameraPermission: capability == 'camera' || capability == 'all'
          ? MediaPermissionState.granted
          : current.cameraPermission,
      screenSharePermission: capability == 'screen_share' || capability == 'all'
          ? MediaPermissionState.granted
          : current.screenSharePermission,
    );
    return current;
  }
}

VideoSystemSnapshot _healthyChromiumSnapshot() {
  return const VideoSystemSnapshot(
    isWebRuntime: true,
    isSecureContext: true,
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
    browserName: 'Google Chrome / Chromium',
    engine: BrowserEngineKind.chromium,
    webGlAvailable: true,
    hardwareAccelerated: true,
    gpuRenderer: 'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 Direct3D11)',
    deviceMemoryGb: 8.0,
    hardwareConcurrency: 8,
    supportsMediaDevices: true,
    supportsDisplayMedia: true,
    microphonePermission: MediaPermissionState.granted,
    cameraPermission: MediaPermissionState.granted,
    screenSharePermission: MediaPermissionState.granted,
  );
}

VideoSystemSnapshot _swiftShaderAndDeniedSnapshot() {
  return const VideoSystemSnapshot(
    isWebRuntime: true,
    isSecureContext: true,
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
    browserName: 'Google Chrome / Chromium',
    engine: BrowserEngineKind.chromium,
    webGlAvailable: true,
    hardwareAccelerated: false,
    gpuRenderer: 'ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device))',
    deviceMemoryGb: 8.0,
    hardwareConcurrency: 8,
    supportsMediaDevices: true,
    supportsDisplayMedia: true,
    microphonePermission: MediaPermissionState.denied,
    cameraPermission: MediaPermissionState.prompt,
    screenSharePermission: MediaPermissionState.prompt,
  );
}

void main() {
  group('VideoPreflightModels and VideoPreflightContainer (#2716)', () {
    test(
      'detects Chromium vs Safari, software GPU renderers, and evaluates requirements',
      () {
        expect(
          classifyBrowserEngine('Mozilla/5.0 Chrome/131.0 Safari/537.36'),
          BrowserEngineKind.chromium,
        );
        expect(
          classifyBrowserEngine('Mozilla/5.0 Version/18.0 Safari/605.1.15'),
          BrowserEngineKind.safari,
        );
        expect(
          isSoftwareGpuRenderer('ANGLE (Google, SwiftShader Device)'),
          isTrue,
        );
        expect(
          isSoftwareGpuRenderer('ANGLE (Apple, Apple M2 Pro, OpenGL)'),
          isFalse,
        );

        final healthy = evaluateVideoPreflight(_healthyChromiumSnapshot());
        expect(healthy.overallSeverity, PreflightSeverity.pass);
        expect(healthy.canProceedSmoothly, isTrue);

        final blocked = evaluateVideoPreflight(_swiftShaderAndDeniedSnapshot());
        expect(blocked.overallSeverity, PreflightSeverity.blocker);
        expect(blocked.hasBlockers, isTrue);
        expect(
          blocked.troubleshootingSteps.any(
            (final String step) => step.contains('chrome://settings/system'),
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'auto-opens troubleshooting dialog when hardware acceleration is disabled, and unlocks editor when remediated',
      (final WidgetTester tester) async {
        var proceeded = false;
        final probe = _FakeVideoPreflightProbe(
          initial: _swiftShaderAndDeniedSnapshot(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: VideoPreflightContainer(
                probe: probe,
                onProceedToEditor: () {
                  proceeded = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('video_preflight_troubleshooting_dialog'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('chrome://settings/system'), findsOneWidget);

        await tester.tap(
          find.byKey(
            const ValueKey<String>('video_preflight_dialog_close_button'),
          ),
        );
        await tester.pumpAndSettle();

        final proceedBtn = find.byKey(
          const ValueKey<String>('video_preflight_proceed_button'),
        );
        await tester.ensureVisible(proceedBtn);
        await tester.pumpAndSettle();
        final ElevatedButton disabledWidget = tester.widget<ElevatedButton>(
          proceedBtn,
        );
        expect(disabledWidget.onPressed, isNull);

        probe.current = _healthyChromiumSnapshot();
        final refreshBtn = find.byKey(
          const ValueKey<String>('video_preflight_refresh_button'),
        );
        await tester.ensureVisible(refreshBtn);
        await tester.pumpAndSettle();
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();

        expect(find.text('適合'), findsWidgets);
        await tester.ensureVisible(proceedBtn);
        await tester.pumpAndSettle();
        await tester.tap(proceedBtn);
        await tester.pumpAndSettle();
        expect(proceeded, isTrue);
      },
    );

    testWidgets(
      'verifies microphone, camera, and screen share permissions interactively',
      (final WidgetTester tester) async {
        const promptSnapshot = VideoSystemSnapshot(
          isWebRuntime: true,
          isSecureContext: true,
          userAgent: 'Mozilla/5.0 Chrome/131.0 Safari/537.36',
          browserName: 'Google Chrome / Chromium',
          engine: BrowserEngineKind.chromium,
          webGlAvailable: true,
          hardwareAccelerated: true,
          gpuRenderer: 'ANGLE (Intel, UHD Graphics 770)',
          deviceMemoryGb: 16.0,
          hardwareConcurrency: 12,
          supportsMediaDevices: true,
          supportsDisplayMedia: true,
          microphonePermission: MediaPermissionState.prompt,
          cameraPermission: MediaPermissionState.prompt,
          screenSharePermission: MediaPermissionState.prompt,
        );
        final probe = _FakeVideoPreflightProbe(initial: promptSnapshot);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: VideoPreflightContainer(probe: probe),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('マイク: 未確認 (要テスト)'), findsOneWidget);

        final verifyAllBtn = find.byKey(
          const ValueKey<String>('verify_all_permissions_button'),
        );
        await tester.ensureVisible(verifyAllBtn);
        await tester.pumpAndSettle();
        await tester.tap(verifyAllBtn);
        await tester.pumpAndSettle();

        expect(find.text('マイク: 許可済み'), findsOneWidget);
        expect(find.text('カメラ: 許可済み'), findsOneWidget);
        expect(find.text('画面共有: 許可済み'), findsOneWidget);
      },
    );

    testWidgets(
      'retries failed probes and handles disposal under pending async probe',
      (final WidgetTester tester) async {
        final probe = _FakeVideoPreflightProbe(
          initial: _healthyChromiumSnapshot(),
        )..throwOnCollect = true;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: VideoPreflightContainer(probe: probe),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('video_preflight_error_banner')),
          findsOneWidget,
        );

        probe.throwOnCollect = false;
        final retryBtn = find.byKey(
          const ValueKey<String>('video_preflight_retry_button'),
        );
        await tester.ensureVisible(retryBtn);
        await tester.pumpAndSettle();
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('video_preflight_error_banner')),
          findsNothing,
        );

        final completer = Completer<VideoSystemSnapshot>();
        final pendingProbe = _FakeVideoPreflightProbe(
          initial: _healthyChromiumSnapshot(),
        )..pendingCollect = completer;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoPreflightContainer(probe: pendingProbe),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        completer.complete(_healthyChromiumSnapshot());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in const <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(1280, 800),
    ]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final probe = _FakeVideoPreflightProbe(
                initial: _healthyChromiumSnapshot(),
              );
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'video_preflight_${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: VideoPreflightContainer(
                            probe: probe,
                            onProceedToEditor: () {},
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

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
              expect(tester.takeException(), isNull);
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
