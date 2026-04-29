import 'package:flutter/material.dart';
import 'package:my_web_app/services/daily_judgment_quality_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyJudgmentPage extends StatefulWidget {
  const DailyJudgmentPage({super.key});

  @override
  State<DailyJudgmentPage> createState() => _DailyJudgmentPageState();
}

class _DailyJudgmentPageState extends State<DailyJudgmentPage> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _fetchJudgment() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      setState(() {
        _loading = false;
        _error = 'AIデイリー判断にはログインが必要です';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'ai-hub',
        body: {'action': 'judgment.get'},
      );
      final data = res.data;
      setState(() {
        _result = data is Map<String, dynamic> ? data : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchJudgment();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final quality = DailyJudgmentQualityEvaluation.fromMap(
      result?['quality_evaluation'] is Map<String, dynamic>
          ? result!['quality_evaluation'] as Map<String, dynamic>
          : null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIデイリー判断'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '再取得',
            onPressed: _loading ? null : _fetchJudgment,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _fetchJudgment)
              : result == null
                  ? const Center(child: Text('データがありません'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _JudgmentSummaryCard(result: result),
                        const SizedBox(height: 12),
                        _QualityGateCard(quality: quality),
                        const SizedBox(height: 12),
                        _KgiCsfKpiCard(result: result),
                      ],
                    ),
    );
  }
}

class _JudgmentSummaryCard extends StatelessWidget {
  const _JudgmentSummaryCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final score = _intText(result['score']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _text(result['judgment'], fallback: '今日の判断'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _ScoreBadge(label: 'AI', value: score),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _text(result['focus_area'], fallback: '最優先領域'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _text(result['advice'], fallback: '今日の具体行動を再取得してください。'),
              style: const TextStyle(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityGateCard extends StatelessWidget {
  const _QualityGateCard({required this.quality});

  final DailyJudgmentQualityEvaluation quality;

  @override
  Widget build(BuildContext context) {
    final color =
        quality.needsReview ? const Color(0xFFD97706) : const Color(0xFF059669);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quality.needsReview
                      ? Icons.rule_folder_outlined
                      : Icons.verified_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scale Evaluation 品質ゲート',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _ScoreBadge(label: 'QE', value: '${quality.overallScore}'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: quality.overallScore / 100,
                minHeight: 10,
                color: color,
                backgroundColor: color.withAlpha(35),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  label: quality.needsReview ? '要確認' : '承認',
                  color: color,
                ),
                _InfoChip(
                  label: 'しきい値 ${quality.threshold}',
                  color: const Color(0xFF2563EB),
                ),
                _InfoChip(
                  label: '監視 ${quality.monitoringCadence}',
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
            if (quality.criteria.isNotEmpty) ...[
              const SizedBox(height: 14),
              ...quality.criteria.map(
                (criterion) => _CriterionRow(criterion: criterion),
              ),
            ],
            if (quality.improvementActions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '改善アクション',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              ...quality.improvementActions.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('・$item'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KgiCsfKpiCard extends StatelessWidget {
  const _KgiCsfKpiCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KGI / CSF / KPI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _MetricLine(label: 'KGI', value: _text(result['kgi'])),
            _MetricLine(label: 'CSF', value: _listText(result['csf'])),
            _MetricLine(label: 'KPI', value: _mapText(result['kpi'])),
          ],
        ),
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({required this.criterion});

  final DailyJudgmentQualityCriterion criterion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              criterion.label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: criterion.score / 100,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Text(
              '${criterion.score}',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1A2A) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF1D3A6A) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE53935)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('再取得'),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _intText(Object? value) {
  if (value is num) return value.round().toString();
  return int.tryParse(value?.toString() ?? '')?.toString() ?? '-';
}

String _listText(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).join(' / ');
  }
  return _text(value);
}

String _mapText(Object? value) {
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' / ');
  }
  return _text(value);
}
