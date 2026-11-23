import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/ai_fsrs_service.dart';
import '../services/fsrs_scheduler.dart';

class FsrsPracticeQueueCard extends StatefulWidget {
  const FsrsPracticeQueueCard({
    super.key,
    required this.initialCards,
    this.promptLabels = const <String, String>{},
    this.service,
    this.debugNow,
    this.onGraded,
  });

  final List<FsrsCardState> initialCards;
  final Map<String, String> promptLabels;
  final AiFsrsService? service;
  final DateTime? debugNow;
  final ValueChanged<FsrsReviewOutcome>? onGraded;

  @override
  State<FsrsPracticeQueueCard> createState() => _FsrsPracticeQueueCardState();
}

class _FsrsPracticeQueueCardState extends State<FsrsPracticeQueueCard> {
  late List<FsrsCardState> _cards;
  late DateTime _cardShownAt;
  FsrsReviewOutcome? _lastOutcome;

  DateTime get _now => widget.debugNow ?? DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _cards = FsrsScheduler.sortPracticeQueue(widget.initialCards, now: _now);
    _cardShownAt = DateTime.now().toUtc();
  }

  void _gradeTopCard(int grade) {
    if (_cards.isEmpty) {
      return;
    }
    final top = _cards.first;
    final elapsedMs = math.max(
      1,
      DateTime.now().toUtc().difference(_cardShownAt).inMilliseconds,
    );
    final schedulerService = widget.service ?? AiFsrsService();
    final outcome = schedulerService.gradeCardLocal(
      top,
      grade: grade,
      elapsedMs: elapsedMs,
      now: _now,
    );

    final updated = <FsrsCardState>[
      outcome.nextCard,
      ..._cards.skip(1),
    ];
    setState(() {
      _cards = FsrsScheduler.sortPracticeQueue(updated, now: _now);
      _lastOutcome = outcome;
      _cardShownAt = DateTime.now().toUtc();
    });
    widget.onGraded?.call(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reference = _now.toUtc();
    final overdueCount =
        _cards.where((c) => !c.dueDate.toUtc().isAfter(reference)).length;

    return Card(
      key: const Key('fsrs_practice_queue_card'),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology_alt_outlined,
                  size: 20,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Practice Mode (FSRS 優先復習キュー)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                Semantics(
                  label: '期限超過 $overdueCount件',
                  child: Chip(
                    key: const Key('fsrs_overdue_count_chip'),
                    label: Text(
                      '期限超過 $overdueCount件',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_cards.isEmpty)
              const Text('復習キューは空です。')
            else ...[
              _buildActivePrompt(scheme),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final g in const <int>[1, 2, 3, 4])
                    OutlinedButton(
                      key: Key('fsrs_grade_btn_$g'),
                      onPressed: () => _gradeTopCard(g),
                      child: Text(AiFsrsService.gradeLabel(g)),
                    ),
                ],
              ),
            ],
            if (_lastOutcome case final last?)
              Padding(
                key: const Key('fsrs_last_outcome_banner'),
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '次回: ${last.scheduledDays}日後 (stability: ${last.stability}, difficulty: ${last.difficulty})',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivePrompt(ColorScheme scheme) {
    final top = _cards.first;
    final label = widget.promptLabels[top.questionId] ?? top.questionId;
    final overdue = !top.dueDate.toUtc().isAfter(_now.toUtc());
    return Container(
      key: const Key('fsrs_active_card_box'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue
            ? const Color(0xFFFEF3C7).withAlpha(110)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: overdue ? const Color(0xFFF59E0B) : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '優先対象: $label',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '状態: ${top.state} · stability ${top.stability} · difficulty ${top.difficulty}',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
