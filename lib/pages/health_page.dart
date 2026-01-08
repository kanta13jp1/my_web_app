import 'dart:convert';
import 'dart:typed_data'; // Web対応: 画像をバイトデータとして扱う
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../main.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  List<Map<String, dynamic>> _mealLogs = [];

  // Colors
  final Color _green = const Color(0xFF059669);
  final Color _bg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchMeals();
  }

  Future<void> _fetchMeals() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _mealLogs = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Error fetching meals: $e');
    }
  }

  //  Web対応版: カメラ撮影 & AI監査
  Future<void> _auditMeal() async {
    try {
      // 1. 画像選択 (Web対応: XFileを使用)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (photo == null) return;

      setState(() => _isLoading = true);

      // 2. バイトデータとして読み込み (dart:ioのFileは使わない)
      final Uint8List imageBytes = await photo.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // 3. AI監査リクエスト
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'audit_meal',
          'imageBase64': base64Image,
          'mimeType': 'image/jpeg',
          'currentTime': DateTime.now().toIso8601String(),
        },
      );

      if (response.status != 200) throw Exception('AI Audit Failed');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      final result = data['result']; // JSON from AI

      // 4. 結果をDBに保存
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('meal_logs').insert({
          'user_id': userId,
          'menu_name': result['menu_name'] ?? 'Unknown',
          'calories': result['calorie_estimate'] ?? 0,
          'performance_score': result['performance_score'] ?? 50,
          'ai_comment': result['audit_result'] ?? '',
          'advice': result['advice'] ?? '',
          'image_url': 'base64_placeholder', // ストレージ実装までは省略
        });
      }

      // 5. 結果表示
      if (mounted) {
        _showAuditResultDialog(result);
        _fetchMeals(); // リスト更新
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('検食エラー: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAuditResultDialog(Map<String, dynamic> result) {
    final int score = result['performance_score'] ?? 0;
    final Color scoreColor =
        score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restaurant_menu, color: _green),
            const SizedBox(width: 8),
            const Text('AI検食結果', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text(
                      '$score点',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      result['menu_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${result['calorie_estimate']} kcal',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),
              const Text('判定:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                result['audit_result'] ?? '',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              const Text('助言:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                result['advice'] ?? '',
                style: const TextStyle(height: 1.5, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('ごちそうさまでした'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('健康管理室 (CHO)'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: _isLoading ? null : _auditMeal,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('AI栄養士が分析中...', style: TextStyle(color: _green)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mealLogs.length,
              itemBuilder: (context, index) {
                final meal = _mealLogs[index];
                final score = meal['performance_score'] ?? 0;
                final date = DateTime.parse(meal['created_at']).toLocal();

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (score >= 80
                              ? Colors.green
                              : (score >= 50 ? Colors.orange : Colors.red))
                          .withValues(alpha: 0.2),
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (score >= 80
                              ? Colors.green
                              : (score >= 50 ? Colors.orange : Colors.red)),
                        ),
                      ),
                    ),
                    title: Text(
                      meal['menu_name'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat('MM/dd HH:mm').format(date)}  ${meal['calories']} kcal',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      _showAuditResultDialog({
                        'performance_score': score,
                        'menu_name': meal['menu_name'],
                        'calorie_estimate': meal['calories'],
                        'audit_result': meal['ai_comment'],
                        'advice': meal['advice'],
                      });
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _auditMeal,
        backgroundColor: _green,
        icon: const Icon(Icons.camera_alt),
        label: const Text('検食を実行'),
      ),
    );
  }
}
