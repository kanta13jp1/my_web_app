import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 画面録画・スクリーンショット管理ページ
/// 録画一覧・スクリーンショット一覧・ダウンロード。
/// screen-recorder Edge Function と連携。
class ScreenRecorderPage extends StatefulWidget {
  const ScreenRecorderPage({super.key});

  @override
  State<ScreenRecorderPage> createState() => _ScreenRecorderPageState();
}

class _ScreenRecorderPageState extends State<ScreenRecorderPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['recordings', 'screenshots'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recordings = [];
  List<Map<String, dynamic>> _screenshots = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final recRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'recording.list'},
      );
      final ssRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'screenshot.list'},
      );
      setState(() {
        _recordings = _toList(recRes.data, 'recordings');
        _screenshots = _toList(ssRes.data, 'screenshots');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadRecording(Map<String, dynamic> recording) async {
    final rawUrl =
        recording['url'] ?? recording['download_url'] ?? recording['file_url'];
    if (rawUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ダウンロードURLが取得できませんでした')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(rawUrl.toString());
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data, String key) {
    if (data is Map<String, dynamic>) {
      final list = data[key];
      if (list is List) {
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('画面録画'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.videocam),
              text: '録画 (${_recordings.length})',
            ),
            Tab(
              icon: const Icon(Icons.screenshot),
              text: 'スクリーンショット (${_screenshots.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildRecordingsTab(), _buildScreenshotsTab()],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_errorMessage!),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchData, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildRecordingsTab() {
    if (_recordings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              '録画がありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _recordings.length,
      itemBuilder: (ctx, i) {
        final r = _recordings[i];
        final title = r['title'] as String? ?? '録画 ${i + 1}';
        final duration = r['duration'] as String? ?? '';
        final size = r['fileSize'] as String? ?? '';
        final date = r['createdAt'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.play_circle),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(
              [
                if (duration.isNotEmpty) duration,
                if (size.isNotEmpty) size,
              ].join(' · '),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (date.length >= 10)
                  Text(
                    date.substring(0, 10),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.download, size: 20),
                  onPressed: () => _downloadRecording(r),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreenshotsTab() {
    if (_screenshots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.screenshot, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'スクリーンショットがありません',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _screenshots.length,
      itemBuilder: (ctx, i) {
        final ss = _screenshots[i];
        final title = ss['title'] as String? ?? '${i + 1}';
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child:
                    const Icon(Icons.image, size: 40, color: Color(0xFF9CA3AF)),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      height: 1.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
