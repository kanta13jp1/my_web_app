import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// フォトギャラリー管理ページ
/// アルバム管理・写真一覧・タグ付け。
/// photo-gallery-manager Edge Function と連携。
class PhotoGalleryManagerPage extends StatefulWidget {
  const PhotoGalleryManagerPage({super.key});

  @override
  State<PhotoGalleryManagerPage> createState() =>
      _PhotoGalleryManagerPageState();
}

class _PhotoGalleryManagerPageState extends State<PhotoGalleryManagerPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _albums = [];
  Map<String, dynamic>? _selectedAlbum;
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
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
        body: {'action': 'gallery.list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['albums'];
        if (list is List) {
          setState(() {
            _albums = list.map((a) => a as Map<String, dynamic>).toList();
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

  Future<void> _fetchPhotos(String albumId) async {
    try {
      final res = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'gallery.list_photos', 'album_id': albumId},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final list = data['photos'];
        if (list is List) {
          setState(() {
            _photos = list.map((p) => p as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _photos = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フォトギャラリー'),
        leading: _selectedAlbum != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedAlbum = null;
                  _photos = [];
                }),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAlbums,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _selectedAlbum == null
                  ? _buildAlbumGrid()
                  : _buildPhotoGrid(),
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
          ElevatedButton(onPressed: _fetchAlbums, child: const Text('再試行')),
        ],
      ),
    );
  }

  Widget _buildAlbumGrid() {
    if (_albums.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 12),
            Text(
              'アルバムがありません',
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
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _albums.length,
      itemBuilder: (ctx, i) {
        final album = _albums[i];
        final name = album['name'] as String? ?? 'アルバム ${i + 1}';
        final count = album['photoCount'] as int? ?? 0;
        final emoji = album['emoji'] as String? ?? '📷';
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAlbum = album;
              _photos = [];
            });
            _fetchPhotos(album['id'] as String? ?? '');
          },
          child: Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(
                    fontSize: 40,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$count 枚',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoGrid() {
    final albumName = _selectedAlbum?['name'] as String? ?? 'アルバム';
    if (_photos.isEmpty) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.photo_library),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    albumName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'このアルバムに写真がありません',
                style: TextStyle(
                  color: Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              const Icon(Icons.photo_library),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  albumName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              Text('${_photos.length} 枚'),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _photos.length,
            itemBuilder: (ctx, i) {
              final photo = _photos[i];
              final url = photo['thumbnailUrl'] as String? ?? '';
              final title = photo['title'] as String? ?? '';
              return Stack(
                fit: StackFit.expand,
                children: [
                  url.isNotEmpty
                      ? Image.network(url, fit: BoxFit.cover)
                      : Container(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          child: const Icon(
                            Icons.image,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                  if (title.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            height: 1.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
