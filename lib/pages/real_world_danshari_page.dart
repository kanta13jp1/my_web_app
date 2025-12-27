import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // supabaseクライアントのため

class RealWorldDanshariPage extends StatefulWidget {
  const RealWorldDanshariPage({super.key});

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _isAnalyzing = false;
  String? _aiAdvice;
  bool _isDisposed = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // API制限と転送量削減のためリサイズ
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _image = pickedFile;
          _aiAdvice = null;
          _isDisposed = false;
        });
        _analyzeImageWithEdgeFunction(pickedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('画像の取得に失敗しました: $e')),
      );
    }
  }

  Future<void> _analyzeImageWithEdgeFunction(XFile imageFile) async {
    setState(() => _isAnalyzing = true);

    try {
      // 1. 画像をBase64に変換
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Edge Function呼び出し
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_image',
          'imageBase64': base64Image,
        },
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }

      final data = response.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      if (mounted) {
        setState(() {
          _aiAdvice = data['result'];
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAdvice = 'AIの解析に失敗しました。\nエラー: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  void _disposeItem() {
    setState(() {
      _isDisposed = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('素晴らしい！現実の断捨離成功！ +500pt'),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' リアル断捨離クエスト'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '部屋にある「要らないかも？」と思うモノを\n撮影してください。\nAIコーチが判定します。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 画像表示エリア
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('写真を撮る / 選ぶ',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : kIsWeb
                      ? Image.network(_image!.path, fit: BoxFit.cover)
                      : Image.file(File(_image!.path), fit: BoxFit.cover),
            ),

            const SizedBox(height: 24),

            // 操作ボタン
            if (_image == null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera),
                      label: const Text('カメラ'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('アルバム'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              )
            else if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AIコーチが解析中...'),
                ],
              )
            else if (!_isDisposed)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AIのアドバイス表示
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Text(
                      _aiAdvice ?? '',
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _disposeItem,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('捨てました！ (報酬ゲット)'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 4,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _image = null),
                    child: const Text('別のモノを撮る'),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Icon(Icons.celebration, size: 80, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text(
                    '断捨離完了！',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('部屋も心もスッキリしましたね。'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => setState(() => _image = null),
                    child: const Text('続けて断捨離する'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
