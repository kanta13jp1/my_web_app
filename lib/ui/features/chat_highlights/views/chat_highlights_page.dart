import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/chat_highlight_models.dart';
import '../view_models/chat_highlights_view_model.dart';

class ChatHighlightsPage extends StatefulWidget {
  const ChatHighlightsPage({super.key});

  @override
  State<ChatHighlightsPage> createState() => _ChatHighlightsPageState();
}

class _ChatHighlightsPageState extends State<ChatHighlightsPage> {
  static const _wideBreakpoint = 980.0;

  final _sourceTitle = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _window = TextEditingController(text: '30');
  final _minimumComments = TextEditingController(text: '4');
  final _minimumKeywordEvents = TextEditingController(text: '2');
  final _preRoll = TextEditingController(text: '10');
  final _postRoll = TextEditingController(text: '15');
  final _keywords = TextEditingController(text: '笑, 草, すごい, 神, wow, lol');
  final _eventTime = TextEditingController();
  final _eventAuthor = TextEditingController();
  final _eventMessage = TextEditingController();
  var _didHydrateControllers = false;

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _sourceTitle,
      _sourceUrl,
      _window,
      _minimumComments,
      _minimumKeywordEvents,
      _preRoll,
      _postRoll,
      _keywords,
      _eventTime,
      _eventAuthor,
      _eventMessage,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ChatHighlightsViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('チャットハイライト')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.loadStatus == ChatHighlightsLoadStatus.initial ||
                viewModel.loadStatus == ChatHighlightsLoadStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.loadStatus == ChatHighlightsLoadStatus.failure) {
              return _LoadFailure(
                message: viewModel.errorMessage,
                onRetry: viewModel.load,
              );
            }
            _hydrateControllers(viewModel.snapshot);
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                final setup = _buildSetup(context, viewModel);
                final results = _buildResults(context, viewModel);
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 16,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildHero(context),
                          if (viewModel.errorMessage != null ||
                              viewModel.noticeMessage != null) ...<Widget>[
                            const SizedBox(height: 16),
                            _StatusBanner(
                              message: viewModel.errorMessage ??
                                  viewModel.noticeMessage!,
                              error: viewModel.errorMessage != null,
                            ),
                          ],
                          const SizedBox(height: 20),
                          wide
                              ? Row(
                                  key: const Key('chat-highlights-wide'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    SizedBox(width: 430, child: setup),
                                    const SizedBox(width: 24),
                                    Expanded(child: results),
                                  ],
                                )
                              : Column(
                                  key: const Key('chat-highlights-narrow'),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    setup,
                                    const SizedBox(height: 20),
                                    results,
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[colors.primaryContainer, colors.tertiaryContainer],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'チャットの熱量を、編集できる時間帯へ。',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'コメント頻度とキーワード反応を端末内で集計し、候補区間と根拠を自動表示します。'
            '動画そのものではなく、安全に確認できる編集用JSON指示書を出力します。',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onPrimaryContainer,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetup(BuildContext context, ChatHighlightsViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionCard(
          title: '1. 配信情報',
          subtitle: '元動画のURLは指示書に記録され、外部へ送信されません。',
          child: Column(
            children: <Widget>[
              TextField(
                key: const Key('chat-highlight-source-title'),
                controller: _sourceTitle,
                decoration: const InputDecoration(
                  labelText: '配信タイトル',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('chat-highlight-source-url'),
                controller: _sourceUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '元動画URL',
                  hintText: 'https://example.com/stream.mp4',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('chat-highlight-save-source'),
                  onPressed: () => unawaited(
                    viewModel.updateSource(
                      title: _sourceTitle.text,
                      url: _sourceUrl.text,
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('配信情報を保存'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '2. 自動判定条件',
          subtitle: '集計窓内で、コメント数またはキーワード反応数が閾値以上になると候補化します。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 12,
                children: <Widget>[
                  _NumberField(
                    key: const Key('chat-highlight-window'),
                    controller: _window,
                    label: '集計窓（秒）',
                  ),
                  _NumberField(
                    key: const Key('chat-highlight-min-comments'),
                    controller: _minimumComments,
                    label: 'コメント閾値',
                  ),
                  _NumberField(
                    key: const Key('chat-highlight-min-keywords'),
                    controller: _minimumKeywordEvents,
                    label: '反応閾値',
                  ),
                  _NumberField(
                    key: const Key('chat-highlight-pre-roll'),
                    controller: _preRoll,
                    label: '前余白（秒）',
                  ),
                  _NumberField(
                    key: const Key('chat-highlight-post-roll'),
                    controller: _postRoll,
                    label: '後余白（秒）',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('chat-highlight-keywords'),
                controller: _keywords,
                decoration: const InputDecoration(
                  labelText: '反応キーワード（カンマ区切り）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const Key('chat-highlight-apply-settings'),
                onPressed: () => _applySettings(viewModel),
                icon: const Icon(Icons.auto_graph_outlined),
                label: const Text('条件を保存して再計算'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '3. チャットを追加',
          subtitle: '時刻順が前後しても、自動で並べ直して端末内に保存します（最大500件）。',
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: TextField(
                      key: const Key('chat-highlight-event-time'),
                      controller: _eventTime,
                      decoration: const InputDecoration(
                        labelText: '時刻',
                        hintText: '1:23',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const Key('chat-highlight-event-author'),
                      controller: _eventAuthor,
                      decoration: const InputDecoration(
                        labelText: '投稿者（任意）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('chat-highlight-event-message'),
                controller: _eventMessage,
                maxLength: 280,
                onSubmitted: (_) => _addEvent(viewModel),
                decoration: const InputDecoration(
                  labelText: 'コメント',
                  border: OutlineInputBorder(),
                ),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('chat-highlight-demo'),
                      onPressed: () => unawaited(viewModel.addDemoEvents()),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('デモ4件'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('chat-highlight-add-event'),
                      onPressed: () => _addEvent(viewModel),
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('追加'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults(
    BuildContext context,
    ChatHighlightsViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionCard(
          title: 'ハイライト候補 ${viewModel.candidates.length}件',
          subtitle: viewModel.candidates.isEmpty
              ? '閾値を超える区間はまだありません。チャットを追加してください。'
              : '候補は時系列順です。ピーク値と検出理由を確認してから編集へ渡せます。',
          trailing: FilledButton.icon(
            key: const Key('chat-highlight-export'),
            onPressed: viewModel.candidates.isEmpty
                ? null
                : () => unawaited(viewModel.exportManifest()),
            icon: const Icon(Icons.download_outlined),
            label: const Text('JSON指示書'),
          ),
          child: viewModel.candidates.isEmpty
              ? const _EmptyState(
                  icon: Icons.auto_awesome_outlined,
                  message: 'コメントの盛り上がりを検出すると、ここに候補区間が表示されます。',
                )
              : Column(
                  children: <Widget>[
                    for (var index = 0;
                        index < viewModel.candidates.length;
                        index++)
                      _CandidateTile(
                        index: index,
                        candidate: viewModel.candidates[index],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: '保存済みチャット ${viewModel.snapshot.events.length}件',
          subtitle: '同じIDの重複を除外し、配信開始からの時刻で集計します。',
          trailing: TextButton.icon(
            onPressed: viewModel.snapshot.events.isEmpty
                ? null
                : () => _confirmClear(context, viewModel),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('全消去'),
          ),
          child: viewModel.snapshot.events.isEmpty
              ? const _EmptyState(
                  icon: Icons.forum_outlined,
                  message: 'チャットはまだ保存されていません。',
                )
              : Column(
                  children: <Widget>[
                    for (final event in viewModel.snapshot.events)
                      ListTile(
                        dense: true,
                        leading: SizedBox(
                          width: 52,
                          child: Text(
                            _formatDuration(event.offset),
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(event.message),
                        subtitle: Text(event.author),
                        trailing: IconButton(
                          tooltip: 'このコメントを削除',
                          onPressed: () =>
                              unawaited(viewModel.removeEvent(event.id)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  void _hydrateControllers(ChatHighlightSnapshot snapshot) {
    if (_didHydrateControllers) return;
    _didHydrateControllers = true;
    _sourceTitle.text = snapshot.sourceTitle;
    _sourceUrl.text = snapshot.sourceVideoUrl;
    _window.text = '${snapshot.settings.windowSeconds}';
    _minimumComments.text = '${snapshot.settings.minimumComments}';
    _minimumKeywordEvents.text = '${snapshot.settings.minimumKeywordEvents}';
    _preRoll.text = '${snapshot.settings.preRollSeconds}';
    _postRoll.text = '${snapshot.settings.postRollSeconds}';
    _keywords.text = snapshot.settings.keywords.join(', ');
  }

  void _applySettings(ChatHighlightsViewModel viewModel) {
    unawaited(
      viewModel.updateSettings(
        ChatHighlightSettings(
          windowSeconds: int.tryParse(_window.text) ?? 0,
          minimumComments: int.tryParse(_minimumComments.text) ?? 0,
          minimumKeywordEvents: int.tryParse(_minimumKeywordEvents.text) ?? 0,
          preRollSeconds: int.tryParse(_preRoll.text) ?? -1,
          postRollSeconds: int.tryParse(_postRoll.text) ?? -1,
          keywords: _keywords.text.split(','),
        ),
      ),
    );
  }

  void _addEvent(ChatHighlightsViewModel viewModel) {
    final offset = _parseOffset(_eventTime.text);
    if (offset == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('時刻は「1:23」または秒数で入力してください。')));
      return;
    }
    unawaited(
      viewModel
          .addEvent(
        offset: offset,
        author: _eventAuthor.text,
        message: _eventMessage.text,
      )
          .then((added) {
        if (!added || !mounted) return;
        _eventTime.clear();
        _eventMessage.clear();
      }),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    ChatHighlightsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チャット履歴を全消去しますか？'),
        content: const Text('配信情報と判定条件は残ります。この操作は取り消せません。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('全消去'),
          ),
        ],
      ),
    );
    if (confirmed == true) await viewModel.clearEvents();
  }

  Duration? _parseOffset(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length == 1) {
      final seconds = int.tryParse(parts.single);
      return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
    }
    if (parts.length == 2 || parts.length == 3) {
      final values = parts.map(int.tryParse).toList();
      if (values.any((value) => value == null || value < 0)) return null;
      final hours = parts.length == 3 ? values[0]! : 0;
      final minutes = parts.length == 3 ? values[1]! : values[0]!;
      final seconds = parts.length == 3 ? values[2]! : values[1]!;
      if ((minutes >= 60 && parts.length == 3) || seconds >= 60) return null;
      return Duration(hours: hours, minutes: minutes, seconds: seconds);
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final action = trailing;
                if (action == null) return heading;
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      heading,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: heading),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.index, required this.candidate});

  final int index;
  final ChatHighlightCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = <String>[
      if (candidate.triggers.contains(ChatHighlightTrigger.commentBurst))
        'コメント急増',
      if (candidate.triggers.contains(ChatHighlightTrigger.keywordBurst))
        'キーワード反応',
    ].join(' + ');
    return Semantics(
      label: 'ハイライト候補${index + 1}、$reason',
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_formatDuration(candidate.start)} – '
                    '${_formatDuration(candidate.end)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Chip(label: Text('熱量 ${candidate.score.toStringAsFixed(1)}x')),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$reason ・ ピーク${candidate.peakCommentCount}件'
              ' ・ キーワード反応${candidate.peakKeywordEventCount}件',
            ),
            if (candidate.matchedKeywords.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('一致: ${candidate.matchedKeywords.join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.error});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        error ? colors.errorContainer : colors.secondaryContainer;
    final foreground =
        error ? colors.onErrorContainer : colors.onSecondaryContainer;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 42, color: colors.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message ?? '読み込みに失敗しました。'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
