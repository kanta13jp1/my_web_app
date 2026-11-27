import 'package:flutter/foundation.dart';

import '../domain/video_preflight_models.dart';

/// Immutable UI state for pre-editor system/browser preflight diagnostics (#2716).
class VideoPreflightState {
  const VideoPreflightState({
    this.isChecking = false,
    this.isProbingPermissions = false,
    this.report,
    this.errorMessage,
    this.statusNotice,
    this.shouldShowTroubleshootingDialog = false,
  });

  final bool isChecking;
  final bool isProbingPermissions;
  final VideoPreflightReport? report;
  final String? errorMessage;
  final String? statusNotice;
  final bool shouldShowTroubleshootingDialog;

  VideoPreflightState copyWith({
    final bool? isChecking,
    final bool? isProbingPermissions,
    final VideoPreflightReport? report,
    final String? errorMessage,
    final bool clearError = false,
    final String? statusNotice,
    final bool clearNotice = false,
    final bool? shouldShowTroubleshootingDialog,
  }) {
    return VideoPreflightState(
      isChecking: isChecking ?? this.isChecking,
      isProbingPermissions: isProbingPermissions ?? this.isProbingPermissions,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      statusNotice: clearNotice ? null : (statusNotice ?? this.statusNotice),
      shouldShowTroubleshootingDialog: shouldShowTroubleshootingDialog ??
          this.shouldShowTroubleshootingDialog,
    );
  }
}

/// Application controller running pre-editor checks & permission probes (#2716).
class VideoPreflightController extends ChangeNotifier {
  VideoPreflightController({required final VideoPreflightProbe probe})
      : _probe = probe;

  final VideoPreflightProbe _probe;
  VideoPreflightState _state = const VideoPreflightState();
  bool _disposed = false;

  VideoPreflightState get state => _state;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _emit(final VideoPreflightState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    notifyListeners();
  }

  Future<void> runAutomaticPreflight() async {
    _emit(
      _state.copyWith(
        isChecking: true,
        clearError: true,
        clearNotice: true,
        shouldShowTroubleshootingDialog: false,
      ),
    );
    try {
      final snapshot = await _probe.collectSnapshot();
      if (_disposed) return;
      final report = evaluateVideoPreflight(snapshot);
      _emit(
        _state.copyWith(
          isChecking: false,
          report: report,
          shouldShowTroubleshootingDialog: report.hasBlockers,
          statusNotice:
              report.canProceedSmoothly ? '全システム要件・ブラウザ互換チェックに合格しました。' : null,
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isChecking: false,
          errorMessage: 'システム要件の自動検知に失敗しました: $err',
        ),
      );
    }
  }

  Future<void> verifyPermission(final String capability) async {
    _emit(
      _state.copyWith(
        isProbingPermissions: true,
        clearError: true,
        clearNotice: true,
        shouldShowTroubleshootingDialog: false,
      ),
    );
    try {
      final snapshot = await _probe.verifyPermission(capability: capability);
      if (_disposed) return;
      final report = evaluateVideoPreflight(snapshot);
      _emit(
        _state.copyWith(
          isProbingPermissions: false,
          report: report,
          shouldShowTroubleshootingDialog: report.hasBlockers,
          statusNotice: report.hasBlockers
              ? null
              : 'パーミッション検証を更新しました (${capability.toUpperCase()})。',
        ),
      );
    } catch (err) {
      if (_disposed) return;
      _emit(
        _state.copyWith(
          isProbingPermissions: false,
          errorMessage: '権限チェックの実行に失敗しました: $err',
        ),
      );
    }
  }

  void openTroubleshootingDialog() {
    _emit(_state.copyWith(shouldShowTroubleshootingDialog: true));
  }

  void markTroubleshootingDialogShown() {
    if (_state.shouldShowTroubleshootingDialog) {
      _emit(_state.copyWith(shouldShowTroubleshootingDialog: false));
    }
  }
}
