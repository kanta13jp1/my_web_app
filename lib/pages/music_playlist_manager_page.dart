import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 音楽プレイリスト管理ページ
/// ギター録音・音楽コレクション管理。
/// music-playlist-manager Edge Function と連携。
class MusicPlaylistManagerPage extends StatefulWidget {
  const MusicPlaylistManagerPage({super.key});

  @override
  State<MusicPlaylistManagerPage> createState() =>
      _MusicPlaylistManagerPageState();
}

class _MusicPlaylistManagerPageState extends State<MusicPlaylistManagerPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _playlists = [];
  Map<String, dynamic>? _selectedPlaylist;
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoadingTracks = false;

  final _playlistNameController = TextEditingController();
  final _trackTitleController = TextEditingController();
  final _trackArtistController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _trackTitleController.dispose();
    _trackArtistController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylists() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'playlist.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['playlists'];
        if (list is List) {
          setState(() {
            _playlists = list.map((p) => p as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTracks(String playlistId) async {
    setState(() => _isLoadingTracks = true);
    try {
      final res = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'playlist.tracks', 'playlist_id': playlistId},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['tracks'];
        if (list is List) {
          setState(() {
            _tracks = list.map((t) => t as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _tracks = []);
    } finally {
      if (mounted) setState(() => _isLoadingTracks = false);
    }
  }

  Future<void> _createPlaylist() async {
    final name = _playlistNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'playlist.create', 'name': name},
      );
      _playlistNameController.clear();
      await _fetchPlaylists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プレイリストを作成しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addTrack(String playlistId) async {
    final title = _trackTitleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _supabase.functions.invoke(
        'media-hub',
        body: {
          'action': 'playlist.add_track',
          'playlist_id': playlistId,
          'title': title,
          'artist': _trackArtistController.text.trim(),
        },
      );
      _trackTitleController.clear();
      _trackArtistController.clear();
      await _fetchTracks(playlistId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('曲を追加しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('音楽プレイリスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPlaylists,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _selectedPlaylist == null
                  ? _buildPlaylistList()
                  : _buildPlaylistDetail(),
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
          ElevatedButton(
            onPressed: _fetchPlaylists,
            child: const Text('再試行'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList() {
    return Column(
      children: [
        // 新規プレイリスト作成
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _playlistNameController,
                  decoration: const InputDecoration(
                    labelText: '新しいプレイリスト名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _createPlaylist,
                child: const Text('作成'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // プレイリスト一覧
        Expanded(
          child: _playlists.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.queue_music,
                        size: 64,
                        color: Color(0xFF9CA3AF),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'プレイリストがありません',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _playlists.length,
                  itemBuilder: (ctx, i) {
                    final p = _playlists[i];
                    final name = p['name'] as String? ?? 'プレイリスト';
                    final trackCount = p['trackCount'] as int? ?? 0;
                    final cover = p['coverEmoji'] as String? ?? '🎵';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE1BEE7),
                        child: Text(cover),
                      ),
                      title: Text(name),
                      subtitle: Text('$trackCount 曲'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        setState(() {
                          _selectedPlaylist = p;
                          _tracks = [];
                        });
                        _fetchTracks(p['id'] as String? ?? '');
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPlaylistDetail() {
    final playlist = _selectedPlaylist!;
    final name = playlist['name'] as String? ?? '';
    final playlistId = playlist['id'] as String? ?? '';

    return Column(
      children: [
        // ヘッダー
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedPlaylist = null),
              ),
              const Icon(Icons.queue_music, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 曲追加フォーム
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _trackTitleController,
                      decoration: const InputDecoration(
                        labelText: '曲名',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _trackArtistController,
                      decoration: const InputDecoration(
                        labelText: 'アーティスト',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _addTrack(playlistId),
                child: const Text('追加'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // トラック一覧
        Expanded(
          child: _isLoadingTracks
              ? const Center(child: CircularProgressIndicator())
              : _tracks.isEmpty
                  ? const Center(
                      child: Text(
                        'まだ曲がありません',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      itemCount: _tracks.length,
                      onReorder: (_, __) {},
                      itemBuilder: (ctx, i) {
                        final t = _tracks[i];
                        final title = t['title'] as String? ?? '';
                        final artist = t['artist'] as String? ?? '';
                        return ListTile(
                          key: ValueKey(t['id'] ?? i),
                          leading: CircleAvatar(
                            child: Text('${i + 1}'),
                          ),
                          title: Text(title),
                          subtitle: Text(artist),
                          trailing: const Icon(Icons.drag_handle),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
