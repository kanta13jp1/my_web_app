import 'dart:typed_data';

/// Domain contracts for AI voice clone explicit consent verification (#2715).
enum VoiceCloneConsentStatus {
  pendingTerms('pending_terms', 'ポリシー未同意'),
  termsAccepted('terms_accepted', '規約同意済み・録音待ち'),
  recordingUploaded('recording_uploaded', '録音受領済み・検証中'),
  verified('verified', '本人音声検証済み'),
  rejected('rejected', '確認フレーズ不一致'),
  revoked('revoked', '同意取消済み');

  const VoiceCloneConsentStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isVerified => this == VoiceCloneConsentStatus.verified;

  static VoiceCloneConsentStatus fromWire(final String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    for (final status in VoiceCloneConsentStatus.values) {
      if (status.wireValue == normalized) {
        return status;
      }
    }
    return VoiceCloneConsentStatus.pendingTerms;
  }
}

class VoiceAudioCaptureResult {
  const VoiceAudioCaptureResult({
    required this.bytes,
    required this.mimeType,
    required this.durationMs,
    this.spokenTranscript = '',
  });

  final Uint8List bytes;
  final String mimeType;
  final int durationMs;
  final String spokenTranscript;
}

class VoiceCloneConsentRecord {
  const VoiceCloneConsentRecord({
    required this.id,
    required this.status,
    required this.privacyPolicyVersion,
    required this.termsVersion,
    required this.privacyPolicyAccepted,
    required this.termsAccepted,
    required this.biometricNoticeAccepted,
    required this.verificationPhrase,
    required this.phraseNonce,
    this.recordingStoragePath,
    this.recordingSha256,
    this.recordingByteSize = 0,
    this.recordingDurationMs = 0,
    this.verifiedAt,
    this.rejectionReason,
  });

  final String id;
  final VoiceCloneConsentStatus status;
  final String privacyPolicyVersion;
  final String termsVersion;
  final bool privacyPolicyAccepted;
  final bool termsAccepted;
  final bool biometricNoticeAccepted;
  final String verificationPhrase;
  final String phraseNonce;
  final String? recordingStoragePath;
  final String? recordingSha256;
  final int recordingByteSize;
  final int recordingDurationMs;
  final DateTime? verifiedAt;
  final String? rejectionReason;
}

class VoiceCloneProfile {
  const VoiceCloneProfile({
    required this.id,
    required this.voiceName,
    required this.isEnabled,
    required this.createdAt,
  });

  final String id;
  final String voiceName;
  final bool isEnabled;
  final DateTime createdAt;
}

class VoiceCloneConsentBundle {
  const VoiceCloneConsentBundle({
    required this.canGenerateVoiceClone,
    required this.requiredPhrase,
    required this.phraseNonce,
    required this.privacyPolicyVersion,
    required this.termsVersion,
    this.consent,
    this.profiles = const <VoiceCloneProfile>[],
  });

  final bool canGenerateVoiceClone;
  final String requiredPhrase;
  final String phraseNonce;
  final String privacyPolicyVersion;
  final String termsVersion;
  final VoiceCloneConsentRecord? consent;
  final List<VoiceCloneProfile> profiles;
}

class VoiceCloneGenerationResult {
  const VoiceCloneGenerationResult({
    required this.allowed,
    required this.consentStatus,
    required this.message,
    this.profile,
  });

  final bool allowed;
  final VoiceCloneConsentStatus consentStatus;
  final String message;
  final VoiceCloneProfile? profile;
}

abstract interface class VoiceConsentAudioRecorder {
  bool get isMicrophoneSupported;

  Future<void> startRecording();

  Future<VoiceAudioCaptureResult> stopRecording();

  Future<void> dispose();
}

abstract class VoiceCloneConsentRepository {
  Future<VoiceCloneConsentBundle> fetchConsentStatus();

  Future<VoiceCloneConsentBundle> acceptLegalConsents({
    required final bool privacyPolicyAccepted,
    required final bool termsAccepted,
    required final bool biometricNoticeAccepted,
    required final String privacyPolicyVersion,
    required final String termsVersion,
  });

  Future<VoiceCloneConsentBundle> submitConsentRecording({
    required final VoiceAudioCaptureResult recording,
    required final bool microphonePermissionGranted,
  });

  Future<VoiceCloneConsentBundle> revokeConsent();

  Future<VoiceCloneGenerationResult> attemptVoiceCloneGeneration({
    required final String voiceName,
    required final String sampleText,
  });
}
