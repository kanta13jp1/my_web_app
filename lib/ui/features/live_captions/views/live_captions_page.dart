import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/design_tokens.dart';
import '../domain/live_caption_models.dart';
import '../view_models/live_captions_view_model.dart';

class LiveCaptionsPage extends StatelessWidget {
  const LiveCaptionsPage({super.key});

  static const double _wideBreakpoint = 980;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('ライブ多言語字幕'),
      ),
      body: Consumer<LiveCaptionsViewModel>(
        builder: (context, viewModel, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final content = constraints.maxWidth >= _wideBreakpoint
                  ? Row(
                      key: const Key('live-captions-wide'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _PreviewPanel(viewModel: viewModel),
                        ),
                        const SizedBox(width: DesignTokens.space16),
                        Expanded(
                          flex: 2,
                          child: _SettingsPanel(viewModel: viewModel),
                        ),
                      ],
                    )
                  : Column(
                      key: const Key('live-captions-compact'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _PreviewPanel(viewModel: viewModel),
                        const SizedBox(height: DesignTokens.space16),
                        _SettingsPanel(viewModel: viewModel),
                      ],
                    );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(DesignTokens.space16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1320),
                  child: Center(child: content),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.viewModel});

  final LiveCaptionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final viewerLanguage = liveCaptionLanguageByTag(
      viewModel.viewerLanguageTag,
    );
    final viewerLanguages = <LiveCaptionLanguage>[
      viewModel.sourceLanguage,
      ...kLiveCaptionLanguages.where(
        (language) => viewModel.targetLanguageTags.contains(language.tag),
      ),
    ];
    final latestSegments = viewModel.segments.reversed.take(8).toList();

    return _Panel(
      title: '配信プレビュー',
      trailing: _StatusBadge(viewModel: viewModel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              key: const Key('live-caption-preview'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xFF10152F), Color(0xFF050505)],
                ),
                border: Border.all(color: DesignTokens.divider),
              ),
              child: Stack(
                children: <Widget>[
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.live_tv_outlined,
                          size: 56,
                          color: DesignTokens.indigoLight,
                        ),
                        SizedBox(height: DesignTokens.space8),
                        Text(
                          'ライブ映像プレビュー',
                          style: TextStyle(color: DesignTokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Semantics(
                      liveRegion: true,
                      label:
                          '${viewerLanguage.label}、${viewModel.statusLabel}。現在の字幕: ${viewModel.currentViewerText}',
                      child: Container(
                        key: const Key('live-caption-overlay'),
                        width: double.infinity,
                        margin: const EdgeInsets.all(DesignTokens.space16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space16,
                          vertical: DesignTokens.space12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .76),
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusSmall,
                          ),
                        ),
                        child: Text(
                          viewModel.currentViewerText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: DesignTokens.textPrimary,
                            fontSize: 20,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          Row(
            children: <Widget>[
              const Icon(
                Icons.translate,
                color: DesignTokens.indigoLight,
                size: 20,
              ),
              const SizedBox(width: DesignTokens.space8),
              const Text('視聴言語', style: _secondaryStyle),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: DropdownButton<String>(
                  key: const Key('live-caption-viewer-language'),
                  isExpanded: true,
                  value: viewModel.viewerLanguageTag,
                  dropdownColor: DesignTokens.surface2,
                  style: const TextStyle(color: DesignTokens.textPrimary),
                  items: viewerLanguages
                      .map(
                        (language) => DropdownMenuItem<String>(
                          value: language.tag,
                          child: Text(language.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) viewModel.setViewerLanguage(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  '字幕タイムライン',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                key: const Key('live-caption-clear'),
                onPressed:
                    viewModel.segments.isEmpty ? null : viewModel.clearSegments,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('クリア'),
              ),
            ],
          ),
          if (latestSegments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: DesignTokens.space20),
              child: Text(
                '配信を開始すると、確定した字幕が時系列で表示されます。',
                textAlign: TextAlign.center,
                style: _secondaryStyle,
              ),
            )
          else
            ...latestSegments.map(
              (segment) => _TimelineItem(
                segment: segment,
                viewerLanguageTag: viewModel.viewerLanguageTag,
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.viewModel});

  final LiveCaptionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '配信者・管理設定',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('音声のソース言語', style: _secondaryStyle),
          const SizedBox(height: DesignTokens.space8),
          DropdownButtonFormField<String>(
            key: const Key('live-caption-source-language'),
            initialValue: viewModel.sourceLanguageTag,
            dropdownColor: DesignTokens.surface2,
            style: const TextStyle(color: DesignTokens.textPrimary),
            decoration: _inputDecoration(),
            items: kLiveCaptionLanguages
                .map(
                  (language) => DropdownMenuItem<String>(
                    value: language.tag,
                    child: Text(language.label),
                  ),
                )
                .toList(growable: false),
            onChanged: viewModel.isListening
                ? null
                : (value) {
                    if (value != null) viewModel.setSourceLanguage(value);
                  },
          ),
          const SizedBox(height: DesignTokens.space20),
          const Text('視聴者が選べる翻訳字幕', style: _secondaryStyle),
          const SizedBox(height: DesignTokens.space8),
          Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space8,
            children: kLiveCaptionLanguages
                .where(
                  (language) => language.tag != viewModel.sourceLanguageTag,
                )
                .map(
                  (language) => FilterChip(
                    key: Key('live-caption-target-${language.tag}'),
                    label: Text(language.label),
                    selected: viewModel.targetLanguageTags.contains(
                      language.tag,
                    ),
                    onSelected: (_) =>
                        viewModel.toggleTargetLanguage(language.tag),
                    selectedColor: DesignTokens.indigo,
                    backgroundColor: DesignTokens.surface3,
                    checkmarkColor: DesignTokens.textPrimary,
                    labelStyle: const TextStyle(
                      color: DesignTokens.textPrimary,
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: DesignTokens.space20),
          if (!viewModel.isSupported)
            const _MessageBox(
              key: Key('live-caption-unsupported'),
              color: DesignTokens.amber,
              message: '音声認識はChrome / EdgeのWeb版で利用できます。対応ブラウザーでマイクを許可してください。',
            ),
          if (viewModel.errorMessage case final message?)
            Semantics(
              liveRegion: true,
              child: _MessageBox(
                key: const Key('live-caption-error'),
                color: DesignTokens.red,
                message: message,
              ),
            ),
          if (viewModel.isListening)
            OutlinedButton.icon(
              key: const Key('live-caption-stop'),
              onPressed: () => unawaited(viewModel.stop()),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('字幕配信を停止'),
            )
          else
            FilledButton.icon(
              key: const Key('live-caption-start'),
              onPressed: viewModel.isSupported
                  ? () => unawaited(viewModel.start())
                  : null,
              icon: const Icon(Icons.mic),
              label: const Text('マイクで字幕配信を開始'),
            ),
          const SizedBox(height: DesignTokens.space12),
          const Text(
            '確定した音声だけを翻訳し、視聴者が選んだ言語へ順次反映します。APIキーはブラウザーへ公開せず、既存の認証済みAI Edge Functionを経由します。',
            style: _secondaryStyle,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.segment, required this.viewerLanguageTag});

  final LiveCaptionSegment segment;
  final String viewerLanguageTag;

  @override
  Widget build(BuildContext context) {
    final translated = segment.hasTranslation(viewerLanguageTag);
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            segment.sourceText,
            style: const TextStyle(color: DesignTokens.textSecondary),
          ),
          const SizedBox(height: DesignTokens.space4),
          Text(
            segment.textFor(viewerLanguageTag),
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (!translated) const Text('翻訳中…', style: _secondaryStyle),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.viewModel});

  final LiveCaptionsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final latency = viewModel.lastTranslationLatency;
    final isActive = viewModel.isListening;
    return Container(
      key: const Key('live-caption-status'),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space12,
        vertical: DesignTokens.space8,
      ),
      decoration: BoxDecoration(
        color: (isActive ? DesignTokens.green : DesignTokens.surface3)
            .withValues(alpha: .22),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
      ),
      child: Text(
        latency == null
            ? viewModel.statusLabel
            : '${viewModel.statusLabel} · ${latency.inMilliseconds}ms',
        style: TextStyle(
          color: isActive ? DesignTokens.green : DesignTokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          child,
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({super.key, required this.color, required this.message});

  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space12),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Text(message, style: TextStyle(color: color, height: 1.45)),
    );
  }
}

const TextStyle _secondaryStyle = TextStyle(
  color: DesignTokens.textSecondary,
  fontSize: 13,
  height: 1.5,
);

InputDecoration _inputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: DesignTokens.surface3,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      borderSide: const BorderSide(color: DesignTokens.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      borderSide: const BorderSide(color: DesignTokens.indigoLight, width: 2),
    ),
  );
}
