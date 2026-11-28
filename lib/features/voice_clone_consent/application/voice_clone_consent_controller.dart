import 'package:flutter/foundation.dart';

import '../domain/voice_clone_consent_models.dart';

/// Immutable UI state for AI voice clone explicit consent verification (#2715).
class VoiceCloneConsentState {
  const VoiceCloneConsentState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.isRecording = false,
    this.privacyAccepted = false,
    this.termsAccepted = false,
    this.biometricAccepted = false,
    this.bundle,
    this.pendingRecording,
    this.lastGenerationResult,
    this.errorMessage,
    this.statusNotice,
  });

  final bool isLoading;
  final bool isSubmitting;
  final bool isRecording;
  final bool privacyAccepted;
  final bool termsAccepted;
  final bool biometricAccepted;
  final VoiceCloneConsentBundle? bundle;
  final VoiceAudioCaptureResult? pendingRecording;
  final VoiceCloneGenerationResult? lastGenerationResult;
  final String? errorMessage;
  final String? statusNotice;

  bool get allLegalConsentsChecked =>
      privacyAccepted && termsAccepted && biometricAccepted;

  bool get isVerified => bundle?.canGenerateVoiceClone == true;

  VoiceCloneConsentStatus get consentStatus =>
      bundle?.consent?.status ?? VoiceCloneConsentStatus.pendingTerms;

  VoiceCloneConsentState copyWith({
    final bool? isLoading,
    final bool? isSubmitting,
    final bool? isRecording,
    final bool? privacyAccepted,
    final bool? termsAccepted,
    final bool? biometricAccepted,
    final VoiceCloneConsentBundle? bundle,
    final VoiceAudioCaptureResult? pendingRecording,
    final bool clearPendingRecording = false,
    final VoiceCloneGenerationResult? lastGenerationResult,
    final bool clearGenerationResult = false,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
  }) {
    return VoiceCloneConsentState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRecording: isRecording ?? this.isRecording,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      biometricAccepted: biometricAccepted ?? this.biometricAccepted,
      bundle: bundle ?? this.bundle,
      pendingRecording: clearPendingRecording
          ? null
          : (pendingRecording ?? this.pendingRecording),
      lastGenerationResult: clearGenerationResult
          ? null
          : (lastGenerationResult ?? this.lastGenerationResult),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
    );
  }
}

/// Application controller for AI voice clone consent verification (#2715).
class VoiceCloneConsentController extends ChangeNotifier {
  VoiceCloneConsentController({
    required final VoiceCloneConsentRepository repository,
    required final VoiceConsentAudioRecorder recorder,
  })  : _repository = repository,
        _recorder = recorder;

  final VoiceCloneConsentRepository _repository;
  final VoiceConsentAudioRecorder _recorder;
  VoiceCloneConsentState _state = const VoiceCloneConsentState();
  bool _disposed = false;

  VoiceCloneConsentState get state => _state;

  bool get isMicrophoneSupported => _recorder.isMicrophoneSupported;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final VoiceCloneConsentState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  Future<void> loadStatus() async {
    _emit(_state.copyWith(isLoading: true, clearError: true));
    try {
      final bundle = await _repository.fetchConsentStatus();
      if (_disposed) return;
      final consent = bundle.consent;
      _emit(
        _state.copyWith(
          isLoading: false,
          bundle: bundle,
          privacyAccepted: consent?.privacyPolicyAccepted ?? false,
          termsAccepted: consent?.termsAccepted ?? false,
          biometricAccepted: consent?.biometricNoticeAccepted ?? false,
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isLoading: false,
          errorMessage: '同意状態の読み込みに失敗しました: $err',
        ),
      );
    }
  }

  void updateLegalCheck({
    final bool? privacyAccepted,
    final bool? termsAccepted,
    final bool? biometricAccepted,
  }) {
    _emit(
      _state.copyWith(
        privacyAccepted: privacyAccepted ?? _state.privacyAccepted,
        termsAccepted: termsAccepted ?? _state.termsAccepted,
        biometricAccepted: biometricAccepted ?? _state.biometricAccepted,
        clearError: true,
      ),
    );
  }

  Future<void> acceptLegalConsents() async {
    if (!_state.allLegalConsentsChecked) {
      _emit(
        _state.copyWith(
          errorMessage: 'プライバシーポリシー・利用規約・生体声紋通知のすべてに同意してください。',
        ),
      );
      return;
    }

    final privacyVersion = _state.bundle?.privacyPolicyVersion ?? '2026-11';
    final termsVersion = _state.bundle?.termsVersion ?? '2026-11';

    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final bundle = await _repository.acceptLegalConsents(
        privacyPolicyAccepted: _state.privacyAccepted,
        termsAccepted: _state.termsAccepted,
        biometricNoticeAccepted: _state.biometricAccepted,
        privacyPolicyVersion: privacyVersion,
        termsVersion: termsVersion,
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          bundle: bundle,
          statusNotice: '規約への同意を記録しました。続いて確認フレーズを録音してください。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '規約同意の保存に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> startMicrophoneRecording() async {
    if (_state.isRecording || _state.isSubmitting) return;
    _emit(
      _state.copyWith(
        clearError: true,
        clearNotice: true,
        clearPendingRecording: true,
      ),
    );
    try {
      await _recorder.startRecording();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isRecording: true,
          statusNotice: 'マイク録音中です。表示された確認フレーズを読み上げて停止してください。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isRecording: false,
          errorMessage: 'マイク録音の開始に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> stopAndSubmitRecording({
    required final String spokenTranscript,
  }) async {
    if (!_state.isRecording) return;
    _emit(_state.copyWith(isSubmitting: true, clearError: true));
    try {
      final captured = await _recorder.stopRecording();
      if (_disposed) return;
      final withTranscript = VoiceAudioCaptureResult(
        bytes: captured.bytes,
        mimeType: captured.mimeType,
        durationMs: captured.durationMs,
        spokenTranscript: spokenTranscript.trim(),
      );
      _emit(
        _state.copyWith(
          isRecording: false,
          pendingRecording: withTranscript,
        ),
      );
      await _submitAudioInternal(withTranscript);
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isRecording: false,
          isSubmitting: false,
          errorMessage: '録音の停止または送信に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> submitUploadedAudioFile({
    required final Uint8List bytes,
    required final String mimeType,
    required final int durationMs,
    required final String spokenTranscript,
  }) async {
    final capture = VoiceAudioCaptureResult(
      bytes: bytes,
      mimeType: mimeType,
      durationMs: durationMs,
      spokenTranscript: spokenTranscript.trim(),
    );
    _emit(
      _state.copyWith(
        isSubmitting: true,
        pendingRecording: capture,
        clearError: true,
        clearNotice: true,
      ),
    );
    await _submitAudioInternal(capture);
  }

  Future<void> _submitAudioInternal(
    final VoiceAudioCaptureResult capture,
  ) async {
    try {
      final bundle = await _repository.submitConsentRecording(
        recording: capture,
        microphonePermissionGranted: true,
      );
      if (_disposed) return;
      final verified = bundle.canGenerateVoiceClone;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          bundle: bundle,
          clearPendingRecording: true,
          statusNotice: verified
              ? '確認音声の証跡を保存し、ボイスクローン生成の同意検証が完了しました。'
              : '確認音声は保存されましたが、確認フレーズ再提出が必要です。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '確認音声の検証・保存に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> revokeConsent() async {
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final bundle = await _repository.revokeConsent();
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          bundle: bundle,
          privacyAccepted: false,
          termsAccepted: false,
          biometricAccepted: false,
          clearGenerationResult: true,
          statusNotice: 'ボイスクローン同意を取り消し、生成機能をロックしました。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: '同意の取り消しに失敗しました: $err',
        ),
      );
    }
  }

  Future<void> testVoiceCloneGeneration({
    required final String voiceName,
    required final String sampleText,
  }) async {
    final normalizedName =
        voiceName.trim().isEmpty ? 'My Verified Voice' : voiceName.trim();
    _emit(
      _state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );
    try {
      final result = await _repository.attemptVoiceCloneGeneration(
        voiceName: normalizedName,
        sampleText: sampleText.trim(),
      );
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          lastGenerationResult: result,
          statusNotice:
              result.allowed ? result.message : 'システムロック発動: ${result.message}',
        ),
      );
      await loadStatus();
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isSubmitting: false,
          errorMessage: 'ボイスクローン生成テストに失敗しました: $err',
        ),
      );
    }
  }
}
