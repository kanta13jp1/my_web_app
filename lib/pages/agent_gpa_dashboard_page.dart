import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AgentGpaDashboardLoader = Future<List<AgentGpaEvaluation>> Function(
  AgentGpaDashboardQuery query,
);

typedef AgentGpaImprovementActionHandler = Future<void> Function(
  AgentGpaEvaluation evaluation,
  AgentGpaSuggestion suggestion,
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

@visibleForTesting
class AgentGpaHistoryPoint {
  const AgentGpaHistoryPoint({
    required this.day,
    required this.gpa,
    required this.count,
  });

  final DateTime day;
  final double gpa;
  final int count;
}

@visibleForTesting
class AgentGpaImprovementPlan {
  const AgentGpaImprovementPlan({
    required this.title,
    required this.summary,
    required this.primaryLabel,
    required this.icon,
    required this.canRunNow,
  });

  final String title;
  final String summary;
  final String primaryLabel;
  final IconData icon;
  final bool canRunNow;
}

class AgentGpaDashboardPage extends StatefulWidget {
  const AgentGpaDashboardPage({
    super.key,
    SupabaseClient? supabaseClient,
    AgentGpaDashboardLoader? loader,
    AgentGpaImprovementActionHandler? improvementActionHandler,
  })  : _supabaseClient = supabaseClient,
        _loader = loader,
        _improvementActionHandler = improvementActionHandler;

  final SupabaseClient? _supabaseClient;
  final AgentGpaDashboardLoader? _loader;
  final AgentGpaImprovementActionHandler? _improvementActionHandler;

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

  Future<void> _handleImprovementAction(
    AgentGpaEvaluation evaluation,
    AgentGpaSuggestion suggestion,
  ) async {
    final handler = widget._improvementActionHandler;
    if (handler != null) {
      await handler(evaluation, suggestion);
      return;
    }
    if (suggestion.type != 'rerun') return;
    if (_supabase.auth.currentUser == null) {
      throw StateError('Sign in before rerunning a GPA evaluation.');
    }
    await _supabase.functions.invoke(
      'app-hub',
      body: {
        'action': 'agent.evaluate_gpa',
        'source_type': evaluation.sourceType,
        'source_id': evaluation.sourceId,
        'judge_model': evaluation.judgeModel,
      },
    );
    await _loadEvaluations();
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
            _GpaHistoryChart(evaluations: _evaluations),
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
                  child: _GpaEvaluationCard(
                    evaluation: evaluation,
                    onRunImprovement: _handleImprovementAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

@visibleForTesting
List<AgentGpaHistoryPoint> buildAgentGpaHistoryPoints(
  Iterable<AgentGpaEvaluation> evaluations, {
  DateTime? now,
  int days = 30,
}) {
  final dated = evaluations
      .where((item) => item.evaluatedAt != null)
      .map((item) => (evaluation: item, day: _dayOnly(item.evaluatedAt!)))
      .toList();
  if (dated.isEmpty) return const [];

  final latestDay = now == null
      ? dated
          .map((item) => item.day)
          .reduce((left, right) => left.isAfter(right) ? left : right)
      : _dayOnly(now);
  final startDay = latestDay.subtract(Duration(days: days - 1));
  final buckets = <DateTime, List<double>>{};
  for (final item in dated) {
    if (item.day.isBefore(startDay) || item.day.isAfter(latestDay)) {
      continue;
    }
    buckets.putIfAbsent(item.day, () => <double>[]).add(item.evaluation.gpa);
  }

  final points = buckets.entries.map((entry) {
    final values = entry.value;
    final avg =
        values.fold<double>(0, (sum, value) => sum + value) / values.length;
    return AgentGpaHistoryPoint(
      day: entry.key,
      gpa: double.parse(avg.toStringAsFixed(2)),
      count: values.length,
    );
  }).toList()
    ..sort((left, right) => left.day.compareTo(right.day));
  return points;
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

class _GpaHistoryChart extends StatelessWidget {
  const _GpaHistoryChart({required this.evaluations});

  final List<AgentGpaEvaluation> evaluations;

  @override
  Widget build(BuildContext context) {
    final points = buildAgentGpaHistoryPoints(evaluations);
    final latest = points.isEmpty ? null : points.last;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].gpa),
    ];

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
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFFF97316), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '30-day GPA history',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              if (latest != null)
                _Pill(
                  label: '${latest.gpa.toStringAsFixed(2)} latest',
                  color: _gpaColor(latest.gpa),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (spots.length < 2)
            const Text(
              'Trend line pending until another dated evaluation arrives.',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.45,
              ),
            )
          else
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: 0,
                  maxY: 4,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFF262626), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, _) => Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (points.length / 4).ceilToDouble().clamp(
                              1,
                              30,
                            ),
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _formatMonthDay(points[index].day),
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                height: 1.2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (items) => items.map((item) {
                        final index = item.x.toInt();
                        final point = points[index];
                        return LineTooltipItem(
                          '${_formatMonthDay(point.day)}\n'
                          'GPA ${point.gpa.toStringAsFixed(2)}'
                          ' (${point.count})',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: spots.length > 2,
                      color: const Color(0xFFF97316),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                          radius: spot.x == spots.last.x ? 4 : 3,
                          color: _gpaColor(spot.y),
                          strokeColor: const Color(0xFF0A0A0A),
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFF97316).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
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
  const _GpaEvaluationCard({
    required this.evaluation,
    required this.onRunImprovement,
  });

  final AgentGpaEvaluation evaluation;
  final AgentGpaImprovementActionHandler onRunImprovement;

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
                      (suggestion) => _SuggestionButton(
                        evaluation: evaluation,
                        suggestion: suggestion,
                        onRunImprovement: onRunImprovement,
                      ),
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

class _SuggestionButton extends StatelessWidget {
  const _SuggestionButton({
    required this.evaluation,
    required this.suggestion,
    required this.onRunImprovement,
  });

  final AgentGpaEvaluation evaluation;
  final AgentGpaSuggestion suggestion;
  final AgentGpaImprovementActionHandler onRunImprovement;

  @override
  Widget build(BuildContext context) {
    final plan = buildAgentGpaImprovementPlan(suggestion);
    return Tooltip(
      message: suggestion.suggestion,
      child: OutlinedButton.icon(
        onPressed: () => _showImprovementSheet(
          context,
          evaluation,
          suggestion,
          onRunImprovement,
        ),
        icon: Icon(plan.icon, size: 17),
        label: Text('${suggestion.axis}: ${_suggestionTypeLabel(suggestion)}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFEDD5),
          side: BorderSide(
            color: const Color(0xFFF97316).withValues(alpha: 0.55),
          ),
          backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.12),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

Future<void> _showImprovementSheet(
  BuildContext context,
  AgentGpaEvaluation evaluation,
  AgentGpaSuggestion suggestion,
  AgentGpaImprovementActionHandler onRunImprovement,
) async {
  final plan = buildAgentGpaImprovementPlan(suggestion);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF141414),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (sheetContext) {
      var running = false;
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(plan.icon, color: const Color(0xFFF97316)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          plan.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    plan.summary,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImprovementContextPanel(
                    evaluation: evaluation,
                    suggestion: suggestion,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: running
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: running
                              ? null
                              : () async {
                                  if (!plan.canRunNow) {
                                    Navigator.of(sheetContext).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${plan.title} guidance opened for '
                                          '${_sourceLabel(evaluation.sourceType)}.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() => running = true);
                                  try {
                                    await onRunImprovement(
                                      evaluation,
                                      suggestion,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('GPA rerun completed.'),
                                        ),
                                      );
                                    }
                                  } catch (error) {
                                    setSheetState(() => running = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'GPA rerun failed: $error',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: running
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(plan.icon, size: 18),
                          label: Text(plan.primaryLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _ImprovementContextPanel extends StatelessWidget {
  const _ImprovementContextPanel({
    required this.evaluation,
    required this.suggestion,
  });

  final AgentGpaEvaluation evaluation;
  final AgentGpaSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_sourceLabel(evaluation.sourceType)} / '
            '${_shortId(evaluation.sourceId)} / '
            'GPA ${evaluation.gpa.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFFE5E7EB),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.suggestion,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
AgentGpaImprovementPlan buildAgentGpaImprovementPlan(
  AgentGpaSuggestion suggestion,
) {
  switch (suggestion.type) {
    case 'rerun':
      return const AgentGpaImprovementPlan(
        title: 'Rerun evaluation',
        summary:
            'Run agent.evaluate_gpa again for this trace with the same source reference and judge model.',
        primaryLabel: 'Run again',
        icon: Icons.replay_circle_filled_outlined,
        canRunNow: true,
      );
    case 'prompt_edit':
      return const AgentGpaImprovementPlan(
        title: 'Prompt revision brief',
        summary:
            'Use this weak-axis note as the prompt edit brief before the next executive run.',
        primaryLabel: 'Use brief',
        icon: Icons.edit_note_outlined,
        canRunNow: false,
      );
    case 'approval_gate':
      return const AgentGpaImprovementPlan(
        title: 'Approval gate guidance',
        summary:
            'Route the next risky tool or database action through human approval before automation continues.',
        primaryLabel: 'Use gate',
        icon: Icons.verified_user_outlined,
        canRunNow: false,
      );
    case 'scope_split':
      return const AgentGpaImprovementPlan(
        title: 'Scope split checklist',
        summary:
            'Split the original request into one atomic objective, then rerun the agent on that smaller scope.',
        primaryLabel: 'Use split',
        icon: Icons.call_split_outlined,
        canRunNow: false,
      );
    default:
      return const AgentGpaImprovementPlan(
        title: 'Improvement guidance',
        summary: 'Review this GPA suggestion before the next agent run.',
        primaryLabel: 'Use guidance',
        icon: Icons.tips_and_updates_outlined,
        canRunNow: false,
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

String _formatMonthDay(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}';
}

DateTime _dayOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _shortId(String value) {
  if (value.length <= 8) return value;
  return value.substring(0, 8);
}

String _suggestionTypeLabel(AgentGpaSuggestion suggestion) {
  switch (suggestion.type) {
    case 'rerun':
      return 'rerun';
    case 'prompt_edit':
      return 'prompt edit';
    case 'approval_gate':
      return 'approval gate';
    case 'scope_split':
      return 'scope split';
    default:
      return suggestion.type;
  }
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
