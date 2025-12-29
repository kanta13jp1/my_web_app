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
  bool _isTranslating = false;
  String? _strategyResult;
  String? _usedModel;
  List<String> _attemptLogs = [];
  String _currentStrategyType = 'today';

  final ImagePicker _picker = ImagePicker();

  Future<String?> _translateText(String text) async {
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'translate',
          'content': text,
          'targetLanguage': 'Japanese'
        },
      );
      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);
      return data['result'];
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('翻訳エラー: $e')));
      return null;
    }
  }

  Future<void> _consultSecretary(String strategyType) async {
    setState(() {
      _isLoading = true;
      _currentStrategyType = strategyType;
      _strategyResult = null;
      _attemptLogs = [];
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;
      final notesResponse = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('updated_at', ascending: false)
          .limit(10);
      final recentNotes =
          (notesResponse as List).map((n) => Note.fromJson(n)).toList();
      final recentNotesJson = recentNotes
          .map((n) => {'id': n.id, 'title': n.title, 'content': n.content})
          .toList();

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'secretary_strategy',
          'strategyType': strategyType,
          'recentNotes': recentNotesJson
        },
      );

      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data['success'] != true) throw Exception(data['error']);

      setState(() {
        _strategyResult = data['result']?.toString() ?? '回答が得られませんでした';
        _usedModel = data['used_model']?.toString();
        _attemptLogs = List<String>.from(data['attempt_logs'] ?? []);
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('秘書との通信エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _translateStrategy() async {
    if (_strategyResult == null) return;
    setState(() => _isTranslating = true);
    final translated = await _translateText(_strategyResult!);
    if (mounted && translated != null)
      setState(() {
        _strategyResult = translated;
      });
    setState(() => _isTranslating = false);
  }

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
          'imageBase64': base64Image
        },
      );
      if (response.status != 200)
        throw Exception('Server error: ${response.status}');
      final data = response.data;
      if (data is! Map) throw Exception('Invalid response format');
      if (data['success'] != true)
        throw Exception(data['error'] ?? 'Unknown error');

      final resultData = data['result'];
      Map<String, dynamic> taskData;
      if (resultData is Map) {
        taskData = Map<String, dynamic>.from(resultData);
      } else {
        taskData = {
          'title': '解析結果',
          'content': resultData.toString(),
          'priority': '中'
        };
      }
      if (!mounted) return;
      await _showTaskConfirmDialog(taskData, image);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('解析エラー: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTaskConfirmDialog(
      Map<String, dynamic> taskData, XFile imageFile) async {
    final titleController =
        TextEditingController(text: taskData['title']?.toString() ?? '');
    final contentController =
        TextEditingController(text: taskData['content']?.toString() ?? '');
    String priority = taskData['priority']?.toString() ?? '中';
    bool isDialogTranslating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text(' 新規タスク案'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI秘書が画像からタスクを起案しました。',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: isDialogTranslating
                        ? null
                        : () async {
                            setDialogState(() => isDialogTranslating = true);
                            final results = await Future.wait([
                              _translateText(titleController.text),
                              _translateText(contentController.text)
                            ]);
                            if (results[0] != null)
                              titleController.text = results[0]!;
                            if (results[1] != null)
                              contentController.text = results[1]!;
                            setDialogState(() => isDialogTranslating = false);
                          },
                    icon: isDialogTranslating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.translate, size: 18),
                    label: const Text('日本語に翻訳'),
                  ),
                ),
                TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                        labelText: '件名', border: OutlineInputBorder())),
                const SizedBox(height: 8),
                TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                        labelText: '詳細', border: OutlineInputBorder()),
                    maxLines: 3),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.priority_high,
                      size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text('推奨優先度: $priority')
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('却下')),
            ElevatedButton(
              onPressed: isDialogTranslating
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _saveTask(titleController.text,
                          contentController.text, imageFile);
                    },
              child: const Text('承認（保存）'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _saveTask(String title, String content, XFile imageFile) async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now().toIso8601String();
      final noteData = await supabase
          .from('notes')
          .insert({
            'user_id': userId,
            'title': title,
            'content': content,
            'is_archived': false,
            'created_at': now,
            'updated_at': now
          })
          .select()
          .single();
      final noteId = noteData['id'] as int;
      final bytes = await imageFile.readAsBytes();
      final size = await imageFile.length();
      final file = PlatformFile(name: imageFile.name, size: size, bytes: bytes);
      await AttachmentService.uploadFile(noteId: noteId, file: file);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('タスクが登録されました'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  //  シェア内容を自分株式会社仕様に更新
                  Share.share(
                      '【自分株式会社 経営戦略】\n\n$_strategyResult\n\n(Generated by AI Secretary)\n ダウンロード: https://my-web-app-b67f4.web.app/\n#自分株式会社',
                      subject: '本日の戦略');
                })
        ],
      ),
      backgroundColor: Colors.blueGrey[50],
      body: Column(
        children: [
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
                      _buildStrategyButton('今年', 'year', Icons.rocket_launch)
                    ]),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _addTaskFromImage(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50)),
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('視覚情報からタスクを追加 (Camera)'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _strategyResult == null
                    ? Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.assistant,
                                size: 80, color: Colors.blueGrey[200]),
                            const SizedBox(height: 16),
                            const Text('「期間」を選択して、戦略立案を指示してください。',
                                style: TextStyle(color: Colors.grey))
                          ]))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_usedModel != null)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                            color: Colors.amber[100],
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text('Strategist: $_usedModel',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.amber[900],
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      if (_attemptLogs.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                              '(${_attemptLogs.length} attempts failed)',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.red[300])),
                                        )
                                    ],
                                  ),
                                TextButton.icon(
                                  onPressed: _isTranslating
                                      ? null
                                      : _translateStrategy,
                                  icon: _isTranslating
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.translate, size: 18),
                                  label: const Text('日本語に翻訳'),
                                ),
                              ],
                            ),
                            if (_attemptLogs.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Retry Logs:',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                    ..._attemptLogs.map((log) => Text(' $log',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: Colors.grey))),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8),
                            MarkdownBody(data: _strategyResult!),
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
                shape: BoxShape.circle),
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
