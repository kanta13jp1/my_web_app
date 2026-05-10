import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/agent_gpa_dashboard_page.dart';

typedef AgentGpaBadgeLoader = Future<List<AgentGpaEvaluation>> Function(
  AgentGpaDashboardQuery query,
);

class AgentGpaBadge extends StatefulWidget {
  const AgentGpaBadge({
    super.key,
    required this.sourceType,
    this.sourceId,
    this.label,
    this.compact = true,
    this.supabaseClient,
    this.loader,
  });

  final String sourceType;
  final String? sourceId;
  final String? label;
  final bool compact;
  final SupabaseClient? supabaseClient;
  final AgentGpaBadgeLoader? loader;

  @override
  State<AgentGpaBadge> createState() => _AgentGpaBadgeState();
}

class _AgentGpaBadgeState extends State<AgentGpaBadge> {
  AgentGpaEvaluation? _evaluation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvaluation();
  }

  @override
  void didUpdateWidget(covariant AgentGpaBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceType != widget.sourceType ||
        oldWidget.sourceId != widget.sourceId ||
        oldWidget.loader != widget.loader) {
      _loadEvaluation();
    }
  }

  Future<void> _loadEvaluation() async {
    final normalizedSourceType = widget.sourceType.trim();
    if (!agentGpaSourceTypes.contains(normalizedSourceType)) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final loader = widget.loader ?? _loadFromAppHub;
      final evaluations = await loader(
        AgentGpaDashboardQuery(
          sourceType: normalizedSourceType,
          limit: widget.sourceId == null ? 1 : 50,
        ),
      );
      final selected = selectAgentGpaBadgeEvaluation(
        evaluations,
        sourceType: normalizedSourceType,
        sourceId: widget.sourceId,
      );
      if (mounted) setState(() => _evaluation = selected);
    } catch (_) {
      if (mounted) setState(() => _evaluation = null);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<AgentGpaEvaluation>> _loadFromAppHub(
    AgentGpaDashboardQuery query,
  ) async {
    final supabase = widget.supabaseClient ?? Supabase.instance.client;
    if (supabase.auth.currentUser == null) return const [];
    final response = await supabase.functions.invoke(
      'app-hub',
      body: <String, dynamic>{
        'action': 'agent.list_gpa_recent',
        'source_type': query.sourceType,
        'limit': query.limit,
      },
    );
    final data = response.data;
    final raw = data is Map<String, dynamic> && data['evaluations'] is List
        ? data['evaluations'] as List
        : const <dynamic>[];
    return raw
        .whereType<Map>()
        .map(
          (item) =>
              AgentGpaEvaluation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _evaluation;
    final sourceLabel = _sourceLabel(widget.sourceType);
    final badgeLabel = widget.label ?? sourceLabel;
    final color = evaluation == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : _gpaColor(evaluation.gpa);
    final value = _isLoading
        ? '...'
        : evaluation == null
            ? '--'
            : evaluation.gpa.toStringAsFixed(1);

    return Semantics(
      button: true,
      label: '$badgeLabel GPA $value',
      child: InkWell(
        key: Key(
          'agent_gpa_badge_${widget.sourceType}_${widget.sourceId ?? 'latest'}',
        ),
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showDetails(context),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 9 : 12,
            vertical: widget.compact ? 5 : 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.62)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed, size: widget.compact ? 14 : 16, color: color),
              const SizedBox(width: 5),
              Text(
                'GPA $value',
                style: TextStyle(
                  color: color,
                  fontSize: widget.compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final evaluation = _evaluation;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_sourceLabel(widget.sourceType)} GPA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                if (evaluation == null)
                  Text(
                    'No GPA evaluation has been recorded for this trace yet.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _scoreChip('GPA', evaluation.gpa),
                      _scoreChip('Goal', evaluation.goalScore),
                      _scoreChip('Plan', evaluation.planScore),
                      _scoreChip('Action', evaluation.actionScore),
                      _scoreChip('Consistency', evaluation.consistencyScore),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    evaluation.rationaleShort.isEmpty
                        ? 'No rationale recorded.'
                        : evaluation.rationaleShort,
                    style: const TextStyle(height: 1.45),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AgentGpaDashboardPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open dashboard'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

AgentGpaEvaluation? selectAgentGpaBadgeEvaluation(
  Iterable<AgentGpaEvaluation> evaluations, {
  required String sourceType,
  String? sourceId,
}) {
  final normalizedSourceId = sourceId?.trim();
  final matches = evaluations
      .where((item) => item.sourceType == sourceType)
      .where(
        (item) => normalizedSourceId == null || normalizedSourceId.isEmpty
            ? true
            : item.sourceId == normalizedSourceId,
      )
      .toList()
    ..sort((a, b) {
      final aTime = a.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.evaluatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  return matches.isEmpty ? null : matches.first;
}

Widget _scoreChip(String label, double score) {
  final color = _gpaColor(score);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(
      '$label ${score.toStringAsFixed(1)}',
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

Color _gpaColor(double score) {
  if (score < 2.5) return const Color(0xFFEF4444);
  if (score < 3.2) return const Color(0xFF6366F1);
  if (score < 3.6) return const Color(0xFFEAB308);
  return const Color(0xFFF97316);
}

String _sourceLabel(String sourceType) {
  switch (sourceType) {
    case 'executive_chat':
      return 'Executive chat';
    case 'executive_meeting':
      return 'Emergency meeting';
    case 'secretary_action':
      return 'AI Secretary';
    default:
      return sourceType.isEmpty ? 'Agent trace' : sourceType;
  }
}
