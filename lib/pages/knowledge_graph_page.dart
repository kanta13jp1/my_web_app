import 'package:flutter/material.dart';

import '../models/knowledge_graph_rag.dart';
import '../services/knowledge_graph_rag_service.dart';
import '../view_models/knowledge_graph_rag_view_model.dart';

class KnowledgeGraphPage extends StatefulWidget {
  const KnowledgeGraphPage({super.key, this.gateway, this.viewModel});

  final KnowledgeGraphRagGateway? gateway;
  final KnowledgeGraphRagViewModel? viewModel;

  @override
  State<KnowledgeGraphPage> createState() => _KnowledgeGraphPageState();
}

class _KnowledgeGraphPageState extends State<KnowledgeGraphPage> {
  final _queryController = TextEditingController();
  late final KnowledgeGraphRagViewModel _viewModel;
  late final bool _ownsViewModel;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        KnowledgeGraphRagViewModel(
          gateway: widget.gateway ?? const KnowledgeGraphRagService(),
        );
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _query() async {
    await _viewModel.search(_queryController.text);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    if (_ownsViewModel) _viewModel.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI回答と情報源'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildQueryControls(),
            if (_viewModel.errorMessage != null) _buildErrorBanner(),
            Expanded(child: _buildResult()),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryControls() {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '社内ナレッジだけを根拠に回答し、参照したファイルと範囲を表示します。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source
                    in KnowledgeGraphRagViewModel.availableSources)
                  FilterChip(
                    key: Key('knowledge-source-$source'),
                    label: Text(source),
                    selected: _viewModel.selectedSources.contains(source),
                    onSelected: _viewModel.isLoading
                        ? null
                        : (selected) =>
                            _viewModel.setSourceSelected(source, selected),
                  ),
                FilterChip(
                  key: const Key('knowledge-use-llm'),
                  avatar: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('AI回答'),
                  selected: _viewModel.useLlm,
                  onSelected:
                      _viewModel.isLoading ? null : _viewModel.setUseLlm,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final queryField = TextField(
                  key: const Key('knowledge-query-field'),
                  controller: _queryController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '質問',
                    hintText: '例: 今四半期の優先事項と、その根拠を教えて',
                    prefixIcon: Icon(Icons.hub_outlined),
                  ),
                  onSubmitted: (_) => _query(),
                );
                final searchButton = FilledButton.icon(
                  key: const Key('knowledge-query-button'),
                  onPressed: _viewModel.isLoading ? null : _query,
                  icon: _viewModel.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: const Text('根拠付きで回答'),
                );

                if (constraints.maxWidth < 720) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      queryField,
                      const SizedBox(height: 10),
                      SizedBox(height: 48, child: searchButton),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: queryField),
                    const SizedBox(width: 12),
                    SizedBox(height: 56, child: searchButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return MaterialBanner(
      content: Text(_viewModel.errorMessage!),
      leading: Icon(
        _viewModel.requiresLogin ? Icons.lock_outline : Icons.error_outline,
      ),
      actions: const <Widget>[SizedBox.shrink()],
    );
  }

  Widget _buildResult() {
    final answer = _viewModel.answer;
    if (_viewModel.isLoading && answer == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('情報源を照合して回答を生成しています…'),
          ],
        ),
      );
    }
    if (answer == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.find_in_page_outlined, size: 56),
              SizedBox(height: 12),
              Text('質問すると、回答内の引用から元文書を確認できます。'),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final answerPanel = _AnswerPanel(
          answer: answer,
          onCitationPressed: _showCitation,
        );
        if (constraints.maxWidth >= 960) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: answerPanel),
                const SizedBox(width: 16),
                SizedBox(
                  width: 380,
                  child: _SourcesPanel(
                    citations: answer.citations,
                    onCitationPressed: _showCitation,
                    internalScroll: true,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          key: const Key('knowledge-mobile-result-list'),
          padding: const EdgeInsets.all(16),
          children: [
            answerPanel,
            const SizedBox(height: 16),
            _SourcesPanel(
              citations: answer.citations,
              onCitationPressed: _showCitation,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCitation(KnowledgeGraphRagCitation citation) {
    return showDialog<void>(
      context: context,
      builder: (context) => _CitationDocumentDialog(citation: citation),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.answer, required this.onCitationPressed});

  final KnowledgeGraphRagAnswer answer;
  final ValueChanged<KnowledgeGraphRagCitation> onCitationPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusPresentation(answer.status);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '根拠付きAI回答',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(status.label),
                    backgroundColor: status.color.withAlpha(28),
                    labelStyle: TextStyle(
                      color: status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (status.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  status.message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.color,
                  ),
                ),
              ],
              const Divider(height: 28),
              _CitationAnswerText(
                answer: answer,
                onCitationPressed: onCitationPressed,
              ),
              if (answer.traceId.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'trace ${answer.traceId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CitationAnswerText extends StatelessWidget {
  const _CitationAnswerText({
    required this.answer,
    required this.onCitationPressed,
  });

  final KnowledgeGraphRagAnswer answer;
  final ValueChanged<KnowledgeGraphRagCitation> onCitationPressed;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55) ??
            const TextStyle(height: 1.55);
    return SelectionArea(
      child: Text.rich(
        key: const Key('knowledge-answer-text'),
        TextSpan(
          style: baseStyle,
          children: [
            for (final segment in parseKnowledgeGraphAnswer(answer.answer))
              if (!segment.isCitation ||
                  answer.citationById(segment.citationId!) == null)
                TextSpan(text: segment.text)
              else
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ActionChip(
                      key: Key('knowledge-citation-link-${segment.citationId}'),
                      avatar: const Icon(Icons.find_in_page_outlined, size: 16),
                      label: Text(
                        '${segment.text} '
                        '${answer.citationById(segment.citationId!)!.fileName} · '
                        '${answer.citationById(segment.citationId!)!.position.label}',
                      ),
                      onPressed: () => onCitationPressed(
                        answer.citationById(segment.citationId!)!,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SourcesPanel extends StatelessWidget {
  const _SourcesPanel({
    required this.citations,
    required this.onCitationPressed,
    this.internalScroll = false,
  });

  final List<KnowledgeGraphRagCitation> citations;
  final ValueChanged<KnowledgeGraphRagCitation> onCitationPressed;
  final bool internalScroll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '参照元 ${citations.length}件',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (citations.isEmpty)
              const Text('参照元はありません。')
            else if (internalScroll)
              Expanded(child: _buildCitationList(theme))
            else
              _buildCitationList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCitationList(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: !internalScroll,
      physics: internalScroll ? null : const NeverScrollableScrollPhysics(),
      itemCount: citations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final citation = citations[index];
        return Card(
          key: Key('knowledge-citation-card-${citation.id}'),
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            onTap: () => onCitationPressed(citation),
            leading: CircleAvatar(child: Text(citation.id)),
            title: Text(
              citation.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(citation.position.label),
                const SizedBox(height: 4),
                Text(
                  citation.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: const Icon(Icons.open_in_new),
          ),
        );
      },
    );
  }
}

class _CitationDocumentDialog extends StatelessWidget {
  const _CitationDocumentDialog({required this.citation});

  final KnowledgeGraphRagCitation citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = citation.previewText.substring(0, citation.highlightStart);
    final highlighted = citation.previewText.substring(
      citation.highlightStart,
      citation.highlightEnd,
    );
    final after = citation.previewText.substring(citation.highlightEnd);

    return Dialog(
      key: Key('knowledge-citation-dialog-${citation.id}'),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          citation.fileName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          citation.position.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Chip(label: Text(citation.sourceType)),
                  Chip(
                    label: Text(
                      'confidence ${(citation.confidence * 100).round()}%',
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                '参照箇所をハイライト',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectionArea(
                      child: Text.rich(
                        key: Key('knowledge-citation-preview-${citation.id}'),
                        TextSpan(
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurface,
                          ),
                          children: [
                            if (citation.previewTruncatedBefore)
                              const TextSpan(text: '…\n'),
                            TextSpan(text: before),
                            TextSpan(
                              text: highlighted,
                              style: TextStyle(
                                backgroundColor:
                                    theme.colorScheme.tertiary.withAlpha(70),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: after),
                            if (citation.previewTruncatedAfter)
                              const TextSpan(text: '\n…'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                citation.sourceUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.color, [this.message]);

  final String label;
  final Color color;
  final String? message;
}

_StatusPresentation _statusPresentation(String status) {
  switch (status) {
    case 'ok':
      return const _StatusPresentation('verified', Color(0xFF0F766E));
    case 'stale_index':
      return const _StatusPresentation(
        'stale',
        Color(0xFFB45309),
        '一部の情報源が24時間以上更新されていません。日付を確認してください。',
      );
    case 'llm_failure':
      return const _StatusPresentation(
        'extractive',
        Color(0xFF9F1239),
        'AI生成に失敗したため、検索結果の抜粋を表示しています。',
      );
    case 'citation_fallback':
      return const _StatusPresentation(
        'extractive',
        Color(0xFF9F1239),
        'AI回答に有効な引用がなかったため、根拠付きの抜粋を表示しています。',
      );
    case 'no_results':
      return const _StatusPresentation(
        'no results',
        Color(0xFF52525B),
        '一致する情報源が見つかりませんでした。',
      );
    default:
      return const _StatusPresentation('unknown', Color(0xFF334155));
  }
}
