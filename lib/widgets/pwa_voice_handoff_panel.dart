import 'package:flutter/material.dart';
import 'package:my_web_app/services/cross_device_voice_sync_service.dart';

/// モバイル PWA 音声入力フォールバックと Supabase クロスデバイス同期 PoC パネル。
@immutable
class PwaVoiceHandoffPanel extends StatefulWidget {
  const PwaVoiceHandoffPanel({
    required this.service,
    this.onVoiceCapturePressed,
    super.key,
  });

  final CrossDeviceVoiceSyncService service;
  final Future<String?> Function()? onVoiceCapturePressed;

  @override
  State<PwaVoiceHandoffPanel> createState() => _PwaVoiceHandoffPanelState();
}

class _PwaVoiceHandoffPanelState extends State<PwaVoiceHandoffPanel> {
  final TextEditingController _transcriptController = TextEditingController();
  final TextEditingController _promptNoteController = TextEditingController();

  bool _lastCaptureFromVoice = false;

  @override
  void initState() {
    super.initState();
    if (widget.service.session.transcriptDraft.isNotEmpty) {
      _transcriptController.text = widget.service.session.transcriptDraft;
    }
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    _promptNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceCapture() async {
    final Future<String?> Function()? callback = widget.onVoiceCapturePressed;
    if (callback == null) {
      return;
    }
    final String? captured = await callback();
    if (!mounted || captured == null || captured.trim().isEmpty) {
      return;
    }
    setState(() {
      _transcriptController.text = captured.trim();
      _lastCaptureFromVoice = true;
    });
  }

  Future<void> _handleSync() async {
    await widget.service.captureAndSync(
      transcriptDraft: _transcriptController.text,
      fromVoiceInput: _lastCaptureFromVoice,
      promptContextNote: _promptNoteController.text,
    );
  }

  Future<void> _handleRetry() async {
    await widget.service.retryPendingSync();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _VoiceSyncPalette palette = _VoiceSyncPalette.fromBrightness(
      isDark: isDark,
    );

    return ListenableBuilder(
      listenable: widget.service,
      builder: (BuildContext context, Widget? child) {
        final VoiceSpeechCapability cap = widget.service.capability;
        final CrossDeviceVoiceSession session = widget.service.session;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.sync_alt, color: palette.primaryText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PWA 音声入力 & クロスデバイス同期 PoC',
                        softWrap: true,
                        style: TextStyle(
                          color: palette.primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SyncBadgesRow(
                  palette: palette,
                  session: session,
                  capability: cap,
                ),
                if (cap.warningMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _CapabilityBanner(
                    key: const ValueKey<String>('voice-capability-warning'),
                    title: cap.requiresManualFallback
                        ? '手動テキストフォールバック稼働中'
                        : 'WebKit / Safari 音声入力の注意事項',
                    message: cap.warningMessage!,
                    background: cap.requiresManualFallback
                        ? palette.warnBg
                        : palette.infoBg,
                    foreground: cap.requiresManualFallback
                        ? palette.warnFg
                        : palette.infoFg,
                    border: cap.requiresManualFallback
                        ? palette.warnBorder
                        : palette.infoBorder,
                  ),
                ],
                if (widget.service.conflictBanner.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _CapabilityBanner(
                    key: const ValueKey<String>('voice-conflict-banner'),
                    title: '他デバイスからの引き継ぎ・競合解決',
                    message: widget.service.conflictBanner,
                    background: palette.warnBg,
                    foreground: palette.warnFg,
                    border: palette.warnBorder,
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  '検証対象デバイス環境',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const <VoiceDevicePlatform>[
                    VoiceDevicePlatform.desktopWeb,
                    VoiceDevicePlatform.iosSafariTab,
                    VoiceDevicePlatform.iosPwaStandalone,
                    VoiceDevicePlatform.mobileWebview,
                  ].map((VoiceDevicePlatform platform) {
                    final bool selected = cap.platform == platform;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: ChoiceChip(
                        key: ValueKey<String>(
                          'voice-platform-${platform.dbValue}',
                        ),
                        label: Text(
                          platform.labelJa,
                          style: TextStyle(
                            color: selected
                                ? palette.chipSelectedFg
                                : palette.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: selected,
                        selectedColor: palette.chipSelectedBg,
                        backgroundColor: palette.cardSurface,
                        side: BorderSide(
                          color: selected
                              ? palette.chipSelectedBorder
                              : palette.borderColor,
                        ),
                        onSelected: (bool value) {
                          if (!value) {
                            return;
                          }
                          widget.service.selectDevicePlatform(platform);
                        },
                      ),
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.borderColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          key: const ValueKey<String>('voice-transcript-field'),
                          controller: _transcriptController,
                          maxLines: 3,
                          onChanged: (_) {
                            _lastCaptureFromVoice = false;
                          },
                          decoration: InputDecoration(
                            labelText: cap.requiresManualFallback
                                ? '手動入力プロンプト（音声入力フォールバック）'
                                : '音声認識結果・プロンプト下書き',
                            hintText: 'モバイルからデスクトップへ引き継ぐ開発メモや指示を入力',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey<String>('voice-context-field'),
                          controller: _promptNoteController,
                          decoration: const InputDecoration(
                            labelText: 'セッション引き継ぎメモ（任意）',
                            hintText: '例: iPhone移動中に下書き作成 -> デスクトップで実装継続',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: <Widget>[
                            if (cap.speechRecognitionAvailable)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: OutlinedButton.icon(
                                  key: const ValueKey<String>(
                                    'voice-capture-button',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.primaryText,
                                    side: BorderSide(
                                      color: palette.borderColor,
                                    ),
                                  ),
                                  onPressed:
                                      widget.onVoiceCapturePressed == null
                                          ? null
                                          : _handleVoiceCapture,
                                  icon: const Icon(Icons.mic_none),
                                  label: const Text('音声入力を実行'),
                                ),
                              ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: FilledButton.icon(
                                key: const ValueKey<String>(
                                  'voice-sync-button',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.primaryButtonBg,
                                  foregroundColor: palette.primaryButtonFg,
                                ),
                                onPressed: widget.service.isSyncing
                                    ? null
                                    : _handleSync,
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: Text(
                                  widget.service.isSyncing
                                      ? '同期中...'
                                      : '他デバイスへ同期',
                                ),
                              ),
                            ),
                            if (widget.service.hasPendingOfflineSync)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: OutlinedButton.icon(
                                  key: const ValueKey<String>(
                                    'voice-retry-button',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette.warnFg,
                                    side: BorderSide(
                                      color: palette.warnBorder,
                                    ),
                                  ),
                                  onPressed: _handleRetry,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('オフライン再同期'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.service.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    widget.service.statusMessage,
                    key: const ValueKey<String>('voice-status-message'),
                    style: TextStyle(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SessionSnapshotCard(palette: palette, session: session),
              ],
            ),
          ),
        );
      },
    );
  }
}

@immutable
class _SyncBadgesRow extends StatelessWidget {
  const _SyncBadgesRow({
    required this.palette,
    required this.session,
    required this.capability,
  });

  final _VoiceSyncPalette palette;
  final CrossDeviceVoiceSession session;
  final VoiceSpeechCapability capability;

  @override
  Widget build(BuildContext context) {
    final bool isOffline = session.syncStatus == VoiceSyncStatus.queuedOffline;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _BadgePill(
          label: 'Rev ${session.revision}',
          background: palette.infoBg,
          foreground: palette.infoFg,
          border: palette.infoBorder,
        ),
        _BadgePill(
          label: session.syncStatus.labelJa,
          background: isOffline ? palette.warnBg : palette.okBg,
          foreground: isOffline ? palette.warnFg : palette.okFg,
          border: isOffline ? palette.warnBorder : palette.okBorder,
        ),
        _BadgePill(
          label: capability.environmentLabel,
          background: palette.cardSurface,
          foreground: palette.primaryText,
          border: palette.borderColor,
        ),
      ],
    );
  }
}

@immutable
class _CapabilityBanner extends StatelessWidget {
  const _CapabilityBanner({
    required this.title,
    required this.message,
    required this.background,
    required this.foreground,
    required this.border,
    super.key,
  });

  final String title;
  final String message;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.info_outline, color: foreground, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _SessionSnapshotCard extends StatelessWidget {
  const _SessionSnapshotCard({
    required this.palette,
    required this.session,
  });

  final _VoiceSyncPalette palette;
  final CrossDeviceVoiceSession session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '現在の引き継ぎ状態 (${session.sessionKey})',
                    softWrap: true,
                    style: TextStyle(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              session.transcriptDraft.isEmpty
                  ? 'まだ引き継ぎ用のテキスト・音声下書きは保存されていません。'
                  : session.transcriptDraft,
              style: TextStyle(color: palette.secondaryText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

@immutable
class _VoiceSyncPalette {
  const _VoiceSyncPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.borderColor,
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.primaryButtonBg,
    required this.primaryButtonFg,
    required this.chipSelectedBg,
    required this.chipSelectedFg,
    required this.chipSelectedBorder,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color borderColor;
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color primaryButtonBg;
  final Color primaryButtonFg;
  final Color chipSelectedBg;
  final Color chipSelectedFg;
  final Color chipSelectedBorder;

  factory _VoiceSyncPalette.fromBrightness({required bool isDark}) {
    if (isDark) {
      return const _VoiceSyncPalette(
        panelSurface: Color(0xFF0F172A),
        cardSurface: Color(0xFF111827),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        borderColor: Color(0xFF64748B),
        warnBg: Color(0xFF451A03),
        warnFg: Color(0xFFFEF3C7),
        warnBorder: Color(0xFFF59E0B),
        infoBg: Color(0xFF1E3A8A),
        infoFg: Color(0xFFEFF6FF),
        infoBorder: Color(0xFF93C5FD),
        okBg: Color(0xFF052E16),
        okFg: Color(0xFFDCFCE7),
        okBorder: Color(0xFF4ADE80),
        primaryButtonBg: Color(0xFF93C5FD),
        primaryButtonFg: Color(0xFF0F172A),
        chipSelectedBg: Color(0xFF1E3A8A),
        chipSelectedFg: Color(0xFFF8FAFC),
        chipSelectedBorder: Color(0xFF93C5FD),
      );
    }
    return const _VoiceSyncPalette(
      panelSurface: Color(0xFFF8FAFC),
      cardSurface: Color(0xFFFFFFFF),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      borderColor: Color(0xFF475569),
      warnBg: Color(0xFFFEF3C7),
      warnFg: Color(0xFF78350F),
      warnBorder: Color(0xFFB45309),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      infoBorder: Color(0xFF1E40AF),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      primaryButtonBg: Color(0xFF1E40AF),
      primaryButtonFg: Color(0xFFFFFFFF),
      chipSelectedBg: Color(0xFFDBEAFE),
      chipSelectedFg: Color(0xFF1E3A8A),
      chipSelectedBorder: Color(0xFF1E40AF),
    );
  }
}
