import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AI 画像生成ページ
/// ai-image-generator Edge Function と連携して AI 画像を生成・管理
class AiImageGeneratorPage extends StatefulWidget {
  const AiImageGeneratorPage({super.key});

  @override
  State<AiImageGeneratorPage> createState() => _AiImageGeneratorPageState();
}

class _AiImageGeneratorPageState extends State<AiImageGeneratorPage> {
  final _supabase = Supabase.instance.client;
  final _promptController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _images = [];

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
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'ai-image-generator',
        body: {'action': 'list'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['images'] is List) {
        setState(() =>
            _images = (data['images'] as List).cast<Map<String, dynamic>>(),);
      } else if (data is List) {
        setState(() => _images = data.cast<Map<String, dynamic>>());
      } else {
        setState(() => _images = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '画像一覧の取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'ai-image-generator',
        body: {'action': 'generate', 'prompt': prompt},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['error'] != null) {
        setState(() => _errorMessage = data['error'].toString());
      } else {
        _promptController.clear();
        await _fetchImages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '画像の生成に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            onPressed: _isLoading ? null : _fetchImages,
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
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _generate,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI 画像を生成'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_images.isNotEmpty) ...[
              const Text(
                '生成済み画像',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final item = _images[index];
                    final prompt =
                        item['prompt']?.toString() ?? 'プロンプト ${index + 1}';
                    final createdAt = item['created_at']?.toString();
                    final imageUrl = item['url']?.toString() ??
                        item['image_url']?.toString();
                    return Card(
                      child: ListTile(
                        leading: imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image, size: 40),
                                ),
                              )
                            : const Icon(Icons.image, size: 40),
                        title: Text(
                          prompt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: createdAt != null ? Text(createdAt) : null,
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
