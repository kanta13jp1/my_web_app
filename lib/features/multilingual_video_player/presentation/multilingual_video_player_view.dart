import 'package:flutter/material.dart';

import '../application/multilingual_video_player_controller.dart';
import '../domain/multilingual_video_player_models.dart';

/// 多言語リップシンク動画プレイヤーの表示専用 View (#2660).
class MultilingualVideoPlayerView extends StatelessWidget {
  const MultilingualVideoPlayerView({
    super.key,
    required this.controller,
    required this.sourceVideoIdController,
    required this.sourceVideoUrlController,
    required this.durationController,
    required this.selectedTargetLanguage,
    required this.onTargetLanguageChanged,
    required this.onQueueSubmitted,
    required this.onRefresh,
  });

  final MultilingualVideoPlayerController controller;
  final TextEditingController sourceVideoIdController;
  final TextEditingController sourceVideoUrlController;
  final TextEditingController durationController;
  final String selectedTargetLanguage;
  final ValueChanged<String> onTargetLanguageChanged;
  final VoidCallback onQueueSubmitted;
  final VoidCallback onRefresh;

  String _reasonLabel(final MultilingualMatchReason reason) {
    switch (reason) {
      case MultilingualMatchReason.userPreference:
        return 'ユーザー選択言語を優先';
      case MultilingualMatchReason.exactLocale:
        return '端末ロケール完全一致';
      case MultilingualMatchReason.baseLanguage:
        return '端末言語コード一致';
      case MultilingualMatchReason.fallbackLanguage:
        return '既定フォールバック言語';
      case MultilingualMatchReason.firstAvailable:
        return '利用可能トラック先頭';
      case MultilingualMatchReason.none:
        return '翻訳トラック未登録';
    }
  }

  String _statusLabel(final VideoTranslationStatus status) {
    switch (status) {
      case VideoTranslationStatus.queued:
        return '待機中';
      case VideoTranslationStatus.validating:
        return '検証中';
      case VideoTranslationStatus.processing:
        return '変換中';
      case VideoTranslationStatus.done:
        return '再生可能';
      case VideoTranslationStatus.rejected:
        return '拒否';
      case VideoTranslationStatus.error:
        return 'エラー';
      case VideoTranslationStatus.dryRun:
        return 'Dry-Run';
    }
  }

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color primaryInk =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final Color secondaryInk =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    final Color borderInk =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final Color badgeBg =
        isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
    final Color badgeInk =
        isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A);
    final Color errorBg =
        isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    final Color errorInk =
        isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);

    final ResolvedMultilingualPlayback resolved = controller.resolvedPlayback;
    final MultilingualVideoSummary summary = controller.summary;
    final List<VideoTranslationTrack> visibleTracks = controller.filteredTracks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '多言語リップシンク動画 (D-ID Video Translate)',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('multilingual-video-refresh'),
                onPressed: controller.isLoading ? null : onRefresh,
                tooltip: '翻訳一覧を再読み込み',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '端末 Locale (${normalizeLocaleTag(controller.deviceLocale)}) に応じて最適な翻訳トラックを自動選択します。',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
          ),
          const SizedBox(height: 12),
          if (controller.errorMessage != null) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('multilingual-video-error-banner'),
              decoration: BoxDecoration(
                color: errorBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: errorInk.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  controller.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: errorInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetricCard(
                title: '翻訳総数',
                value: '${summary.totalJobs} 件',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _MetricCard(
                title: '再生可能 / 処理中',
                value: '${summary.doneJobs} / ${summary.activeJobs}',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _MetricCard(
                title: '対応言語数',
                value: '${summary.distinctLanguages} 言語',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
              _MetricCard(
                title: '累計概算 USD',
                value:
                    'USD ${summary.totalEstimatedCostUsd.toStringAsFixed(3)}',
                cardBg: cardBg,
                borderInk: borderInk,
                primaryInk: primaryInk,
                secondaryInk: secondaryInk,
              ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            key: const ValueKey<String>('multilingual-video-resolved-card'),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.45)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            resolved.track?.aiProvenanceDisclosure ??
                                'AI 生成・リップシンク翻訳動画',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: badgeInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '選択言語: ${resolved.resolvedLanguageCode.toUpperCase()} (${_reasonLabel(resolved.reason)})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (resolved.track != null) ...<Widget>[
                    Text(
                      '動画 ID: ${resolved.track!.sourceVideoId} / ${resolved.track!.didLanguageName} (${_statusLabel(resolved.track!.status)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolved.track!.resultUrl != null
                          ? '再生 URL: ${resolved.track!.resultUrl}'
                          : '再生 URL: 生成完了待ち (ジョブ: ${resolved.track!.providerJobId ?? 'pending'})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryInk,
                      ),
                    ),
                    if (resolved.track!.subtitlesUrl != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '字幕 URL: ${resolved.track!.subtitlesUrl}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      '該当動画の翻訳トラックがまだありません。下部のフォームから登録してください。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryInk,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '言語トラック切替',
            style: theme.textTheme.titleSmall?.copyWith(
              color: primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ChoiceChip(
                key: const ValueKey<String>('locale-choice-auto'),
                label: const Text('自動 (Locale)'),
                selected: controller.preferredLanguageCode == null,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onSelected: (final bool _) =>
                    controller.updatePreferredLanguageCode(null),
              ),
              for (final String code in <String>['ja', 'en', 'es', 'fr'])
                ChoiceChip(
                  key: ValueKey<String>('locale-choice-$code'),
                  label: Text(
                    '${code.toUpperCase()} (${didSupportedLanguageMap[code]})',
                  ),
                  selected: controller.preferredLanguageCode == code,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  onSelected: (final bool _) =>
                      controller.updatePreferredLanguageCode(code),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderInk),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '新規翻訳ジョブ登録 (上限ガード付き)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('did-source-video-id-input'),
                    controller: sourceVideoIdController,
                    decoration: const InputDecoration(
                      labelText: '動画 ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('did-source-video-url-input'),
                    controller: sourceVideoUrlController,
                    decoration: const InputDecoration(
                      labelText: '公開 HTTPS 動画 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: const ValueKey<String>('did-target-language-select'),
                    initialValue: selectedTargetLanguage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '翻訳先言語',
                      border: OutlineInputBorder(),
                    ),
                    items: didSupportedLanguageMap.entries
                        .map(
                          (final MapEntry<String, String> entry) =>
                              DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              '${entry.key} (${entry.value})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (final String? val) {
                      if (val != null) {
                        onTargetLanguageChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('did-duration-seconds-input'),
                    controller: durationController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '動画尺 (秒・上限 120s)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('did-queue-submit-button'),
                      onPressed:
                          controller.isSubmitting ? null : onQueueSubmitted,
                      icon: const Icon(Icons.translate),
                      label: Text(
                        controller.isSubmitting ? '登録中...' : '翻訳ジョブをキュー登録',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '翻訳トラック一覧 (${visibleTracks.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              color: primaryInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (controller.isLoading && visibleTracks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            for (final VideoTranslationTrack track
                in visibleTracks) ...<Widget>[
              DecoratedBox(
                key: ValueKey<String>('did-track-card-${track.id}'),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderInk),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${track.sourceVideoId} · ${track.languageCode.toUpperCase()} (${track.didLanguageName}) · ${_statusLabel(track.status)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '尺: ${track.durationSeconds.toStringAsFixed(1)}s / 上限 ${track.maxDurationCapSeconds}s · 概算 USD ${track.estimatedCostUsd.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryInk,
                        ),
                      ),
                      if (track.errorReason != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          '理由: ${track.errorReason}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: errorInk,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.cardBg,
    required this.borderInk,
    required this.primaryInk,
    required this.secondaryInk,
  });

  final String title;
  final String value;
  final Color cardBg;
  final Color borderInk;
  final Color primaryInk;
  final Color secondaryInk;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderInk),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(color: secondaryInk),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: primaryInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
