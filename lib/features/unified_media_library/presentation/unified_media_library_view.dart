import 'package:flutter/material.dart';

import '../application/unified_media_library_controller.dart';
import '../domain/unified_media_library_models.dart';

/// 統合メディアライブラリ＆ハッシュ重複排除・複数プロジェクト再利用画面 (#2714)。
class UnifiedMediaLibraryView extends StatefulWidget {
  const UnifiedMediaLibraryView({
    super.key,
    required this.controller,
  });

  final UnifiedMediaLibraryController controller;

  @override
  State<UnifiedMediaLibraryView> createState() =>
      _UnifiedMediaLibraryViewState();
}

class _UnifiedMediaLibraryViewState extends State<UnifiedMediaLibraryView> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _uploadTitleController = TextEditingController();
  final TextEditingController _uploadDescriptionController =
      TextEditingController();
  final TextEditingController _uploadTagsController = TextEditingController();
  final TextEditingController _uploadPayloadController =
      TextEditingController();
  final TextEditingController _uploadProjectController =
      TextEditingController();
  final TextEditingController _reuseProjectKeyController =
      TextEditingController(text: 'proj-alpha');
  final TextEditingController _reuseProjectTitleController =
      TextEditingController(text: 'メイン動画企画');
  final TextEditingController _tagEditController = TextEditingController();

  MediaAssetKind _uploadKind = MediaAssetKind.video;
  PipelineReuseStage _uploadStage = PipelineReuseStage.videoTimeline;
  PipelineReuseStage _reuseStage = PipelineReuseStage.bRoll;

  @override
  void dispose() {
    _searchController.dispose();
    _uploadTitleController.dispose();
    _uploadDescriptionController.dispose();
    _uploadTagsController.dispose();
    _uploadPayloadController.dispose();
    _uploadProjectController.dispose();
    _reuseProjectKeyController.dispose();
    _reuseProjectTitleController.dispose();
    _tagEditController.dispose();
    super.dispose();
  }

  List<String> _parseCommaTags(String raw) {
    return raw
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _handleUpload() async {
    final String projectRaw = _uploadProjectController.text.trim();
    await widget.controller.uploadOrDeduplicateTextPayload(
      title: _uploadTitleController.text,
      assetKind: _uploadKind,
      rawPayloadText: _uploadPayloadController.text,
      description: _uploadDescriptionController.text,
      tags: _parseCommaTags(_uploadTagsController.text),
      projectKey: projectRaw.isEmpty ? null : projectRaw,
      pipelineStage: _uploadStage,
    );
  }

  Future<void> _handleReuseAsset(UnifiedMediaAsset asset) async {
    await widget.controller.reuseAssetInProject(
      asset: asset,
      projectKey: _reuseProjectKeyController.text,
      projectTitle: _reuseProjectTitleController.text,
      pipelineStage: _reuseStage,
    );
  }

  Future<void> _handleRefreshAutoTags(UnifiedMediaAsset asset) async {
    final List<String> extraTags = _parseCommaTags(_tagEditController.text);
    final List<String> mergedTags = <String>{
      ...asset.tags,
      ...extraTags,
    }.toList(growable: false);
    await widget.controller.updateAssetTags(
      asset: asset,
      tags: mergedTags,
      refreshAutoTags: true,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final _MediaLibraryPalette palette = _MediaLibraryPalette.fromBrightness(
      Theme.of(context).brightness,
    );

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<UnifiedMediaAsset> filtered =
            widget.controller.filteredAssets;

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
                    key: const ValueKey<String>('media-status-banner'),
                    text: widget.controller.statusMessage,
                    bg: palette.okBg,
                    fg: palette.okFg,
                    border: palette.okBorder,
                  ),
                ],
                if (widget.controller.errorMessage.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  _buildBanner(
                    key: const ValueKey<String>('media-error-banner'),
                    text: widget.controller.errorMessage,
                    bg: palette.dangerBg,
                    fg: palette.dangerFg,
                    border: palette.dangerBorder,
                  ),
                ],
                const SizedBox(height: 14),
                _buildSearchAndFilters(palette),
                const SizedBox(height: 14),
                _buildUploadSection(palette),
                const SizedBox(height: 14),
                _buildReuseTargetSection(palette),
                const SizedBox(height: 14),
                _buildAssetList(palette, filtered),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(_MediaLibraryPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Icon(
          Icons.perm_media_outlined,
          color: palette.primaryText,
        ),
        Text(
          '統合メディアライブラリ・アセット再利用',
          softWrap: true,
          style: TextStyle(
            color: palette.primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        _buildBadge(
          label: 'SHA-256 重複排除',
          bg: palette.infoBg,
          fg: palette.infoFg,
          border: palette.infoBorder,
        ),
      ],
    );
  }

  Widget _buildSummaryMetrics(_MediaLibraryPalette palette) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        _buildMetricCard(
          key: const ValueKey<String>('media-summary-count'),
          label: '登録アセット',
          value: '${widget.controller.assets.length} 件',
          palette: palette,
        ),
        _buildMetricCard(
          key: const ValueKey<String>('media-summary-reuse'),
          label: '累計再利用',
          value: '${widget.controller.totalReuseCount} 回',
          palette: palette,
        ),
        _buildMetricCard(
          key: const ValueKey<String>('media-summary-saved'),
          label: '重複削減容量',
          value: _formatBytes(widget.controller.totalDeduplicatedBytesSaved),
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required Key key,
    required String label,
    required String value,
    required _MediaLibraryPalette palette,
  }) {
    return DecoratedBox(
      key: key,
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
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required _MediaLibraryPalette palette,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: palette.secondaryText),
      hintStyle: TextStyle(color: palette.secondaryText),
      filled: true,
      fillColor: palette.panelSurface,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: palette.primaryBtnBg, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildSelectableChipButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
    required _MediaLibraryPalette palette,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: OutlinedButton(
        key: key,
        style: OutlinedButton.styleFrom(
          foregroundColor:
              selected ? palette.primaryBtnFg : palette.primaryText,
          backgroundColor:
              selected ? palette.primaryBtnBg : palette.panelSurface,
          side: BorderSide(
            color: selected ? palette.primaryBtnBg : palette.border,
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          softWrap: true,
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(_MediaLibraryPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'アセット検索・種別・AI自動タグ設定',
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-search-field'),
              controller: _searchController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: 'キーワード・タグ検索',
                hint: 'タイトル、説明、タグで検索',
                palette: palette,
                suffixIcon: widget.controller.searchQuery.isNotEmpty
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: IconButton(
                          key: const ValueKey<String>('media-search-clear'),
                          tooltip: '検索キーワードをクリア',
                          onPressed: () {
                            _searchController.clear();
                            widget.controller.setSearchQuery('');
                          },
                          icon: Icon(
                            Icons.clear,
                            color: palette.primaryText,
                          ),
                        ),
                      )
                    : null,
              ),
              onChanged: widget.controller.setSearchQuery,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildSelectableChipButton(
                  key: const ValueKey<String>('media-filter-all'),
                  label: 'すべて',
                  selected: widget.controller.selectedKind == null,
                  onPressed: () => widget.controller.selectKindFilter(null),
                  palette: palette,
                ),
                for (final MediaAssetKind kind in MediaAssetKind.values)
                  _buildSelectableChipButton(
                    key: ValueKey<String>('media-filter-${kind.wireValue}'),
                    label: kind.labelJa,
                    selected: widget.controller.selectedKind == kind,
                    onPressed: () => widget.controller.selectKindFilter(kind),
                    palette: palette,
                  ),
              ],
            ),
            if (widget.controller.selectedTag.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _buildBadge(
                    label: '絞り込みタグ: #${widget.controller.selectedTag}',
                    bg: palette.warnBg,
                    fg: palette.warnFg,
                    border: palette.warnBorder,
                  ),
                  _buildSelectableChipButton(
                    key: const ValueKey<String>('media-clear-tag-filter'),
                    label: 'タグ解除',
                    selected: false,
                    onPressed: () => widget.controller.selectTagFilter(''),
                    palette: palette,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              'AI 自動タグ付けモデルフック',
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final AutoTagModelPreference model
                    in AutoTagModelPreference.values)
                  _buildSelectableChipButton(
                    key: ValueKey<String>('media-ai-model-${model.wireValue}'),
                    label: model.labelJa,
                    selected: widget.controller.selectedAiModel == model,
                    onPressed: () => widget.controller.selectAiModel(model),
                    palette: palette,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection(_MediaLibraryPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '新規アップロード / SHA-256 重複チェック登録',
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final MediaAssetKind kind in MediaAssetKind.values)
                  _buildSelectableChipButton(
                    key:
                        ValueKey<String>('media-upload-kind-${kind.wireValue}'),
                    label: kind.labelJa,
                    selected: _uploadKind == kind,
                    onPressed: () {
                      setState(() {
                        _uploadKind = kind;
                      });
                    },
                    palette: palette,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('media-upload-title-field'),
              controller: _uploadTitleController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: 'アセット名',
                hint: '例: オープニング動画ジングル',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-upload-description-field'),
              controller: _uploadDescriptionController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '説明・用途メモ',
                hint: '例: YouTube イントロ / 4K',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-upload-tags-field'),
              controller: _uploadTagsController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '手動タグ (カンマ区切り)',
                hint: '例: intro, bgm, product',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-upload-payload-field'),
              controller: _uploadPayloadController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: 'メディアペイロード / バイナリ署名データ',
                hint: '同一内容なら重複アップロードをスキップ',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-upload-project-field'),
              controller: _uploadProjectController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '初回紐付けプロジェクトキー (任意)',
                hint: '例: launch-video-2026',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PipelineReuseStage stage
                    in PipelineReuseStage.values)
                  _buildSelectableChipButton(
                    key: ValueKey<String>(
                      'media-upload-stage-${stage.wireValue}',
                    ),
                    label: stage.labelJa,
                    selected: _uploadStage == stage,
                    onPressed: () {
                      setState(() {
                        _uploadStage = stage;
                      });
                    },
                    palette: palette,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: ElevatedButton(
                key: const ValueKey<String>('media-upload-submit-button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryBtnBg,
                  foregroundColor: palette.primaryBtnFg,
                ),
                onPressed: widget.controller.isBusy ? null : _handleUpload,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.cloud_upload_outlined),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '重複チェック付きで登録・再利用',
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReuseTargetSection(_MediaLibraryPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '複数プロジェクト再利用先・追加タグ設定',
              softWrap: true,
              style: TextStyle(
                color: palette.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-reuse-project-key-field'),
              controller: _reuseProjectKeyController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '再利用先プロジェクトキー',
                hint: '例: proj-beta',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-reuse-project-title-field'),
              controller: _reuseProjectTitleController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '再利用先プロジェクト名',
                hint: '例: 新商品ショート動画',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey<String>('media-tag-edit-field'),
              controller: _tagEditController,
              style: TextStyle(color: palette.primaryText),
              decoration: _inputDecoration(
                label: '追加手動タグ (タグ更新時に併合)',
                hint: '例: b-roll, campaign',
                palette: palette,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PipelineReuseStage stage
                    in PipelineReuseStage.values)
                  _buildSelectableChipButton(
                    key: ValueKey<String>(
                      'media-reuse-stage-${stage.wireValue}',
                    ),
                    label: stage.labelJa,
                    selected: _reuseStage == stage,
                    onPressed: () {
                      setState(() {
                        _reuseStage = stage;
                      });
                    },
                    palette: palette,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetList(
    _MediaLibraryPalette palette,
    List<UnifiedMediaAsset> assets,
  ) {
    if (assets.isEmpty) {
      return DecoratedBox(
        key: const ValueKey<String>('media-empty-state'),
        decoration: BoxDecoration(
          color: palette.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '該当する統合メディアアセットはありません。検索条件を変更するか新規アセットを登録してください。',
            softWrap: true,
            style: TextStyle(color: palette.secondaryText),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final UnifiedMediaAsset asset in assets) ...<Widget>[
          _buildAssetCard(palette, asset),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildAssetCard(
    _MediaLibraryPalette palette,
    UnifiedMediaAsset asset,
  ) {
    final String shortHash = asset.contentSha256.length > 12
        ? '${asset.contentSha256.substring(0, 12)}...'
        : asset.contentSha256;

    return DecoratedBox(
      key: ValueKey<String>('media-asset-card-${asset.id}'),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  asset.title,
                  softWrap: true,
                  style: TextStyle(
                    color: palette.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildBadge(
                  label: asset.assetKind.labelJa,
                  bg: palette.infoBg,
                  fg: palette.infoFg,
                  border: palette.infoBorder,
                ),
                _buildBadge(
                  label: '再利用 ${asset.reuseCount} 回',
                  bg: palette.okBg,
                  fg: palette.okFg,
                  border: palette.okBorder,
                ),
              ],
            ),
            if (asset.description.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                asset.description,
                softWrap: true,
                style: TextStyle(color: palette.secondaryText),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'SHA-256: $shortHash | 容量 ${_formatBytes(asset.byteSize)} '
              '| タグモデル: ${asset.taggingModel.labelJa}',
              softWrap: true,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 12,
              ),
            ),
            if (asset.allSearchTags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String tag in asset.allSearchTags)
                    _buildSelectableChipButton(
                      key: ValueKey<String>('media-tag-chip-${asset.id}-$tag'),
                      label: '#$tag',
                      selected: widget.controller.selectedTag == tag,
                      onPressed: () => widget.controller.selectTagFilter(tag),
                      palette: palette,
                    ),
                ],
              ),
            ],
            if (asset.usages.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '使用プロジェクト履歴 (${asset.usages.length} 件): '
                '${asset.usages.map((MediaProjectUsage u) => '${u.projectKey}(${u.pipelineStage.labelJa})').join(', ')}',
                softWrap: true,
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: ValueKey<String>('media-reuse-btn-${asset.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: widget.controller.isBusy
                        ? null
                        : () => _handleReuseAsset(asset),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.link),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'プロジェクトへ再利用',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: ValueKey<String>('media-autotag-btn-${asset.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primaryText,
                      backgroundColor: palette.panelSurface,
                      side: BorderSide(color: palette.border),
                    ),
                    onPressed: widget.controller.isBusy
                        ? null
                        : () => _handleRefreshAutoTags(asset),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.auto_awesome_outlined),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'AI自動タグ・保存',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: OutlinedButton(
                    key: ValueKey<String>('media-delete-btn-${asset.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.dangerFg,
                      backgroundColor: palette.dangerBg,
                      side: BorderSide(color: palette.dangerBorder),
                    ),
                    onPressed: widget.controller.isBusy
                        ? null
                        : () => widget.controller.deleteAsset(asset.id),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.delete_outline),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '削除',
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          softWrap: true,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MediaLibraryPalette {
  const _MediaLibraryPalette({
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
    required this.warnBg,
    required this.warnFg,
    required this.warnBorder,
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
  final Color warnBg;
  final Color warnFg;
  final Color warnBorder;
  final Color dangerBg;
  final Color dangerFg;
  final Color dangerBorder;
  final Color primaryBtnBg;
  final Color primaryBtnFg;

  static _MediaLibraryPalette fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _MediaLibraryPalette(
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
        warnBg: Color(0xFF78350F),
        warnFg: Color(0xFFFEF3C7),
        warnBorder: Color(0xFFFCD34D),
        dangerBg: Color(0xFF7F1D1D),
        dangerFg: Color(0xFFFEE2E2),
        dangerBorder: Color(0xFFFCA5A5),
        primaryBtnBg: Color(0xFF93C5FD),
        primaryBtnFg: Color(0xFF090D16),
      );
    }
    return const _MediaLibraryPalette(
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
      warnBg: Color(0xFFFEF3C7),
      warnFg: Color(0xFF78350F),
      warnBorder: Color(0xFFB45309),
      dangerBg: Color(0xFFFEE2E2),
      dangerFg: Color(0xFF7F1D1D),
      dangerBorder: Color(0xFFB91C1C),
      primaryBtnBg: Color(0xFF1E3A8A),
      primaryBtnFg: Color(0xFFFFFFFF),
    );
  }
}
