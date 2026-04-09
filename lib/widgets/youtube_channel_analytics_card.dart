import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// YouTube チャンネル分析カード
///
/// `youtube_video_stats` テーブルから動画統計（視聴回数・高評価・コメント）を
/// 複数スナップショット日付で比較表示する。
/// チャンネル: 国民民主党サブチャンネル (@DPFP_sub)
class YoutubeChannelAnalyticsCard extends StatefulWidget {
  final String channelHandle;
  final String channelName;
  final String? channelUrl;

  const YoutubeChannelAnalyticsCard({
    super.key,
    this.channelHandle = '@DPFP_sub',
    this.channelName = '国民民主党サブチャンネル',
    this.channelUrl,
  });

  @override
  State<YoutubeChannelAnalyticsCard> createState() =>
      _YoutubeChannelAnalyticsCardState();
}

class _YoutubeChannelAnalyticsCardState
    extends State<YoutubeChannelAnalyticsCard> {
  bool _loading = true;
  List<_VideoRow> _videos = [];
  List<String> _snapshotDates = [];
  String? _error;
  bool _expanded = false;
  String _sortBy = 'views'; // views / likes / comments / growth

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      // youtube_video_stats テーブルから取得
      final data = await supabase
          .from('youtube_video_stats')
          .select(
            'video_url, video_type, published_at, title, performers, '
            'snapshot_date, comments, likes, views',
          )
          .eq('channel_handle', widget.channelHandle)
          .order('snapshot_date', ascending: false)
          .order('video_url')
          .limit(500);

      final rows = List<Map<String, dynamic>>.from(data as List);
      if (rows.isEmpty) {
        if (mounted) {
          setState(() {
            _videos = [];
            _snapshotDates = [];
            _loading = false;
          });
        }
        return;
      }

      // スナップショット日付一覧 (最新3日分)
      final dates = rows
          .map((r) => r['snapshot_date']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      final latestDates = dates.take(3).toList();

      // video_url ごとにグループ化
      final Map<String, _VideoRow> byUrl = {};
      for (final r in rows) {
        final url = r['video_url']?.toString() ?? '';
        final date = r['snapshot_date']?.toString() ?? '';
        if (url.isEmpty || date.isEmpty) continue;
        if (!latestDates.contains(date)) continue;

        byUrl.putIfAbsent(
          url,
          () => _VideoRow(
            url: url,
            type: r['video_type']?.toString() ?? '',
            publishedAt: r['published_at']?.toString() ?? '',
            title: r['title']?.toString() ?? '',
            performers: r['performers']?.toString() ?? '',
          ),
        );
        byUrl[url]!.snapshots[date] = _Snapshot(
          views: _parseInt(r['views']),
          likes: _parseInt(r['likes']),
          comments: _parseInt(r['comments']),
        );
      }

      final videoList = byUrl.values.toList();
      _sortVideos(videoList, _sortBy, latestDates);

      if (mounted) {
        setState(() {
          _videos = videoList;
          _snapshotDates = latestDates;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _sortVideos(
    List<_VideoRow> list,
    String sortBy,
    List<String> dates,
  ) {
    final latestDate = dates.isNotEmpty ? dates.first : '';
    list.sort((a, b) {
      final sa = a.snapshots[latestDate];
      final sb = b.snapshots[latestDate];
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      switch (sortBy) {
        case 'likes':
          return sb.likes.compareTo(sa.likes);
        case 'comments':
          return sb.comments.compareTo(sa.comments);
        case 'growth':
          final prev = dates.length > 1 ? dates[1] : '';
          final ga = prev.isNotEmpty
              ? (a.snapshots[prev] != null
                  ? sa.views - a.snapshots[prev]!.views
                  : 0)
              : sa.views;
          final gb = prev.isNotEmpty
              ? (b.snapshots[prev] != null
                  ? sb.views - b.snapshots[prev]!.views
                  : 0)
              : sb.views;
          return gb.compareTo(ga);
        default: // views
          return sb.views.compareTo(sa.views);
      }
    });
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ─── ヘッダー ───
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline,
                      size: 20,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YouTube チャンネル分析',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.channelName}  ${widget.channelHandle}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.channelUrl != null)
                    Tooltip(
                      message: 'チャンネルを開く',
                      child: IconButton(
                        icon: const Icon(Icons.open_in_new, size: 16),
                        onPressed: () => launchUrl(
                          Uri.parse(widget.channelUrl!),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: _loadData,
                    tooltip: '更新',
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    _buildError()
                  else if (_videos.isEmpty)
                    _buildEmpty()
                  else
                    _buildContent(isDark),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'データ取得エラー: $_error',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.upload_file, color: Colors.orange, size: 32),
          const SizedBox(height: 8),
          const Text(
            'データがありません',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'youtube_video_stats テーブルにデータをインポートしてください。\n'
            'TSV形式のYouTubeアナリティクスデータを管理者ページからアップロードできます。',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    final latestDate =
        _snapshotDates.isNotEmpty ? _snapshotDates.first : '';
    final prevDate =
        _snapshotDates.length > 1 ? _snapshotDates[1] : '';

    // サマリー統計
    int totalViews = 0;
    int totalLikes = 0;
    int totalViewsGrowth = 0;
    for (final v in _videos) {
      final latest = v.snapshots[latestDate];
      final prev = prevDate.isNotEmpty ? v.snapshots[prevDate] : null;
      if (latest != null) {
        totalViews += latest.views;
        totalLikes += latest.likes;
        if (prev != null) totalViewsGrowth += latest.views - prev.views;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── サマリーバー ───
        Row(
          children: [
            _buildSummaryChip(
              '動画数',
              '${_videos.length}本',
              Colors.blue,
            ),
            const SizedBox(width: 8),
            _buildSummaryChip(
              '総視聴',
              _formatK(totalViews),
              Colors.red,
            ),
            const SizedBox(width: 8),
            _buildSummaryChip(
              '高評価',
              _formatK(totalLikes),
              Colors.orange,
            ),
            if (prevDate.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildSummaryChip(
                '視聴数増加',
                '+${_formatK(totalViewsGrowth)}',
                Colors.green,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // ─── ソート切替 ───
        Row(
          children: [
            Text(
              'ソート:',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 8),
            ...['views', 'likes', 'comments', 'growth'].map((s) {
              final labels = {
                'views': '視聴数',
                'likes': '高評価',
                'comments': 'コメント',
                'growth': '増加数',
              };
              final active = _sortBy == s;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _sortBy = s;
                      _sortVideos(_videos, s, _snapshotDates);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF6366F1).withAlpha(30)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: active
                            ? const Color(0xFF6366F1)
                            : Colors.grey.withAlpha(60),
                      ),
                    ),
                    child: Text(
                      labels[s]!,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                        color: active
                            ? const Color(0xFF6366F1)
                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 8),

        // ─── スナップショット日付ヘッダー ───
        if (_snapshotDates.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '動画タイトル',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ),
                ..._snapshotDates.take(3).map(
                  (d) => SizedBox(
                    width: 72,
                    child: Text(
                      _formatDate(d),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ─── 動画一覧 ───
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _videos.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, thickness: 0.5),
          itemBuilder: (context, index) =>
              _buildVideoRow(_videos[index], isDark),
        ),
      ],
    );
  }

  Widget _buildVideoRow(_VideoRow video, bool isDark) {
    final latestDate =
        _snapshotDates.isNotEmpty ? _snapshotDates.first : '';
    final prevDate =
        _snapshotDates.length > 1 ? _snapshotDates[1] : '';
    final latest = video.snapshots[latestDate];
    final prev = prevDate.isNotEmpty ? video.snapshots[prevDate] : null;
    final viewGrowth =
        (latest != null && prev != null) ? latest.views - prev.views : null;

    final typeColor = _typeColor(video.type);
    final typeLabel = _typeLabel(video.type);

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: video.url.isNotEmpty
          ? () => launchUrl(
                Uri.parse(video.url),
                mode: LaunchMode.externalApplication,
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タイプバッジ
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: typeColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // タイトル・出演者
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (video.performers.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      video.performers.replaceAll('\n', ' / '),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (viewGrowth != null && viewGrowth > 0)
                    Text(
                      '▲+${_formatK(viewGrowth)} 視聴増',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            // スナップショット値
            ..._snapshotDates.take(3).map((d) {
              final snap = video.snapshots[d];
              return SizedBox(
                width: 72,
                child: snap == null
                    ? const Center(
                        child: Text(
                          '—',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatK(snap.views),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          Text(
                            '♥${_formatK(snap.likes)}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  String _formatK(int v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    return iso.substring(5, 10).replaceAll('-', '/');
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ショート':
        return Colors.red;
      case 'ライブ':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'ショート':
        return 'Short';
      case 'ライブ':
        return 'Live';
      default:
        return '動画';
    }
  }
}

// ─────────────────────────────────────────────────────
// データモデル
// ─────────────────────────────────────────────────────

class _VideoRow {
  final String url;
  final String type;
  final String publishedAt;
  final String title;
  final String performers;
  final Map<String, _Snapshot> snapshots = {};

  _VideoRow({
    required this.url,
    required this.type,
    required this.publishedAt,
    required this.title,
    required this.performers,
  });
}

class _Snapshot {
  final int views;
  final int likes;
  final int comments;
  const _Snapshot({
    required this.views,
    required this.likes,
    required this.comments,
  });
}
