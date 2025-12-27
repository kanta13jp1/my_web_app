import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart'; // シェア用
import 'dart:convert';
import '../main.dart';

class RealWorldDanshariPage extends StatefulWidget {
  const RealWorldDanshariPage({super.key});

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  File? _image;
  final picker = ImagePicker();
  bool _isAnalyzing = false;
  String? _analysisResult;

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source, maxWidth: 800);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _analysisResult = null;
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      List<int> imageBytes = await _image!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

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

      setState(() {
        _analysisResult = data['result'];
      });

      if (mounted) {
        _showAnalysisResultDialog(_analysisResult!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI解析エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  //  判定結果をシェアする機能 (新規追加)
  void _shareResult(String result) {
    // 結果からキャッチーな部分を抽出（簡易的に最初の数行）
    final shortResult = result.split('\n').take(5).join('\n');

    Share.share(
      'AI鬼コーチに部屋のモノを判定してもらいました\n\n$shortResult\n...\n\nあなたも無料で診断！\n#マイメモ #断捨離 #Gemini\nhttps://my-web-app-b67f4.web.app/?ref=share_image_result',
      subject: 'AI断捨離コーチの衝撃診断',
    );
  }

  // ダイアログを修正
  void _showAnalysisResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.indigo),
            SizedBox(width: 8),
            Text('鬼コーチの判定'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            result,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          // シェアボタンを追加
          TextButton.icon(
            onPressed: () {
              _shareResult(result);
            },
            icon: const Icon(Icons.share),
            label: const Text('この結果をシェア'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' リアル断捨離判定'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '捨てられないモノを撮影してください。\nAI鬼コーチが忖度なしで判定します。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(_image!, height: 300, fit: BoxFit.cover),
              ),
              const SizedBox(height: 32),
            ],
            if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AIが鋭意判定中...',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () => _getImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.camera_alt, size: 32),
                label: const Text('カメラで撮影', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _getImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                icon: const Icon(Icons.photo_library),
                label: const Text('アルバムから選択'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
