import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../data/services/guitar_metronome_audio_service.dart';
import '../../../../../data/services/structured_tab_catalog_service.dart';
import '../../../../../data/services/structured_tab_pdf_service.dart';
import '../../../../../data/services/user_structured_tab_storage_service.dart';
import '../../../../../domain/models/structured_guitar_tab.dart';
import '../../../../../theme/design_tokens.dart';
import 'structured_chord_diagram.dart';
import 'structured_tab_score_view.dart';

/// 構造化コードTABスコアの表示・メトロノーム同期・ローカルJSON取込・PDF印刷を担うスタジオパネル。
class StructuredTabStudioPanel extends StatefulWidget {
  const StructuredTabStudioPanel({
    super.key,
    this.catalogService,
    this.userStorageService,
    this.pdfService,
    this.jsonFilePicker,
    this.metronomeAudioService,
  });

  final StructuredTabCatalogService? catalogService;
  final UserStructuredTabStorageService? userStorageService;
  final StructuredTabPdfService? pdfService;
  final Future<FilePickerResult?> Function()? jsonFilePicker;
  final GuitarMetronomeAudioService? metronomeAudioService;

  @override
  State<StructuredTabStudioPanel> createState() =>
      _StructuredTabStudioPanelState();
}

class _StructuredTabStudioPanelState extends State<StructuredTabStudioPanel> {
  late final StructuredTabCatalogService _catalogService;
  late final UserStructuredTabStorageService _userStorageService;
  late final StructuredTabPdfService _pdfService;
  late final GuitarMetronomeAudioService _audioService;
  late final bool _ownsAudioService;
  final Stopwatch _tickStopwatch = Stopwatch();

  bool _isLoading = true;
  String? _loadError;
  List<StructuredGuitarTabScore> _bundledScores =
      const <StructuredGuitarTabScore>[];
  List<StructuredGuitarTabScore> _userScores =
      const <StructuredGuitarTabScore>[];
  String? _selectedScoreId;
  bool? _selectedIsUserImported;

  List<StructuredTabPlaybackStep> _timeline =
      const <StructuredTabPlaybackStep>[];
  int _cursorIndex = 0;
  int _bpm = 120;
  bool _isPlaying = false;
  bool _soundEnabled = true;
  bool _lightSheet = true;
  bool _isPrintingPdf = false;
  int _scheduledDelayMs = 500;
  Timer? _playbackTimer;

  List<StructuredGuitarTabScore> get _allScores =>
      <StructuredGuitarTabScore>[..._bundledScores, ..._userScores];

  StructuredGuitarTabScore? get _selectedScore {
    for (final score in _allScores) {
      if (score.id == _selectedScoreId &&
          (_selectedIsUserImported == null ||
              score.isUserImported == _selectedIsUserImported)) {
        return score;
      }
    }
    for (final score in _allScores) {
      if (score.id == _selectedScoreId) {
        return score;
      }
    }
    return _allScores.isEmpty ? null : _allScores.first;
  }

  @override
  void initState() {
    super.initState();
    _catalogService =
        widget.catalogService ?? const StructuredTabCatalogService();
    _userStorageService = widget.userStorageService ??
        SharedPreferencesUserStructuredTabStorageService();
    _pdfService = widget.pdfService ?? const LocalStructuredTabPdfService();
    _ownsAudioService = widget.metronomeAudioService == null;
    _audioService =
        widget.metronomeAudioService ?? createGuitarMetronomeAudioService();
    _loadScores();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _tickStopwatch.stop();
    if (_ownsAudioService) {
      _audioService.dispose();
    }
    super.dispose();
  }

  Future<void> _loadScores({String? selectId}) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final bundled = await _catalogService.loadCatalog();
      final user = await _userStorageService.loadScores();
      if (!mounted) return;
      final combined = <StructuredGuitarTabScore>[...bundled, ...user];
      if (combined.isEmpty) {
        setState(() {
          _bundledScores = bundled;
          _userScores = user;
          _isLoading = false;
          _playbackTimer?.cancel();
          _tickStopwatch.stop();
          _isPlaying = false;
          _selectedScoreId = null;
          _selectedIsUserImported = null;
          _timeline = const <StructuredTabPlaybackStep>[];
          _cursorIndex = 0;
        });
        return;
      }
      final targetId = selectId ?? _selectedScoreId;
      final selected = combined.firstWhere(
        (StructuredGuitarTabScore s) => s.id == targetId,
        orElse: () => combined.first,
      );
      setState(() {
        _bundledScores = bundled;
        _userScores = user;
        _isLoading = false;
        _applySelectedScore(selected);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '構造化TAB譜カタログの読み込みに失敗しました。';
      });
    }
  }

  void _applySelectedScore(StructuredGuitarTabScore score) {
    _playbackTimer?.cancel();
    _tickStopwatch.stop();
    _isPlaying = false;
    _selectedScoreId = score.id;
    _selectedIsUserImported = score.isUserImported;
    _bpm = score.bpm.clamp(30, 260);
    _timeline = expandStructuredTabTimeline(score);
    _cursorIndex = 0;
  }

  void _selectScore(StructuredGuitarTabScore score) {
    setState(() {
      _applySelectedScore(score);
    });
  }

  void _togglePlayback() {
    if (_timeline.isEmpty) return;
    if (_isPlaying) {
      _playbackTimer?.cancel();
      _tickStopwatch.stop();
      setState(() {
        _isPlaying = false;
      });
      return;
    }
    setState(() {
      _isPlaying = true;
    });
    if (_soundEnabled) {
      _audioService.playClick(accent: _timeline[_cursorIndex].beatIndex == 0);
    }
    _scheduleNextStep(overdueMs: 0);
  }

  void _resetCursor() {
    _playbackTimer?.cancel();
    _tickStopwatch.stop();
    setState(() {
      _isPlaying = false;
      _cursorIndex = 0;
    });
  }

  void _scheduleNextStep({required int overdueMs}) {
    if (!mounted || !_isPlaying || _timeline.isEmpty) return;
    final step = _timeline[_cursorIndex];
    final rawDelayMs =
        ((60000.0 / _bpm) * step.durationBeats).round().clamp(60, 4000);
    final delayMs = (rawDelayMs - overdueMs).clamp(30, rawDelayMs);
    _scheduledDelayMs = delayMs;
    _tickStopwatch
      ..reset()
      ..start();
    _playbackTimer?.cancel();
    _playbackTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || !_isPlaying || _timeline.isEmpty) return;
      final elapsed = _tickStopwatch.elapsedMilliseconds;
      final lag = elapsed > _scheduledDelayMs ? elapsed - _scheduledDelayMs : 0;
      final nextIndex = (_cursorIndex + 1) % _timeline.length;
      setState(() {
        _cursorIndex = nextIndex;
      });
      if (_soundEnabled) {
        _audioService.playClick(accent: _timeline[nextIndex].beatIndex == 0);
      }
      _scheduleNextStep(overdueMs: lag);
    });
  }

  void _jumpToMeasure(int measureIndex) {
    if (_timeline.isEmpty) return;
    final stepIndex = _timeline.indexWhere(
      (StructuredTabPlaybackStep step) => step.measureIndex == measureIndex,
    );
    if (stepIndex < 0) return;
    setState(() {
      _cursorIndex = stepIndex;
    });
  }

  Future<void> _openImportDialog() async {
    final current = _selectedScore;
    final reservedIds =
        _bundledScores.map((StructuredGuitarTabScore s) => s.id).toSet();
    final imported = await showDialog<StructuredGuitarTabScore>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ImportStructuredTabDialog(
          templateScore: current,
          reservedIds: reservedIds,
          jsonFilePicker: widget.jsonFilePicker,
        );
      },
    );
    if (imported == null || !mounted) return;
    if (reservedIds.contains(imported.id)) {
      if (!context.mounted) return;
      _showSnackBar(
        SnackBar(
          content: Text('同梱譜面と同じID（${imported.id}）は保存できません。'),
          backgroundColor: DesignTokens.red,
        ),
      );
      return;
    }
    try {
      await _userStorageService.saveScore(imported);
      final updatedUser = await _userStorageService.loadScores();
      if (!mounted) return;
      setState(() {
        _userScores = updatedUser;
        _applySelectedScore(
          updatedUser.firstWhere(
            (StructuredGuitarTabScore s) => s.id == imported.id,
            orElse: () => imported,
          ),
        );
      });
      if (!context.mounted) return;
      _showSnackBar(
        SnackBar(
          content: Text('「${imported.title}」をこの端末に保存しました（非公開）。'),
          backgroundColor: DesignTokens.green,
        ),
      );
    } catch (error) {
      if (!mounted || !context.mounted) return;
      final message = error is FormatException
          ? error.message
          : '端末ローカルへの保存に失敗しました。空き容量やブラウザ設定を確認してください。';
      _showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: DesignTokens.red,
        ),
      );
    }
  }

  Future<void> _deleteSelectedUserScore() async {
    final selected = _selectedScore;
    if (selected == null || !selected.isUserImported) return;
    try {
      await _userStorageService.deleteScore(selected.id);
      final updatedUser = await _userStorageService.loadScores();
      if (!mounted) return;
      setState(() {
        _userScores = updatedUser;
        final remaining = _allScores;
        if (remaining.isNotEmpty) {
          _applySelectedScore(remaining.first);
        } else {
          _playbackTimer?.cancel();
          _isPlaying = false;
          _selectedScoreId = null;
          _selectedIsUserImported = null;
          _timeline = const <StructuredTabPlaybackStep>[];
          _cursorIndex = 0;
        }
      });
      if (!context.mounted) return;
      _showSnackBar(
        const SnackBar(
          content: Text('端末ローカルのマイ譜面を削除しました。'),
        ),
      );
    } catch (_) {
      if (!mounted || !context.mounted) return;
      _showSnackBar(
        const SnackBar(
          content: Text('マイ譜面の削除に失敗しました。'),
          backgroundColor: DesignTokens.red,
        ),
      );
    }
  }

  Future<void> _copyJsonToClipboard() async {
    final selected = _selectedScore;
    if (selected == null) return;
    await Clipboard.setData(ClipboardData(text: selected.toPrettyJson()));
    if (!mounted || !context.mounted) return;
    _showSnackBar(
      const SnackBar(
        content: Text('構造化TABのJSONをクリップボードへコピーしました。'),
      ),
    );
  }

  Future<void> _printPdf() async {
    final selected = _selectedScore;
    if (selected == null || _isPrintingPdf) return;
    setState(() {
      _isPrintingPdf = true;
    });
    try {
      await _pdfService.printScore(selected);
    } catch (_) {
      if (!mounted || !context.mounted) return;
      _showSnackBar(
        const SnackBar(
          content: Text('PDF印刷またはプレビューを開けませんでした。'),
          backgroundColor: DesignTokens.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingPdf = false;
        });
      }
    }
  }

  void _showSnackBar(SnackBar snackBar) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: DesignTokens.orange),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline,
                color: DesignTokens.red,
                size: 42,
              ),
              const SizedBox(height: DesignTokens.space12),
              Text(
                _loadError!,
                style: const TextStyle(color: DesignTokens.textSecondary),
              ),
              const SizedBox(height: DesignTokens.space16),
              FilledButton.icon(
                onPressed: () => _loadScores(),
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedScore;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final currentStep =
        (_timeline.isNotEmpty && _cursorIndex < _timeline.length)
            ? _timeline[_cursorIndex]
            : null;
    final cursorText = currentStep == null
        ? '小節 -'
        : '小節 ${currentStep.measureNumber} • 拍 ${currentStep.beatIndex + 1} (${_cursorIndex + 1}/${_timeline.length})';

    return ListView(
      key: const Key('structured_tab_studio_scroll'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space16,
        DesignTokens.space16,
        96,
      ),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildRightsBanner(),
                const SizedBox(height: DesignTokens.space16),
                _buildScoreSelector(selected),
                const SizedBox(height: DesignTokens.space16),
                _buildControlBar(selected, cursorText),
                const SizedBox(height: DesignTokens.space16),
                _buildScoreSheetCard(selected, currentStep),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightsBanner() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: DesignTokens.indigo.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.35)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.verified_user_outlined,
            color: DesignTokens.indigoLight,
            size: 20,
          ),
          SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Text(
              '同梱サンプルは権利に配慮したオリジナル練習譜です。「JSON読込」で追加したマイ譜面はこの端末内のみに非公開保存され、外部や他ユーザーには送信されません。',
              style: TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSelector(StructuredGuitarTabScore selected) {
    final scores = _allScores;
    final seenIds = <String>{};
    return Wrap(
      spacing: DesignTokens.space8,
      runSpacing: DesignTokens.space8,
      children: <Widget>[
        for (var i = 0; i < scores.length; i++)
          _buildScoreChip(
            score: scores[i],
            selected: selected,
            chipKey: seenIds.add(scores[i].id)
                ? Key('structured_score_chip_${scores[i].id}')
                : Key('structured_score_chip_${scores[i].id}_dup_$i'),
          ),
      ],
    );
  }

  Widget _buildScoreChip({
    required StructuredGuitarTabScore score,
    required StructuredGuitarTabScore selected,
    required Key chipKey,
  }) {
    final isSelected = identical(score, selected) ||
        (score.id == selected.id &&
            score.isUserImported == selected.isUserImported);
    return ChoiceChip(
      key: chipKey,
      avatar: Icon(
        score.isUserImported ? Icons.lock_outline : Icons.music_note,
        size: 16,
        color:
            isSelected ? DesignTokens.orangeLight : DesignTokens.textSecondary,
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          score.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _selectScore(score),
      selectedColor: DesignTokens.orange.withValues(alpha: 0.22),
      backgroundColor: DesignTokens.surface2,
      side: BorderSide(
        color: isSelected ? DesignTokens.orange : DesignTokens.divider,
      ),
      labelStyle: TextStyle(
        color:
            isSelected ? DesignTokens.orangeLight : DesignTokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildControlBar(
    StructuredGuitarTabScore selected,
    String cursorText,
  ) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              FilledButton.icon(
                key: const Key('structured_tab_play_toggle'),
                onPressed: _togglePlayback,
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? '停止' : 'メトロノーム同期再生'),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                  foregroundColor: DesignTokens.textPrimary,
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_reset_cursor'),
                onPressed: _resetCursor,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('先頭へ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textOnDark,
                  side: const BorderSide(color: DesignTokens.divider),
                  minimumSize: const Size(48, 44),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: DesignTokens.surface3,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Text(
                  cursorText,
                  key: const Key('structured_tab_cursor_label'),
                  style: const TextStyle(
                    color: DesignTokens.orangeLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_audio_toggle'),
                onPressed: () =>
                    setState(() => _soundEnabled = !_soundEnabled),
                icon: Icon(
                  _soundEnabled
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  size: 18,
                ),
                label: Text(_soundEnabled ? 'クリック音 ON' : 'クリック音 OFF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _soundEnabled
                      ? DesignTokens.orangeLight
                      : DesignTokens.textSecondary,
                  side: BorderSide(
                    color: _soundEnabled
                        ? DesignTokens.orange.withValues(alpha: 0.45)
                        : DesignTokens.divider,
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_theme_toggle'),
                onPressed: () => setState(() => _lightSheet = !_lightSheet),
                icon: Icon(
                  _lightSheet ? Icons.dark_mode : Icons.description_outlined,
                  size: 18,
                ),
                label: Text(_lightSheet ? 'ダーク表示' : '白紙譜面'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textOnDark,
                  side: const BorderSide(color: DesignTokens.divider),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_import_button'),
                onPressed: _openImportDialog,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('JSON読込 (ローカル専用)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.indigoLight,
                  side: BorderSide(
                    color: DesignTokens.indigoLight.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_copy_json_button'),
                onPressed: _copyJsonToClipboard,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('JSONコピー'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textOnDark,
                  side: const BorderSide(color: DesignTokens.divider),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('structured_tab_pdf_button'),
                onPressed: _isPrintingPdf ? null : _printPdf,
                icon: _isPrintingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF印刷 / 保存'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.orangeLight,
                  side: BorderSide(
                    color: DesignTokens.orange.withValues(alpha: 0.5),
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
              if (selected.isUserImported)
                OutlinedButton.icon(
                  key: const Key('structured_tab_delete_user_score'),
                  onPressed: _deleteSelectedUserScore,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('このマイ譜面を削除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DesignTokens.red,
                    side: BorderSide(
                      color: DesignTokens.red.withValues(alpha: 0.5),
                    ),
                    minimumSize: const Size(48, 44),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.space12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.speed,
                size: 18,
                color: DesignTokens.indigoLight,
              ),
              const SizedBox(width: DesignTokens.space8),
              const Text(
                '練習テンポ',
                style: TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Slider(
                  key: const Key('structured_tab_bpm_slider'),
                  value: _bpm.toDouble(),
                  min: 30,
                  max: 260,
                  divisions: 230,
                  activeColor: DesignTokens.orange,
                  inactiveColor: DesignTokens.surface3,
                  label: '$_bpm BPM',
                  onChanged: (double value) {
                    setState(() {
                      _bpm = value.round().clamp(30, 260);
                    });
                    if (_isPlaying) {
                      _scheduleNextStep(overdueMs: 0);
                    }
                  },
                ),
              ),
              Text(
                '$_bpm BPM',
                key: const Key('structured_tab_bpm_value'),
                style: const TextStyle(
                  color: DesignTokens.orangeLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSheetCard(
    StructuredGuitarTabScore selected,
    StructuredTabPlaybackStep? currentStep,
  ) {
    final sheetBg = _lightSheet ? Colors.white : DesignTokens.background;
    final titleColor =
        _lightSheet ? const Color(0xFF111827) : DesignTokens.textPrimary;
    final subtitleColor =
        _lightSheet ? const Color(0xFF374151) : DesignTokens.textSecondary;
    final borderColor = _lightSheet
        ? const Color(0xFFD1D5DB)
        : DesignTokens.orange.withValues(alpha: 0.25);

    return Container(
      key: Key(
        _lightSheet
            ? 'structured_tab_sheet_light'
            : 'structured_tab_sheet_dark',
      ),
      padding: const EdgeInsets.all(DesignTokens.space24),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            selected.title,
            key: const Key('structured_tab_selected_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: titleColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            selected.artist,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (selected.chords.isNotEmpty) ...<Widget>[
            const SizedBox(height: DesignTokens.space16),
            StructuredChordDiagramStrip(
              chords: selected.chords,
              lightSheet: _lightSheet,
            ),
          ],
          const SizedBox(height: DesignTokens.space16),
          Wrap(
            spacing: DesignTokens.space16,
            runSpacing: DesignTokens.space4,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Text(
                selected.tuning,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '♩ = ${selected.bpm}  |  Capo: ${selected.capo}  |  ${selected.beatsPerMeasure}/${selected.beatUnit}',
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (selected.summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: DesignTokens.space8),
            Text(
              selected.summary,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.space20),
          StructuredTabScoreView(
            score: selected,
            lightSheet: _lightSheet,
            activeMeasureIndex: currentStep?.measureIndex,
            activeBeatIndex: currentStep?.beatIndex,
            onMeasureTap: _jumpToMeasure,
            autoScrollToActive: _isPlaying,
          ),
        ],
      ),
    );
  }
}

class _ImportStructuredTabDialog extends StatefulWidget {
  const _ImportStructuredTabDialog({
    required this.templateScore,
    required this.reservedIds,
    this.jsonFilePicker,
  });

  final StructuredGuitarTabScore? templateScore;
  final Set<String> reservedIds;
  final Future<FilePickerResult?> Function()? jsonFilePicker;

  @override
  State<_ImportStructuredTabDialog> createState() =>
      _ImportStructuredTabDialogState();
}

class _ImportStructuredTabDialogState
    extends State<_ImportStructuredTabDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fillTemplate() {
    final template = widget.templateScore;
    if (template == null) return;
    var nextId = '${template.id}-custom';
    while (widget.reservedIds.contains(nextId)) {
      nextId = '$nextId-user';
    }
    final customTemplate = template.copyWith(
      id: nextId,
      isOriginalPractice: false,
      isUserImported: true,
    );
    setState(() {
      _errorText = null;
      _controller.text = customTemplate.toPrettyJson();
    });
  }

  Future<void> _pickJsonFile() async {
    try {
      final result = await (widget.jsonFilePicker?.call() ??
          FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const <String>['json'],
            withData: true,
          ));
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.size > StructuredGuitarTabScore.maxJsonLength) {
        if (!mounted) return;
        setState(() {
          _errorText = 'ファイルサイズが大きすぎます（256KB以下のJSONファイルを選択してください）。';
        });
        return;
      }
      final bytes = picked.bytes;
      if (bytes == null) {
        if (!mounted) return;
        setState(() {
          _errorText = 'ファイル内容を読み取れませんでした。テキストを直接貼り付けてください。';
        });
        return;
      }
      if (bytes.length > StructuredGuitarTabScore.maxJsonLength) {
        if (!mounted) return;
        setState(() {
          _errorText = 'ファイルサイズが大きすぎます（256KB以下のJSONファイルを選択してください）。';
        });
        return;
      }
      final String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        if (!mounted) return;
        setState(() {
          _errorText = 'UTF-8形式のJSONファイルとして読み取れませんでした。文字コードを確認してください。';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _errorText = null;
        _controller.text = text;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'ファイル選択を開けませんでした。JSONテキストを直接貼り付けてください。';
      });
    }
  }

  void _submit() {
    try {
      final parsed = StructuredGuitarTabScore.parseJsonString(
        _controller.text,
        forceUserImported: true,
      );
      if (widget.reservedIds.contains(parsed.id)) {
        setState(() {
          _errorText = '同梱譜面と同じid「${parsed.id}」は使用できません。別のidを指定してください。';
        });
        return;
      }
      Navigator.of(context).pop(parsed);
    } on FormatException catch (error) {
      setState(() {
        _errorText = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('structured_tab_import_dialog'),
      backgroundColor: DesignTokens.surface1,
      title: const Text(
        '構造化TAB JSONを読み込む（端末ローカル専用）',
        style: TextStyle(
          color: DesignTokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                '保存した譜面はこの端末内（SharedPreferences）だけに非公開保存され、サーバーや他ユーザーへ公開されません。',
                style: TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Wrap(
                spacing: DesignTokens.space8,
                runSpacing: DesignTokens.space8,
                children: <Widget>[
                  if (widget.templateScore != null)
                    OutlinedButton.icon(
                      key: const Key('structured_tab_load_template'),
                      onPressed: _fillTemplate,
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('現在の譜面を雛形に使う'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('structured_tab_pick_file'),
                    onPressed: _pickJsonFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('.json ファイルを選択'),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                key: const Key('structured_tab_json_input'),
                controller: _controller,
                maxLines: 10,
                style: const TextStyle(
                  color: DesignTokens.textOnDark,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText:
                      '{"id": "my-score", "title": "...", "bpm": 120, ...}',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: DesignTokens.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusSmall,
                    ),
                  ),
                ),
              ),
              if (_errorText != null) ...<Widget>[
                const SizedBox(height: DesignTokens.space8),
                Text(
                  _errorText!,
                  key: const Key('structured_tab_json_error'),
                  style: const TextStyle(
                    color: DesignTokens.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('structured_tab_json_save'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.orange,
            foregroundColor: DesignTokens.textPrimary,
          ),
          child: const Text('保存して表示'),
        ),
      ],
    );
  }
}
