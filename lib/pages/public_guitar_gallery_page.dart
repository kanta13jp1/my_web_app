import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 公開ギターレコーディングギャラリー
/// 全ユーザーの公開録音を一覧表示。いいね・再生数でソート可能。
/// guitar-recording-studio Edge Function の public_gallery アクションと連携。
class PublicGuitarGalleryPage extends StatefulWidget {
  const PublicGuitarGalleryPage({super.key});

  @override
  State<PublicGuitarGalleryPage> createState() =>
      _PublicGuitarGalleryPageState();
}

class _PublicGuitarGalleryPageState extends State<PublicGuitarGalleryPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _recordings = [];
  int _total = 0;
  int _offset = 0;
  static const int _limit = 20;
  String _sortBy = 'created_at'; // created_at | likes | plays
  final Set<String> _likedIds = {};
  final Set<String> _playingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchGallery(reset: true);
  }

  Future<void> _fetchGallery({bool reset = false}) async {
    if (_supabase.auth.currentUser == null) return;
    if (_isLoading) return;
    final nextOffset = reset ? 0 : _offset;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (reset) {
        _recordings = [];
        _offset = 0;
      }
    });
    try {
      final res = await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {
          'action': 'public_gallery',
          'limit': _limit,
          'offset': nextOffset,
          'sortBy': _sortBy,
        },
      );
      final data = res.data as Map<String, dynamic>?;
      final items =
          (data?['recordings'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final total = (data?['total'] as num?)?.toInt() ?? 0;
      setState(() {
        if (reset) {
          _recordings = items;
        } else {
          _recordings = [..._recordings, ...items];
        }
        _total = total;
        _offset = nextOffset + items.length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _likeRecording(String recordingId) async {
    try {
      await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'like_recording', 'recordingId': recordingId},
      );
      setState(() {
        _likedIds.add(recordingId);
        for (final r in _recordings) {
          if (_recordingIdOf(r) == recordingId) {
            r['likes'] = ((r['likes'] as num?)?.toInt() ?? 0) + 1;
            break;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _incrementPlay(String recordingId) async {
    if (_playingIds.contains(recordingId)) return;
    _playingIds.add(recordingId);
    try {
      await _supabase.functions.invoke(
        'guitar-recording-studio',
        body: {'action': 'increment_play', 'recordingId': recordingId},
      );
      setState(() {
        for (final r in _recordings) {
          if (_recordingIdOf(r) == recordingId) {
            r['plays'] = ((r['plays'] as num?)?.toInt() ?? 0) + 1;
            break;
          }
        }
      });
    } catch (_) {}
  }

  String _recordingIdOf(Map<String, dynamic> r) =>
      r['recordingId']?.toString() ?? r['id']?.toString() ?? '';

  String _sortLabel(String s) {
    switch (s) {
      case 'likes':
        return 'いいね順';
      case 'plays':
        return '再生数順';
      default:
        return '新着順';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Text(
              'ギターギャラリー',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            tooltip: 'ソート',
            color: const Color(0xFF2A2A2A),
            onSelected: (val) {
              setState(() => _sortBy = val);
              _fetchGallery(reset: true);
            },
            itemBuilder: (_) => [
              for (final s in ['created_at', 'likes', 'plays'])
                PopupMenuItem(
                  value: s,
                  child: Text(
                    _sortLabel(s),
                    style: TextStyle(
                      color:
                          _sortBy == s ? const Color(0xFFFF6B35) : Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _recordings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
      );
    }
    if (_errorMessage != null && _recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 48),
            const SizedBox(height: 12),
            Text(
              'ギャラリーの読み込みに失敗しました',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _fetchGallery(reset: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
              ),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }
    if (_recordings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_off,
              color: Color(0xFFFF6B35),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'まだ公開録音がありません',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ギタースタジオで録音して公開しましょう！',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/guitar-recording-studio'),
              icon: const Icon(Icons.mic),
              label: const Text('ギタースタジオへ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchGallery(reset: true),
            color: const Color(0xFFFF6B35),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _recordings.length + (_offset < _total ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _recordings.length) {
                  return _buildLoadMoreButton();
                }
                return _buildRecordingCard(_recordings[i]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '公開録音 $_total件',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _sortLabel(_sortBy),
              style: const TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(Map<String, dynamic> recording) {
    final id = _recordingIdOf(recording);
    final title = recording['title']?.toString() ?? '無題の録音';
    final preset = recording['preset']?.toString() ?? '';
    final durationDisplay = recording['durationDisplay']?.toString() ?? '';
    final bpm = (recording['bpm'] as num?)?.toInt() ?? 0;
    final tuning = recording['tuning']?.toString() ?? '';
    final likes = (recording['likes'] as num?)?.toInt() ?? 0;
    final plays = (recording['plays'] as num?)?.toInt() ?? 0;
    final tags = (recording['tags'] as List?)?.cast<String>() ?? [];
    final createdAt = recording['createdAt']?.toString() ?? '';
    final shareUrl = recording['shareUrl']?.toString();
    final isLiked = _likedIds.contains(id);

    String dateLabel = '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      dateLabel =
          '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Color(0xFFFF6B35),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateLabel.isNotEmpty)
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                if (shareUrl != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    tooltip: '詳細ページ',
                    onPressed: () => Navigator.of(context).pushNamed(
                      '/guitar-recording-studio',
                      arguments: {'share': id},
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (durationDisplay.isNotEmpty)
                  _chip(Icons.timer, durationDisplay),
                if (preset.isNotEmpty)
                  _chip(Icons.graphic_eq, preset.replaceAll('_', ' ')),
                if (bpm > 0) _chip(Icons.speed, '$bpm BPM'),
                if (tuning.isNotEmpty) _chip(Icons.tune, tuning),
                ...tags.take(3).map((t) => _tagChip(t)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  onTap: isLiked ? null : () => _likeRecording(id),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked
                              ? const Color(0xFFE53935)
                              : const Color(0xFFBDBDBD),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$likes',
                          style: TextStyle(
                            color: isLiked
                                ? const Color(0xFFE53935)
                                : const Color(0xFFBDBDBD),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$plays',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    _incrementPlay(id);
                    Navigator.of(context).pushNamed(
                      '/guitar-recording-studio',
                      arguments: {'share': id},
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('再生'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: () => _fetchGallery(),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF6B35)),
            foregroundColor: const Color(0xFFFF6B35),
          ),
          child: const Text('さらに読み込む'),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#$tag',
        style: const TextStyle(
          color: Color(0xFFFF6B35),
          fontSize: 11,
          height: 1.5,
        ),
      ),
    );
  }
}
