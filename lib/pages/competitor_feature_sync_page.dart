import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompetitorFeatureSyncPage extends StatefulWidget {
  const CompetitorFeatureSyncPage({super.key});

  @override
  State<CompetitorFeatureSyncPage> createState() =>
      _CompetitorFeatureSyncPageState();
}

class _CompetitorFeatureSyncPageState extends State<CompetitorFeatureSyncPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _competitors = [];
  List<Map<String, dynamic>> _pendingFeatures = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isGeneratingReport = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'competitor.sync'},
      );
      final data = res.data;
      if (data is Map) {
        final features = data['features'];
        if (features is List) {
          _pendingFeatures = features.map<Map<String, dynamic>>((f) {
            final row = (f as Map<String, dynamic>);
            final meta = (row['metadata'] as Map<String, dynamic>?) ?? {};
            return {
              'id': row['id'] ?? '',
              'competitor': meta['competitor'] ?? '',
              'feature_name': meta['feature'] ?? '',
              'category': meta['status'] ?? 'detected',
              'status': meta['status'] ?? 'detected',
            };
          }).toList();
        }
        _competitors = [];
      }
      final reportRes = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'competitor.reports'},
      );
      final reportData = reportRes.data;
      if (reportData is Map && reportData['reports'] is List) {
        _reports = (reportData['reports'] as List)
            .map<Map<String, dynamic>>(
              (row) => Map<String, dynamic>.from(row as Map),
            )
            .toList();
      }
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'データ取得失敗: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFeatureStatus(
    String featureId,
    String competitor,
    String status,
  ) async {
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {
          'action': 'competitor.add_feature',
          'competitor': competitor,
          'feature': featureId,
          'status': status,
        },
      );
      await _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ステータスを更新しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失敗: $e')),
        );
      }
    }
  }

  Future<void> _generateWeeklyManusReport() async {
    setState(() => _isGeneratingReport = true);
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'competitor.weekly_manus_report'},
      );
      await _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manus週次競合レポートを生成しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('レポート生成に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('競合機能パリティ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      height: 1.5,
                    ),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _CompetitorProgressGrid(
                        competitors: _competitors,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _ManusWeeklyReportPanel(
                        reports: _reports,
                        isGenerating: _isGeneratingReport,
                        onGenerate: _generateWeeklyManusReport,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '未実装機能 (${_pendingFeatures.length} 件)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _FeatureTile(
                          feature: _pendingFeatures[i],
                          onStatusUpdate: _updateFeatureStatus,
                        ),
                        childCount: _pendingFeatures.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
    );
  }
}

class _ManusWeeklyReportPanel extends StatelessWidget {
  final List<Map<String, dynamic>> reports;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _ManusWeeklyReportPanel({
    required this.reports,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final latest = reports.isNotEmpty ? reports.first : null;
    final latestMeta = latest?['metadata'] is Map
        ? Map<String, dynamic>.from(latest!['metadata'] as Map)
        : const <String, dynamic>{};
    final markdown = latestMeta['report_markdown']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Manus週次競合レポート',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.summarize),
                    label: const Text('生成'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'competitor_feature を週次で集約し、KGI/CSF/KPI、競合別サマリー、次の実行案を competitor_report として保存します。',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (latestMeta.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text('履歴 ${reports.length}件'),
                      avatar: const Icon(Icons.history, size: 16),
                    ),
                    Chip(
                      label: Text('監視 ${latestMeta['feature_count'] ?? 0}件'),
                      avatar: const Icon(Icons.radar, size: 16),
                    ),
                    Chip(
                      label: Text('競合 ${latestMeta['competitor_count'] ?? 0}社'),
                      avatar: const Icon(Icons.business, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    latestMeta['report_id']?.toString() ?? 'latest report',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    latestMeta['generated_at']?.toString() ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SelectableText(
                        markdown,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CompetitorProgressGrid extends StatelessWidget {
  final List<Map<String, dynamic>> competitors;
  const _CompetitorProgressGrid({required this.competitors});

  @override
  Widget build(BuildContext context) {
    if (competitors.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              '競合別進捗率',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ),
          ...competitors.map((c) {
            final pct = (c['progress_pct'] as num?)?.toDouble() ?? 0.0;
            final name =
                c['name'] as String? ?? c['competitor'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '${pct.round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFB0B0B0).withAlpha(40),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 80
                            ? const Color(0xFF4CAF50)
                            : pct >= 50
                                ? const Color(0xFFF97316)
                                : const Color(0xFFE53935),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final Map<String, dynamic> feature;
  final void Function(String featureId, String competitor, String status)
      onStatusUpdate;

  const _FeatureTile({
    required this.feature,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final featureId = feature['id'] as String? ?? '';
    final competitor = feature['competitor'] as String? ?? '';
    final featureName = feature['feature_name'] as String? ?? '';
    final category = feature['category'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(featureName),
        subtitle: Text('$competitor · $category'),
        trailing: PopupMenuButton<String>(
          onSelected: (status) => onStatusUpdate(featureId, competitor, status),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'done', child: Text('✅ 完了')),
            PopupMenuItem(value: 'partial', child: Text('🔶 部分実装')),
            PopupMenuItem(value: 'notYet', child: Text('❌ 未実装')),
          ],
          child: const Chip(label: Text('更新')),
        ),
      ),
    );
  }
}
