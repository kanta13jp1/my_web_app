import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/ai_image_generation_request.dart';

/// AI 画像生成ページ
/// media-hub Edge Function と連携して AI 画像を生成・管理
class AiImageGeneratorPage extends StatefulWidget {
  const AiImageGeneratorPage({super.key});

  @override
  State<AiImageGeneratorPage> createState() => _AiImageGeneratorPageState();
}

class _AiImageGeneratorPageState extends State<AiImageGeneratorPage> {
  final _supabase = Supabase.instance.client;
  final _sceneSubjectController = TextEditingController();
  final _detailsStyleController = TextEditingController();
  final _constraintsController = TextEditingController();
  final _imageTextController = TextEditingController();

  bool _isFetching = false;
  bool _isGenerating = false;
  String? _errorMessage;
  String _selectedSize = '1024x1024';
  String _selectedStyle = 'vivid';
  AiImageGenerationQuality _selectedQuality = AiImageGenerationQuality.medium;
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
    _sceneSubjectController.dispose();
    _detailsStyleController.dispose();
    _constraintsController.dispose();
    _imageTextController.dispose();
    super.dispose();
  }

  Future<void> _fetchImages() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isFetching = false);
      return;
    }
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
            (row) => _GeneratedImage.fromHubRow(Map<String, dynamic>.from(row)),
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
    final structuredPrompt = AiImageStructuredPrompt(
      sceneAndSubject: _sceneSubjectController.text,
      detailsAndStyle: _detailsStyleController.text,
      constraints: _constraintsController.text,
      imageText: _imageTextController.text,
    );
    if (!structuredPrompt.hasInput) return;
    final prompt = structuredPrompt.buildPrompt();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'media-hub',
        body: buildAiImageGenerateBody(
          prompt: prompt,
          size: _selectedSize,
          style: _selectedStyle,
          quality: _selectedQuality,
        ),
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        setState(() => _errorMessage = data['error'].toString());
        return;
      }
      _sceneSubjectController.clear();
      _detailsStyleController.clear();
      _constraintsController.clear();
      _imageTextController.clear();
      await _fetchImages();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '画像の生成に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _buildPromptField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool highlight = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabledBorder: highlight
            ? const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE65100)),
              )
            : const OutlineInputBorder(),
        focusedBorder: highlight
            ? const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE65100), width: 2),
              )
            : null,
        prefixIcon: Icon(icon),
        suffixIcon: highlight
            ? const Icon(Icons.priority_high, color: Color(0xFFE65100))
            : null,
        filled: highlight,
        fillColor: highlight ? const Color(0xFFFFF8E1) : null,
      ),
    );
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
            _buildPromptField(
              controller: _sceneSubjectController,
              label: 'シーンと対象',
              icon: Icons.image_search,
            ),
            const SizedBox(height: 8),
            _buildPromptField(
              controller: _detailsStyleController,
              label: 'スタイル',
              icon: Icons.palette_outlined,
            ),
            const SizedBox(height: 8),
            _buildPromptField(
              controller: _constraintsController,
              label: '制約（維持・除外するもの）',
              icon: Icons.rule,
              highlight: true,
            ),
            const SizedBox(height: 8),
            _buildPromptField(
              controller: _imageTextController,
              label: '画像内テキスト',
              icon: Icons.text_fields,
              maxLines: 1,
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
                        entry.key == 'vivid' ? Icons.palette : Icons.landscape,
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
            const SizedBox(height: 8),
            SegmentedButton<AiImageGenerationQuality>(
              segments: AiImageGenerationQuality.values
                  .map(
                    (quality) => ButtonSegment<AiImageGenerationQuality>(
                      value: quality,
                      label: Text(quality.label),
                      tooltip: quality.description,
                      icon: Icon(
                        switch (quality) {
                          AiImageGenerationQuality.low => Icons.flash_on,
                          AiImageGenerationQuality.medium =>
                            Icons.balance_outlined,
                          AiImageGenerationQuality.high => Icons.high_quality,
                        },
                      ),
                    ),
                  )
                  .toList(),
              selected: {_selectedQuality},
              onSelectionChanged: _isBusy
                  ? null
                  : (selection) =>
                      setState(() => _selectedQuality = selection.first),
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
                style: const TextStyle(color: Color(0xFFE53935), height: 1.5),
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
              const Expanded(child: Center(child: Text('生成済み画像はありません'))),
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
    required this.quality,
    required this.createdAt,
  });

  final String prompt;
  final String imageUrl;
  final String size;
  final String style;
  final String quality;
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
      quality: metadata['quality']?.toString() ?? '',
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
      if (quality.isNotEmpty) AiImageGenerationQuality.fromValue(quality).label,
      if (createdAt.isNotEmpty) createdAt,
    ];
    return parts.join(' / ');
  }
}
