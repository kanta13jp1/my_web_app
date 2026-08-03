import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// YouTube 動画統計インポート・管理ページ (/youtube-stats)
///
/// TSV 形式の YouTube アナリティクスデータを貼り付けてインポートし、
/// youtube_video_stats テーブルで管理する。
/// 統計を複数スナップショット日で比較表示する。

enum _SortMode { views, growth, engagement }

class YoutubeStatsPage extends StatefulWidget {
  const YoutubeStatsPage({super.key});

  @override
  State<YoutubeStatsPage> createState() => _YoutubeStatsPageState();
}

class _YoutubeStatsPageState extends State<YoutubeStatsPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['import', 'stats'];

  @override
  TabController get tabUrlController => _tabController;

  late TabController _tabController;
  bool _importing = false;
  String? _importResult;
  bool _importSuccess = false;

  // Import form
  final TextEditingController _tsvController = TextEditingController();
  final TextEditingController _channelHandleController =
      TextEditingController(text: '@DPFP_sub');
  final TextEditingController _snapshotDateController =
      TextEditingController(text: _todayIso());
  final TextEditingController _subscriberCountController =
      TextEditingController();

  // Stats list
  bool _loadingStats = true;
  List<Map<String, dynamic>> _stats = [];
  List<String> _channels = [];
  String _selectedChannel = '';
  _SortMode _sortMode = _SortMode.views;
  // url → previous snapshot row (for growth delta)
  Map<String, Map<String, dynamic>> _prevSnapshot = {};

  static String _todayIso() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tsvController.dispose();
    _channelHandleController.dispose();
    _snapshotDateController.dispose();
    _subscriberCountController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('youtube_video_stats')
          .select(
            'channel_handle, video_url, title, video_type, snapshot_date, views, likes, comments',
          )
          .order('snapshot_date', ascending: false)
          .order('views', ascending: false)
          .limit(500);

      final rows = List<Map<String, dynamic>>.from(data as List);
      final channels = rows
          .map((r) => r['channel_handle']?.toString() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      // 直近2スナップショット日を特定して成長デルタ用マップを構築
      final allDates = rows
          .map((r) => r['snapshot_date']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      final prevMap = <String, Map<String, dynamic>>{};
      if (allDates.length >= 2) {
        final prevDate = allDates[1];
        for (final row in rows) {
          if (row['snapshot_date'] == prevDate) {
            final url = row['video_url']?.toString() ?? '';
            if (url.isNotEmpty) prevMap[url] = row;
          }
        }
      }

      if (mounted) {
        setState(() {
          _stats = rows;
          _channels = channels;
          _prevSnapshot = prevMap;
          if (_selectedChannel.isEmpty && channels.isNotEmpty) {
            _selectedChannel = channels.first;
          }
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  /// TSV を parse して youtube_video_stats に upsert
  Future<void> _importTsv() async {
    final tsv = _tsvController.text.trim();
    if (tsv.isEmpty) {
      _setResult('TSVデータを貼り付けてください', false);
      return;
    }

    final channelHandle = _channelHandleController.text.trim();
    final snapshotDate = _snapshotDateController.text.trim();
    if (channelHandle.isEmpty) {
      _setResult('チャンネルハンドルを入力してください', false);
      return;
    }

    setState(() => _importing = true);

    try {
      final records = _parseTsv(tsv, channelHandle, snapshotDate);
      if (records.isEmpty) {
        _setResult('解析できる行が0件でした。TSV形式を確認してください', false);
        setState(() => _importing = false);
        return;
      }

      final supabase = Supabase.instance.client;

      // subscriber_count の更新（任意）
      final subCount = int.tryParse(
        _subscriberCountController.text.trim().replaceAll(',', ''),
      );
      if (subCount != null) {
        await supabase.from('youtube_channels').upsert(
          {
            'channel_handle': channelHandle,
            'subscriber_count': subCount,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'channel_handle',
        );
      }

      // バッチ upsert (50件ずつ)
      int total = 0;
      for (var i = 0; i < records.length; i += 50) {
        final batch = records.sublist(
          i,
          i + 50 > records.length ? records.length : i + 50,
        );
        await supabase.from('youtube_video_stats').upsert(
              batch,
              onConflict: 'video_url,snapshot_date',
            );
        total += batch.length;
      }

      // 検出されたスナップショット日数を表示
      final detectedDates = records
          .map((r) => r['snapshot_date']?.toString() ?? '')
          .toSet()
        ..remove('');
      final dateInfo = detectedDates.length > 1
          ? ' (${detectedDates.length}スナップショット日を自動検出)'
          : ' (${detectedDates.firstOrNull ?? snapshotDate})';
      _setResult('✅ $total 件をインポートしました$dateInfo', true);
      await _loadStats();
      _tsvController.clear();
      _tabController.animateTo(1);
    } catch (e) {
      _setResult('エラー: $e', false);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// RFC 4180 準拠: ダブルクォート内の改行を空白に置換してから行分割できるよう前処理
  static String _mergeQuotedLines(String tsv) {
    final buf = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < tsv.length; i++) {
      final c = tsv[i];
      if (c == '"') {
        inQuote = !inQuote;
        buf.write(c);
      } else if (c == '\n' && inQuote) {
        buf.write(' '); // quoted 改行 → スペースに置換
      } else {
        buf.write(c);
      }
    }
    return buf.toString();
  }

  /// "2026/4/2" → "2026-04-02"
  static String _normalizeDate(String d) {
    final parts = d.split('/');
    if (parts.length == 3) {
      return '${parts[0].padLeft(4, '0')}-'
          '${parts[1].padLeft(2, '0')}-'
          '${parts[2].padLeft(2, '0')}';
    }
    return d;
  }

  List<Map<String, dynamic>> _parseTsv(
    String tsv,
    String channelHandle,
    String snapshotDate,
  ) {
    final merged = _mergeQuotedLines(tsv);
    final lines = merged.split('\n').map((l) => l.trimRight()).toList();
    final records = <Map<String, dynamic>>[];

    // マルチスナップショット形式を検出:
    // 「URL / 種別 / 投稿日 / 出演者 / 2026/M/D ...」のヘッダー行を探す
    List<String>? snapshotDates; // スナップショット日付リスト (col 6 から3列ずつ)

    for (final line in lines) {
      if (line.isEmpty) continue;
      final cols = line.split('\t');

      // 日付ヘッダー行: "2026/" を含む列がある
      if (snapshotDates == null &&
          cols.any((c) => c.trim().contains('2026/'))) {
        snapshotDates = [];
        for (var i = 6; i < cols.length; i += 3) {
          final d = cols[i].trim();
          if (d.isNotEmpty) snapshotDates.add(_normalizeDate(d));
        }
        continue;
      }

      // 先頭が行番号（数字）かチェック
      final firstCol = cols[0].trim();
      if (int.tryParse(firstCol) == null) continue; // ヘッダー/空行はスキップ
      if (cols.length < 6) continue;

      final url = cols[1].trim();
      final type = cols[2].trim();
      final publishedAt = cols[3].trim();
      final title = cols[4].trim();
      final performers = cols[5].trim().replaceAll('"', '');

      if (url.isEmpty || !url.startsWith('http')) continue;

      if (snapshotDates != null && snapshotDates.isNotEmpty) {
        // マルチスナップショット: 各日付ごとにレコードを生成
        for (var i = 0; i < snapshotDates.length; i++) {
          final baseCol = 6 + i * 3;
          if (baseCol + 2 >= cols.length) break;
          final comments = _parseInt(cols[baseCol]);
          final likes = _parseInt(cols[baseCol + 1]);
          final views = _parseInt(cols[baseCol + 2]);
          if (views == 0) continue; // データ未収録スナップショットをスキップ
          records.add({
            'channel_handle': channelHandle,
            'video_url': url,
            'video_type': type,
            'published_at': publishedAt,
            'title': title,
            'performers': performers,
            'snapshot_date': snapshotDates[i],
            'views': views,
            'likes': likes,
            'comments': comments,
          });
        }
      } else {
        // シングルスナップショット: 最後の3カラムを使用
        final numCols = cols.length;
        int views = 0, likes = 0, comments = 0;
        if (numCols >= 9) {
          comments = _parseInt(cols[numCols - 3]);
          likes = _parseInt(cols[numCols - 2]);
          views = _parseInt(cols[numCols - 1]);
        }
        records.add({
          'channel_handle': channelHandle,
          'video_url': url,
          'video_type': type,
          'published_at': publishedAt,
          'title': title,
          'performers': performers,
          'snapshot_date': snapshotDate,
          'views': views,
          'likes': likes,
          'comments': comments,
        });
      }
    }
    return records;
  }

  int _parseInt(String s) {
    return int.tryParse(s.trim().replaceAll(',', '')) ?? 0;
  }

  void _setResult(String msg, bool success) {
    if (mounted) {
      setState(() {
        _importResult = msg;
        _importSuccess = success;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube 統計管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: '@DPFP_sub チャンネルを開く',
            onPressed: () => launchUrl(
              Uri.parse('https://www.youtube.com/@DPFP_sub'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'TSVインポート'),
            Tab(icon: Icon(Icons.bar_chart), text: '統計一覧'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildImportTab(isDark),
          _buildStatsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildImportTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 説明
          Card(
            elevation: 0,
            color: const Color(0xFF3D5AFE).withAlpha(15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: const Color(0xFF3D5AFE).withAlpha(40)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TSV インポート手順',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '1. YouTube Studio → アナリティクス → コンテンツ\n'
                    '2. 動画一覧テーブルをコピー（Ctrl+A → Ctrl+C）\n'
                    '3. 下のテキストエリアに貼り付け\n'
                    '4. 列の形式: 行番号 | URL | 種別 | 投稿日 | タイトル | 出演者 | [コメント | 高評価 | 視聴回数]\n'
                    '💡 複数日付ヘッダー付きの TSV は全スナップショット日を自動検出してまとめてインポートします',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // チャンネル・日付入力
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _channelHandleController,
                  decoration: const InputDecoration(
                    labelText: 'チャンネルハンドル',
                    hintText: '@DPFP_sub',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _snapshotDateController,
                  decoration: const InputDecoration(
                    labelText: 'スナップショット日 (YYYY-MM-DD) ※複数日付TSVは自動検出',
                    hintText: '2026-04-10',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _subscriberCountController,
                  decoration: const InputDecoration(
                    labelText: 'チャンネル登録者数 (任意)',
                    hintText: '13200',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // TSVテキストエリア
          TextField(
            controller: _tsvController,
            maxLines: 14,
            decoration: InputDecoration(
              labelText: 'TSVデータ貼り付け',
              hintText:
                  '1\thttps://www.youtube.com/...\t動画\t3週間前\tタイトル\t出演者\t148\t1018\t8094',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
            ),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // インポートボタン
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _importing ? null : _importTsv,
              icon: _importing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload),
              label: Text(_importing ? 'インポート中...' : 'TSVをインポート'),
            ),
          ),

          // 結果表示
          if (_importResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _importSuccess
                    ? const Color(0xFF4CAF50).withAlpha(20)
                    : const Color(0xFFE53935).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _importSuccess
                      ? const Color(0xFF4CAF50).withAlpha(60)
                      : const Color(0xFFE53935).withAlpha(60),
                ),
              ),
              child: Text(
                _importResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _importSuccess
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsTab(bool isDark) {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            const Text('統計データがありません'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: const Icon(Icons.upload_file),
              label: const Text('TSVをインポートする'),
            ),
          ],
        ),
      );
    }

    // チャンネルフィルター
    final filtered = _selectedChannel.isEmpty
        ? _stats
        : _stats.where((r) => r['channel_handle'] == _selectedChannel).toList();

    // スナップショット日付一覧
    final dates = filtered
        .map((r) => r['snapshot_date']?.toString() ?? '')
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final latestDate = dates.isNotEmpty ? dates.first : '';

    // 最新スナップショットの統計
    var latestRows =
        filtered.where((r) => r['snapshot_date'] == latestDate).toList();

    // サマリー計算
    int totalViews = 0, totalLikes = 0, totalGrowth = 0;
    for (final r in latestRows) {
      final url = r['video_url']?.toString() ?? '';
      final views = r['views'] as int? ?? 0;
      final likes = r['likes'] as int? ?? 0;
      totalViews += views;
      totalLikes += likes;
      final prevViews = _prevSnapshot[url]?['views'] as int? ?? 0;
      if (prevViews > 0) totalGrowth += (views - prevViews);
    }

    // ソート
    latestRows = List.of(latestRows);
    switch (_sortMode) {
      case _SortMode.views:
        latestRows.sort(
          (a, b) =>
              ((b['views'] as int? ?? 0)).compareTo(a['views'] as int? ?? 0),
        );
      case _SortMode.growth:
        latestRows.sort((a, b) {
          final urlA = a['video_url']?.toString() ?? '';
          final urlB = b['video_url']?.toString() ?? '';
          final dA = (a['views'] as int? ?? 0) -
              (_prevSnapshot[urlA]?['views'] as int? ?? 0);
          final dB = (b['views'] as int? ?? 0) -
              (_prevSnapshot[urlB]?['views'] as int? ?? 0);
          return dB.compareTo(dA);
        });
      case _SortMode.engagement:
        latestRows.sort((a, b) {
          final vA = a['views'] as int? ?? 0;
          final vB = b['views'] as int? ?? 0;
          final eA = vA > 0 ? (a['likes'] as int? ?? 0) / vA : 0.0;
          final eB = vB > 0 ? (b['likes'] as int? ?? 0) / vB : 0.0;
          return eB.compareTo(eA);
        });
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // チャンネル選択
                  if (_channels.length > 1)
                    Wrap(
                      spacing: 8,
                      children: _channels.map((c) {
                        final active = _selectedChannel == c;
                        return FilterChip(
                          label: Text(c),
                          selected: active,
                          onSelected: (_) =>
                              setState(() => _selectedChannel = c),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 12),

                  // サマリーカード
                  Row(
                    children: [
                      _summaryTile(
                        '動画数',
                        '${latestRows.length}',
                        const Color(0xFF3D5AFE),
                      ),
                      const SizedBox(width: 8),
                      _summaryTile(
                        '総視聴',
                        _fmtK(totalViews),
                        const Color(0xFFE53935),
                      ),
                      const SizedBox(width: 8),
                      _summaryTile(
                        '高評価',
                        _fmtK(totalLikes),
                        const Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 8),
                      _summaryTile(
                        '成長',
                        totalGrowth > 0 ? '+${_fmtK(totalGrowth)}' : '-',
                        const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    '最新: $latestDate  |  全${filtered.length}件  |  ${dates.length}スナップショット',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ソート切り替え
                  Row(
                    children: [
                      Text(
                        'ソート: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ..._SortMode.values.map((mode) {
                        final labels = {
                          _SortMode.views: '視聴数',
                          _SortMode.growth: '成長数',
                          _SortMode.engagement: 'エンゲージメント',
                        };
                        final active = _sortMode == mode;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              labels[mode]!,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                            selected: active,
                            onSelected: (_) => setState(() => _sortMode = mode),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final row = latestRows[index];
                final url = row['video_url']?.toString() ?? '';
                final type = row['video_type']?.toString() ?? '';
                final title = row['title']?.toString() ?? '';
                final views = row['views'] as int? ?? 0;
                final likes = row['likes'] as int? ?? 0;
                final comments = row['comments'] as int? ?? 0;

                // 成長デルタ
                final prevViews = _prevSnapshot[url]?['views'] as int? ?? 0;
                final delta = prevViews > 0 ? views - prevViews : 0;

                // エンゲージメント率
                final engRate = views > 0 ? (likes / views * 100) : 0.0;

                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _typeColor(type).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        _typeLabel(type),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _typeColor(type),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        '視聴 ${_fmtK(views)}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      if (delta > 0)
                        Text(
                          '+${_fmtK(delta)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      Text(
                        '♥${_fmtK(likes)}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '💬${_fmtK(comments)}',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        'EG ${engRate.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: engRate >= 5
                              ? const Color(0xFFFF6B35)
                              : isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF4B5563),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  trailing: url.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          onPressed: () => launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          ),
                        )
                      : null,
                );
              },
              childCount: latestRows.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.5,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtK(int v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ショート':
        return const Color(0xFFE53935);
      case 'ライブ':
        return const Color(0xFF3D5AFE);
      default:
        return const Color(0xFFFF6B35);
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
