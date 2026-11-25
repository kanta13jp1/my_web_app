import 'package:flutter/material.dart';

import '../application/voice_clone_consent_controller.dart';
import '../domain/voice_clone_consent_models.dart';

/// Pure presentation view for AI voice clone explicit consent verification (#2715).
class VoiceCloneConsentView extends StatelessWidget {
  const VoiceCloneConsentView({
    super.key,
    required this.state,
    required this.isMicrophoneSupported,
    required this.spokenTranscriptController,
    required this.voiceNameController,
    required this.sampleTextController,
    required this.onRetryLoad,
    required this.onTogglePrivacy,
    required this.onToggleTerms,
    required this.onToggleBiometric,
    required this.onAcceptLegalConsents,
    required this.onStartRecording,
    required this.onStopAndSubmitRecording,
    required this.onRevokeConsent,
    required this.onTestVoiceCloneGeneration,
  });

  final VoiceCloneConsentState state;
  final bool isMicrophoneSupported;
  final TextEditingController spokenTranscriptController;
  final TextEditingController voiceNameController;
  final TextEditingController sampleTextController;
  final VoidCallback onRetryLoad;
  final ValueChanged<bool> onTogglePrivacy;
  final ValueChanged<bool> onToggleTerms;
  final ValueChanged<bool> onToggleBiometric;
  final VoidCallback onAcceptLegalConsents;
  final VoidCallback onStartRecording;
  final VoidCallback onStopAndSubmitRecording;
  final VoidCallback onRevokeConsent;
  final VoidCallback onTestVoiceCloneGeneration;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bundle = state.bundle;
    final status = state.consentStatus;
    final legalDone = bundle?.consent?.privacyPolicyAccepted == true &&
        bundle?.consent?.termsAccepted == true &&
        bundle?.consent?.biometricNoticeAccepted == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ConsentStatusHeaderCard(
            state: state,
            status: status,
            colors: colors,
            onRefresh: onRetryLoad,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('voice_consent_error_banner'),
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('voice_consent_retry_button'),
              onAction: onRetryLoad,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _NoticeBanner(
              key: const ValueKey<String>('voice_consent_status_banner'),
              message: state.statusNotice!,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          _LegalConsentStepCard(
            state: state,
            colors: colors,
            onTogglePrivacy: onTogglePrivacy,
            onToggleTerms: onToggleTerms,
            onToggleBiometric: onToggleBiometric,
            onAcceptLegalConsents: onAcceptLegalConsents,
          ),
          const SizedBox(height: 12),
          _PhraseRecordingStepCard(
            state: state,
            legalDone: legalDone,
            isMicrophoneSupported: isMicrophoneSupported,
            spokenTranscriptController: spokenTranscriptController,
            colors: colors,
            onStartRecording: onStartRecording,
            onStopAndSubmitRecording: onStopAndSubmitRecording,
            onRevokeConsent: onRevokeConsent,
          ),
          const SizedBox(height: 12),
          _SystemGateVerificationCard(
            state: state,
            voiceNameController: voiceNameController,
            sampleTextController: sampleTextController,
            colors: colors,
            onTestVoiceCloneGeneration: onTestVoiceCloneGeneration,
          ),
        ],
      ),
    );
  }
}

class _ConsentStatusHeaderCard extends StatelessWidget {
  const _ConsentStatusHeaderCard({
    required this.state,
    required this.status,
    required this.colors,
    required this.onRefresh,
  });

  final VoiceCloneConsentState state;
  final VoiceCloneConsentStatus status;
  final ColorScheme colors;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
    final verified = status.isVerified;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Icon(
                  verified ? Icons.verified_user : Icons.lock_outline,
                  color: verified ? colors.primary : colors.error,
                ),
                Text(
                  'AIボイスクローン明示的同意 & 本人音声検証',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Chip(
                  key: const ValueKey<String>('voice_consent_status_chip'),
                  backgroundColor: verified
                      ? colors.primaryContainer
                      : colors.errorContainer,
                  label: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: verified
                          ? colors.onPrimaryContainer
                          : colors.onErrorContainer,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('voice_consent_refresh_button'),
                  tooltip: '同意検証状態を再読み込み',
                  onPressed: state.isLoading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ディープフェイク・無断音声クローン防止のため、規約同意と本人確認フレーズの音声録音検証が完了するまでシステムレベルで生成をロックします。',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalConsentStepCard extends StatelessWidget {
  const _LegalConsentStepCard({
    required this.state,
    required this.colors,
    required this.onTogglePrivacy,
    required this.onToggleTerms,
    required this.onToggleBiometric,
    required this.onAcceptLegalConsents,
  });

  final VoiceCloneConsentState state;
  final ColorScheme colors;
  final ValueChanged<bool> onTogglePrivacy;
  final ValueChanged<bool> onToggleTerms;
  final ValueChanged<bool> onToggleBiometric;
  final VoidCallback onAcceptLegalConsents;

  @override
  Widget build(final BuildContext context) {
    final bundle = state.bundle;
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step 1: プライバシーポリシー・利用規約への同意',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '適用バージョン: Privacy ${bundle?.privacyPolicyVersion ?? '2026-11'} / Terms ${bundle?.termsVersion ?? '2026-11'}',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey<String>('voice_privacy_checkbox'),
              contentPadding: EdgeInsets.zero,
              title: const Text('プライバシーポリシー（音声証跡の暗号化保管と目的外利用禁止）に同意する'),
              value: state.privacyAccepted,
              onChanged: state.isSubmitting
                  ? null
                  : (final bool? value) => onTogglePrivacy(value ?? false),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('voice_terms_checkbox'),
              contentPadding: EdgeInsets.zero,
              title: const Text('利用規約（本人自身の声のみを使用し第三者の声質を模倣しないこと）に同意する'),
              value: state.termsAccepted,
              onChanged: state.isSubmitting
                  ? null
                  : (final bool? value) => onToggleTerms(value ?? false),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('voice_biometric_checkbox'),
              contentPadding: EdgeInsets.zero,
              title: const Text('同意確認音声をSupabase非公開ストレージに検証証跡として保存することに同意する'),
              value: state.biometricAccepted,
              onChanged: state.isSubmitting
                  ? null
                  : (final bool? value) => onToggleBiometric(value ?? false),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              key: const ValueKey<String>('voice_accept_terms_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSubmitting || !state.allLegalConsentsChecked
                  ? null
                  : onAcceptLegalConsents,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('同意して本人音声録音ステップへ進む'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhraseRecordingStepCard extends StatelessWidget {
  const _PhraseRecordingStepCard({
    required this.state,
    required this.legalDone,
    required this.isMicrophoneSupported,
    required this.spokenTranscriptController,
    required this.colors,
    required this.onStartRecording,
    required this.onStopAndSubmitRecording,
    required this.onRevokeConsent,
  });

  final VoiceCloneConsentState state;
  final bool legalDone;
  final bool isMicrophoneSupported;
  final TextEditingController spokenTranscriptController;
  final ColorScheme colors;
  final VoidCallback onStartRecording;
  final VoidCallback onStopAndSubmitRecording;
  final VoidCallback onRevokeConsent;

  @override
  Widget build(final BuildContext context) {
    final phrase =
        state.bundle?.requiredPhrase ?? '規約同意完了後に本人確認用の読み上げフレーズが発行されます。';
    final consent = state.bundle?.consent;

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step 2: 同意確認フレーズの読み上げ録音・証跡提出',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                phrase,
                key: const ValueKey<String>('voice_verification_phrase_text'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('voice_spoken_transcript_field'),
              controller: spokenTranscriptController,
              enabled: legalDone && !state.isSubmitting,
              decoration: const InputDecoration(
                labelText: '読み上げテキスト / 確認コード (照合用・任意)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ElevatedButton.icon(
                  key: const ValueKey<String>('voice_start_recording_button'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: !legalDone ||
                          state.isRecording ||
                          state.isSubmitting ||
                          !isMicrophoneSupported
                      ? null
                      : onStartRecording,
                  icon: const Icon(Icons.mic),
                  label: const Text('マイク録音を開始'),
                ),
                ElevatedButton.icon(
                  key: const ValueKey<String>('voice_stop_submit_button'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: !state.isRecording || state.isSubmitting
                      ? null
                      : onStopAndSubmitRecording,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('録音停止 & 検証提出'),
                ),
                if (consent != null &&
                    consent.status != VoiceCloneConsentStatus.revoked)
                  OutlinedButton.icon(
                    key: const ValueKey<String>('voice_revoke_consent_button'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: state.isSubmitting ? null : onRevokeConsent,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('同意を取り消す'),
                  ),
              ],
            ),
            if (consent?.recordingSha256 != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '保管済み音声証跡 SHA-256: ${consent!.recordingSha256!.substring(0, 16)}... (${consent.recordingByteSize} bytes / ${consent.recordingDurationMs} ms)',
                key: const ValueKey<String>('voice_evidence_metadata_text'),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SystemGateVerificationCard extends StatelessWidget {
  const _SystemGateVerificationCard({
    required this.state,
    required this.voiceNameController,
    required this.sampleTextController,
    required this.colors,
    required this.onTestVoiceCloneGeneration,
  });

  final VoiceCloneConsentState state;
  final TextEditingController voiceNameController;
  final TextEditingController sampleTextController;
  final ColorScheme colors;
  final VoidCallback onTestVoiceCloneGeneration;

  @override
  Widget build(final BuildContext context) {
    final result = state.lastGenerationResult;
    final profiles = state.bundle?.profiles ?? const <VoiceCloneProfile>[];

    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step 3: システムレベル・ボイスクローン生成アクセス制御',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('voice_clone_name_field'),
              controller: voiceNameController,
              decoration: const InputDecoration(
                labelText: 'カスタムボイス名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('voice_clone_sample_text_field'),
              controller: sampleTextController,
              decoration: const InputDecoration(
                labelText: '生成テストテキスト',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const ValueKey<String>('voice_test_clone_generate_button'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: state.isSubmitting ? null : onTestVoiceCloneGeneration,
              icon: const Icon(Icons.record_voice_over),
              label: Text(
                state.isVerified
                    ? '検証済みカスタムボイスを有効化・生成'
                    : '未同意アクセス制御をテスト (システムブロック確認)',
              ),
            ),
            if (result != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '生成ゲート結果: allowed=${result.allowed} (${result.consentStatus.label}) - ${result.message}',
                key: const ValueKey<String>('voice_generation_result_text'),
                style: TextStyle(
                  fontSize: 13,
                  color: result.allowed ? colors.primary : colors.error,
                ),
              ),
            ],
            if (profiles.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                '有効ボイスプロファイル (${profiles.length})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              for (final profile in profiles)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '・${profile.voiceName} (${profile.isEnabled ? '有効' : '無効/ロック'})',
                    style:
                        TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(final BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            message,
            style: TextStyle(fontSize: 13, color: foregroundColor),
          ),
          if (actionLabel != null && onAction != null)
            OutlinedButton(
              key: actionKey,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: foregroundColor,
                side: BorderSide(color: foregroundColor),
              ),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
