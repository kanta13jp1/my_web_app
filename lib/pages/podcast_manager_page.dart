import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// ポッドキャスト管理ページ
/// エピソード一覧・再生状態・チャンネル管理。
/// podcast-manager Edge Function と連携。
class PodcastManagerPage extends StatefulWidget {
  const PodcastManagerPage({super.key});

  @override
  State<PodcastManagerPage> createState() => _PodcastManagerPageState();
}

class _PodcastManagerPageState extends State<PodcastManagerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs => const <String>['episodes', 'channels'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _channels = [];
  String? _playingId;

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
      final epRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'podcast.episodes'},
      );
      final chRes = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'podcast.channels'},
      );
      setState(() {
        _episodes = _toList(epRes.data, 'episodes');
        _channels = _toList(chRes.data, 'channels');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('ポッドキャスト'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.podcasts),
              text: 'エピソード (${_episodes.length})',
            ),
            const Tab(icon: Icon(Icons.rss_feed), text: 'チャンネル'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildEpisodesTab(), _buildChannelsTab()],
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

  Widget _buildEpisodesTab() {
    if (_episodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.podcasts, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'エピソードがありません',
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
      itemCount: _episodes.length,
      itemBuilder: (ctx, i) {
        final ep = _episodes[i];
        final id = ep['id'] as String? ?? '$i';
        final title = ep['title'] as String? ?? 'エピソード ${i + 1}';
        final channel = ep['channelName'] as String? ?? '';
        final duration = ep['duration'] as String? ?? '';
        final listened = ep['listened'] as bool? ?? false;
        final isPlaying = _playingId == id;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: isPlaying
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: isPlaying ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                ),
                if (listened)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: listened ? const Color(0xFF9CA3AF) : null,
                height: 1.5,
              ),
            ),
            subtitle: Text(channel.isNotEmpty ? channel : '—'),
            trailing: Text(
              duration,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
                height: 1.5,
              ),
            ),
            onTap: () => setState(() {
              _playingId = isPlaying ? null : id;
            }),
          ),
        );
      },
    );
  }

  Widget _buildChannelsTab() {
    if (_channels.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rss_feed, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'チャンネルがありません',
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
      itemCount: _channels.length,
      itemBuilder: (ctx, i) {
        final ch = _channels[i];
        final name = ch['name'] as String? ?? 'チャンネル ${i + 1}';
        final author = ch['author'] as String? ?? '';
        final episodeCount = ch['episodeCount'] as int? ?? 0;
        final subscribed = ch['subscribed'] as bool? ?? false;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFE1BEE7),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            subtitle: Text(author.isNotEmpty ? author : '$episodeCount エピソード'),
            trailing: Chip(
              label: Text(subscribed ? '購読中' : '未購読'),
              backgroundColor: subscribed ? const Color(0xFFF3E5F5) : null,
            ),
          ),
        );
      },
    );
  }
}
