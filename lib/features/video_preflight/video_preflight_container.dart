import 'dart:async';

import 'package:flutter/material.dart';

import 'application/video_preflight_controller.dart';
import 'data/browser_video_preflight_probe.dart';
import 'domain/video_preflight_models.dart';
import 'presentation/video_preflight_view.dart';

/// DI container running browser/hardware preflight before video editing (#2716).
class VideoPreflightContainer extends StatefulWidget {
  const VideoPreflightContainer({
    super.key,
    this.probe,
    this.controller,
    this.autoRun = true,
    this.onProceedToEditor,
  });

  final VideoPreflightProbe? probe;
  final VideoPreflightController? controller;
  final bool autoRun;
  final VoidCallback? onProceedToEditor;

  @override
  State<VideoPreflightContainer> createState() =>
      _VideoPreflightContainerState();
}

class _VideoPreflightContainerState extends State<VideoPreflightContainer> {
  late final VideoPreflightController _controller;
  late final bool _ownsController;
  bool _dialogShowing = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        VideoPreflightController(
          probe: widget.probe ?? createBrowserVideoPreflightProbe(),
        );
    _controller.addListener(_handleControllerChanged);
    if (widget.autoRun) {
      unawaited(_controller.runAutomaticPreflight());
    }
  }

  void _handleControllerChanged() {
    if (!mounted) return;
    final state = _controller.state;
    final report = state.report;
    if (state.shouldShowTroubleshootingDialog &&
        report != null &&
        !_dialogShowing) {
      _dialogShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((final Duration _) async {
        if (!mounted) {
          _dialogShowing = false;
          return;
        }
        _controller.markTroubleshootingDialogShown();
        await showDialog<void>(
          context: context,
          builder: (final BuildContext dialogCtx) =>
              buildVideoPreflightTroubleshootingDialog(dialogCtx, report),
        );
        _dialogShowing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (final BuildContext context, final Widget? child) {
        return VideoPreflightView(
          state: _controller.state,
          onRerunPreflight: () {
            unawaited(_controller.runAutomaticPreflight());
          },
          onVerifyPermission: (final String capability) {
            unawaited(_controller.verifyPermission(capability));
          },
          onOpenTroubleshooting: () {
            _controller.openTroubleshootingDialog();
          },
          onProceedToEditor: widget.onProceedToEditor,
        );
      },
    );
  }
}
