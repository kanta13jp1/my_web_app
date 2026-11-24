import 'package:flutter/material.dart';

import '../services/external_markdown_extraction_service.dart';

class _ExtractorPalette {
  const _ExtractorPalette({
    required this.cardSurface,
    required this.subSurface,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
    required this.infoBg,
    required this.infoFg,
    required this.successBg,
    required this.successFg,
    required this.errorBg,
    required this.errorFg,
  });

  factory _ExtractorPalette.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _ExtractorPalette(
        cardSurface: Color(0xFF0F172A),
        subSurface: Color(0xFF1E293B),
        textPrimary: Color(0xFFF8FAFC),
        textMuted: Color(0xFFCBD5E1),
        border: Color(0xFF64748B),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF0F172A),
        infoBg: Color(0xFF172554),
        infoFg: Color(0xFFBFDBFE),
        successBg: Color(0xFF052E16),
        successFg: Color(0xFFBBF7D0),
        errorBg: Color(0xFF450A0A),
        errorFg: Color(0xFFFECACA),
      );
    }
    return const _ExtractorPalette(
      cardSurface: Color(0xFFFFFFFF),
      subSurface: Color(0xFFF8FAFC),
      textPrimary: Color(0xFF0F172A),
      textMuted: Color(0xFF334155),
      border: Color(0xFF94A3B8),
      primaryBtnBg: Color(0xFF1E40AF),
      primaryBtnFg: Color(0xFFFFFFFF),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      successBg: Color(0xFFDCFCE7),
      successFg: Color(0xFF14532D),
      errorBg: Color(0xFFFEE2E2),
      errorFg: Color(0xFF7F1D1D),
    );
  }

  final Color cardSurface;
  final Color subSurface;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color primaryBtnBg;
  final Color primaryBtnFg;
  final Color infoBg;
  final Color infoFg;
  final Color successBg;
  final Color successFg;
  final Color errorBg;
  final Color errorFg;

  _StatusColorPair colorsForStatus(ExternalExtractionStatus status) {
    return switch (status) {
      ExternalExtractionStatus.completed =>
        _StatusColorPair(successBg, successFg),
      ExternalExtractionStatus.queued => _StatusColorPair(infoBg, infoFg),
      ExternalExtractionStatus.failed => _StatusColorPair(errorBg, errorFg),
      ExternalExtractionStatus.blocked => _StatusColorPair(errorBg, errorFg),
    };
  }
}

class _StatusColorPair {
  const _StatusColorPair(this.bg, this.fg);

  final Color bg;
  final Color fg;
}

/// 外部URLのMarkdown変換・構造化JSON抽出パイプラインUI (#2639)。
class ExternalMarkdownExtractorPanel extends StatefulWidget {
  const ExternalMarkdownExtractorPanel({
    super.key,
    this.repository,
  });

  final ExternalMarkdownExtractionRepository? repository;

  @override
  State<ExternalMarkdownExtractorPanel> createState() =>
      _ExternalMarkdownExtractorPanelState();
}

class _ExternalMarkdownExtractorPanelState
    extends State<ExternalMarkdownExtractorPanel> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  late final ExternalMarkdownExtractionRepository _repository;

  List<ExternalMarkdownExtractionRecord> _records =
      const <ExternalMarkdownExtractionRecord>[];
  ExternalMarkdownExtractionRecord? _selectedRecord;
  ExternalExtractorMode _selectedMode = ExternalExtractorMode.stdlibHtml;
  bool _loading = true;
  bool _submitting = false;
  bool _disposed = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? SupabaseExternalMarkdownExtractionRepository();
    _loadExtractions();
  }

  @override
  void dispose() {
    _disposed = true;
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExtractions() async {
    if (!mounted || _disposed) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final items = await _repository.listExtractions();
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _records = items;
        _selectedRecord = items.isNotEmpty ? items.first : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _loading = false;
        _errorMessage = '抽出履歴の読込に失敗しました: $error';
      });
    }
  }

  Future<void> _submitUrl() async {
    final rawUrl = _urlController.text.trim();
    final validationError = validateExternalHttpsUrl(rawUrl);
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
        _statusMessage = null;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final created = await _repository.submitExtraction(
        url: rawUrl,
        mode: _selectedMode,
      );
      if (!mounted || _disposed) {
        return;
      }
      _urlController.clear();
      setState(() {
        _records = <ExternalMarkdownExtractionRecord>[created, ..._records];
        _selectedRecord = created;
        _submitting = false;
        _statusMessage = 'URL 抽出ジョブを登録しました (${created.status.labelJa})。';
      });
    } catch (error) {
      if (!mounted || _disposed) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = 'URL 抽出リクエストに失敗しました: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _ExtractorPalette.of(context);
    return Material(
      color: palette.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(palette),
            const SizedBox(height: 12),
            _buildInputCard(palette),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorBanner(palette, _errorMessage!),
            ],
            if (_statusMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildStatusBanner(palette, _statusMessage!),
            ],
            if (_selectedRecord != null) ...<Widget>[
              const SizedBox(height: 16),
              _buildPreviewCard(palette, _selectedRecord!),
            ],
            const SizedBox(height: 16),
            _buildHistorySection(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(_ExtractorPalette palette) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '外部URL Markdown変換・構造化抽出',
            softWrap: true,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton.icon(
              key: const ValueKey<String>('ext_md_refresh_button'),
              onPressed: _loading ? null : _loadExtractions,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                foregroundColor: palette.textPrimary,
                disabledBackgroundColor: palette.cardSurface,
                disabledForegroundColor: palette.textMuted,
                side: BorderSide(color: palette.border),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('更新'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(_ExtractorPalette palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('ext_md_url_input'),
            controller: _urlController,
            focusNode: _urlFocusNode,
            keyboardType: TextInputType.url,
            style: TextStyle(color: palette.textPrimary),
            decoration: InputDecoration(
              labelText: '抽出対象 URL (https:// のみ)',
              hintText: 'https://docs.example.com/guide',
              labelStyle: TextStyle(color: palette.textMuted),
              hintStyle: TextStyle(color: palette.textMuted),
              filled: true,
              fillColor: palette.cardSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final mode in ExternalExtractorMode.values)
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: OutlinedButton(
                    key: ValueKey<String>('ext_md_mode_${mode.wireValue}'),
                    onPressed: () {
                      setState(() {
                        _selectedMode = mode;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedMode == mode
                          ? palette.infoBg
                          : palette.cardSurface,
                      foregroundColor: _selectedMode == mode
                          ? palette.infoFg
                          : palette.textPrimary,
                      side: BorderSide(
                        color: palette.border,
                        width: _selectedMode == mode ? 2 : 1,
                      ),
                    ),
                    child: Text(mode.labelJa),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: FilledButton(
                  key: const ValueKey<String>('ext_md_submit_button'),
                  onPressed: _submitting ? null : _submitUrl,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                    disabledBackgroundColor: palette.cardSurface,
                    disabledForegroundColor: palette.textMuted,
                  ),
                  child: const Text('Markdown抽出を送信'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(_ExtractorPalette palette, String message) {
    return Container(
      key: const ValueKey<String>('ext_md_error_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.errorBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  message,
                  softWrap: true,
                  style: TextStyle(
                    color: palette.errorFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: OutlinedButton(
              key: const ValueKey<String>('ext_md_retry_button'),
              onPressed: _loadExtractions,
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                foregroundColor: palette.textPrimary,
                side: BorderSide(color: palette.border),
              ),
              child: const Text('再試行'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(_ExtractorPalette palette, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.successBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              message,
              softWrap: true,
              style: TextStyle(
                color: palette.successFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(
    _ExtractorPalette palette,
    ExternalMarkdownExtractionRecord record,
  ) {
    final payload = record.structuredPayload;
    final statusColors = palette.colorsForStatus(record.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.subSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                payload.title.isNotEmpty ? payload.title : record.sourceTitle,
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              _ExtractorBadge(
                label:
                    '${record.status.labelJa} · ${record.extractorMode.labelJa}',
                bg: statusColors.bg,
                fg: statusColors.fg,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey<String>('ext_md_json_preview'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '構造化 JSON サマリー (単語数: ${payload.wordCount} / リンク: ${payload.links.length})',
                        softWrap: true,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (payload.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          payload.description,
                          softWrap: true,
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                for (final point in payload.keyPoints) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          '・$point',
                          softWrap: true,
                          style: TextStyle(color: palette.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: const ValueKey<String>('ext_md_markdown_preview'),
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: <Widget>[
                Flexible(
                  child: SelectableText(
                    record.markdownContent.isNotEmpty
                        ? record.markdownContent
                        : '（Markdown 出力待機中）',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(_ExtractorPalette palette) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '抽出履歴 (${_records.length}件)',
                softWrap: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_records.isEmpty)
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  '抽出履歴はまだありません。',
                  softWrap: true,
                  style: TextStyle(color: palette.textMuted),
                ),
              ),
            ],
          )
        else
          for (final item in _records)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.subSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    item.sourceUrl,
                    softWrap: true,
                    style: TextStyle(color: palette.textPrimary),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    child: OutlinedButton(
                      key: ValueKey<String>('ext_md_select_${item.id}'),
                      onPressed: () {
                        setState(() {
                          _selectedRecord = item;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: palette.cardSurface,
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.border),
                      ),
                      child: const Text('詳細表示'),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ExtractorBadge extends StatelessWidget {
  const _ExtractorBadge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        softWrap: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
