import 'dart:async';

import 'package:flutter/material.dart';

import 'application/voice_clone_consent_controller.dart';
import 'data/supabase_voice_clone_consent_repository.dart';
import 'data/voice_audio_recorder.dart';
import 'domain/voice_clone_consent_models.dart';
import 'presentation/voice_clone_consent_view.dart';

/// DI container for AI voice clone explicit consent verification (#2715).
class VoiceCloneConsentContainer extends StatefulWidget {
  const VoiceCloneConsentContainer({
    super.key,
    this.repository,
    this.recorder,
    this.controller,
    this.autoLoad = true,
  });

  final VoiceCloneConsentRepository? repository;
  final VoiceConsentAudioRecorder? recorder;
  final VoiceCloneConsentController? controller;
  final bool autoLoad;

  @override
  State<VoiceCloneConsentContainer> createState() =>
      _VoiceCloneConsentContainerState();
}

class _VoiceCloneConsentContainerState
    extends State<VoiceCloneConsentContainer> {
  late final VoiceConsentAudioRecorder _recorder;
  late final bool _ownsRecorder;
  late final VoiceCloneConsentController _controller;
  late final bool _ownsController;
  final TextEditingController _spokenTranscriptController =
      TextEditingController();
  final TextEditingController _voiceNameController = TextEditingController();
  final TextEditingController _sampleTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsRecorder = widget.recorder == null;
    _recorder = widget.recorder ?? createVoiceConsentAudioRecorder();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        VoiceCloneConsentController(
          repository:
              widget.repository ?? SupabaseVoiceCloneConsentRepository(),
          recorder: _recorder,
        );
    if (widget.autoLoad) {
      unawaited(_controller.loadStatus());
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    if (_ownsRecorder) {
      unawaited(_recorder.dispose());
    }
    _spokenTranscriptController.dispose();
    _voiceNameController.dispose();
    _sampleTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return VoiceCloneConsentView(
          state: _controller.state,
          isMicrophoneSupported: _controller.isMicrophoneSupported,
          spokenTranscriptController: _spokenTranscriptController,
          voiceNameController: _voiceNameController,
          sampleTextController: _sampleTextController,
          onRetryLoad: () {
            unawaited(_controller.loadStatus());
          },
          onTogglePrivacy: (final bool nextVal) {
            _controller.updateLegalCheck(privacyAccepted: nextVal);
          },
          onToggleTerms: (final bool nextVal) {
            _controller.updateLegalCheck(termsAccepted: nextVal);
          },
          onToggleBiometric: (final bool nextVal) {
            _controller.updateLegalCheck(biometricAccepted: nextVal);
          },
          onAcceptLegalConsents: () {
            unawaited(_controller.acceptLegalConsents());
          },
          onStartRecording: () {
            unawaited(_controller.startMicrophoneRecording());
          },
          onStopAndSubmitRecording: () {
            unawaited(
              _controller.stopAndSubmitRecording(
                spokenTranscript: _spokenTranscriptController.text,
              ),
            );
          },
          onRevokeConsent: () {
            unawaited(_controller.revokeConsent());
          },
          onTestVoiceCloneGeneration: () {
            unawaited(
              _controller.testVoiceCloneGeneration(
                voiceName: _voiceNameController.text,
                sampleText: _sampleTextController.text,
              ),
            );
          },
        );
      },
    );
  }
}
