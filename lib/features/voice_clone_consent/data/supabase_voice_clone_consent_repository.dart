import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/voice_clone_consent_models.dart';

typedef _JsonMap = Map<String, Object?>;

/// Supabase `ai-hub` repository for AI voice clone consent verification (#2715).
class SupabaseVoiceCloneConsentRepository
    implements VoiceCloneConsentRepository {
  SupabaseVoiceCloneConsentRepository({final SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _resolvedClient => _client ?? Supabase.instance.client;

  Future<_JsonMap> _invoke(final _JsonMap body) async {
    final response = await _resolvedClient.functions.invoke(
      'ai-hub',
      body: body,
    );
    final Object? raw = response.data;
    if (raw is! Map) {
      throw StateError('Unexpected response payload from ai-hub');
    }
    return Map<String, Object?>.from(raw);
  }

  VoiceCloneConsentBundle _parseBundle(final _JsonMap data) {
    final Object? rawConsent = data['consent'];
    final _JsonMap? consentMap =
        rawConsent is Map ? Map<String, Object?>.from(rawConsent) : null;
    final List<Object?> rawProfiles =
        (data['profiles'] as List<Object?>?) ?? const <Object?>[];
    final profilesList = rawProfiles.whereType<Map<Object?, Object?>>().map(
      (final Map<Object?, Object?> item) {
        final m = Map<String, Object?>.from(item);
        return VoiceCloneProfile(
          id: m['id']?.toString() ?? '',
          voiceName: m['voice_name']?.toString() ?? 'Custom Voice',
          isEnabled: m['is_enabled'] == true,
          createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
              DateTime.now().toUtc(),
        );
      },
    ).toList();

    return VoiceCloneConsentBundle(
      canGenerateVoiceClone: data['can_generate_voice_clone'] == true,
      requiredPhrase: data['required_phrase']?.toString() ??
          consentMap?['verification_phrase']?.toString() ??
          '',
      phraseNonce: data['phrase_nonce']?.toString() ??
          consentMap?['phrase_nonce']?.toString() ??
          '',
      privacyPolicyVersion:
          data['privacy_policy_version']?.toString() ?? '2026-11',
      termsVersion: data['terms_version']?.toString() ?? '2026-11',
      consent: consentMap == null
          ? null
          : VoiceCloneConsentRecord(
              id: consentMap['id']?.toString() ?? '',
              status: VoiceCloneConsentStatus.fromWire(
                consentMap['consent_status']?.toString(),
              ),
              privacyPolicyVersion:
                  consentMap['privacy_policy_version']?.toString() ?? '2026-11',
              termsVersion:
                  consentMap['terms_version']?.toString() ?? '2026-11',
              privacyPolicyAccepted:
                  consentMap['privacy_policy_accepted'] == true,
              termsAccepted: consentMap['terms_accepted'] == true,
              biometricNoticeAccepted:
                  consentMap['biometric_notice_accepted'] == true,
              verificationPhrase:
                  consentMap['verification_phrase']?.toString() ?? '',
              phraseNonce: consentMap['phrase_nonce']?.toString() ?? '',
              recordingStoragePath:
                  consentMap['recording_storage_path']?.toString(),
              recordingSha256: consentMap['recording_sha256']?.toString(),
              recordingByteSize: _asInt(consentMap['recording_byte_size']),
              recordingDurationMs: _asInt(consentMap['recording_duration_ms']),
              verifiedAt: DateTime.tryParse(
                consentMap['verified_at']?.toString() ?? '',
              ),
              rejectionReason: consentMap['rejection_reason']?.toString(),
            ),
      profiles: profilesList,
    );
  }

  @override
  Future<VoiceCloneConsentBundle> fetchConsentStatus() async {
    final data = await _invoke(<String, Object?>{
      'action': 'voice.clone.consent.status',
    });
    return _parseBundle(data);
  }

  @override
  Future<VoiceCloneConsentBundle> acceptLegalConsents({
    required final bool privacyPolicyAccepted,
    required final bool termsAccepted,
    required final bool biometricNoticeAccepted,
    required final String privacyPolicyVersion,
    required final String termsVersion,
  }) async {
    final data = await _invoke(<String, Object?>{
      'action': 'voice.clone.consent.accept',
      'privacy_policy_accepted': privacyPolicyAccepted,
      'terms_accepted': termsAccepted,
      'biometric_notice_accepted': biometricNoticeAccepted,
      'privacy_policy_version': privacyPolicyVersion,
      'terms_version': termsVersion,
    });
    return _parseBundle(data);
  }

  @override
  Future<VoiceCloneConsentBundle> submitConsentRecording({
    required final VoiceAudioCaptureResult recording,
    required final bool microphonePermissionGranted,
  }) async {
    final data = await _invoke(<String, Object?>{
      'action': 'voice.clone.consent.submit_recording',
      'audio_base64': base64Encode(recording.bytes),
      'mime_type': recording.mimeType,
      'duration_ms': recording.durationMs,
      'spoken_transcript': recording.spokenTranscript,
      'microphone_permission_granted': microphonePermissionGranted,
    });
    return _parseBundle(data);
  }

  @override
  Future<VoiceCloneConsentBundle> revokeConsent() async {
    final data = await _invoke(<String, Object?>{
      'action': 'voice.clone.consent.revoke',
    });
    return _parseBundle(data);
  }

  @override
  Future<VoiceCloneGenerationResult> attemptVoiceCloneGeneration({
    required final String voiceName,
    required final String sampleText,
  }) async {
    try {
      final data = await _invoke(<String, Object?>{
        'action': 'voice.clone.generate',
        'voice_name': voiceName,
        'sample_text': sampleText,
      });
      final Object? rawProfile = data['profile'];
      final _JsonMap? profileMap =
          rawProfile is Map ? Map<String, Object?>.from(rawProfile) : null;
      return VoiceCloneGenerationResult(
        allowed: data['allowed'] == true,
        consentStatus: VoiceCloneConsentStatus.fromWire(
          data['consent_status']?.toString(),
        ),
        message: data['message']?.toString() ?? 'ボイスクローン生成を許可しました。',
        profile: profileMap == null
            ? null
            : VoiceCloneProfile(
                id: profileMap['id']?.toString() ?? '',
                voiceName: profileMap['voice_name']?.toString() ?? voiceName,
                isEnabled: profileMap['is_enabled'] == true,
                createdAt: DateTime.tryParse(
                      profileMap['created_at']?.toString() ?? '',
                    ) ??
                    DateTime.now().toUtc(),
              ),
      );
    } on FunctionException catch (err) {
      final Object? errDetails = err.details;
      if (err.status == 403 && errDetails is Map) {
        final detail = Map<String, Object?>.from(errDetails);
        return VoiceCloneGenerationResult(
          allowed: false,
          consentStatus: VoiceCloneConsentStatus.fromWire(
            detail['consent_status']?.toString(),
          ),
          message:
              detail['message']?.toString() ?? '同意検証未完了のためシステムレベルでブロックされました。',
        );
      }
      rethrow;
    }
  }
}

int _asInt(final Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
