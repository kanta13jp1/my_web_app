import 'package:flutter/material.dart';

import '../application/image_moderation_controller.dart';
import '../domain/image_moderation_models.dart';

@immutable
class _ImageModerationPalette {
  const _ImageModerationPalette({
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
  });

  factory _ImageModerationPalette.fromBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const _ImageModerationPalette(
        surface: Color(0xFF111827),
        surfaceSubtle: Color(0xFF1F2937),
        border: Color(0xFF9CA3AF),
        ink: Color(0xFFF9FAFB),
        inkSecondary: Color(0xFFE5E7EB),
        accent: Color(0xFF93C5FD),
        onAccent: Color(0xFF0B2545),
        accentSoft: Color(0xFF1E3A5F),
        accentSoftInk: Color(0xFFE0F2FE),
        warnBg: Color(0xFF332100),
        warnBorder: Color(0xFFFBBF24),
        warnInk: Color(0xFFFEF3C7),
      );
    }
    return const _ImageModerationPalette(
      surface: Color(0xFFFFFFFF),
      surfaceSubtle: Color(0xFFF3F5F8),
      border: Color(0xFF4B5563),
      ink: Color(0xFF111827),
      inkSecondary: Color(0xFF374151),
      accent: Color(0xFF0F4C81),
      onAccent: Color(0xFFFFFFFF),
      accentSoft: Color(0xFFE6EFF8),
      accentSoftInk: Color(0xFF0B355C),
      warnBg: Color(0xFFFFF4E5),
      warnBorder: Color(0xFF8A4B00),
      warnInk: Color(0xFF5A2E00),
    );
  }

  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color ink;
  final Color inkSecondary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentSoftInk;
  final Color warnBg;
  final Color warnBorder;
  final Color warnInk;
}

/// ViT 画像モデレーション・自動タグ検索 純粋 Presentation View (#2644).
class ImageModerationView extends StatelessWidget {
  const ImageModerationView({
    super.key,
    required this.state,
    required this.uploadPathController,
    required this.searchController,
    required this.onRetryLoad,
    required this.onSearchChanged,
    required this.onSelectTag,
    required this.onToggleIncludeRestricted,
    required this.onToggleExternalConsent,
    required this.onSubmitUpload,
  });

  final ImageModerationState state;
  final TextEditingController uploadPathController;
  final TextEditingController searchController;
  final VoidCallback onRetryLoad;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelectTag;
  final ValueChanged<bool> onToggleIncludeRestricted;
  final ValueChanged<bool> onToggleExternalConsent;
  final VoidCallback onSubmitUpload;

  @override
  Widget build(BuildContext context) {
    final palette = _ImageModerationPalette.fromBrightness(
      Theme.of(context).brightness,
    );
    final filtered = state.filteredAssets;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'ViT 画像モデレーション＆自動タグ検索',
              style: TextStyle(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Storage アップロード時の安全スコア検証・自動非表示・自動付与タグによる絞り込み検索',
              style: TextStyle(color: palette.inkSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildUploadSection(palette),
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              _buildErrorCard(palette, state.errorMessage!),
            ],
            const SizedBox(height: 16),
            _buildFilterSection(palette),
            const SizedBox(height: 12),
            if (state.isLoading && state.assets.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: palette.accent),
                ),
              )
            else if (filtered.isEmpty)
              DecoratedBox(
                key: const ValueKey<String>('image_moderation_empty_state'),
                decoration: BoxDecoration(
                  color: palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '条件に一致する表示対象画像はありません。タグ選択や検索語を見直してください。',
                    style: TextStyle(color: palette.inkSecondary),
                  ),
                ),
              )
            else
              for (final asset in filtered) ...<Widget>[
                _buildAssetCard(palette, asset),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection(_ImageModerationPalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('image_upload_path_input'),
              controller: uploadPathController,
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                labelText: 'Storage 画像パス',
                hintText: '例: receipt_2026_11_24.png',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: CheckboxListTile(
                key: const ValueKey<String>('external_transfer_consent_toggle'),
                contentPadding: EdgeInsets.zero,
                value: state.externalTransferConsented,
                activeColor: palette.accent,
                checkColor: palette.onAccent,
                onChanged: (bool? checked) {
                  onToggleExternalConsent(checked ?? false);
                },
                title: Text(
                  '外部Vision API解析への送信に同意する',
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '既定は OFF です。本番有効化には利用規約・プライバシーポリシーの確認が必要です。',
                  style: TextStyle(color: palette.inkSecondary, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: FilledButton(
                  key: const ValueKey<String>('image_submit_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: palette.onAccent,
                  ),
                  onPressed: state.isSubmitting ? null : onSubmitUpload,
                  child: Text(state.isSubmitting ? '解析中...' : '画像を解析登録'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(_ImageModerationPalette palette, String message) {
    return DecoratedBox(
      key: const ValueKey<String>('image_moderation_error_banner'),
      decoration: BoxDecoration(
        color: palette.warnBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.warnBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message,
              style: TextStyle(
                color: palette.warnInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: OutlinedButton(
                key: const ValueKey<String>('image_moderation_retry_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.warnInk,
                  side: BorderSide(color: palette.warnBorder),
                ),
                onPressed: onRetryLoad,
                child: const Text('再読み込み'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(_ImageModerationPalette palette) {
    final tags = state.availableTags;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('image_tag_search_input'),
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(color: palette.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: palette.surface,
                labelText: 'タグ・ファイル名で絞り込み検索',
                hintText: '例: receipt / portrait',
                labelStyle: TextStyle(color: palette.inkSecondary),
                hintStyle: TextStyle(color: palette.inkSecondary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildTagChipButton(
                  palette: palette,
                  buttonKey: const ValueKey<String>('tag_filter_all'),
                  label: '全て',
                  selected: state.selectedTag.isEmpty,
                  onPressed: () => onSelectTag(''),
                ),
                for (final tag in tags)
                  _buildTagChipButton(
                    palette: palette,
                    buttonKey: ValueKey<String>('tag_filter_$tag'),
                    label: '#$tag',
                    selected: state.selectedTag == tag,
                    onPressed: () => onSelectTag(tag),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: CheckboxListTile(
                key: const ValueKey<String>('toggle_include_restricted'),
                contentPadding: EdgeInsets.zero,
                value: state.includeRestricted,
                activeColor: palette.accent,
                checkColor: palette.onAccent,
                onChanged: (bool? checked) {
                  onToggleIncludeRestricted(checked ?? false);
                },
                title: Text(
                  '非表示/要確認を表示 (${state.hiddenOrFlaggedCount} 件)',
                  style: TextStyle(
                    color: palette.accentSoftInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChipButton({
    required _ImageModerationPalette palette,
    required Key buttonKey,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          key: buttonKey,
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? palette.accent : palette.surface,
            foregroundColor: selected ? palette.onAccent : palette.ink,
            side: BorderSide(color: palette.border),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildAssetCard(
    _ImageModerationPalette palette,
    ModeratedImageAsset asset,
  ) {
    final bool restricted = asset.isRestricted;
    final Color bg = restricted ? palette.warnBg : palette.surfaceSubtle;
    final Color fg = restricted ? palette.warnInk : palette.ink;
    final Color border = restricted ? palette.warnBorder : palette.border;

    return DecoratedBox(
      key: ValueKey<String>('asset_card_${asset.id}'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              restricted ? '[安全マスク中] ${asset.storagePath}' : asset.storagePath,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '判定: ${asset.moderationStatus.label} / スコア: ${asset.safetyScore.toStringAsFixed(2)} / タグ: ${asset.tags.join(', ')}',
              style: TextStyle(
                color: restricted ? palette.warnInk : palette.inkSecondary,
                fontSize: 13,
              ),
            ),
            if (restricted) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '不適切コンテンツ自動検知によりプレビュー非表示化済み',
                style: TextStyle(
                  color: palette.warnInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
