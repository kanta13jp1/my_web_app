import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../data/services/chord_lyrics_catalog_service.dart';
import '../../../../../data/services/user_chord_lyrics_storage_service.dart';
import '../../../../../domain/models/chord_lyrics_sheet.dart';
import '../../../../../theme/design_tokens.dart';
import 'structured_chord_diagram.dart';

/// 補助文字用の WCAG 2.1 AA 準拠色。
const Color _mutedOnDarkSurface = Color(0xFF9CA3AF);

/// U-FRET スタイルの弾き語りコード譜（横向きコード図＋歌詞連動＋タップ自動スクロール＋カポ/移調）スタジオ。
class ChordLyricsStudioPanel extends StatefulWidget {
  const ChordLyricsStudioPanel({
    super.key,
    this.catalogService,
    this.userStorageService,
    this.chordProFilePicker,
  });

  final ChordLyricsCatalogService? catalogService;
  final UserChordLyricsStorageService? userStorageService;
  final Future<FilePickerResult?> Function()? chordProFilePicker;

  @override
  State<ChordLyricsStudioPanel> createState() => _ChordLyricsStudioPanelState();
}

class _ChordLyricsStudioPanelState extends State<ChordLyricsStudioPanel> {
  late final ChordLyricsCatalogService _catalogService;
  late final UserChordLyricsStorageService _userStorageService;
  final ScrollController _scrollController = ScrollController();

  List<ChordLyricsSheetDocument> _presets = const <ChordLyricsSheetDocument>[];
  List<ChordLyricsSheetDocument> _userSheets =
      const <ChordLyricsSheetDocument>[];
  bool _isLoading = true;
  String? _loadError;

  String? _selectedId;
  bool? _selectedIsUserImported;
  int _capoFret = 0;
  int _transposeSemitones = 0;
  bool _preferFlats = false;
  bool _showDiagrams = true;
  bool _lightSheet = true;
  bool _isAutoScrolling = false;
  double _scrollSpeedPxPerSec = 28.0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _catalogService =
        widget.catalogService ?? const LocalChordLyricsCatalogService();
    _userStorageService = widget.userStorageService ??
        SharedPreferencesUserChordLyricsStorageService();
    _loadSheets();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<ChordLyricsSheetDocument> get _allSheets =>
      <ChordLyricsSheetDocument>[..._userSheets, ..._presets];

  ChordLyricsSheetDocument? get _selectedSheet {
    final all = _allSheets;
    if (all.isEmpty) return null;
    if (_selectedId == null) return all.first;
    for (final item in all) {
      if (item.id == _selectedId &&
          (_selectedIsUserImported == null ||
              item.isUserImported == _selectedIsUserImported)) {
        return item;
      }
    }
    return all.first;
  }

  Future<void> _loadSheets() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait<List<ChordLyricsSheetDocument>>(<Future<
          List<ChordLyricsSheetDocument>>>[
        _catalogService.fetchPresetSheets(),
        _userStorageService.loadSheets(),
      ]);
      if (!mounted) return;
      final presets = results[0];
      final userSheets = results[1];
      setState(() {
        _presets = presets;
        _userSheets = userSheets;
        _isLoading = false;
        final combined = <ChordLyricsSheetDocument>[...userSheets, ...presets];
        if (combined.isNotEmpty && _selectedSheet == null) {
          _applySelectedSheet(combined.first);
        } else if (combined.isNotEmpty && _selectedId == null) {
          _applySelectedSheet(combined.first);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = '弾き語りコード譜データの読み込みに失敗しました。';
      });
    }
  }

  void _applySelectedSheet(ChordLyricsSheetDocument sheet) {
    _stopAutoScroll(notify: false);
    _selectedId = sheet.id;
    _selectedIsUserImported = sheet.isUserImported;
    _capoFret = sheet.defaultCapo.clamp(0, 7);
    _transposeSemitones = 0;
  }

  void _selectSheet(ChordLyricsSheetDocument sheet) {
    setState(() {
      _applySelectedSheet(sheet);
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _toggleAutoScroll() {
    if (_isAutoScrolling) {
      _stopAutoScroll();
      return;
    }
    setState(() {
      _isAutoScrolling = true;
    });
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!mounted || !_isAutoScrolling) {
          _autoScrollTimer?.cancel();
          return;
        }
        if (!_scrollController.hasClients) return;
        final pos = _scrollController.position;
        final nextOffset =
            _scrollController.offset + _scrollSpeedPxPerSec * 0.033;
        if (pos.maxScrollExtent <= 0) {
          return;
        }
        if (nextOffset >= pos.maxScrollExtent) {
          _scrollController.jumpTo(pos.maxScrollExtent);
          _stopAutoScroll();
          return;
        }
        _scrollController.jumpTo(nextOffset);
      },
    );
  }

  void _stopAutoScroll({bool notify = true}) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (!_isAutoScrolling) return;
    if (notify && mounted) {
      setState(() {
        _isAutoScrolling = false;
      });
    } else {
      _isAutoScrolling = false;
    }
  }

  Future<void> _openImportDialog() async {
    final current = _selectedSheet;
    final reservedIds =
        _presets.map((ChordLyricsSheetDocument s) => s.id).toSet();
    final imported = await showDialog<ChordLyricsSheetDocument>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ImportChordProDialog(
          templateSheet: current,
          reservedIds: reservedIds,
          chordProFilePicker: widget.chordProFilePicker,
        );
      },
    );
    if (imported == null || !mounted) return;
    try {
      await _userStorageService.saveSheet(imported);
      final updatedUser = await _userStorageService.loadSheets();
      if (!mounted) return;
      setState(() {
        _userSheets = updatedUser;
        _applySelectedSheet(
          updatedUser.firstWhere(
            (ChordLyricsSheetDocument s) => s.id == imported.id,
            orElse: () => imported,
          ),
        );
      });
      _showSnackBar(
        SnackBar(
          content: Text('「${imported.title}」をこの端末に保存しました（非公開）。'),
          backgroundColor: DesignTokens.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
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

  Future<void> _deleteSelectedUserSheet() async {
    final selected = _selectedSheet;
    if (selected == null || !selected.isUserImported) return;
    try {
      await _userStorageService.deleteSheet(selected.id);
      final updatedUser = await _userStorageService.loadSheets();
      if (!mounted) return;
      setState(() {
        _userSheets = updatedUser;
        final remaining = _allSheets;
        if (remaining.isNotEmpty) {
          _applySelectedSheet(remaining.first);
        } else {
          _stopAutoScroll(notify: false);
          _selectedId = null;
          _selectedIsUserImported = null;
        }
      });
      _showSnackBar(
        const SnackBar(
          content: Text('端末ローカルの弾き語りマイ譜面を削除しました。'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(
        const SnackBar(
          content: Text('マイ譜面の削除に失敗しました。'),
          backgroundColor: DesignTokens.red,
        ),
      );
    }
  }

  Future<void> _copyChordProToClipboard() async {
    final selected = _selectedSheet;
    if (selected == null) return;
    await Clipboard.setData(ClipboardData(text: selected.sourceChordPro));
    if (!mounted) return;
    _showSnackBar(
      const SnackBar(
        content: Text('ChordPro テキストをクリップボードへコピーしました。'),
      ),
    );
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
                onPressed: _loadSheets,
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    final selected = _selectedSheet;
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final parsed = parseChordLyricsDocument(
      selected,
      capoFret: _capoFret,
      transposeSemitones: _transposeSemitones,
      preferFlats: _preferFlats,
    );

    return ListView(
      key: const Key('chord_lyrics_studio_scroll'),
      controller: _scrollController,
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
                _buildSheetSelector(selected),
                const SizedBox(height: DesignTokens.space16),
                _buildControlBar(selected, parsed),
                const SizedBox(height: DesignTokens.space16),
                _buildScoreSheetCard(selected, parsed),
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
        color: DesignTokens.indigo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.verified_user_outlined,
              color: DesignTokens.indigoLight, size: 18),
          SizedBox(width: DesignTokens.space8),
          Expanded(
            child: Text(
              '同梱曲は著作権保護のためオリジナル練習譜面のみを収録しています。個人練習用の ChordPro（.cho / .crd / .txt）譜面は「ChordPro読込」からこの端末内のみに非公開保存できます。',
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

  Widget _buildSheetSelector(ChordLyricsSheetDocument selected) {
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
          const Text(
            '弾き語りコード譜を選択',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space8,
            children: <Widget>[
              for (final sheet in _allSheets)
                ChoiceChip(
                  key: Key(
                    sheet.isUserImported
                        ? 'chord_lyrics_user_${sheet.id}'
                        : 'chord_lyrics_preset_${sheet.id}',
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  label: Text(
                    sheet.isUserImported ? '[マイ] ${sheet.title}' : sheet.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: sheet.id == selected.id &&
                      sheet.isUserImported == selected.isUserImported,
                  onSelected: (_) => _selectSheet(sheet),
                  selectedColor: DesignTokens.orange.withValues(alpha: 0.22),
                  backgroundColor: DesignTokens.surface2,
                  side: BorderSide(
                    color: (sheet.id == selected.id &&
                            sheet.isUserImported == selected.isUserImported)
                        ? DesignTokens.orange
                        : DesignTokens.divider,
                  ),
                  labelStyle: TextStyle(
                    color: (sheet.id == selected.id &&
                            sheet.isUserImported == selected.isUserImported)
                        ? DesignTokens.orangeLight
                        : DesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          if (selected.description.isNotEmpty) ...<Widget>[
            const SizedBox(height: DesignTokens.space8),
            Text(
              selected.description,
              style: const TextStyle(
                color: _mutedOnDarkSurface,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlBar(
    ChordLyricsSheetDocument selected,
    ParsedChordLyricsSong parsed,
  ) {
    final transposeLabel = _transposeSemitones == 0
        ? '移調 ±0'
        : _transposeSemitones > 0
            ? '移調 +$_transposeSemitones'
            : '移調 $_transposeSemitones';

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
                key: const Key('chord_lyrics_autoscroll_toggle'),
                onPressed: _toggleAutoScroll,
                icon: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow),
                label: Text(_isAutoScrolling ? '自動スクロール停止' : '自動スクロール開始'),
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                  foregroundColor: DesignTokens.textPrimary,
                  minimumSize: const Size(48, 44),
                ),
              ),
              _StepperBadge(
                labelKey: const Key('chord_lyrics_capo_value'),
                labelText: 'Capo $_capoFret',
                minusKey: const Key('chord_lyrics_capo_minus'),
                minusTooltip: 'カポを1つ下げる',
                onMinus: _capoFret > 0
                    ? () => setState(() => _capoFret = _capoFret - 1)
                    : null,
                plusKey: const Key('chord_lyrics_capo_plus'),
                plusTooltip: 'カポを1つ上げる',
                onPlus: _capoFret < 7
                    ? () => setState(() => _capoFret = _capoFret + 1)
                    : null,
              ),
              _StepperBadge(
                labelKey: const Key('chord_lyrics_transpose_value'),
                labelText: transposeLabel,
                minusKey: const Key('chord_lyrics_transpose_minus'),
                minusTooltip: 'キーを半音下げる',
                onMinus: _transposeSemitones > -6
                    ? () => setState(
                          () => _transposeSemitones = _transposeSemitones - 1,
                        )
                    : null,
                plusKey: const Key('chord_lyrics_transpose_plus'),
                plusTooltip: 'キーを半音上げる',
                onPlus: _transposeSemitones < 6
                    ? () => setState(
                          () => _transposeSemitones = _transposeSemitones + 1,
                        )
                    : null,
              ),
              OutlinedButton.icon(
                key: const Key('chord_lyrics_accidental_toggle'),
                onPressed: () => setState(() => _preferFlats = !_preferFlats),
                icon: const Icon(Icons.music_note_outlined, size: 18),
                label: Text(_preferFlats ? '♭表記' : '♯/原表記'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textOnDark,
                  side: const BorderSide(color: DesignTokens.divider),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('chord_lyrics_diagram_toggle'),
                onPressed: () => setState(() => _showDiagrams = !_showDiagrams),
                icon: Icon(
                  _showDiagrams
                      ? Icons.grid_view_outlined
                      : Icons.grid_off_outlined,
                  size: 18,
                ),
                label: Text(_showDiagrams ? 'コード図 ON' : 'コード図 OFF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _showDiagrams
                      ? DesignTokens.orangeLight
                      : DesignTokens.textSecondary,
                  side: BorderSide(
                    color: _showDiagrams
                        ? DesignTokens.orange.withValues(alpha: 0.45)
                        : DesignTokens.divider,
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('chord_lyrics_theme_toggle'),
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
                key: const Key('chord_lyrics_import_button'),
                onPressed: _openImportDialog,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('ChordPro読込 (ローカル専用)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.indigoLight,
                  side: BorderSide(
                    color: DesignTokens.indigoLight.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size(48, 44),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('chord_lyrics_copy_button'),
                onPressed: _copyChordProToClipboard,
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('ChordProコピー'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textOnDark,
                  side: const BorderSide(color: DesignTokens.divider),
                  minimumSize: const Size(48, 44),
                ),
              ),
              if (selected.isUserImported)
                OutlinedButton.icon(
                  key: const Key('chord_lyrics_delete_button'),
                  onPressed: _deleteSelectedUserSheet,
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
                Icons.swap_vert,
                size: 18,
                color: DesignTokens.indigoLight,
              ),
              const SizedBox(width: DesignTokens.space8),
              const Expanded(
                child: Text(
                  'スクロール速度',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space8),
              Text(
                '${_scrollSpeedPxPerSec.round()} px/s',
                key: const Key('chord_lyrics_scroll_speed_value'),
                style: const TextStyle(
                  color: DesignTokens.orangeLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Semantics(
            label: '自動スクロール速度',
            child: Slider(
              key: const Key('chord_lyrics_scroll_speed_slider'),
              value: _scrollSpeedPxPerSec,
              min: 12,
              max: 90,
              divisions: 26,
              activeColor: DesignTokens.orange,
              inactiveColor: DesignTokens.surface3,
              label: '${_scrollSpeedPxPerSec.round()} px/s',
              onChanged: (double value) {
                setState(() {
                  _scrollSpeedPxPerSec = value.clamp(12, 90);
                });
              },
            ),
          ),
          const SizedBox(height: DesignTokens.space4),
          Wrap(
            spacing: DesignTokens.space12,
            runSpacing: DesignTokens.space4,
            children: <Widget>[
              Text(
                '表示キー: ${parsed.effectiveKeyLabel}',
                key: const Key('chord_lyrics_effective_key'),
                style: const TextStyle(
                  color: _mutedOnDarkSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (parsed.tempoBpm != null)
                Text(
                  '推奨テンポ: ${parsed.tempoBpm} BPM',
                  style: const TextStyle(
                    color: _mutedOnDarkSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSheetCard(
    ChordLyricsSheetDocument selected,
    ParsedChordLyricsSong parsed,
  ) {
    final sheetBg = _lightSheet ? Colors.white : DesignTokens.background;
    final titleColor =
        _lightSheet ? const Color(0xFF111827) : DesignTokens.textPrimary;
    final subtitleColor =
        _lightSheet ? const Color(0xFF374151) : DesignTokens.textSecondary;
    final lyricColor =
        _lightSheet ? const Color(0xFF991B1B) : DesignTokens.orangeLight;
    final sectionBg =
        _lightSheet ? const Color(0xFFF3F4F6) : DesignTokens.surface2;
    final borderColor = _lightSheet
        ? const Color(0xFFD1D5DB)
        : DesignTokens.orange.withValues(alpha: 0.25);

    return GestureDetector(
      key: const Key('chord_lyrics_score_tap_area'),
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: _toggleAutoScroll,
      child: Container(
        key: Key(
          _lightSheet ? 'chord_lyrics_sheet_light' : 'chord_lyrics_sheet_dark',
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
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space12,
                vertical: DesignTokens.space8,
              ),
              decoration: BoxDecoration(
                color: _isAutoScrolling
                    ? DesignTokens.orange.withValues(alpha: 0.14)
                    : sectionBg,
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _isAutoScrolling
                        ? Icons.pause_circle_outline
                        : Icons.touch_app_outlined,
                    size: 16,
                    color:
                        _isAutoScrolling ? DesignTokens.orange : subtitleColor,
                  ),
                  const SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: Text(
                      _isAutoScrolling
                          ? '自動スクロール中 — 楽譜タップで停止'
                          : '楽譜タップで自動スクロール開始',
                      key: const Key('chord_lyrics_autoscroll_banner'),
                      style: TextStyle(
                        color: _isAutoScrolling
                            ? DesignTokens.orange
                            : subtitleColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              parsed.title,
              key: const Key('chord_lyrics_selected_title'),
              style: TextStyle(
                color: titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            Text(
              '${parsed.subtitle}  •  表示キー ${parsed.effectiveKeyLabel}  •  Capo $_capoFret',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesignTokens.space20),
            for (final section in parsed.sections) ...<Widget>[
              if (section.label != null) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: sectionBg,
                      borderRadius:
                          BorderRadius.circular(DesignTokens.radiusSmall),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      section.label!,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.space12),
              ],
              for (final line in section.lines) ...<Widget>[
                _buildSheetLine(
                  line: line,
                  titleColor: titleColor,
                  subtitleColor: subtitleColor,
                  lyricColor: lyricColor,
                  sectionBg: sectionBg,
                ),
                const SizedBox(height: DesignTokens.space16),
              ],
              const SizedBox(height: DesignTokens.space8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSheetLine({
    required ChordLyricsLineView line,
    required Color titleColor,
    required Color subtitleColor,
    required Color lyricColor,
    required Color sectionBg,
  }) {
    if (line.commentText != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          line.commentText!,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (line.verbatimText != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DesignTokens.space8),
        decoration: BoxDecoration(
          color: sectionBg,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        ),
        child: Text(
          line.verbatimText!,
          style: TextStyle(
            color: titleColor,
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      );
    }

    if (line.isEmpty) {
      return const SizedBox(height: DesignTokens.space8);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: line.hasLyrics ? 2 : 6,
      runSpacing: 12,
      children: <Widget>[
        for (final cluster in line.clusters)
          _buildClusterWidget(
            cluster: cluster,
            titleColor: titleColor,
            lyricColor: lyricColor,
            sectionBg: sectionBg,
            hasLineLyrics: line.hasLyrics,
          ),
      ],
    );
  }

  Widget _buildClusterWidget({
    required ChordLyricCluster cluster,
    required Color titleColor,
    required Color lyricColor,
    required Color sectionBg,
    required bool hasLineLyrics,
  }) {
    final resolved = cluster.diagram;
    final hasLyric = cluster.lyricText.isNotEmpty;

    Widget? chordHeader;
    if (cluster.hasChord) {
      if (_showDiagrams && resolved != null && resolved.hasDiagram) {
        chordHeader = HorizontalChordDiagramCard(
          chord: resolved.diagram,
          lightSheet: _lightSheet,
          isNoChord: resolved.isNoChord,
        );
      } else {
        chordHeader = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: sectionBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            cluster.chordLabel!,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(right: hasLyric ? 4 : 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (chordHeader != null) chordHeader,
          if (hasLyric) ...<Widget>[
            if (chordHeader != null) const SizedBox(height: 2),
            Text(
              cluster.lyricText,
              style: TextStyle(
                color: lyricColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ] else if (hasLineLyrics && chordHeader != null) ...<Widget>[
            // 同一行の他の歌詞と高さ基準を揃えつつ、末尾の独立コードを崩さない。
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}

class _StepperBadge extends StatelessWidget {
  const _StepperBadge({
    required this.labelKey,
    required this.labelText,
    required this.minusKey,
    required this.minusTooltip,
    required this.onMinus,
    required this.plusKey,
    required this.plusTooltip,
    required this.onPlus,
  });

  final Key labelKey;
  final String labelText;
  final Key minusKey;
  final String minusTooltip;
  final VoidCallback? onMinus;
  final Key plusKey;
  final String plusTooltip;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: minusKey,
            tooltip: minusTooltip,
            onPressed: onMinus,
            icon: const Icon(Icons.remove, size: 18),
            color: DesignTokens.textOnDark,
            disabledColor: _mutedOnDarkSurface.withValues(alpha: 0.45),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              labelText,
              key: labelKey,
              style: const TextStyle(
                color: DesignTokens.orangeLight,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: plusKey,
            tooltip: plusTooltip,
            onPressed: onPlus,
            icon: const Icon(Icons.add, size: 18),
            color: DesignTokens.textOnDark,
            disabledColor: _mutedOnDarkSurface.withValues(alpha: 0.45),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          ),
        ],
      ),
    );
  }
}

class _ImportChordProDialog extends StatefulWidget {
  const _ImportChordProDialog({
    required this.templateSheet,
    required this.reservedIds,
    this.chordProFilePicker,
  });

  final ChordLyricsSheetDocument? templateSheet;
  final Set<String> reservedIds;
  final Future<FilePickerResult?> Function()? chordProFilePicker;

  @override
  State<_ImportChordProDialog> createState() => _ImportChordProDialogState();
}

class _ImportChordProDialogState extends State<_ImportChordProDialog> {
  late final TextEditingController _controller;
  String? _validationError;
  bool _isPickingFile = false;

  static const String _sampleTemplate = '''{title: マイ練習コード譜}
{subtitle: 個人練習メモ}
{key: C}
{tempo: 96}

[C]静かな部屋で[Am]ギターを鳴らして
[F]ゆっくり[G]呼吸を[C]整える
''';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.templateSheet?.sourceChordPro ?? _sampleTemplate,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_isPickingFile) return;
    setState(() {
      _isPickingFile = true;
      _validationError = null;
    });
    try {
      final result = await (widget.chordProFilePicker?.call() ??
          FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const <String>['cho', 'crd', 'chopro', 'txt'],
            withData: true,
          ));
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() {
          _validationError = 'ファイル内容を取得できませんでした。';
        });
        return;
      }
      if (bytes.length >
          SharedPreferencesUserChordLyricsStorageService.maxSourceBytes) {
        setState(() {
          _validationError = '64KB を超えるファイルは読み込めません。';
        });
        return;
      }
      try {
        final decoded = utf8.decode(bytes);
        _controller.text = decoded;
        setState(() {
          _validationError = null;
        });
      } on FormatException {
        setState(() {
          _validationError = 'UTF-8 の ChordPro テキストファイルを選択してください。';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _validationError = 'ファイル選択に失敗しました。下の入力欄へ直接貼り付けて保存できます。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  void _submit() {
    try {
      final candidateId =
          'user-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      final uniqueId = widget.reservedIds.contains(candidateId)
          ? '${candidateId}_local'
          : candidateId;
      final doc = buildUserChordLyricsDocument(
        id: uniqueId,
        rawChordPro: _controller.text,
      );
      Navigator.of(context).pop(doc);
    } on FormatException catch (error) {
      setState(() {
        _validationError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('chord_lyrics_import_dialog'),
      backgroundColor: DesignTokens.surface1,
      title: const Text(
        'ChordPro 譜面を読み込む（端末ローカル専用）',
        style: TextStyle(color: DesignTokens.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'この端末内のストレージにのみ保存され、サーバーや他のユーザーへは一切送信・公開されません。',
                style: TextStyle(
                  color: _mutedOnDarkSurface,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('chord_lyrics_file_pick_button'),
                  onPressed: _isPickingFile ? null : _pickFile,
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  label: Text(
                    _isPickingFile ? '読み込み中...' : '.cho / .txt ファイルを選択',
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                key: const Key('chord_lyrics_source_input'),
                controller: _controller,
                maxLines: 10,
                style: const TextStyle(
                  color: DesignTokens.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: DesignTokens.background,
                  border: OutlineInputBorder(),
                  hintText: '{title: 曲名}\n[C]歌詞...',
                ),
              ),
              if (_validationError != null) ...<Widget>[
                const SizedBox(height: DesignTokens.space8),
                Text(
                  _validationError!,
                  key: const Key('chord_lyrics_import_error'),
                  style: const TextStyle(color: DesignTokens.red, fontSize: 12),
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
          key: const Key('chord_lyrics_source_save'),
          onPressed: _submit,
          child: const Text('この端末に保存'),
        ),
      ],
    );
  }
}
