import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AgentGpaDashboardLoader = Future<List<AgentGpaEvaluation>> Function(
  AgentGpaDashboardQuery query,
);

const List<String> agentGpaSourceTypes = <String>[
  'executive_chat',
  'executive_meeting',
  'secretary_action',
];

class AgentGpaDashboardQuery {
  const AgentGpaDashboardQuery({
    this.sourceType,
    this.lowOnly = false,
    this.limit = 50,
  });

  final String? sourceType;
  final bool lowOnly;
  final int limit;
}

class AgentGpaEvaluation {
  const AgentGpaEvaluation({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.goalScore,
    required this.planScore,
    required this.actionScore,
    required this.consistencyScore,
    required this.gpa,
    required this.rationaleShort,
    required this.improvementSuggestions,
    required this.judgeModel,
    this.evaluatedAt,
  });

  final String id;
  final String sourceType;
  final String sourceId;
  final double goalScore;
  final double planScore;
  final double actionScore;
  final double consistencyScore;
  final double gpa;
  final String rationaleShort;
  final List<AgentGpaSuggestion> improvementSuggestions;
  final String judgeModel;
  final DateTime? evaluatedAt;

  factory AgentGpaEvaluation.fromJson(Map<String, dynamic> json) {
    return AgentGpaEvaluation(
      id: _stringValue(json['id'] ?? json['evaluation_id']),
      sourceType: _stringValue(json['source_type']),
      sourceId: _stringValue(json['source_id']),
      goalScore: _doubleValue(json['goal_score']),
      planScore: _doubleValue(json['plan_score']),
      actionScore: _doubleValue(json['action_score']),
      consistencyScore: _doubleValue(json['consistency_score']),
      gpa: _doubleValue(json['gpa']),
      rationaleShort: _stringValue(json['rationale_short']),
      judgeModel: _stringValue(json['judge_model'], fallback: 'unknown'),
      evaluatedAt: _dateValue(json['evaluated_at'] ?? json['created_at']),
      improvementSuggestions: _suggestionsValue(
        json['improvement_suggestions'],
      ),
    );
  }
}

class AgentGpaSuggestion {
  const AgentGpaSuggestion({
    required this.type,
    required this.axis,
    required this.suggestion,
  });

  final String type;
  final String axis;
  final String suggestion;

  factory AgentGpaSuggestion.fromJson(Map<String, dynamic> json) {
    return AgentGpaSuggestion(
      type: _stringValue(json['type'], fallback: 'improve'),
      axis: _stringValue(json['axis'], fallback: 'gpa'),
      suggestion: _stringValue(json['suggestion']),
    );
  }
}

class AgentGpaDashboardPage extends StatefulWidget {
  const AgentGpaDashboardPage({
    super.key,
    SupabaseClient? supabaseClient,
    AgentGpaDashboardLoader? loader,
  })  : _supabaseClient = supabaseClient,
        _loader = loader;

  final SupabaseClient? _supabaseClient;
  final AgentGpaDashboardLoader? _loader;

  @override
  State<AgentGpaDashboardPage> createState() => _AgentGpaDashboardPageState();
}

class _AgentGpaDashboardPageState extends State<AgentGpaDashboardPage> {
  late final SupabaseClient _supabase =
      widget._supabaseClient ?? Supabase.instance.client;

  bool _isLoading = false;
  bool _lowOnly = false;
  String? _sourceType;
  String? _errorMessage;
  List<AgentGpaEvaluation> _evaluations = const [];

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    if (widget._loader == null && _supabase.auth.currentUser == null) {
      setState(() {
        _evaluations = const [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final query = AgentGpaDashboardQuery(
        sourceType: _sourceType,
        lowOnly: _lowOnly,
      );
      final loader = widget._loader ?? _loadFromAppHub;
      final evaluations = await loader(query);
      if (mounted) {
        setState(() {
          _evaluations = filterAgentGpaEvaluations(
            evaluations,
            sourceType: _sourceType,
            lowOnly: _lowOnly,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to load GPA evaluations: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<AgentGpaEvaluation>> _loadFromAppHub(
    AgentGpaDashboardQuery query,
  ) async {
    final body = <String, dynamic>{
      'action': 'agent.list_gpa_recent',
      'limit': query.limit,
      if (query.sourceType != null) 'source_type': query.sourceType,
      if (query.lowOnly) 'max_gpa': 2.49,
    };
    final response = await _supabase.functions.invoke('app-hub', body: body);
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

  void _setSourceType(String? sourceType) {
    if (_sourceType == sourceType) return;
    setState(() => _sourceType = sourceType);
    _loadEvaluations();
  }

  void _toggleLowOnly(bool selected) {
    setState(() => _lowOnly = selected);
    _loadEvaluations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('AI Executive GPA'),
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEvaluations,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEvaluations,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _DashboardSummary(evaluations: _evaluations),
            const SizedBox(height: 14),
            _FilterBar(
              sourceType: _sourceType,
              lowOnly: _lowOnly,
              onSourceChanged: _setSourceType,
              onLowOnlyChanged: _toggleLowOnly,
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 52),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF97316)),
                ),
              )
            else if (_errorMessage != null)
              _MessagePanel(
                icon: Icons.error_outline,
                title: 'GPA feed unavailable',
                message: _errorMessage!,
              )
            else if (_evaluations.isEmpty)
              _MessagePanel(
                icon: Icons.query_stats_outlined,
                title: 'No GPA evaluations yet',
                message: widget._loader == null &&
                        _supabase.auth.currentUser == null
                    ? 'Sign in and run an executive action to create the first evaluation.'
                    : 'Run agent.evaluate_gpa from an AI executive trace, then refresh this dashboard.',
              )
            else
              ..._evaluations.map(
                (evaluation) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _GpaEvaluationCard(evaluation: evaluation),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
List<AgentGpaEvaluation> filterAgentGpaEvaluations(
  Iterable<AgentGpaEvaluation> evaluations, {
  String? sourceType,
  bool lowOnly = false,
}) {
  final filtered = evaluations.where((evaluation) {
    if (sourceType != null && evaluation.sourceType != sourceType) {
      return false;
    }
    if (lowOnly && evaluation.gpa >= 2.5) return false;
    return true;
  }).toList();
  filtered.sort((a, b) {
    final byDate = _compareNullableDate(b.evaluatedAt, a.evaluatedAt);
    if (byDate != 0) return byDate;
    return a.gpa.compareTo(b.gpa);
  });
  return filtered;
}

int _compareNullableDate(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  return a.compareTo(b);
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.evaluations});

  final List<AgentGpaEvaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    final avg = evaluations.isEmpty
        ? 0.0
        : evaluations.fold<double>(0, (sum, item) => sum + item.gpa) /
            evaluations.length;
    final lowCount = evaluations.where((item) => item.gpa < 2.5).length;
    final latest = evaluations.isEmpty ? null : evaluations.first.evaluatedAt;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent GPA signal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryMetric(
                label: 'Average',
                value: evaluations.isEmpty ? '-' : avg.toStringAsFixed(2),
                color: _gpaColor(avg),
              ),
              _SummaryMetric(
                label: 'Low GPA',
                value: lowCount.toString(),
                color: lowCount == 0
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
              ),
              _SummaryMetric(
                label: 'Total',
                value: evaluations.length.toString(),
                color: const Color(0xFF60A5FA),
              ),
              _SummaryMetric(
                label: 'Latest',
                value: latest == null ? '-' : _formatShortDateTime(latest),
                color: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.sourceType,
    required this.lowOnly,
    required this.onSourceChanged,
    required this.onLowOnlyChanged,
  });

  final String? sourceType;
  final bool lowOnly;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<bool> onLowOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: sourceType == null,
          onSelected: (_) => onSourceChanged(null),
        ),
        for (final type in agentGpaSourceTypes)
          ChoiceChip(
            label: Text(_sourceLabel(type)),
            selected: sourceType == type,
            onSelected: (_) => onSourceChanged(type),
          ),
        FilterChip(
          avatar: const Icon(Icons.warning_amber_outlined, size: 18),
          label: const Text('Low GPA'),
          selected: lowOnly,
          onSelected: onLowOnlyChanged,
        ),
      ],
    );
  }
}

class _GpaEvaluationCard extends StatelessWidget {
  const _GpaEvaluationCard({required this.evaluation});

  final AgentGpaEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final low = evaluation.gpa < 2.5;
    final tone = _gpaColor(evaluation.gpa);

    return Card(
      color: const Color(0xFF141414),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: low ? const Color(0xFFEF4444) : const Color(0xFF262626),
          width: low ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GpaBadge(value: evaluation.gpa, color: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Pill(
                            label: _sourceLabel(evaluation.sourceType),
                            color: const Color(0xFF60A5FA),
                          ),
                          if (low)
                            const _Pill(
                              label: 'Needs review',
                              color: Color(0xFFEF4444),
                            ),
                          _Pill(
                            label: evaluation.judgeModel,
                            color: const Color(0xFFA78BFA),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        evaluation.rationaleShort.isEmpty
                            ? 'No rationale recorded.'
                            : evaluation.rationaleShort,
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AxisScoreRow(label: 'Goal', score: evaluation.goalScore),
            _AxisScoreRow(label: 'Plan', score: evaluation.planScore),
            _AxisScoreRow(label: 'Action', score: evaluation.actionScore),
            _AxisScoreRow(
              label: 'Consistency',
              score: evaluation.consistencyScore,
            ),
            if (evaluation.improvementSuggestions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: evaluation.improvementSuggestions
                    .map(
                      (suggestion) => _SuggestionChip(suggestion: suggestion),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              [
                if (evaluation.evaluatedAt != null)
                  _formatShortDateTime(evaluation.evaluatedAt!),
                if (evaluation.sourceId.isNotEmpty)
                  'source ${_shortId(evaluation.sourceId)}',
              ].join('  |  '),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpaBadge extends StatelessWidget {
  const _GpaBadge({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const Text(
            'GPA',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AxisScoreRow extends StatelessWidget {
  const _AxisScoreRow({required this.label, required this.score});

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = _gpaColor(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (score / 4).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: const Color(0xFF262626),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              score.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.suggestion});

  final AgentGpaSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: suggestion.suggestion,
      child: Chip(
        avatar: const Icon(Icons.tips_and_updates_outlined, size: 17),
        label: Text('${suggestion.axis}: ${suggestion.type}'),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: const Color(0xFFF97316).withValues(alpha: 0.55),
        ),
        backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.12),
        labelStyle: const TextStyle(
          color: Color(0xFFFFEDD5),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
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
      return 'Chat';
    case 'executive_meeting':
      return 'Meeting';
    case 'secretary_action':
      return 'Secretary';
    default:
      return sourceType.isEmpty ? 'Unknown' : sourceType;
  }
}

String _formatShortDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

double _doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateValue(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

List<AgentGpaSuggestion> _suggestionsValue(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => AgentGpaSuggestion.fromJson(Map<String, dynamic>.from(item)),
      )
      .toList();
}
