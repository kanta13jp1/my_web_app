import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 管理者ダッシュボード用: 競合サイト可用性モニタリングカード。
/// get-competitor-monitoring Edge Function からデータを取得して表示。
class CompetitorMonitoringCard extends StatefulWidget {
  const CompetitorMonitoringCard({super.key});

  @override
  State<CompetitorMonitoringCard> createState() =>
      _CompetitorMonitoringCardState();
}

class _CompetitorMonitoringCardState extends State<CompetitorMonitoringCard> {
  bool _loading = false;
  bool _checking = false;
  String? _error;
  List<Map<String, dynamic>> _competitors = [];
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _runCheck() async {
    setState(() => _checking = true);
    try {
      await Supabase.instance.client.functions.invoke(
        'admin-hub',
        body: {'action': 'competitor.check'},
      );
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke('admin-hub',
          body: {'action': 'monitoring.get'}, queryParameters: {'days': '7'},);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final raw = data['competitors'];
        final rawSummary = data['summary'];
        setState(() {
          _competitors = raw is List
              ? List<Map<String, dynamic>>.from(
                  raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
                )
              : [];
          _summary = rawSummary is Map<String, dynamic> ? rawSummary : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '競合モニタリング取得失敗: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final availPct = summary != null
        ? (summary['availabilityPct'] as num?)?.toStringAsFixed(1)
        : null;
    final total = summary?['total'] as int?;
    final available = summary?['available'] as int?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monitor_heart, color: Colors.teal),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '競合サイト可用性モニタリング',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _load,
                    tooltip: '再読み込み',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _SummaryChip(
                    label: '可用率',
                    value: '$availPct%',
                    color: _availColor(double.tryParse(availPct ?? '0') ?? 0),
                  ),
                  const SizedBox(width: 8),
                  _SummaryChip(
                    label: '正常',
                    value: '$available / $total',
                    color: Colors.green,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_loading && _competitors.isEmpty)
              const SizedBox(height: 40)
            else if (_competitors.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'データがありません。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _checking ? null : _runCheck,
                    icon: _checking
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow, size: 16),
                    label: Text(
                      _checking ? 'チェック中...' : '今すぐチェック',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              )
            else
              ..._competitors.map(_buildRow),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Map<String, dynamic> c) {
    final name = c['competitor']?.toString() ?? c['url']?.toString() ?? '?';
    final isUp = c['is_available'] as bool? ?? false;
    final ms = (c['response_ms'] as num?)?.toInt();
    final checkedAt = c['checked_at']?.toString();
    final timeStr = checkedAt != null
        ? checkedAt.substring(0, 16).replaceFirst('T', ' ')
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isUp ? Icons.check_circle : Icons.cancel,
            color: isUp ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (ms != null)
            Text(
              '${ms}ms',
              style: TextStyle(
                fontSize: 12,
                color: ms > 2000 ? Colors.orange : Colors.grey,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _availColor(double pct) {
    if (pct >= 90) return Colors.green;
    if (pct >= 70) return Colors.orange;
    return Colors.red;
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
