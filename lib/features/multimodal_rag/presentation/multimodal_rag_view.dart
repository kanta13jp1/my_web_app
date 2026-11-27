import 'package:flutter/material.dart';

import '../application/multimodal_rag_controller.dart';
import '../domain/multimodal_rag_models.dart';

/// Gemini Embedding 2 × Supabase pgvector マルチモーダル RAG パネル (#2687)。
class MultimodalRagView extends StatefulWidget {
  const MultimodalRagView({
    super.key,
    required this.controller,
  });

  final MultimodalRagController controller;

  @override
  State<MultimodalRagView> createState() => _MultimodalRagViewState();
}

class _MultimodalRagViewState extends State<MultimodalRagView> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _attachSamplePngOnIngest = false;

  @override
  void dispose() {
    _queryController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final _MultimodalPalette palette = _MultimodalPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.panelSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(palette),
                const SizedBox(height: 12),
                _buildSummaryMetrics(palette),
                if (widget.controller.statusMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('multimodal-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.okBg,
                    fg: palette.okFg,
                    border: palette.okBorder,
                  ),
                ],
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('multimodal-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                ],
                const SizedBox(height: 12),
                _buildSearchCard(palette),
                const SizedBox(height: 12),
                _buildIngestCard(palette),
                const SizedBox(height: 12),
                _buildResultsCard(palette),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_MultimodalPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(Icons.auto_awesome_mosaic_outlined, color: palette.primaryText),
        Text(
          'マルチモーダルRAG検索 (Gemini Embedding 2)',
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.infoBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.infoBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              widget.controller.activeEmbeddingMode.displayLabel,
              key: const ValueKey<String>('multimodal-mode-badge'),
              style: TextStyle(
                color: palette.infoFg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics(_MultimodalPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _buildMetricPill(
          palette,
          label: '登録件数',
          value: '${widget.controller.items.length}件',
        ),
        _buildMetricPill(
          palette,
          label: '検索ヒット',
          value: '${widget.controller.hits.length}件',
        ),
        _buildMetricPill(
          palette,
          label: 'ベクトル次元',
          value: '768d pgvector',
        ),
      ],
    );
  }

  Widget _buildMetricPill(
    _MultimodalPalette palette, {
    required String label,
    required String value,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(color: palette.secondaryText, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchCard(_MultimodalPalette palette) {
    final List<MultimodalModality> filters = <MultimodalModality>[
      MultimodalModality.all,
      MultimodalModality.text,
      MultimodalModality.image,
      MultimodalModality.video,
      MultimodalModality.pdf,
      MultimodalModality.mixed,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'クロスモーダル検索（テキスト・画像クエリ）',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('multimodal-query-input'),
              controller: _queryController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                labelText: '検索クエリ（テキスト）',
                labelStyle: TextStyle(color: palette.secondaryText),
                hintText: '例: 配線図 / デモ動画 / PDF マニュアル',
                hintStyle: TextStyle(color: palette.secondaryText),
                filled: true,
                fillColor: palette.panelSurface,
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
              children: filters.map((MultimodalModality modality) {
                final bool selected =
                    widget.controller.selectedModality == modality;
                return ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    key: ValueKey<String>('multimodal-filter-${modality.name}'),
                    label: Text(
                      modality.displayLabel,
                      style: TextStyle(
                        color: selected
                            ? palette.primaryBtnFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    selectedColor: palette.primaryBtnBg,
                    backgroundColor: palette.panelSurface,
                    side: BorderSide(color: palette.border),
                    onSelected: (_) {
                      widget.controller.setModalityFilter(modality);
                    },
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  key: const ValueKey<String>(
                    'multimodal-attach-sample-image-btn',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: palette.primaryText,
                    backgroundColor: palette.panelSurface,
                    side: BorderSide(color: palette.border),
                  ),
                  onPressed: () {
                    if (widget.controller.hasQueryImage) {
                      widget.controller.clearQueryImage();
                    } else {
                      widget.controller.attachQueryImage(
                        bytes: kSampleMultimodalPngBytes,
                        mimeType: 'image/png',
                        fileName: 'sample-query.png',
                      );
                    }
                  },
                  child: _buildIconText(
                    widget.controller.hasQueryImage
                        ? Icons.close
                        : Icons.image_search_outlined,
                    widget.controller.hasQueryImage ? '画像クエリ解除' : 'サンプル画像添付',
                  ),
                ),
                FilledButton(
                  key: const ValueKey<String>('multimodal-search-submit-btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                  ),
                  onPressed: widget.controller.isSearching
                      ? null
                      : () {
                          widget.controller.runSearch(_queryController.text);
                        },
                  child: _buildIconText(
                    Icons.search,
                    widget.controller.isSearching ? '検索中...' : 'マルチモーダル検索',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngestCard(_MultimodalPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規マルチモーダル資産のインデックス登録',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('multimodal-ingest-title-input'),
              controller: _titleController,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                labelText: 'コンテンツタイトル',
                labelStyle: TextStyle(color: palette.secondaryText),
                filled: true,
                fillColor: palette.panelSurface,
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
            TextField(
              key: const ValueKey<String>('multimodal-ingest-content-input'),
              controller: _contentController,
              maxLines: 2,
              style: TextStyle(color: palette.primaryText),
              decoration: InputDecoration(
                labelText: '解説・テキスト本文',
                labelStyle: TextStyle(color: palette.secondaryText),
                filled: true,
                fillColor: palette.panelSurface,
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
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: FilterChip(
                    key: const ValueKey<String>(
                      'multimodal-ingest-attach-png-chip',
                    ),
                    label: Text(
                      'PNG画像を連携',
                      style: TextStyle(
                        color: _attachSamplePngOnIngest
                            ? palette.primaryBtnFg
                            : palette.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: _attachSamplePngOnIngest,
                    selectedColor: palette.primaryBtnBg,
                    checkmarkColor: palette.primaryBtnFg,
                    backgroundColor: palette.panelSurface,
                    side: BorderSide(color: palette.border),
                    onSelected: (bool next) {
                      setState(() {
                        _attachSamplePngOnIngest = next;
                      });
                    },
                  ),
                ),
                FilledButton(
                  key: const ValueKey<String>('multimodal-ingest-submit-btn'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: palette.primaryBtnBg,
                    foregroundColor: palette.primaryBtnFg,
                  ),
                  onPressed: widget.controller.isIngesting
                      ? null
                      : () async {
                          final bool ok = await widget.controller.ingestItem(
                            sourceKey: '',
                            title: _titleController.text,
                            contentText: _contentController.text,
                            mediaBytes: _attachSamplePngOnIngest
                                ? kSampleMultimodalPngBytes
                                : null,
                            mimeType: _attachSamplePngOnIngest
                                ? 'image/png'
                                : 'text/plain',
                          );
                          if (ok && mounted) {
                            _titleController.clear();
                            _contentController.clear();
                          }
                        },
                  child: _buildIconText(
                    Icons.upload_file,
                    widget.controller.isIngesting ? '登録中...' : 'Storage連携保存',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard(_MultimodalPalette palette) {
    final List<MultimodalSearchHit> hits = widget.controller.hits;
    return DecoratedBox(
      key: const ValueKey<String>('multimodal-results-card'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '検索結果・Storage連携ステータス',
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (hits.isEmpty)
              Text(
                '一致するマルチモーダル項目はありません。条件を変更して再検索してください。',
                style: TextStyle(color: palette.secondaryText, fontSize: 13),
              )
            else
              ...hits.map((MultimodalSearchHit hit) {
                final int pct = (hit.similarityScore * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DecoratedBox(
                    key: ValueKey<String>('multimodal-hit-${hit.itemId}'),
                    decoration: BoxDecoration(
                      color: palette.panelSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: <Widget>[
                              Text(
                                hit.title,
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              _buildInlineChip(
                                palette,
                                '${hit.modality.displayLabel} • 類似度 $pct%',
                              ),
                              _buildInlineChip(
                                palette,
                                hit.hasStorageLink
                                    ? 'Storage保護済'
                                    : 'テキストインデックス',
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hit.matchedExcerpt,
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (hit.hasStorageLink)
                                OutlinedButton(
                                  key: ValueKey<String>(
                                    'multimodal-signed-url-${hit.itemId}',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    foregroundColor: palette.primaryText,
                                    side: BorderSide(color: palette.border),
                                  ),
                                  onPressed: () {
                                    widget.controller.refreshSignedUrl(
                                      hit.itemId,
                                    );
                                  },
                                  child: _buildIconText(
                                    Icons.lock_outline,
                                    '署名URL確認',
                                  ),
                                ),
                              OutlinedButton.icon(
                                key: ValueKey<String>(
                                  'multimodal-delete-${hit.itemId}',
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  foregroundColor: palette.dangerFg,
                                  backgroundColor: palette.dangerBg,
                                  side: BorderSide(color: palette.dangerBorder),
                                ),
                                onPressed: () {
                                  widget.controller.deleteItem(hit.itemId);
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('削除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildIconText(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );
  }

  Widget _buildInlineChip(_MultimodalPalette palette, String label) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.infoBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.infoBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: palette.infoFg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBanner({
    required Key key,
    required String text,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          text,
          style:
              TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MultimodalPalette {
  const _MultimodalPalette({
    required this.panelSurface,
    required this.cardSurface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.infoBg,
    required this.infoFg,
    required this.infoBorder,
    required this.okBg,
    required this.okFg,
    required this.okBorder,
    required this.dangerBg,
    required this.dangerFg,
    required this.dangerBorder,
    required this.primaryBtnBg,
    required this.primaryBtnFg,
  });

  final Color panelSurface;
  final Color cardSurface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color infoBg;
  final Color infoFg;
  final Color infoBorder;
  final Color okBg;
  final Color okFg;
  final Color okBorder;
  final Color dangerBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _MultimodalPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _MultimodalPalette(
        panelSurface: Color(0xFF090D16),
        cardSurface: Color(0xFF111827),
        border: Color(0xFFCBD5E1),
        primaryText: Color(0xFFF8FAFC),
        secondaryText: Color(0xFFE2E8F0),
        infoBg: Color(0xFF1E3A8A),
        infoFg: Color(0xFFDBEAFE),
        infoBorder: Color(0xFF93C5FD),
        okBg: Color(0xFF064E3B),
        okFg: Color(0xFFECFDF5),
        okBorder: Color(0xFF6EE7B7),
        dangerBg: Color(0xFF7F1D1D),
        dangerFg: Color(0xFFFEE2E2),
        dangerBorder: Color(0xFFFCA5A5),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _MultimodalPalette(
      panelSurface: Color(0xFFFFFFFF),
      cardSurface: Color(0xFFF8FAFC),
      border: Color(0xFF475569),
      primaryText: Color(0xFF0F172A),
      secondaryText: Color(0xFF1E293B),
      infoBg: Color(0xFFDBEAFE),
      infoFg: Color(0xFF1E3A8A),
      infoBorder: Color(0xFF1E40AF),
      okBg: Color(0xFFDCFCE7),
      okFg: Color(0xFF14532D),
      okBorder: Color(0xFF15803D),
      dangerBg: Color(0xFFFEE2E2),
      dangerFg: Color(0xFF7F1D1D),
      dangerBorder: Color(0xFFB91C1C),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
