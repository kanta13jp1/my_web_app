import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/voice_clone_consent/domain/voice_clone_consent_models.dart';
import 'package:my_web_app/features/voice_clone_consent/voice_clone_consent_container.dart';

class _FakeVoiceConsentRecorder implements VoiceConsentAudioRecorder {
  bool started = false;
  bool disposed = false;

  @override
  bool get isMicrophoneSupported => true;

  @override
  Future<void> startRecording() async {
    started = true;
  }

  @override
  Future<VoiceAudioCaptureResult> stopRecording() async {
    started = false;
    return VoiceAudioCaptureResult(
      bytes: Uint8List.fromList(
        List<int>.generate(
          256,
          (final int i) => (i % 120) + 1,
        ),
      ),
      mimeType: 'audio/webm',
      durationMs: 2400,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeVoiceCloneConsentRepository implements VoiceCloneConsentRepository {
  VoiceCloneConsentRecord? _consent;
  final List<VoiceCloneProfile> _profiles = <VoiceCloneProfile>[];
  bool throwOnLoad = false;
  Completer<VoiceCloneConsentBundle>? pendingLoad;

  static const String _nonce = 'VC-TEST01';
  static const String _phrase =
      '私は自分株式会社のプライバシーポリシーおよび利用規約に同意し、私自身の声でAIボイスクローンを生成することを明示的に許可します。確認コード VC-TEST01';

  VoiceCloneConsentBundle _buildBundle() {
    final consent = _consent;
    return VoiceCloneConsentBundle(
      canGenerateVoiceClone: consent?.status.isVerified ?? false,
      requiredPhrase: _phrase,
      phraseNonce: _nonce,
      privacyPolicyVersion: '2026-11',
      termsVersion: '2026-11',
      consent: consent,
      profiles: List<VoiceCloneProfile>.unmodifiable(_profiles),
    );
  }

  @override
  Future<VoiceCloneConsentBundle> fetchConsentStatus() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('consent backend unavailable');
    }
    return _buildBundle();
  }

  @override
  Future<VoiceCloneConsentBundle> acceptLegalConsents({
    required final bool privacyPolicyAccepted,
    required final bool termsAccepted,
    required final bool biometricNoticeAccepted,
    required final String privacyPolicyVersion,
    required final String termsVersion,
  }) async {
    if (!privacyPolicyAccepted || !termsAccepted || !biometricNoticeAccepted) {
      throw StateError('all legal consents must be accepted');
    }
    _consent = VoiceCloneConsentRecord(
      id: 'consent-1',
      status: VoiceCloneConsentStatus.termsAccepted,
      privacyPolicyVersion: privacyPolicyVersion,
      termsVersion: termsVersion,
      privacyPolicyAccepted: true,
      termsAccepted: true,
      biometricNoticeAccepted: true,
      verificationPhrase: _phrase,
      phraseNonce: _nonce,
    );
    return _buildBundle();
  }

  @override
  Future<VoiceCloneConsentBundle> submitConsentRecording({
    required final VoiceAudioCaptureResult recording,
    required final bool microphonePermissionGranted,
  }) async {
    if (!microphonePermissionGranted || recording.bytes.length < 128) {
      throw StateError('invalid audio capture');
    }
    final transcript = recording.spokenTranscript.trim();
    final matched = transcript.isEmpty ||
        transcript.contains(_nonce) ||
        transcript.contains('同意');
    final prev = _consent;
    _consent = VoiceCloneConsentRecord(
      id: prev?.id ?? 'consent-1',
      status: matched
          ? VoiceCloneConsentStatus.verified
          : VoiceCloneConsentStatus.rejected,
      privacyPolicyVersion: prev?.privacyPolicyVersion ?? '2026-11',
      termsVersion: prev?.termsVersion ?? '2026-11',
      privacyPolicyAccepted: prev?.privacyPolicyAccepted ?? true,
      termsAccepted: prev?.termsAccepted ?? true,
      biometricNoticeAccepted: prev?.biometricNoticeAccepted ?? true,
      verificationPhrase: _phrase,
      phraseNonce: _nonce,
      recordingStoragePath: 'usr-1/$_nonce.webm',
      recordingSha256:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      recordingByteSize: recording.bytes.length,
      recordingDurationMs: recording.durationMs,
      verifiedAt: matched ? DateTime.now().toUtc() : null,
      rejectionReason: matched ? null : 'spoken phrase mismatch',
    );
    return _buildBundle();
  }

  @override
  Future<VoiceCloneConsentBundle> revokeConsent() async {
    for (int i = 0; i < _profiles.length; i++) {
      final p = _profiles[i];
      _profiles[i] = VoiceCloneProfile(
        id: p.id,
        voiceName: p.voiceName,
        isEnabled: false,
        createdAt: p.createdAt,
      );
    }
    _consent = VoiceCloneConsentRecord(
      id: _consent?.id ?? 'consent-1',
      status: VoiceCloneConsentStatus.revoked,
      privacyPolicyVersion: '2026-11',
      termsVersion: '2026-11',
      privacyPolicyAccepted: false,
      termsAccepted: false,
      biometricNoticeAccepted: false,
      verificationPhrase: _phrase,
      phraseNonce: _nonce,
    );
    return _buildBundle();
  }

  @override
  Future<VoiceCloneGenerationResult> attemptVoiceCloneGeneration({
    required final String voiceName,
    required final String sampleText,
  }) async {
    final current = _consent;
    if (current == null || !current.status.isVerified) {
      return VoiceCloneGenerationResult(
        allowed: false,
        consentStatus: current?.status ?? VoiceCloneConsentStatus.pendingTerms,
        message: '同意検証未完了のためシステムレベルでブロックされました。',
      );
    }
    final created = VoiceCloneProfile(
      id: 'clone_profile_${_profiles.length + 1}',
      voiceName: voiceName,
      isEnabled: true,
      createdAt: DateTime.now().toUtc(),
    );
    _profiles.insert(0, created);
    return VoiceCloneGenerationResult(
      allowed: true,
      consentStatus: VoiceCloneConsentStatus.verified,
      message: '検証済みボイスクローンを有効化しました。',
      profile: created,
    );
  }
}

void main() {
  group('VoiceCloneConsentModels and VoiceCloneConsentContainer (#2715)', () {
    test(
      'parses VoiceCloneConsentStatus wire values safely and marks only verified as unlocked',
      () {
        expect(
          VoiceCloneConsentStatus.fromWire('verified').isVerified,
          isTrue,
        );
        expect(
          VoiceCloneConsentStatus.fromWire('terms_accepted').isVerified,
          isFalse,
        );
        expect(
          VoiceCloneConsentStatus.fromWire('revoked').isVerified,
          isFalse,
        );
        expect(
          VoiceCloneConsentStatus.fromWire('unknown'),
          VoiceCloneConsentStatus.pendingTerms,
        );
      },
    );

    testWidgets(
      'blocks generation until legal terms + spoken voice recording verification pass, and re-locks on revoke',
      (final WidgetTester tester) async {
        final repo = _FakeVoiceCloneConsentRepository();
        final recorder = _FakeVoiceConsentRecorder();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: VoiceCloneConsentContainer(
                repository: repo,
                recorder: recorder,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Before consent, attempting generation hits system-level block.
        final testGenBtn = find.byKey(
          const ValueKey<String>('voice_test_clone_generate_button'),
        );
        await tester.ensureVisible(testGenBtn);
        await tester.pumpAndSettle();
        await tester.tap(testGenBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('allowed=false'),
          findsOneWidget,
        );

        // 2. Check all 3 legal checkboxes and accept terms.
        for (final keyName in const <String>[
          'voice_privacy_checkbox',
          'voice_terms_checkbox',
          'voice_biometric_checkbox',
        ]) {
          final box = find.byKey(ValueKey<String>(keyName));
          await tester.ensureVisible(box);
          await tester.pumpAndSettle();
          await tester.tap(box);
          await tester.pumpAndSettle();
        }

        final acceptBtn = find.byKey(
          const ValueKey<String>('voice_accept_terms_button'),
        );
        await tester.ensureVisible(acceptBtn);
        await tester.pumpAndSettle();
        await tester.tap(acceptBtn);
        await tester.pumpAndSettle();

        expect(find.text('規約同意済み・録音待ち'), findsOneWidget);

        // 3. Record spoken confirmation phrase and submit verification evidence.
        final transcriptField = find.byKey(
          const ValueKey<String>('voice_spoken_transcript_field'),
        );
        await tester.ensureVisible(transcriptField);
        await tester.pumpAndSettle();
        await tester.enterText(transcriptField, '同意します VC-TEST01');

        final startRecBtn = find.byKey(
          const ValueKey<String>('voice_start_recording_button'),
        );
        await tester.ensureVisible(startRecBtn);
        await tester.pumpAndSettle();
        await tester.tap(startRecBtn);
        await tester.pumpAndSettle();
        expect(recorder.started, isTrue);

        final stopSubmitBtn = find.byKey(
          const ValueKey<String>('voice_stop_submit_button'),
        );
        await tester.ensureVisible(stopSubmitBtn);
        await tester.pumpAndSettle();
        await tester.tap(stopSubmitBtn);
        await tester.pumpAndSettle();

        expect(find.text('本人音声検証済み'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('voice_evidence_metadata_text')),
          findsOneWidget,
        );

        // 4. Verified user unlocks clone generation.
        final voiceNameField = find.byKey(
          const ValueKey<String>('voice_clone_name_field'),
        );
        await tester.ensureVisible(voiceNameField);
        await tester.pumpAndSettle();
        await tester.enterText(voiceNameField, 'Studio Narrator');

        await tester.ensureVisible(testGenBtn);
        await tester.pumpAndSettle();
        await tester.tap(testGenBtn);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('allowed=true'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Studio Narrator (有効)'),
          findsOneWidget,
        );

        // 5. Revoking locks generation again and disables existing profiles.
        final revokeBtn = find.byKey(
          const ValueKey<String>('voice_revoke_consent_button'),
        );
        await tester.ensureVisible(revokeBtn);
        await tester.pumpAndSettle();
        await tester.tap(revokeBtn);
        await tester.pumpAndSettle();

        expect(find.text('同意取消済み'), findsOneWidget);
        expect(
          find.textContaining('Studio Narrator (無効/ロック)'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'retries failed status loads and handles async completion safely after dispose',
      (final WidgetTester tester) async {
        final repo = _FakeVoiceCloneConsentRepository()..throwOnLoad = true;
        final recorder = _FakeVoiceConsentRecorder();

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: VoiceCloneConsentContainer(
                repository: repo,
                recorder: recorder,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('voice_consent_error_banner')),
          findsOneWidget,
        );

        repo.throwOnLoad = false;
        final retryBtn = find.byKey(
          const ValueKey<String>('voice_consent_retry_button'),
        );
        await tester.ensureVisible(retryBtn);
        await tester.pumpAndSettle();
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('voice_consent_error_banner')),
          findsNothing,
        );

        final completer = Completer<VoiceCloneConsentBundle>();
        final pendingRepo = _FakeVoiceCloneConsentRepository()
          ..pendingLoad = completer;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceCloneConsentContainer(
                repository: pendingRepo,
                recorder: _FakeVoiceConsentRecorder(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        completer.complete(
          const VoiceCloneConsentBundle(
            canGenerateVoiceClone: false,
            requiredPhrase: _FakeVoiceCloneConsentRepository._phrase,
            phraseNonce: _FakeVoiceCloneConsentRepository._nonce,
            privacyPolicyVersion: '2026-11',
            termsVersion: '2026-11',
          ),
        );
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
              final repo = _FakeVoiceCloneConsentRepository();
              final recorder = _FakeVoiceConsentRecorder();
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'voice_consent_${viewport.width.toInt()}_${brightness.name}',
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
                          body: VoiceCloneConsentContainer(
                            repository: repo,
                            recorder: recorder,
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
