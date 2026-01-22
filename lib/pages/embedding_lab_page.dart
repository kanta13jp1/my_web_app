import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
      // models/embedding-gecko-001 は古い embedText メソッドのみサポートしているため、
      // SDKではなく直接 REST API を叩きます。
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/embedding-gecko-001:embedText?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': _inputController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // レスポンス形式: { "embedding": { "value": [0.1, 0.2, ...] } }
        final embeddingData = data['embedding'];
        List<dynamic> vector = [];

        if (embeddingData != null && embeddingData['value'] != null) {
          vector = embeddingData['value'];
        }

        if (mounted) {
          setState(() {
            _result = 'モデル: embedding-gecko-001 (via embedText)\n'
                '次元数: ${vector.length}\n\n'
                '--- 先頭データ(10件) ---\n[${vector.take(10).join(', ')}...]\n\n'
                '※Embedding成功！';
          });
        }
      } else {
        throw Exception('API Error: ${response.statusCode}\n${response.body}');
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
            const Card(
              color: Colors.teal,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Icon(Icons.science, color: Colors.white, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'モデル: models/embedding-gecko-001',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Legacy method: embedText',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _inputController,
              decoration: const InputDecoration(
                labelText: 'テキストを入力 (max 1024 tokens)',
                border: OutlineInputBorder(),
                hintText: '例: 人工知能について教えて',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  (_isLoading || _apiKey == null) ? null : _generateEmbedding,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.calculate),
              label: const Text('Embeddingを実行'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_apiKey == null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '※設定画面でGemini APIキーを設定してください',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
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
                  child: SelectableText(
                    _result.isEmpty ? 'ここに結果が表示されます' : _result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _result.isEmpty ? Colors.grey : Colors.black87,
                    ),
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
