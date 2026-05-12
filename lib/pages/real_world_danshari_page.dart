import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';

class RealWorldDanshariPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;
  // テスト用にImagePickerを注入できるようにする
  final ImagePicker imagePicker;

  // ↓ 【修正点】ここにあった 'const' を削除しました
  RealWorldDanshariPage({
    super.key,
    required this.supabaseClient,
    ImagePicker? imagePicker,
  }) : imagePicker = imagePicker ?? ImagePicker();

  @override
  State<RealWorldDanshariPage> createState() => _RealWorldDanshariPageState();
}

class _RealWorldDanshariPageState extends State<RealWorldDanshariPage> {
  Uint8List? _imageBytes;
  bool _isLoading = false;
  Map<String, dynamic>? _result;

  // テスト時は注入されたクライアントを使い、通常時はシングルトンを使う
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await widget.imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageBytes = bytes;
          _result = null;
        });
        // bytesを直接渡す形に変更なし
        _analyzeImage(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('画像の取得に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final base64Image = base64Encode(bytes);

      // ここでゲッター(_supabase)経由でアクセスする
      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'analyze_danshari_item',
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
        },
      );

      final dynamic rawData = response.data;
      final Map<String, dynamic> data = rawData is String
          ? jsonDecode(rawData) as Map<String, dynamic>
          : rawData as Map<String, dynamic>;

      if (data['success'] == true) {
        setState(() {
          _result = data['result'];
        });
      } else {
        throw Exception(data['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI分析エラー: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// ... 以下、buildメソッド等は変更なし ...
  @override
  Widget build(BuildContext context) {
    // ... (元のコードのまま) ...
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('リアル断捨離クエスト'),
        backgroundColor: const Color(0xFFFF6B35),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFFF3E0),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 48,
                      color: Color(0xFFFF6B35),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'あなたの部屋にある「捨てるか迷っているモノ」を撮影してください。\nCSOが容赦なく判定します。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Image Preview Area
            if (_imageBytes != null)
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF6B35)),
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: MemoryImage(_imageBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF9CA3AF)),
                ),
                child: Center(
                  child: Text(
                    'ここに写真が表示されます',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera),
                  label: const Text('カメラで撮影'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('アルバムから選択'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Result Area
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
              )
            else if (_result != null)
              _buildResultCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    // ... (元のコードのまま) ...
    final decision = _result!['decision'] as String;
    final isDiscard = decision == 'DISCARD';
    final color = isDiscard
        ? const Color(0xFF3D5AFE)
        : const Color(0xFF4CAF50); // Discard=Blue(Cool), Keep=Green(Safe)

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              isDiscard ? ' 廃棄推奨 (DISCARD)' : ' 維持 (KEEP)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _result!['item_name'] ?? '不明なアイテム',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'ときめきスコア: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '${_result!['spark_joy_score']} / 100',
                      style: TextStyle(
                        fontSize: 18,
                        color: (_result!['spark_joy_score'] as int) < 50
                            ? const Color(0xFF3D5AFE)
                            : const Color(0xFFE53935),
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  ' 判定理由:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                Text(
                  _result!['reason'] ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.format_quote,
                        color: Color(0xFFFF6B35),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _result!['witty_comment'] ?? '',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFF1F2937),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
