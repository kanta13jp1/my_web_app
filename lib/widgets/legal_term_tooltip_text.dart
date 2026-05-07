import 'package:flutter/material.dart';

import '../services/legal_term_glossary_service.dart';

class LegalTermTooltipText extends StatelessWidget {
  const LegalTermTooltipText({
    super.key,
    required this.text,
    this.style,
    this.glossary = const LegalTermGlossaryService(),
  });

  final String text;
  final TextStyle? style;
  final LegalTermGlossaryService glossary;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final highlightStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
      decorationThickness: 1.4,
    );
    final matches = glossary.matchTerms(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in matches) {
      if (cursor < match.start) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _LegalTermTooltipChip(
            text: match.matchedText,
            tooltip: match.definition.tooltipText,
            style: highlightStyle,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

class _LegalTermTooltipChip extends StatefulWidget {
  const _LegalTermTooltipChip({
    required this.text,
    required this.tooltip,
    required this.style,
  });

  final String text;
  final String tooltip;
  final TextStyle style;

  @override
  State<_LegalTermTooltipChip> createState() => _LegalTermTooltipChipState();
}

class _LegalTermTooltipChipState extends State<_LegalTermTooltipChip> {
  final _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      key: _tooltipKey,
      message: widget.tooltip,
      showDuration: const Duration(seconds: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tooltipKey.currentState?.ensureTooltipVisible(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(widget.text, style: widget.style),
          ),
        ),
      ),
    );
  }
}
