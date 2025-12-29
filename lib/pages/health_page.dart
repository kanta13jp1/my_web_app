import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
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

  // 最新の監査結果
  Map<String, dynamic>? _lastAudit;
  String? _usedModel;
  List<String> _attemptLogs = [];

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
        });
      }
    } catch (e) {
      debugPrint('Error fetching meals: $e');
    }
  }

  Future<void> _auditMeal(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
        source: source, maxWidth: 800, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isLoading = true;
      _lastAudit = null;
      _attemptLogs = [];
    });

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'audit_meal',
          'imageBase64': base64Image,
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      final result = data['result']; // JSON map
      final usedModel = data['used_model'];
      final logs = List<String>.from(data['attempt_logs'] ?? []);

      setState(() {
        _lastAudit = result;
        _usedModel = usedModel;
        _attemptLogs = logs;
      });

      if (!mounted) return;
      _showAuditResultDialog(result, usedModel, logs);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('監査エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAuditResult(Map<String, dynamic> result) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('meal_logs').insert({
        'user_id': userId,
        'menu_name': result['menu_name'],
        'calorie_estimate': result['calorie_estimate'],
        'performance_score': result['performance_score'],
        'audit_result': result['audit_result'],
        'advice': result['advice'],
      });

      _fetchMealLogs();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('監査ログを記録しました'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存エラー: $e')));
    }
  }

  void _showAuditResultDialog(
      Map<String, dynamic> result, String? model, List<String> logs) {
    int score = result['performance_score'] ?? 0;
    Color scoreColor =
        score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: scoreColor),
            const SizedBox(width: 8),
            const Text('CHO 監査報告書'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (model != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Auditor: $model',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.amber[900],
                          fontWeight: FontWeight.bold)),
                ),
              if (logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('(${logs.length} attempts failed)',
                      style: TextStyle(fontSize: 10, color: Colors.red[300])),
                ),
              Text(result['menu_name'] ?? '不明なメニュー',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text('推定カロリー',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('${result['calorie_estimate']} kcal',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text('パフォーマンス',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text('$score点',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: scoreColor)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
              const Text('【監査コメント】',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(result['audit_result'] ?? '',
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              const Text('【CHOの助言】',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blue)),
              Text(result['advice'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('破棄'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveAuditResult(result);
            },
            child: const Text('記録する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' 健康管理室 (CHO)'),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // ダッシュボード
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.teal.shade50,
            child: Column(
              children: [
                const Text('本日のパフォーマンススコア',
                    style: TextStyle(color: Colors.teal)),
                const SizedBox(height: 8),
                // 平均スコアなどを計算してもよいが、ここでは簡易表示
                const Text('Ready to Audit',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _auditMeal(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.camera_alt),
                  label: const Text('食事を監査する (Camera)'),
                ),
              ],
            ),
          ),

          // ログリスト
          Expanded(
            child: _mealLogs.isEmpty
                ? const Center(child: Text('食事履歴がありません。\nAI監査を受けてください。'))
                : ListView.builder(
                    itemCount: _mealLogs.length,
                    itemBuilder: (context, index) {
                      final log = _mealLogs[index];
                      final score = log['performance_score'] as int? ?? 0;
                      final scoreColor = score >= 80
                          ? Colors.green
                          : (score >= 50 ? Colors.orange : Colors.red);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: scoreColor,
                            child: Text('$score',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                          title: Text(log['menu_name'] ?? '不明',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${log['calorie_estimate']} kcal - ${log['created_at'].toString().substring(0, 10)}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log['audit_result'] ?? '',
                                      style: const TextStyle(fontSize: 14)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.tips_and_updates,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 4),
                                      Expanded(
                                          child: Text(log['advice'] ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        Share.share(
                                            '【自分株式会社 CHO監査報告】\nメニュー: ${log['menu_name']}\nスコア: $score点\n判定: ${log['advice']}\n\n#マイメモ #AI検食',
                                            subject: '食事監査結果');
                                      },
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const Text('シェア'),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ],
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
