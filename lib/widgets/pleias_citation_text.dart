import 'package:flutter/material.dart';

import '../services/local_rag_runtime_service.dart';

class PleiasCitationText extends StatelessWidget {
  final String text;
  final List<LocalRagCitation> citations;
  final bool isDark;

  const PleiasCitationText({
    super.key,
    required this.text,
    required this.citations,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = parsePleiasCitationText(text);
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ) ??
        TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        );

    if (!parsed.hasCitationTokens) {
      return SelectableText(text, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: baseStyle,
            children: parsed.segments
                .expand((segment) => _spansFor(context, segment, baseStyle))
                .toList(),
          ),
        ),
        if (citations.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: citations
                .map((citation) => _sourceChip(context, citation))
                .toList(),
          ),
        ],
      ],
    );
  }

  Iterable<InlineSpan> _spansFor(
    BuildContext context,
    PleiasCitationSegment segment,
    TextStyle baseStyle,
  ) sync* {
    if (!segment.cited) {
      yield TextSpan(text: segment.text);
      return;
    }

    final citation = _resolveCitation(segment.sourceId!);
    if (segment.markerOnly) {
      yield WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _inlineCitationMarker(context, segment, citation),
        ),
      );
      return;
    }

    final tokenPattern = RegExp(r'\s+|[^\s]+');
    for (final match in tokenPattern.allMatches(segment.text)) {
      final part = match.group(0) ?? '';
      if (part.trim().isEmpty) {
        yield TextSpan(text: part);
        continue;
      }
      yield WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Tooltip(
          message: _tooltip(segment.sourceId!, citation),
          waitDuration: const Duration(milliseconds: 250),
          child: GestureDetector(
            onTap: () =>
                _showCitationDialog(context, segment.sourceId!, citation),
            child: Text(
              part,
              style: baseStyle.copyWith(
                backgroundColor:
                    isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
                color: isDark ? Colors.white : const Color(0xFF115E59),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _inlineCitationMarker(
    BuildContext context,
    PleiasCitationSegment segment,
    LocalRagCitation? citation,
  ) {
    return Tooltip(
      message: _tooltip(segment.sourceId!, citation),
      waitDuration: const Duration(milliseconds: 250),
      child: GestureDetector(
        key: ValueKey('pleias-citation-marker-${segment.sourceId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _showCitationDialog(context, segment.sourceId!, citation),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF134E4A) : const Color(0xFFCCFBF1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF2DD4BF) : const Color(0xFF14B8A6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              segment.text,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF115E59),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceChip(BuildContext context, LocalRagCitation citation) {
    final label = citation.title.isEmpty ? citation.sourceId : citation.title;
    return Tooltip(
      message: _tooltip(citation.sourceId, citation),
      waitDuration: const Duration(milliseconds: 250),
      child: ActionChip(
        label: Text(label),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            _showCitationDialog(context, citation.sourceId, citation),
      ),
    );
  }

  LocalRagCitation? _resolveCitation(String sourceId) {
    final normalized = sourceId.trim().toLowerCase();
    for (final citation in citations) {
      if (citation.sourceId.trim().toLowerCase() == normalized) {
        return citation;
      }
    }

    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric > 0 && numeric <= citations.length) {
      return citations[numeric - 1];
    }

    for (final citation in citations) {
      final candidate = citation.sourceId.trim().toLowerCase();
      if (candidate == 'doc-$normalized' ||
          candidate == 'source-$normalized' ||
          candidate.endsWith('-$normalized')) {
        return citation;
      }
    }
    return null;
  }

  String _tooltip(String sourceId, LocalRagCitation? citation) {
    if (citation == null) return 'source:$sourceId';
    final title = citation.title.isEmpty ? citation.sourceId : citation.title;
    final parts = <String>[
      title,
      if (citation.snippet.isNotEmpty) citation.snippet,
      if (citation.path.isNotEmpty) citation.path,
      if (citation.score > 0) 'score ${citation.score.toStringAsFixed(2)}',
    ];
    return parts.join('\n');
  }

  void _showCitationDialog(
    BuildContext context,
    String sourceId,
    LocalRagCitation? citation,
  ) {
    final title = citation?.title.trim().isNotEmpty == true
        ? citation!.title
        : 'source:$sourceId';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(
          [
            if (citation?.snippet.trim().isNotEmpty == true) citation!.snippet,
            if (citation?.path.trim().isNotEmpty == true) citation!.path,
            if (citation == null) 'No source metadata was returned.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
