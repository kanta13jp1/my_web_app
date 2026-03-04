import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/note.dart';
import '../services/attachment_service.dart';
import '../services/agent_org_service.dart';
import '../utils/ai_secretary_content.dart';

class AISecretaryPage extends StatefulWidget {
  final String? initialStrategyType;
  final bool autoRunOnOpen;

  const AISecretaryPage({
    super.key,
    this.initialStrategyType,
    this.autoRunOnOpen = false,
  });

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
  final AgentOrgService _agentOrgService = AgentOrgService();

  Map<String, dynamic> _normalizeFunctionPayload(dynamic rawPayload) {
    if (rawPayload is Map) {
      return Map<String, dynamic>.from(rawPayload);
    }

    final payloadText = rawPayload?.toString().trim() ?? '';
    if (payloadText.isEmpty) {
      return const <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(payloadText);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      // Fall back below.
    }

    return <String, dynamic>{
      'success': true,
      'result': payloadText,
    };
  }

  String _strategyLabel(String strategyType) {
    switch (strategyType) {
      case 'now':
        return '今この瞬間';
      case 'today':
        return '今日';
      case 'week':
        return '今週';
      case 'month':
        return '今月';
      case 'year':
        return '今年';
      default:
        return '直近';
    }
  }

  bool _isSupportedStrategyType(String? strategyType) {
    switch (strategyType) {
      case 'now':
      case 'today':
      case 'week':
      case 'month':
      case 'year':
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialType = widget.initialStrategyType;
    if (_isSupportedStrategyType(initialType)) {
      _currentStrategyType = initialType!;
      if (widget.autoRunOnOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _consultSecretary(initialType);
        });
      }
    }
  }

  Future<String?> _translateText(String text) async {
    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'translate',
          'content': text,
          'targetLanguage': 'Japanese',
        },
      );
      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }
      final data = _normalizeFunctionPayload(response.data);
      if (data['success'] != true) throw Exception(data['error']);
      return data['result'] as String?;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('翻訳エラー: $e')));
      }
      return null;
    }
  }

  Future<String?> _loadStartupPromptFor(String slug) async {
    try {
      final workspace = await _agentOrgService.loadWorkspaceBySlug(slug);
      final startupPrompt = workspace?.startupPrompt.trim();
      if (startupPrompt == null || startupPrompt.isEmpty) {
        return null;
      }
      return startupPrompt;
    } catch (error) {
      debugPrint('Failed to load startup prompt for $slug: $error');
      return null;
    }
  }

  String _injectStartupPrompt({
    required String taskPrompt,
    String? startupPrompt,
  }) {
    final normalizedStartupPrompt = startupPrompt?.trim();
    if (normalizedStartupPrompt == null || normalizedStartupPrompt.isEmpty) {
      return taskPrompt;
    }
    return '$normalizedStartupPrompt\n\n[Current Request]\n$taskPrompt';
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
      final basePrompt = buildAiSecretaryPrompt(
        strategyLabel: _strategyLabel(strategyType),
        recentNotesJson: recentNotesJson,
      );
      final startupPrompt = await _loadStartupPromptFor('ceo');
      final prompt = _injectStartupPrompt(
        taskPrompt: basePrompt,
        startupPrompt: startupPrompt,
      );

      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'improve',
          'content': prompt,
        },
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }
      final data = _normalizeFunctionPayload(response.data);
      if (data['success'] != true) throw Exception(data['error']);

      setState(() {
        _strategyResult = data['result']?.toString() ?? '回答が得られませんでした';
        _usedModel = data['used_model']?.toString();
        _attemptLogs = List<String>.from(data['attempt_logs'] as List? ?? []);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('MAGI秘書との通信エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _translateStrategy() async {
    if (_strategyResult == null) return;
    setState(() => _isTranslating = true);
    final translated = await _translateText(_strategyResult!);
    if (mounted && translated != null) {
      setState(() {
        _strategyResult = translated;
      });
    }
    setState(() => _isTranslating = false);
  }

  Future<void> _addTaskFromImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 80,
    );
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
      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      final resultData = data['result'];
      Map<String, dynamic> taskData;
      if (resultData is Map) {
        taskData = Map<String, dynamic>.from(resultData);
      } else {
        taskData = {
          'title': '解析結果',
          'content': resultData.toString(),
          'priority': '中',
        };
      }
      if (!mounted) return;
      await _showTaskConfirmDialog(taskData, image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析エラー: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTaskConfirmDialog(
    Map<String, dynamic> taskData,
    XFile imageFile,
  ) async {
    final titleController =
        TextEditingController(text: taskData['title']?.toString() ?? '');
    final contentController =
        TextEditingController(text: taskData['content']?.toString() ?? '');
    final String priority = taskData['priority']?.toString() ?? '中';
    bool isDialogTranslating = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text(' 新規タスク案'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MAGI秘書が画像からタスクを起案しました。',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
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
                                _translateText(contentController.text),
                              ]);
                              if (results[0] != null) {
                                titleController.text = results[0]!;
                              }
                              if (results[1] != null) {
                                contentController.text = results[1]!;
                              }
                              setDialogState(() => isDialogTranslating = false);
                            },
                      icon: isDialogTranslating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.translate, size: 18),
                      label: const Text('日本語に翻訳'),
                    ),
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '件名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '詳細',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.priority_high,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text('推奨優先度: $priority'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('却下'),
              ),
              ElevatedButton(
                onPressed: isDialogTranslating
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _saveTask(
                          titleController.text,
                          contentController.text,
                          imageFile,
                        );
                      },
                child: const Text('承認（保存）'),
              ),
            ],
          );
        },
      ),
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
            'updated_at': now,
          })
          .select()
          .single();
      final noteId = (noteData)['id'] as int;
      final bytes = await imageFile.readAsBytes();
      final size = await imageFile.length();
      final file = PlatformFile(name: imageFile.name, size: size, bytes: bytes);
      await AttachmentService.uploadFile(noteId: noteId, file: file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('タスクが登録されました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失敗: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MAGI戦略秘書室'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [
          if (_strategyResult != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text: buildAiSecretaryShareText(_strategyResult!),
                    subject: '本日の戦略',
                  ),
                );
              },
            ),
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
                const Text(
                  'CEO Dashboard',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStrategyButton('今', 'now', Icons.flash_on),
                    _buildStrategyButton('今日', 'today', Icons.today),
                    _buildStrategyButton(
                      '今週',
                      'week',
                      Icons.calendar_view_week,
                    ),
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _strategyResult == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assistant,
                              size: 80,
                              color: Colors.blueGrey[200],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '「期間」を選択して、MAGIに戦略立案を指示してください。',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
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
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber[100],
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'MAGI Strategist: $_usedModel',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.amber[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (_attemptLogs.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            '(${_attemptLogs.length} MAGI attempts failed)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red[300],
                                            ),
                                          ),
                                        ),
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
                                            strokeWidth: 2,
                                          ),
                                        )
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
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MAGI Retry Logs:',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    ..._attemptLogs.map(
                                      (log) => Text(
                                        ' $log',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
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
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.indigo : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
