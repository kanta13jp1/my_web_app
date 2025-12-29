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
  Map<String, dynamic>? _lastAudit;
  String? _usedModel;
  List<String> _attemptLogs = [];
  bool _hasPermit = false;

  @override
  void initState() {
    super.initState();
    _fetchMealLogs();
    _checkPermit();
  }

  Future<void> _checkPermit() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final permit = await supabase
        .from('user_inventory')
        .select('*, welfare_items!inner(*)')
        .eq('user_id', userId)
        .eq('is_used', false)
        .eq('welfare_items.effect_type', 'ramen_permit')
        .maybeSingle();
    if (mounted) setState(() => _hasPermit = permit != null);
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
      if (mounted)
        setState(() => _mealLogs = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _auditMeal(ImageSource source) async {
    bool usePermit = false;
    if (_hasPermit) {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text(' ラーメン許可証を提示'),
                  content: const Text('CHOの厳しい監査を無効化し、カロリーを「経費」として処理しますか？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('使わない')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('使う'))
                  ]));
      usePermit = confirm ?? false;
    }
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
      if (usePermit) {
        final userId = supabase.auth.currentUser!.id;
        final item = await supabase
            .from('user_inventory')
            .select('id, welfare_items!inner(*)')
            .eq('user_id', userId)
            .eq('is_used', false)
            .eq('welfare_items.effect_type', 'ramen_permit')
            .limit(1)
            .single();
        await supabase
            .from('user_inventory')
            .update({'is_used': true}).eq('id', item['id']);
        _checkPermit();
      }
      final response = await supabase.functions.invoke('ai-assistant', body: {
        'action': 'audit_meal',
        'imageBase64': base64Image,
        'hasPermit': usePermit
      });
      if (response.status != 200) throw Exception('Server error');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      setState(() {
        _lastAudit = data['result'];
        _usedModel = data['used_model'];
        _attemptLogs = List<String>.from(data['attempt_logs'] ?? []);
      });
      if (mounted)
        _showAuditResultDialog(_lastAudit!, _usedModel, _attemptLogs);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('監査エラー: $e')));
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
        'advice': result['advice']
      });
      _fetchMealLogs();
    } catch (e) {}
  }

  void _showAuditResultDialog(
      Map<String, dynamic> result, String? model, List<String> logs) {
    int score = result['performance_score'] ?? 0;
    Color scoreColor =
        score >= 80 ? Colors.green : (score >= 50 ? Colors.orange : Colors.red);
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Row(children: [
                  Icon(Icons.health_and_safety, color: scoreColor),
                  const SizedBox(width: 8),
                  const Text('CHO 監査報告書')
                ]),
                content: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      if (model != null)
                        Text('Auditor: $model',
                            style: TextStyle(
                                fontSize: 10, color: Colors.amber[900])),
                      Text(result['menu_name'] ?? '不明',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('$score点',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: scoreColor)),
                      const Divider(),
                      Text(result['audit_result'] ?? ''),
                      const SizedBox(height: 8),
                      Text('【助言】 ${result['advice'] ?? ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.blue))
                    ])),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _saveAuditResult(result);
                      },
                      child: const Text('記録する'))
                ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(' 健康管理室 (CHO)'),
          backgroundColor: Colors.teal.shade800,
          foregroundColor: Colors.white),
      body: Column(children: [
        Container(
            padding: const EdgeInsets.all(20),
            color: Colors.teal.shade50,
            child: Column(children: [
              if (_hasPermit)
                const Text(' ラーメン許可証 保有中',
                    style: TextStyle(
                        color: Colors.pink, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                  onPressed:
                      _isLoading ? null : () => _auditMeal(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('食事を監査する (Camera)'))
            ])),
        Expanded(
            child: ListView.builder(
                itemCount: _mealLogs.length,
                itemBuilder: (context, index) {
                  final log = _mealLogs[index];
                  return ListTile(
                    leading: CircleAvatar(
                        child: Text('${log['performance_score']}')),
                    title: Text(log['menu_name'] ?? ''),
                    subtitle: Text(log['advice'] ?? ''),
                    //  シェアボタン更新
                    trailing: IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          Share.share(
                              '【自分株式会社 CHO監査報告】\nメニュー: ${log['menu_name']}\nスコア: ${log['performance_score']}点\n判定: ${log['advice']}\n\n ダウンロード: https://my-web-app-b67f4.web.app/\n#自分株式会社',
                              subject: '食事監査結果');
                        }),
                  );
                })),
      ]),
    );
  }
}
