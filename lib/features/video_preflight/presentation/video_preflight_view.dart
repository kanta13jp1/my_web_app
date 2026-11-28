import 'package:flutter/material.dart';

import '../application/video_preflight_controller.dart';
import '../domain/video_preflight_models.dart';

/// Builds a troubleshooting dialog explaining concrete Chrome & OS fixes (#2716).
AlertDialog buildVideoPreflightTroubleshootingDialog(
  final BuildContext context,
  final VideoPreflightReport report,
) {
  final colors = Theme.of(context).colorScheme;
  final steps = report.troubleshootingSteps.isNotEmpty
      ? report.troubleshootingSteps
      : const <String>[
          'Google Chrome / Microsoft Edge 最新版を利用し、chrome://settings/system のハードウェアアクセラレーションがオンになっているか確認してください。',
        ];

  return AlertDialog(
    key: const ValueKey<String>('video_preflight_troubleshooting_dialog'),
    icon: Icon(
      Icons.warning_amber_rounded,
      color: report.hasBlockers ? colors.error : colors.primary,
    ),
    title: Text(
      report.hasBlockers ? '動作要件未達・設定変更のご案内' : 'ブラウザ互換・推奨設定ガイド',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '検知環境: ${report.snapshot.browserName} / GPU: ${report.snapshot.gpuRenderer.isEmpty ? '不明' : report.snapshot.gpuRenderer}',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${i + 1}. ${steps[i]}',
                style: TextStyle(fontSize: 13, color: colors.onSurface),
              ),
            ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(
        key: const ValueKey<String>('video_preflight_dialog_close_button'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('閉じる'),
      ),
    ],
  );
}

/// Pure presentation view for Pre-Video-Edit System & Browser Preflight (#2716).
class VideoPreflightView extends StatelessWidget {
  const VideoPreflightView({
    super.key,
    required this.state,
    required this.onRerunPreflight,
    required this.onVerifyPermission,
    required this.onOpenTroubleshooting,
    this.onProceedToEditor,
  });

  final VideoPreflightState state;
  final VoidCallback onRerunPreflight;
  final ValueChanged<String> onVerifyPermission;
  final VoidCallback onOpenTroubleshooting;
  final VoidCallback? onProceedToEditor;

  @override
  Widget build(final BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final report = state.report;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PreflightHeaderCard(
            state: state,
            report: report,
            colors: colors,
            onRefresh: onRerunPreflight,
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            _AlertStrip(
              key: const ValueKey<String>('video_preflight_error_banner'),
              message: state.errorMessage!,
              backgroundColor: colors.errorContainer,
              foregroundColor: colors.onErrorContainer,
              actionLabel: '再試行',
              actionKey: const ValueKey<String>('video_preflight_retry_button'),
              onAction: onRerunPreflight,
            ),
            const SizedBox(height: 12),
          ],
          if (state.statusNotice != null) ...<Widget>[
            _AlertStrip(
              key: const ValueKey<String>('video_preflight_status_banner'),
              message: state.statusNotice!,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
            ),
            const SizedBox(height: 12),
          ],
          if (report != null) ...<Widget>[
            _DiagnosticsListCard(
              report: report,
              colors: colors,
            ),
            const SizedBox(height: 12),
            _PermissionsVerificationCard(
              snapshot: report.snapshot,
              isBusy: state.isChecking || state.isProbingPermissions,
              colors: colors,
              onVerifyPermission: onVerifyPermission,
            ),
            const SizedBox(height: 12),
            _ActionFooterCard(
              report: report,
              colors: colors,
              onOpenTroubleshooting: onOpenTroubleshooting,
              onProceedToEditor: onProceedToEditor,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreflightHeaderCard extends StatelessWidget {
  const _PreflightHeaderCard({
    required this.state,
    required this.report,
    required this.colors,
    required this.onRefresh,
  });

  final VideoPreflightState state;
  final VideoPreflightReport? report;
  final ColorScheme colors;
  final VoidCallback onRefresh;

  @override
  Widget build(final BuildContext context) {
    final severity = report?.overallSeverity ?? PreflightSeverity.warning;
    final Color chipBg;
    final Color chipFg;
    switch (severity) {
      case PreflightSeverity.pass:
        chipBg = colors.primaryContainer;
        chipFg = colors.onPrimaryContainer;
      case PreflightSeverity.warning:
        chipBg = colors.secondaryContainer;
        chipFg = colors.onSecondaryContainer;
      case PreflightSeverity.blocker:
        chipBg = colors.errorContainer;
        chipFg = colors.onErrorContainer;
    }

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
                Icon(Icons.fact_check_outlined, color: colors.primary),
                Text(
                  '動画編集 起動前システム・ブラウザ互換チェック',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                Chip(
                  key: const ValueKey<String>('video_preflight_status_chip'),
                  backgroundColor: chipBg,
                  label: Text(
                    severity.label,
                    style: TextStyle(fontSize: 12, color: chipFg),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('video_preflight_refresh_button'),
                  tooltip: '動作環境を再チェック',
                  onPressed: state.isChecking ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Chromium系ブラウザ推奨、WebGL GPU ハードウェアアクセラレーション、メモリ残量、およびマイク・カメラ・画面共有権限を事前診断します。',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsListCard extends StatelessWidget {
  const _DiagnosticsListCard({
    required this.report,
    required this.colors,
  });

  final VideoPreflightReport report;
  final ColorScheme colors;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '環境診断結果 (${report.checks.length}項目)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in report.checks)
              Padding(
                key: ValueKey<String>('video_preflight_check_${item.id}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Chip(
                          backgroundColor:
                              item.severity == PreflightSeverity.blocker
                                  ? colors.errorContainer
                                  : item.severity == PreflightSeverity.pass
                                      ? colors.primaryContainer
                                      : colors.secondaryContainer,
                          label: Text(
                            item.severity.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: item.severity == PreflightSeverity.blocker
                                  ? colors.onErrorContainer
                                  : item.severity == PreflightSeverity.pass
                                      ? colors.onPrimaryContainer
                                      : colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.summary,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsVerificationCard extends StatelessWidget {
  const _PermissionsVerificationCard({
    required this.snapshot,
    required this.isBusy,
    required this.colors,
    required this.onVerifyPermission,
  });

  final VideoSystemSnapshot snapshot;
  final bool isBusy;
  final ColorScheme colors;
  final ValueChanged<String> onVerifyPermission;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '録音・録画・画面共有 パーミッション事前検証',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  key: const ValueKey<String>('perm_chip_mic'),
                  label: Text('マイク: ${snapshot.microphonePermission.label}'),
                ),
                Chip(
                  key: const ValueKey<String>('perm_chip_camera'),
                  label: Text('カメラ: ${snapshot.cameraPermission.label}'),
                ),
                Chip(
                  key: const ValueKey<String>('perm_chip_screen'),
                  label: Text('画面共有: ${snapshot.screenSharePermission.label}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton.icon(
                  key: const ValueKey<String>('verify_mic_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      isBusy ? null : () => onVerifyPermission('microphone'),
                  icon: const Icon(Icons.mic),
                  label: const Text('マイク許可検証'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('verify_camera_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isBusy ? null : () => onVerifyPermission('camera'),
                  icon: const Icon(Icons.videocam),
                  label: const Text('カメラ許可検証'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey<String>('verify_screen_button'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed:
                      isBusy ? null : () => onVerifyPermission('screen_share'),
                  icon: const Icon(Icons.screen_share),
                  label: const Text('画面共有検証'),
                ),
                ElevatedButton.icon(
                  key: const ValueKey<String>('verify_all_permissions_button'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: isBusy ? null : () => onVerifyPermission('all'),
                  icon: const Icon(Icons.security),
                  label: const Text('全パーミッションを一括検証'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionFooterCard extends StatelessWidget {
  const _ActionFooterCard({
    required this.report,
    required this.colors,
    required this.onOpenTroubleshooting,
    required this.onProceedToEditor,
  });

  final VideoPreflightReport report;
  final ColorScheme colors;
  final VoidCallback onOpenTroubleshooting;
  final VoidCallback? onProceedToEditor;

  @override
  Widget build(final BuildContext context) {
    return Card(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              key: const ValueKey<String>(
                'video_preflight_troubleshoot_button',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
              ),
              onPressed: onOpenTroubleshooting,
              icon: const Icon(Icons.build_outlined),
              label: const Text('Chrome 設定変更・トラブルシューティング案内'),
            ),
            if (onProceedToEditor != null)
              ElevatedButton.icon(
                key: const ValueKey<String>('video_preflight_proceed_button'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: report.hasBlockers ? null : onProceedToEditor,
                icon: const Icon(Icons.play_arrow),
                label: const Text('動画編集スタジオへ進む'),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip({
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
