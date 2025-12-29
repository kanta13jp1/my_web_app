import 'dart:convert';
import 'dart:typed_data'; // For Uint8List
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class RealWorldDanshariPage extends StatefulWidget {
  const RealWorldDanshariPage({super.key});

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  // Web対応のため File ではなく Uint8List (バイトデータ) を使用
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;

  // Analysis Results
  String? _itemName;
  int? _keepScore;
  String? _analysisResult;
  String? _usedModel;

  final Color _navy = const Color(0xFF0F172A);
  final Color _gold = const Color(0xFFD4AF37);

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);

      if (pickedFile != null) {
        // Webでも動くようにバイトデータを読み込む
        final bytes = await pickedFile.readAsBytes();

        setState(() {
          _imageBytes = bytes;
          _analysisResult = null; // Reset previous result
          _itemName = null;
          _keepScore = null;
        });
        _analyzeImage();
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    try {
      // バイトデータをBase64に変換 (Web対応済み)
      final base64Image = base64Encode(_imageBytes!);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_image',
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
        },
      );

      if (response.status != 200)
        throw Exception('API Error: ${response.status}');

      final data = response.data;
      if (data['success'] == true) {
        final resultData = data['result']; // This is a Map

        setState(() {
          if (resultData is String) {
            _analysisResult = resultData;
          } else {
            _analysisResult = resultData['result'] ?? 'No advice returned.';
            _itemName = resultData['item_name'];
            _keepScore = resultData['keep_score'];
          }
          _usedModel = data['used_model'];
        });
      } else {
        throw Exception(data['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('解析エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('リアル断捨離判定'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '捨てられないモノを撮影してください。\nOpenAI, Gemini, Claudeなど最新のAIが、あなたの代わりに断捨離を即決します。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Image Area (Web対応: Image.memoryを使用)
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _imageBytes == null
                  ? Icon(Icons.camera_alt, size: 60, color: Colors.grey[400])
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(height: 24),

            if (!_isAnalyzing && _analysisResult == null) ...[
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text('カメラで撮影',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: _navy),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(Icons.photo_library, color: _navy),
                label: Text('アルバムから選択',
                    style:
                        TextStyle(color: _navy, fontWeight: FontWeight.bold)),
              ),
            ],

            if (_isAnalyzing)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('鬼コーチが画像を解析中...\n(Claude 4.5 Opus / Gemini 3.0)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _navy)),
                ],
              ),

            if (_analysisResult != null) ...[
              const SizedBox(height: 20),
              if (_keepScore != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_navy, const Color(0xFF1E293B)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: _navy.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_itemName ?? '不明なアイテム',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('未練スコア (Keep Score)',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1)),
                        child: Text(
                          '$_keepScore',
                          style: TextStyle(
                            color: (_keepScore ?? 0) < 30
                                ? Colors.redAccent
                                : _gold,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        const Text('鬼コーチの判定',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.redAccent)),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      _analysisResult!,
                      style: const TextStyle(
                          fontSize: 15, height: 1.6, color: Colors.black87),
                    ),
                    if (_usedModel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text('Judge: $_usedModel',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('素晴らしい決断です！ +50pt')));
                        setState(() {
                          _imageBytes = null;
                          _analysisResult = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('今すぐ捨てる'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                          _analysisResult = null;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('次のモノへ'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }
}
