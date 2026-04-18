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
        'competitor-feature-sync',
        queryParameters: {'action': 'progress'},
      );
      final data = res.data;
      if (data is Map) {
        if (data['competitors'] is List) {
          _competitors =
              (data['competitors'] as List).cast<Map<String, dynamic>>();
        }
        if (data['pending'] is List) {
          _pendingFeatures =
              (data['pending'] as List).cast<Map<String, dynamic>>();
        }
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
        'competitor-feature-sync',
        body: {
          'action': 'update_status',
          'feature_id': featureId,
          'competitor': competitor,
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
                    style: const TextStyle(color: Colors.red),
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '未実装機能 (${_pendingFeatures.length} 件)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      Text(name, style: const TextStyle(fontSize: 13)),
                      Text(
                        '${pct.round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                      backgroundColor: Colors.grey.withAlpha(40),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        pct >= 80
                            ? Colors.green
                            : pct >= 50
                                ? Color(0xFFF97316)
                                : Colors.red,
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
