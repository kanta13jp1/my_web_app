import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// バイラル広告キャンペーンページ
/// 直接呼び出し: viral-ad-generator (プレビュー), viral-growth-pipeline (実行)
/// x-media-post は viral-growth-pipeline のサーバーサイド内部で呼び出される
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
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'viral-growth-pipeline',
        method: HttpMethod.get,
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['runs'] is List) {
        setState(() {
          _recentRuns = (data['runs'] as List).cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      // 履歴取得失敗は無視
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
        'viral-ad-generator',
        body: {'template': _selectedTemplate},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == true) {
        setState(() {
          _tweetText = data['tweetText']?.toString();
          _svgPreview = data['svg']?.toString();
        });
      } else {
        setState(() => _errorMessage = (data as Map<String, dynamic>?)?['error']?.toString() ?? 'プレビュー失敗');
      }
    } catch (e) {
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
        'viral-growth-pipeline',
        body: {
          'action': 'run_campaign',
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
          setState(() => _errorMessage = data['error']?.toString() ?? 'キャンペーン失敗');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'キャンペーンエラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            // Template selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '広告テンプレート',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade100,
                        ),
                        child: const Center(
                          child: Text(
                            'SVG 生成済み\n(フロントエンドでの SVG 描画は\nwebview_flutter 等で対応)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
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
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _tweetText!,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_tweetText!.length}/280文字',
                        style: TextStyle(
                          fontSize: 12,
                          color: _tweetText!.length > 280
                              ? Colors.red
                              : Colors.grey,
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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: Colors.green),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                _isDryRun ? Icons.science : Icons.send,
                              ),
                        label: Text(
                          _isDryRun ? 'ドライランで実行' : 'X に投稿する',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isDryRun ? Colors.orange : Colors.blue,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._recentRuns.take(5).map((run) {
                final status = run['status']?.toString() ?? '';
                final template = run['template']?.toString() ?? '';
                final createdAt = run['created_at']?.toString() ?? '';
                final tweetId = run['tweet_id']?.toString();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      status == 'success'
                          ? Icons.check_circle
                          : status == 'dry_run'
                              ? Icons.science
                              : Icons.error,
                      color: status == 'success'
                          ? Colors.green
                          : status == 'dry_run'
                              ? Colors.orange
                              : Colors.red,
                    ),
                    title: Text(template),
                    subtitle: Text(
                      '${createdAt.length > 16 ? createdAt.substring(0, 16) : createdAt}'
                      '${tweetId != null ? '  •  ID: $tweetId' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: status == 'success'
                            ? Colors.green.shade100
                            : status == 'dry_run'
                                ? Colors.orange.shade100
                                : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'success'
                              ? Colors.green.shade700
                              : status == 'dry_run'
                                  ? Colors.orange.shade700
                                  : Colors.red.shade700,
                        ),
                      ),
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
