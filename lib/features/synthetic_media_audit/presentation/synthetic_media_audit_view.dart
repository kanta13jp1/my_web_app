import 'package:flutter/material.dart';

import '../application/synthetic_media_audit_controller.dart';
import '../domain/synthetic_media_audit_models.dart';

/// 合成メディア動画の倫理監査・モデレーション表示専用 View (#2661).
class SyntheticMediaAuditView extends StatelessWidget {
  const SyntheticMediaAuditView({
    super.key,
    required this.state,
    required this.titleController,
    required this.videoUrlController,
    required this.trackTraceIdController,
    required this.reviewNoteController,
    required this.sourceProvider,
    required this.copyrightConsent,
    required this.likenessConsent,
    required this.commercialWatermarkPresent,
    required this.celebrityLikenessCleared,
    required this.trackAndTraceProvider,
    required this.onRefresh,
    required this.onSelectFilter,
    required this.onSourceProviderChanged,
    required this.onCopyrightConsentChanged,
    required this.onLikenessConsentChanged,
    required this.onCommercialWatermarkChanged,
    required this.onCelebrityClearedChanged,
    required this.onTrackAndTraceProviderChanged,
    required this.onSubmitVideo,
    required this.onApproveVideo,
    required this.onRejectVideo,
  });

  final SyntheticMediaAuditState state;
  final TextEditingController titleController;
  final TextEditingController videoUrlController;
  final TextEditingController trackTraceIdController;
  final TextEditingController reviewNoteController;
  final String sourceProvider;
  final ConsentVerificationStatus copyrightConsent;
  final ConsentVerificationStatus likenessConsent;
  final bool commercialWatermarkPresent;
  final bool celebrityLikenessCleared;
  final TrackAndTraceProvider trackAndTraceProvider;
  final VoidCallback onRefresh;
  final ValueChanged<SyntheticMediaModerationStatus> onSelectFilter;
  final ValueChanged<String> onSourceProviderChanged;
  final ValueChanged<ConsentVerificationStatus> onCopyrightConsentChanged;
  final ValueChanged<ConsentVerificationStatus> onLikenessConsentChanged;
  final ValueChanged<bool> onCommercialWatermarkChanged;
  final ValueChanged<bool> onCelebrityClearedChanged;
  final ValueChanged<TrackAndTraceProvider> onTrackAndTraceProviderChanged;
  final VoidCallback onSubmitVideo;
  final ValueChanged<SyntheticMediaVideo> onApproveVideo;
  final ValueChanged<SyntheticMediaVideo> onRejectVideo;

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
    final Color okBg =
        isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
    final Color okInk =
        isDark ? const Color(0xFFD1FAE5) : const Color(0xFF065F46);
    final Color warnBg =
        isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
    final Color warnInk =
        isDark ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);
    final Color errBg =
        isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
    final Color errInk =
        isDark ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);

    final List<SyntheticMediaVideo> approvedFeed = state.approvedFeedVideos;
    final List<SyntheticMediaVideo> queueVideos =
        state.filteredModerationVideos;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '合成メディア倫理監査 & 動画承認キュー',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('synthetic-media-refresh-button'),
                onPressed: state.isLoading ? null : onRefresh,
                tooltip: '監査キューを再読み込み',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'D-ID Ethics Pledge（著作権・肖像権同意、商用透かし、著名人除外、Track-and-Trace 来歴）を満たした動画のみ公開します。',
            style: theme.textTheme.bodyMedium?.copyWith(color: secondaryInk),
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('synthetic-media-error-banner'),
              decoration: BoxDecoration(
                color: errBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: errInk.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: errInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (state.isAdmin) ...<Widget>[
            DecoratedBox(
              key: const ValueKey<String>('synthetic-media-admin-section'),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.45)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '管理者モデレーションキュー',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: primaryInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final SyntheticMediaModerationStatus status
                            in SyntheticMediaModerationStatus.values)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'audit-filter-${status.wireValue}',
                            ),
                            label: Text(
                              '${status.label} (${state.countByStatus(status)})',
                            ),
                            selected: state.selectedFilter == status,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            onSelected: (final bool _) =>
                                onSelectFilter(status),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey<String>('audit-review-note-input'),
                      controller: reviewNoteController,
                      decoration: const InputDecoration(
                        labelText: '審査ノート（却下時は必須）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (queueVideos.isEmpty)
                      Text(
                        '選択中のステータスに該当する動画はありません。',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryInk,
                        ),
                      )
                    else
                      for (final SyntheticMediaVideo video
                          in queueVideos) ...<Widget>[
                        DecoratedBox(
                          key: ValueKey<String>('audit-queue-card-${video.id}'),
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
                                  '${video.title} (${video.sourceProvider})',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: primaryInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: <Widget>[
                                    _StatusPill(
                                      text:
                                          '著作権: ${video.copyrightConsentStatus.label}',
                                      bg: video.copyrightConsentStatus ==
                                              ConsentVerificationStatus.verified
                                          ? okBg
                                          : warnBg,
                                      ink: video.copyrightConsentStatus ==
                                              ConsentVerificationStatus.verified
                                          ? okInk
                                          : warnInk,
                                    ),
                                    _StatusPill(
                                      text:
                                          '肖像権: ${video.likenessConsentStatus.label}',
                                      bg: video.likenessConsentStatus ==
                                              ConsentVerificationStatus.verified
                                          ? okBg
                                          : warnBg,
                                      ink: video.likenessConsentStatus ==
                                              ConsentVerificationStatus.verified
                                          ? okInk
                                          : warnInk,
                                    ),
                                    _StatusPill(
                                      text: video.commercialWatermarkPresent
                                          ? '商用透かし: 確認済み'
                                          : '商用透かし: 未確認',
                                      bg: video.commercialWatermarkPresent
                                          ? okBg
                                          : warnBg,
                                      ink: video.commercialWatermarkPresent
                                          ? okInk
                                          : warnInk,
                                    ),
                                    _StatusPill(
                                      text: video.celebrityLikenessCleared
                                          ? '著名人除外: 確認済み'
                                          : '著名人除外: 未確認',
                                      bg: video.celebrityLikenessCleared
                                          ? okBg
                                          : warnBg,
                                      ink: video.celebrityLikenessCleared
                                          ? okInk
                                          : warnInk,
                                    ),
                                    _StatusPill(
                                      text:
                                          'Track-and-Trace: ${video.trackAndTraceProvider.label}${video.trackAndTraceId != null && video.trackAndTraceId!.isNotEmpty ? ' (${video.trackAndTraceId})' : ''}',
                                      bg: badgeBg,
                                      ink: badgeInk,
                                    ),
                                  ],
                                ),
                                if (video.reviewNote != null &&
                                    video.reviewNote!.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    '審査メモ: ${video.reviewNote}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: secondaryInk,
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
                                        minHeight: 48,
                                      ),
                                      child: FilledButton.icon(
                                        key: ValueKey<String>(
                                          'audit-approve-button-${video.id}',
                                        ),
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => onApproveVideo(video),
                                        icon: const Icon(Icons.verified),
                                        label: const Text('承認して公開'),
                                      ),
                                    ),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                      ),
                                      child: OutlinedButton.icon(
                                        key: ValueKey<String>(
                                          'audit-reject-button-${video.id}',
                                        ),
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => onRejectVideo(video),
                                        icon: const Icon(Icons.block),
                                        label: const Text('却下'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    if (state.auditLogs.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        '監査ログ履歴 (${state.auditLogs.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: primaryInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final SyntheticMediaAuditLogEntry entry
                          in state.auditLogs) ...<Widget>[
                        Text(
                          '${entry.action} · ${entry.previousStatus ?? 'new'} → ${entry.newStatus}${entry.reason != null ? ' (${entry.reason})' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondaryInk,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          DecoratedBox(
            key:
                const ValueKey<String>('synthetic-media-approved-feed-section'),
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
                    '一般公開フィード（承認済み動画のみ: ${approvedFeed.length} 件）',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.isLoading && approvedFeed.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (approvedFeed.isEmpty)
                    Text(
                      '承認済みの合成メディア動画はまだありません。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: secondaryInk,
                      ),
                    )
                  else
                    for (final SyntheticMediaVideo item
                        in approvedFeed) ...<Widget>[
                      DecoratedBox(
                        key: ValueKey<String>('approved-feed-card-${item.id}'),
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  _StatusPill(
                                    text: 'AI 生成・倫理承認済み',
                                    bg: badgeBg,
                                    ink: badgeInk,
                                  ),
                                  Text(
                                    item.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: primaryInk,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '配信 URL: ${item.videoUrl}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondaryInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '来歴検証: ${item.trackAndTraceProvider.label}${item.trackAndTraceId != null && item.trackAndTraceId!.isNotEmpty ? ' · ${item.trackAndTraceId}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondaryInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
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
                    '新規合成メディア動画の審査提出',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: primaryInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('audit-submit-title-input'),
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '動画タイトル',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('audit-submit-url-input'),
                    controller: videoUrlController,
                    decoration: const InputDecoration(
                      labelText: '公開 HTTPS 動画 URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: const ValueKey<String>('audit-submit-provider-select'),
                    initialValue: sourceProvider,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '生成プロバイダ',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: 'd_id',
                        child: Text('D-ID', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem<String>(
                        value: 'notebooklm',
                        child:
                            Text('NotebookLM', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem<String>(
                        value: 'hybrid',
                        child: Text('Hybrid', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem<String>(
                        value: 'custom',
                        child: Text('Custom', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (final String? val) {
                      if (val != null) {
                        onSourceProviderChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ConsentVerificationStatus>(
                    key: const ValueKey<String>('audit-copyright-select'),
                    initialValue: copyrightConsent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '著作権同意ステータス',
                      border: OutlineInputBorder(),
                    ),
                    items: ConsentVerificationStatus.values
                        .map(
                          (final ConsentVerificationStatus s) =>
                              DropdownMenuItem<ConsentVerificationStatus>(
                            value: s,
                            child:
                                Text(s.label, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (final ConsentVerificationStatus? val) {
                      if (val != null) {
                        onCopyrightConsentChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<ConsentVerificationStatus>(
                    key: const ValueKey<String>('audit-likeness-select'),
                    initialValue: likenessConsent,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: '肖像権・音声同意ステータス',
                      border: OutlineInputBorder(),
                    ),
                    items: ConsentVerificationStatus.values
                        .map(
                          (final ConsentVerificationStatus s) =>
                              DropdownMenuItem<ConsentVerificationStatus>(
                            value: s,
                            child:
                                Text(s.label, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (final ConsentVerificationStatus? val) {
                      if (val != null) {
                        onLikenessConsentChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TrackAndTraceProvider>(
                    key: const ValueKey<String>('audit-trace-provider-select'),
                    initialValue: trackAndTraceProvider,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Track-and-Trace プロバイダ',
                      border: OutlineInputBorder(),
                    ),
                    items: TrackAndTraceProvider.values
                        .map(
                          (final TrackAndTraceProvider p) =>
                              DropdownMenuItem<TrackAndTraceProvider>(
                            value: p,
                            child:
                                Text(p.label, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (final TrackAndTraceProvider? val) {
                      if (val != null) {
                        onTrackAndTraceProviderChanged(val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey<String>('audit-trace-id-input'),
                    controller: trackTraceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Track-and-Trace 検証 ID (任意)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey<String>('audit-watermark-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '商用透かし・AI生成表記あり',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    value: commercialWatermarkPresent,
                    onChanged: onCommercialWatermarkChanged,
                  ),
                  SwitchListTile(
                    key: const ValueKey<String>('audit-celebrity-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '著名人なりすまし排除確認済み',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: primaryInk,
                      ),
                    ),
                    value: celebrityLikenessCleared,
                    onChanged: onCelebrityClearedChanged,
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey<String>('audit-submit-button'),
                      onPressed: state.isSubmitting ? null : onSubmitVideo,
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        state.isSubmitting ? '提出中...' : '倫理審査へ提出',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.bg,
    required this.ink,
  });

  final String text;
  final Color bg;
  final Color ink;

  @override
  Widget build(final BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
