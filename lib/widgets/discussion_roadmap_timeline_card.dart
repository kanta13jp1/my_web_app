import 'package:flutter/material.dart';
import 'package:my_web_app/services/discussion_roadmap_service.dart';

/// Visualizes discussion roadmap milestones, stage progression, and
/// immutable schedule-change audit logs without horizontal overflow.
class DiscussionRoadmapTimelineCard extends StatefulWidget {
  final DiscussionRoadmapService service;

  const DiscussionRoadmapTimelineCard({
    super.key,
    required this.service,
  });

  @override
  State<DiscussionRoadmapTimelineCard> createState() =>
      _DiscussionRoadmapTimelineCardState();
}

class _DiscussionRoadmapTimelineCardState
    extends State<DiscussionRoadmapTimelineCard> {
  DiscussionStage? _selectedStage;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDelta(int deltaDays) {
    if (deltaDays > 0) return '+$deltaDays日遅延';
    if (deltaDays < 0) return '$deltaDays日前倒';
    return '日程変更なし';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final milestones =
            widget.service.listMilestones(stageFilter: _selectedStage);
        final audits = widget.service.listAuditHistory();
        return Card(
          key: const Key('discussion_roadmap_card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '議論ロードマップ・マイルストーン',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('roadmap_filter_all'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 48),
                      ),
                      onPressed: () => setState(() => _selectedStage = null),
                      child: const Text('すべて'),
                    ),
                    for (final stage in DiscussionStage.values)
                      OutlinedButton(
                        key: Key('roadmap_filter_${stage.wireKey}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 48),
                        ),
                        onPressed: () => setState(() => _selectedStage = stage),
                        child: Text(stage.labelJa),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (milestones.isEmpty)
                  const Text('該当マイルストーンはありません')
                else
                  for (final ms in milestones)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        key: Key('roadmap_item_${ms.id}'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ms.topic,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(label: Text(ms.stage.labelJa)),
                                Chip(label: Text(_formatDate(ms.targetDate))),
                                Chip(label: Text(ms.ownerGroup)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (ms.stage.nextStage != null)
                                  FilledButton(
                                    key: Key('roadmap_advance_${ms.id}'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(64, 48),
                                    ),
                                    onPressed: () {
                                      widget.service.updateMilestoneSchedule(
                                        milestoneId: ms.id,
                                        nextStage: ms.stage.nextStage,
                                        reason: 'ステージ前進',
                                      );
                                    },
                                    child: const Text('進める'),
                                  ),
                                OutlinedButton(
                                  key: Key('roadmap_delay_${ms.id}'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 48),
                                  ),
                                  onPressed: () {
                                    widget.service.updateMilestoneSchedule(
                                      milestoneId: ms.id,
                                      nextTargetDate: ms.targetDate.add(
                                        const Duration(days: 7),
                                      ),
                                      reason: '7日延長',
                                    );
                                  },
                                  child: const Text('7日延長'),
                                ),
                                OutlinedButton(
                                  key: Key('roadmap_pull_${ms.id}'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 48),
                                  ),
                                  onPressed: () {
                                    widget.service.updateMilestoneSchedule(
                                      milestoneId: ms.id,
                                      nextTargetDate: ms.targetDate.subtract(
                                        const Duration(days: 7),
                                      ),
                                      reason: '7日前倒',
                                    );
                                  },
                                  child: const Text('7日前倒'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                if (audits.isNotEmpty) ...[
                  const Divider(),
                  Text(
                    '変更監査ログ (${audits.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final entry in audits.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${entry.topic}: ${entry.previousStage.labelJa} → '
                        '${entry.nextStage.labelJa} (${_formatDelta(entry.deltaDays)})',
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
