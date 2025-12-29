import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _mealLogs = [];
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isSuggesting = false; // 提案中フラグ

  @override
  void initState() {
    super.initState();
    _fetchMealLogs();
  }

  Future<void> _fetchMealLogs() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('meal_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _mealLogs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, maxWidth: 800, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isAnalyzing = true);

    try {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'audit_meal',
          'imageBase64': base64Image,
        },
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      final result = data['result'];
      await _saveMealLog(result, data['used_model']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '検食完了: ${result['menu_name']} (${result['performance_score']}点)'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _suggestNextMeal() async {
    setState(() => _isSuggesting = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 直近の食事データを取得（コンテキスト用）
      final recentMeals = _mealLogs.take(3).toList();

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'suggest_next_meal',
          'recentMeals': recentMeals,
          'currentTime': TimeOfDay.now().format(context),
        },
      );

      if (response.status != 200) throw Exception('AI Error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      if (mounted) {
        _showSuggestionDialog(
            data['result'], data['provider'], data['used_model']);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('提案エラー: $e')));
    } finally {
      if (mounted) setState(() => _isSuggesting = false);
    }
  }

  Future<void> _saveMealLog(
      Map<String, dynamic> aiResult, String? model) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('meal_logs').insert({
      'user_id': userId,
      'menu_name': aiResult['menu_name'],
      'calorie_estimate': aiResult['calorie_estimate'],
      'performance_score': aiResult['performance_score'],
      'ai_feedback': aiResult['advice'] ?? aiResult['audit_result'],
      'created_at': DateTime.now().toIso8601String(),
    });

    // ポイント付与
    await supabase.rpc('increment_points',
        params: {'user_id': userId, 'points_to_add': 50});

    _fetchMealLogs();
  }

  void _showSuggestionDialog(
      Map<String, dynamic> result, String provider, String model) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)))),
            Row(
              children: [
                const Icon(Icons.restaurant_menu, color: Colors.teal, size: 28),
                const SizedBox(width: 12),
                const Text('AIシェフの提案',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('$provider ($model)',
                      style:
                          TextStyle(fontSize: 10, color: Colors.teal.shade800)),
                )
              ],
            ),
            const SizedBox(height: 24),
            Text(result['menu_name'] ?? '名称なし',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(result['reason'] ?? '',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // 栄養素
            if (result['nutrients'] != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNutrientItem(
                      'カロリー', '${result['calorie_estimate']}kcal'),
                  _buildNutrientItem(
                      'タンパク質', result['nutrients']['protein'] ?? '-'),
                  _buildNutrientItem('脂質', result['nutrients']['fat'] ?? '-'),
                  _buildNutrientItem(
                      '炭水化物', result['nutrients']['carbs'] ?? '-'),
                ],
              ),
              const Divider(height: 32),
            ],

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('【材料】',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(result['ingredients'] as List? ?? [])
                        .map((e) => Text('$e'))
                        .toList(),
                    const SizedBox(height: 16),
                    const Text('【作り方】',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...(result['recipe_steps'] as List? ?? [])
                        .asMap()
                        .entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.key + 1}. ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal)),
                                  Expanded(child: Text(e.value)),
                                ],
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16)),
                child: const Text('ごちそうさま（閉じる）'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('健康管理室 (CHO)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Actions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing
                        ? null
                        : () => _pickAndAnalyzeImage(ImageSource.camera),
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt),
                    label: const Text('検食 (撮影)'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSuggesting ? null : _suggestNextMeal,
                    icon: _isSuggesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.restaurant),
                    label: const Text('献立提案'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _mealLogs.isEmpty
                    ? const Center(
                        child: Text('食事記録がありません',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _mealLogs.length,
                        itemBuilder: (context, index) {
                          final log = _mealLogs[index];
                          final date =
                              DateTime.parse(log['created_at']).toLocal();
                          final score = log['performance_score'] as int;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          DateFormat('MM/dd HH:mm')
                                              .format(date),
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: score >= 80
                                                ? Colors.green[100]
                                                : (score >= 60
                                                    ? Colors.orange[100]
                                                    : Colors.red[100]),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text('$score点',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: score >= 80
                                                    ? Colors.green[800]
                                                    : (score >= 60
                                                        ? Colors.orange[800]
                                                        : Colors.red[800]))),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(log['menu_name'] ?? '不明な食事',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(log['ai_feedback'] ?? '',
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.local_fire_department,
                                          size: 14, color: Colors.orange[300]),
                                      const SizedBox(width: 4),
                                      Text('${log['calorie_estimate']} kcal',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
