import 'package:flutter/material.dart';

import '../services/inline_text_diff_service.dart';

enum AiInlineDiffDecision { pending, applied, discarded }

class AiInlineDiffCard extends StatefulWidget {
  final InlineDiffProposal proposal;
  final Future<void> Function(String proposedText)? onApply;
  final VoidCallback? onDiscard;

  const AiInlineDiffCard({
    super.key,
    required this.proposal,
    this.onApply,
    this.onDiscard,
  });

  @override
  State<AiInlineDiffCard> createState() => _AiInlineDiffCardState();
}

class _AiInlineDiffCardState extends State<AiInlineDiffCard> {
  AiInlineDiffDecision _decision = AiInlineDiffDecision.pending;
  bool _applying = false;

  Future<void> _handleApply() async {
    if (_applying || _decision != AiInlineDiffDecision.pending) return;
    setState(() => _applying = true);
    try {
      await widget.onApply?.call(widget.proposal.proposedText);
      if (!mounted) return;
      setState(() => _decision = AiInlineDiffDecision.applied);
    } finally {
      if (mounted) {
        setState(() => _applying = false);
      }
    }
  }

  void _handleDiscard() {
    if (_applying || _decision != AiInlineDiffDecision.pending) return;
    widget.onDiscard?.call();
    setState(() => _decision = AiInlineDiffDecision.discarded);
  }

  @override
  Widget build(BuildContext context) {
    final decisionLabel = switch (_decision) {
      AiInlineDiffDecision.pending => '確認待ち',
      AiInlineDiffDecision.applied => '適用済み',
      AiInlineDiffDecision.discarded => '破棄済み',
    };

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '${widget.proposal.title} ($decisionLabel)',
      child: Container(
        key: const Key('ai_inline_diff_card'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141826),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.difference_outlined,
                  size: 16,
                  color: Color(0xFF60A5FA),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.proposal.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  key: const Key('ai_inline_diff_status_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    decisionLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '+追加 ${widget.proposal.addedSegmentCount}箇所 / '
              '-削除 ${widget.proposal.deletedSegmentCount}箇所',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text.rich(
                key: const Key('ai_inline_diff_rich_text'),
                TextSpan(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  children: <InlineSpan>[
                    for (final seg in widget.proposal.segments)
                      _segmentToSpan(seg),
                  ],
                ),
              ),
            ),
            if (_decision == AiInlineDiffDecision.pending) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  FilledButton.icon(
                    key: const Key('ai_inline_diff_apply_button'),
                    onPressed: _applying ? null : _handleApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: Icon(
                      _applying ? Icons.hourglass_top : Icons.check,
                      size: 16,
                    ),
                    label: const Text('適用'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('ai_inline_diff_discard_button'),
                    onPressed: _applying ? null : _handleDiscard,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('破棄'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextSpan _segmentToSpan(InlineDiffSegment seg) {
    switch (seg.type) {
      case InlineDiffSegmentType.unchanged:
        return TextSpan(text: seg.text);
      case InlineDiffSegmentType.added:
        return TextSpan(
          text: '[+${seg.text}]',
          style: TextStyle(
            backgroundColor: const Color(0xFF065F46).withValues(alpha: 0.7),
            color: const Color(0xFF6EE7B7),
            fontWeight: FontWeight.w700,
          ),
        );
      case InlineDiffSegmentType.deleted:
        return TextSpan(
          text: '[-${seg.text}]',
          style: TextStyle(
            backgroundColor: const Color(0xFF7F1D1D).withValues(alpha: 0.7),
            color: const Color(0xFFFCA5A5),
            decoration: TextDecoration.lineThrough,
          ),
        );
    }
  }
}
