import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI 画像生成ページ
/// media-hub Edge Function と連携して AI 画像を生成・管理
class AiImageGeneratorPage extends StatefulWidget {
  const AiImageGeneratorPage({super.key});

  @override
  State<AiImageGeneratorPage> createState() => _AiImageGeneratorPageState();
}

class _AiImageGeneratorPageState extends State<AiImageGeneratorPage> {
  final _supabase = Supabase.instance.client;
  final _promptController = TextEditingController();

  bool _isFetching = false;
  bool _isGenerating = false;
  String? _errorMessage;
  String _selectedSize = '1024x1024';
  String _selectedStyle = 'vivid';
  List<_GeneratedImage> _images = [];

  bool get _isBusy => _isFetching || _isGenerating;

  static const Map<String, String> _sizeLabels = {
    '1024x1024': '正方形',
    '1024x1792': '縦長',
    '1792x1024': '横長',
  };

  static const Map<String, String> _styleLabels = {
    'vivid': '鮮やか',
    'natural': '自然',
  };

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _fetchImages() async {
    setState(() {
      _isFetching = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {'action': 'image.list'},
      );
      final data = response.data;
      final rows = switch (data) {
        {'images': final List images} => images,
        final List images => images,
        _ => const <Object?>[],
      };
      final images = rows
          .whereType<Map>()
          .map(
            (row) => _GeneratedImage.fromHubRow(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((image) => image.imageUrl.isNotEmpty)
          .toList();
      if (mounted) setState(() => _images = images);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '画像一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: {
          'action': 'image.generate',
          'prompt': prompt,
          'size': _selectedSize,
          'style': _selectedStyle,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        setState(() => _errorMessage = data['error'].toString());
        return;
      }
      _promptController.clear();
      await _fetchImages();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '画像の生成に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 画像生成'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _isBusy ? null : _fetchImages,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '画像プロンプト',
                hintText: '例: 青い空と富士山の風景、水彩画風',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image_search),
              ),
              onSubmitted: (_) {
                if (!_isBusy) _generate();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sizeLabels.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedSize == entry.key,
                  onSelected: _isBusy
                      ? null
                      : (_) => setState(() => _selectedSize = entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: _styleLabels.entries
                  .map(
                    (entry) => ButtonSegment<String>(
                      value: entry.key,
                      label: Text(entry.value),
                      icon: Icon(
                        entry.key == 'vivid'
                            ? Icons.palette
                            : Icons.landscape,
                      ),
                    ),
                  )
                  .toList(),
              selected: {_selectedStyle},
              onSelectionChanged: _isBusy
                  ? null
                  : (selection) =>
                      setState(() => _selectedStyle = selection.first),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _generate,
              icon: _isGenerating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('AI 画像を生成'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            if (_isFetching && _images.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_images.isNotEmpty) ...[
              const Text(
                '生成済み画像',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: GridView.builder(
                  itemCount: _images.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final item = _images[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, size: 40),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.prompt.isEmpty
                                      ? 'プロンプト ${index + 1}'
                                      : item.prompt,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.description(_styleLabels),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(child: Text('生成済み画像はありません')),
              ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedImage {
  const _GeneratedImage({
    required this.prompt,
    required this.imageUrl,
    required this.size,
    required this.style,
    required this.createdAt,
  });

  final String prompt;
  final String imageUrl;
  final String size;
  final String style;
  final String createdAt;

  factory _GeneratedImage.fromHubRow(Map<String, dynamic> row) {
    final metadata = row['metadata'] is Map
        ? Map<String, dynamic>.from(row['metadata'] as Map)
        : row;
    return _GeneratedImage(
      prompt: metadata['prompt']?.toString() ?? '',
      imageUrl: metadata['url']?.toString() ??
          metadata['image_url']?.toString() ??
          metadata['imageUrl']?.toString() ??
          '',
      size: metadata['size']?.toString() ?? '',
      style: metadata['style']?.toString() ?? '',
      createdAt: row['created_at']?.toString() ??
          row['createdAt']?.toString() ??
          metadata['created_at']?.toString() ??
          '',
    );
  }

  String description(Map<String, String> styleLabels) {
    final parts = [
      if (size.isNotEmpty) size,
      if (style.isNotEmpty) styleLabels[style] ?? style,
      if (createdAt.isNotEmpty) createdAt,
    ];
    return parts.join(' / ');
  }
}
