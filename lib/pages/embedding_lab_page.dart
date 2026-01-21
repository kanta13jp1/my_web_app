import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmbeddingLabPage extends StatefulWidget {
  const EmbeddingLabPage({super.key});

  @override
  State<EmbeddingLabPage> createState() => _EmbeddingLabPageState();
}

class _EmbeddingLabPageState extends State<EmbeddingLabPage> {
  final TextEditingController _inputController = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  Future<void> _generateEmbedding() async {
    if (_apiKey == null || _inputController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // ★ ここで指定されたモデルを使用します
      final model = GenerativeModel(
        model: 'models/embedding-gecko-001',
        apiKey: _apiKey!,
      );

      final content = Content.text(_inputController.text);
      
      // SDKでは 'embedText' ではなく 'embedContent' を使用します
      final response = await model.embedContent(content);

      if (mounted) {
        setState(() {
          // ベクトルデータ（数値の配列）が返ってきます
          final vector = response.embedding.values;
          _result = '次元数: ${vector.length}\n\n'
              '先頭のデータ(5件):\n${vector.take(5).join(', ')}...\n\n'
              '※Embedding成功！この数値配列がテキストの意味を表しています。';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = 'エラーが発生しました:\n$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Embedding Lab (Gecko)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'モデル: models/embedding-gecko-001',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'テキストを入力すると、その意味を数値ベクトル（Embedding）に変換します。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'テキストを入力',
                border: OutlineInputBorder(),
                hintText: '例: 人工知能について教えて',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: (_isLoading || _apiKey == null) ? null : _generateEmbedding,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calculate),
              label: const Text('Embeddingを実行'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            ),
            const SizedBox(height: 24),
            const Text(
              '実行結果:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}