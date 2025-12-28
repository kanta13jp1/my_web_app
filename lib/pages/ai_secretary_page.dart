import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/note.dart';
import '../services/attachment_service.dart';

class AISecretaryPage extends StatefulWidget {
  const AISecretaryPage({super.key});

  @override
  State<AISecretaryPage> createState() => _AISecretaryPageState();
}

class _AISecretaryPageState extends State<AISecretaryPage> {
  bool _isLoading = false;
  String? _strategyResult;
  String? _usedModel;
  String _currentStrategyType = 'today'; // default

  final ImagePicker _picker = ImagePicker();

  // 戦略を立てるためのデータを取得してAIに投げる
  Future<void> _consultSecretary(String strategyType) async {
    setState(() {
      _isLoading = true;
      _currentStrategyType = strategyType;
      _strategyResult = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 現在のアクティブなタスク（メモ）を取得
      final notesResponse = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('updated_at', ascending: false)
          .limit(20); // 文脈制限のため最新20件

      final recentNotes =
          (notesResponse as List).map((n) => Note.fromJson(n)).toList();

      final recentNotesJson = recentNotes
          .map((n) => {
                'id': n.id,
                'title': n.title,
                'content': n.content,
                'created_at': n.createdAt.toIso8601String(),
                'updated_at': n.updatedAt.toIso8601String(),
              })
          .toList();

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'secretary_strategy',
          'strategyType': strategyType,
          'recentNotes': recentNotesJson,
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      setState(() {
        _strategyResult = data['result']; // 生テキスト(Markdown)
        _usedModel = data['used_model'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('秘書との通信エラー: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // カメラ/画像からタスクを追加
  Future<void> _addTaskFromImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
        source: source, maxWidth: 800, imageQuality: 80);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'secretary_task_from_image',
          'imageBase64': base64Image,
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      final taskData = data['result']; // JSONオブジェクト {title, content, priority}

      if (!mounted) return;

      // 確認ダイアログを表示して保存
      await _showTaskConfirmDialog(taskData, image);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析エラー: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showTaskConfirmDialog(
      Map<String, dynamic> taskData, XFile imageFile) async {
    final titleController = TextEditingController(text: taskData['title']);
    final contentController = TextEditingController(text: taskData['content']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(' 新規タスク案'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AI秘書が画像からタスクを起案しました。',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: '件名', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                    labelText: '詳細', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.priority_high,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('推奨優先度: ${taskData['priority']}'),
                ],
              )
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('却下')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // ダイアログ閉じる
              await _saveTask(
                  titleController.text, contentController.text, imageFile);
            },
            child: const Text('承認（保存）'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTask(String title, String content, XFile imageFile) async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now().toIso8601String();

      // メモ作成
      final noteData = await supabase
          .from('notes')
          .insert({
            'user_id': userId,
            'title': title,
            'content': content,
            'is_archived': false,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      // 画像添付
      final noteId = noteData['id'] as int;
      final bytes = await imageFile.readAsBytes();
      final file = PlatformFile(
          name: imageFile.name, size: await imageFile.length(), bytes: bytes);
      await AttachmentService.uploadFile(noteId: noteId, file: file);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('タスクが登録されました'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI戦略秘書室'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          if (_strategyResult != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.share(
                  '【自分株式会社 経営戦略】\n\n$_strategyResult\n\n(Generated by 14 AI Models)\n#マイメモ #AI秘書',
                  subject: '本日の戦略',
                );
              },
            )
        ],
      ),
      backgroundColor: Colors.blueGrey[50],
      body: Column(
        children: [
          // 上部コントロールパネル
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                const Text('CEO Dashboard',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStrategyButton('今', 'now', Icons.flash_on),
                    _buildStrategyButton('今日', 'today', Icons.today),
                    _buildStrategyButton(
                        '今週', 'week', Icons.calendar_view_week),
                    _buildStrategyButton('今月', 'month', Icons.calendar_month),
                    _buildStrategyButton('今年', 'year', Icons.rocket_launch),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _addTaskFromImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('視覚情報からタスクを追加 (Camera)'),
                ),
              ],
            ),
          ),

          // 結果表示エリア
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        const Text('14種類のAI頭脳が戦略を練っています...',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('Gemini 3.0 / 2.5 / Pro ...',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  )
                : _strategyResult == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assistant,
                                size: 80, color: Colors.blueGrey[200]),
                            const SizedBox(height: 16),
                            const Text('「期間」を選択して、戦略立案を指示してください。',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_usedModel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.amber[100],
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('Strategist: $_usedModel',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.amber[900],
                                        fontWeight: FontWeight.bold)),
                              ),
                            const SizedBox(height: 8),
                            MarkdownBody(
                              data: _strategyResult!,
                              styleSheet: MarkdownStyleSheet(
                                h1: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo),
                                h2: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87),
                                p: const TextStyle(fontSize: 16, height: 1.6),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyButton(String label, String type, IconData icon) {
    final isSelected = _currentStrategyType == type;
    return InkWell(
      onTap: _isLoading ? null : () => _consultSecretary(type),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.indigo : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isSelected ? Colors.white : Colors.grey[600], size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.indigo : Colors.grey)),
        ],
      ),
    );
  }
}
