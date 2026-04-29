import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// バイラル広告キャンペーンページ
/// 直接呼び出し: growth-hub (プレビュー・実行)
/// viral-ad-generator, viral-growth-engine は growth-hub に統合済み
class ViralAdCampaignPage extends StatefulWidget {
  const ViralAdCampaignPage({super.key});

  @override
  State<ViralAdCampaignPage> createState() => _ViralAdCampaignPageState();
}

class _ViralAdCampaignPageState extends State<ViralAdCampaignPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _isDryRun = true;
  String _selectedTemplate = 'growth_stats';
  String? _svgPreview;
  String? _tweetText;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _recentRuns = [];
  Map<String, dynamic>? _stats;

  static const _templates = [
    ('growth_stats', '成長統計カード', Icons.bar_chart),
    ('dark_war', 'ダークウォー衝撃スタイル', Icons.local_fire_department),
    ('vs_notion', 'Notion 比較表', Icons.compare_arrows),
    ('ai_secretary', 'AI秘書・ターミナル', Icons.terminal),
    ('feature_highlight', '機能ハイライト', Icons.stars),
    ('milestone', 'マイルストーン達成', Icons.emoji_events),
  ];

  @override
  void initState() {
    super.initState();
    _fetchRecentRuns();
  }

  Future<void> _fetchRecentRuns() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.functions.invoke(
          'growth-hub',
          body: {'action': 'viral.list'},
        ),
        _supabase.functions.invoke(
          'growth-hub',
          body: {'action': 'engine.stats'},
        ),
      ]);
      final runsData = results[0].data;
      if (runsData is Map<String, dynamic> && runsData['runs'] is List) {
        setState(() {
          _recentRuns = (runsData['runs'] as List).cast<Map<String, dynamic>>();
        });
      }
      final statsData = results[1].data;
      if (statsData is Map<String, dynamic> && statsData['stats'] != null) {
        setState(() => _stats = statsData['stats'] as Map<String, dynamic>);
      }
    } catch (e) {
      // 取得失敗は無視
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _previewAd() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _svgPreview = null;
      _tweetText = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'viral_ad.create', 'template': _selectedTemplate},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        setState(() {
          _tweetText = data['tweetText']?.toString();
          _svgPreview = data['svg']?.toString();
        });
      } else {
        setState(
          () => _errorMessage =
              (data as Map<String, dynamic>?)?['error']?.toString() ??
                  'プレビュー失敗',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'プレビュー取得エラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runCampaign() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'growth-hub',
        body: {
          'action': 'engine.run',
          'template': _selectedTemplate,
          'dryRun': _isDryRun,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == true) {
          setState(() {
            _successMessage = _isDryRun
                ? 'ドライラン完了 — 実際には投稿されませんでした'
                : 'X に投稿しました！ tweetId: ${data['tweetId'] ?? '-'}';
            _svgPreview = data['svgPreview'] != null
                ? (data['svgPreview'] as String).replaceFirst(
                    'data:image/svg+xml;base64,',
                    '',
                  )
                : _svgPreview;
            _tweetText = data['tweetText']?.toString() ?? _tweetText;
          });
          _fetchRecentRuns();
        } else {
          setState(
            () => _errorMessage = data['error']?.toString() ?? 'キャンペーン失敗',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'キャンペーンエラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _metricBadge(BuildContext context, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    final s = _stats!;
    final total = s['total_campaigns'] as int? ?? 0;
    final success = s['successful_tweets'] as int? ?? 0;
    final byTemplate = s['by_template'] as Map<String, dynamic>? ?? {};
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '効果測定',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(context, '総実行', '$total'),
                const SizedBox(width: 8),
                _statChip(
                  context,
                  '投稿成功',
                  '$success',
                  highlight: success > 0,
                ),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  _statChip(
                    context,
                    '成功率',
                    '${(success / total * 100).toStringAsFixed(0)}%',
                    highlight: success / total >= 0.8,
                  ),
                ],
              ],
            ),
            if (byTemplate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: byTemplate.entries
                    .map(
                      (e) => Chip(
                        label: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statChip(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFFF6B35).withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? const Color(0xFFFF6B35) : null,
              height: 1.5,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('バイラルキャンペーン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchRecentRuns,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats summary
            if (_stats != null) ...[
              _buildStatsCard(context),
              const SizedBox(height: 12),
            ],
            // Template selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '広告テンプレート',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _templates.map((t) {
                        final (id, label, icon) = t;
                        final selected = _selectedTemplate == id;
                        return FilterChip(
                          avatar: Icon(icon, size: 16),
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) =>
                              setState(() => _selectedTemplate = id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _previewAd,
                            icon: const Icon(Icons.preview),
                            label: const Text('プレビュー'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // SVG preview
            if (_svgPreview != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '広告プレビュー (SVG)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                        ),
                        child: Center(
                          child: Text(
                            'SVG 生成済み\n(フロントエンドでの SVG 描画は\nwebview_flutter 等で対応)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Tweet text preview
            if (_tweetText != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ツイートテキスト',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tweetText!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tweetText!.length}/280文字',
                        style: TextStyle(
                          fontSize: 12,
                          color: _tweetText!.length > 280
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Post controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'キャンペーン実行',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('ドライラン'),
                      subtitle: const Text('ON: 実際には投稿しない (テスト)'),
                      value: _isDryRun,
                      onChanged: (v) => setState(() => _isDryRun = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            height: 1.5,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _runCampaign,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _isDryRun ? Icons.science : Icons.send,
                              ),
                        label: Text(
                          _isDryRun ? 'ドライランで実行' : 'X に投稿する',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDryRun
                              ? const Color(0xFFFF6B35)
                              : const Color(0xFF3D5AFE),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recent runs
            if (_recentRuns.isNotEmpty) ...[
              const Text(
                '直近のキャンペーン実行',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._recentRuns.take(5).map((run) {
                final status = run['status']?.toString() ?? '';
                final template = run['template']?.toString() ?? '';
                final createdAt = run['created_at']?.toString() ?? '';
                final tweetId = run['tweet_id']?.toString();
                final impressions = run['impressions'] as int?;
                final clicks = run['clicks'] as int?;
                final follows = run['new_follows'] as int?;
                final hasMetrics =
                    impressions != null || clicks != null || follows != null;
                final statusColor = status == 'success'
                    ? const Color(0xFF4CAF50)
                    : status == 'dry_run'
                        ? const Color(0xFFFF6B35)
                        : Theme.of(context).colorScheme.error;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              status == 'success'
                                  ? Icons.check_circle
                                  : status == 'dry_run'
                                      ? Icons.science
                                      : Icons.error,
                              color: statusColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(template)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: statusColor,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${createdAt.length > 16 ? createdAt.substring(0, 16) : createdAt}'
                          '${tweetId != null ? '  •  ID: $tweetId' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        if (hasMetrics) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (impressions != null)
                                _metricBadge(
                                  context,
                                  Icons.visibility,
                                  '$impressions',
                                ),
                              if (clicks != null) ...[
                                const SizedBox(width: 6),
                                _metricBadge(
                                  context,
                                  Icons.touch_app,
                                  '$clicks',
                                ),
                              ],
                              if (follows != null) ...[
                                const SizedBox(width: 6),
                                _metricBadge(
                                  context,
                                  Icons.person_add,
                                  '+$follows',
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
