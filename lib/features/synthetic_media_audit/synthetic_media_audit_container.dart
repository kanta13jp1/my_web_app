import 'package:flutter/material.dart';

import 'application/synthetic_media_audit_controller.dart';
import 'data/supabase_synthetic_media_audit_repository.dart';
import 'domain/synthetic_media_audit_models.dart';
import 'presentation/synthetic_media_audit_view.dart';

/// SyntheticMediaAuditController と View・入力コントローラを接続する Container (#2661).
class SyntheticMediaAuditContainer extends StatefulWidget {
  const SyntheticMediaAuditContainer({
    super.key,
    this.repository,
    this.controller,
    this.autoLoad = true,
  });

  final SyntheticMediaAuditRepository? repository;
  final SyntheticMediaAuditController? controller;
  final bool autoLoad;

  @override
  State<SyntheticMediaAuditContainer> createState() =>
      _SyntheticMediaAuditContainerState();
}

class _SyntheticMediaAuditContainerState
    extends State<SyntheticMediaAuditContainer> {
  late SyntheticMediaAuditController _controller;
  late bool _ownsController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController(
    text: 'https://cdn.example.com/synthetic/demo.mp4',
  );
  final TextEditingController _trackTraceIdController = TextEditingController();
  final TextEditingController _reviewNoteController = TextEditingController();

  String _sourceProvider = 'd_id';
  ConsentVerificationStatus _copyrightConsent =
      ConsentVerificationStatus.pending;
  ConsentVerificationStatus _likenessConsent =
      ConsentVerificationStatus.pending;
  bool _commercialWatermarkPresent = false;
  bool _celebrityLikenessCleared = false;
  TrackAndTraceProvider _trackAndTraceProvider = TrackAndTraceProvider.none;

  @override
  void initState() {
    super.initState();
    _initController();
    if (widget.autoLoad) {
      Future<void>.microtask(_loadInitial);
    }
  }

  void _initController() {
    final SyntheticMediaAuditController? provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ??
        SyntheticMediaAuditController(
          repository:
              widget.repository ?? SupabaseSyntheticMediaAuditRepository(),
        );
  }

  Future<void> _loadInitial() async {
    if (!mounted || _controller.isDisposed) {
      return;
    }
    await _controller.loadDashboard();
  }

  @override
  void didUpdateWidget(covariant final SyntheticMediaAuditContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        widget.repository != oldWidget.repository) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
      if (widget.autoLoad) {
        Future<void>.microtask(_loadInitial);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _trackTraceIdController.dispose();
    _reviewNoteController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleSubmitVideo() {
    _controller.submitVideo(
      SubmitSyntheticMediaInput(
        title: _titleController.text,
        videoUrl: _videoUrlController.text,
        sourceProvider: _sourceProvider,
        copyrightConsentStatus: _copyrightConsent,
        likenessConsentStatus: _likenessConsent,
        commercialWatermarkPresent: _commercialWatermarkPresent,
        celebrityLikenessCleared: _celebrityLikenessCleared,
        trackAndTraceProvider: _trackAndTraceProvider,
        trackAndTraceId: _trackTraceIdController.text.trim().isEmpty
            ? null
            : _trackTraceIdController.text.trim(),
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? _) {
        return SyntheticMediaAuditView(
          state: _controller.state,
          titleController: _titleController,
          videoUrlController: _videoUrlController,
          trackTraceIdController: _trackTraceIdController,
          reviewNoteController: _reviewNoteController,
          sourceProvider: _sourceProvider,
          copyrightConsent: _copyrightConsent,
          likenessConsent: _likenessConsent,
          commercialWatermarkPresent: _commercialWatermarkPresent,
          celebrityLikenessCleared: _celebrityLikenessCleared,
          trackAndTraceProvider: _trackAndTraceProvider,
          onRefresh: _loadInitial,
          onSelectFilter: _controller.selectStatusFilter,
          onSourceProviderChanged: (final String value) {
            setState(() {
              _sourceProvider = value;
            });
          },
          onCopyrightConsentChanged: (final ConsentVerificationStatus value) {
            setState(() {
              _copyrightConsent = value;
            });
          },
          onLikenessConsentChanged: (final ConsentVerificationStatus value) {
            setState(() {
              _likenessConsent = value;
            });
          },
          onCommercialWatermarkChanged: (final bool value) {
            setState(() {
              _commercialWatermarkPresent = value;
            });
          },
          onCelebrityClearedChanged: (final bool value) {
            setState(() {
              _celebrityLikenessCleared = value;
            });
          },
          onTrackAndTraceProviderChanged: (final TrackAndTraceProvider value) {
            setState(() {
              _trackAndTraceProvider = value;
            });
          },
          onSubmitVideo: _handleSubmitVideo,
          onApproveVideo: (final SyntheticMediaVideo video) {
            _controller.reviewVideo(
              target: video,
              decision: SyntheticMediaModerationStatus.approved,
              reviewNote: _reviewNoteController.text.trim().isEmpty
                  ? null
                  : _reviewNoteController.text.trim(),
            );
          },
          onRejectVideo: (final SyntheticMediaVideo video) {
            _controller.reviewVideo(
              target: video,
              decision: SyntheticMediaModerationStatus.rejected,
              reviewNote: _reviewNoteController.text,
            );
          },
        );
      },
    );
  }
}
