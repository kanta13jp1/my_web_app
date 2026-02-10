import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EmergencyMeetingPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;

  const EmergencyMeetingPage({super.key, this.supabaseClient});

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  final ScrollController _scrollController = ScrollController();
  BoardMeetingLog? _currentLog;
  bool _isLoading = false;
  String _loadingStatus = '';

  // --- Start of new state variables ---
  String? _geminiApiKey;
  String _selectedModel =
      'gemma-3-4b-it'; // Default model, similar to morning briefing
  List<String> _selectableModels = [
    'gemma-3-1b-it',
    'gemma-3-4b-it',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];
  final String _customPromptInstructions = _defaultPromptInstructions;
  static const String _defaultPromptInstructions =
      'あなたは「自分株式会社」の役員会のファシリテーターです。\n'
      '以下の【現状データ】と【役員構成】に基づき、緊急役員会議の議事録をJSON形式で生成してください。\n\n'
      '【役員構成と専門分野】\n'
      '- CEO: 最高経営責任者 (ユーザー自身)\n'
      '- CSO: 最高戦略責任者 (全体戦略、目標達成)\n'
      '- CFO: 最高財務責任者 (コスト、サブスクリプション)\n'
      '- CKO: 最高知識責任者 (メモ、知識蓄積)\n'
      '- CHRO: 最高人事責任者 (ユーザーのモチベーション、ポイント、レベル)\n'
      '- CHO: 最高健康責任者 (健康状態、運動)\n'
      '- CMO: 最高マーケティング責任者 (アプリ利用頻度、市場での立ち位置)\n'
      '- M&A: 合併・買収担当 (外部連携、データインポート)\n\n'
      '【現状データ】\n'
      '- userId: {userId}\n'
      '- noteCount: {noteCount}\n'
      '- subCount: {subCount}\n'
      '- points: {points}\n'
      '- level: {level}\n'
      '- danshariCount: {danshariCount}\n'
      '- healthData: "データ未連携"\n'
      '- marketData: "データ未連携"\n'
      '- importUsed: "未確認"\n\n'
      '【指示】\n'
      '1. 各役員に、担当分野のデータに基づいて辛口な現状分析と報告をさせてください。データが未連携の場合は、仮説に基づいて報告させてください。\n'
      '2. 数字が少ない場合は「怠慢」、多い場合は「リソースの無駄遣いや管理不足」の観点から指摘させてください。\n'
      '3. 最後に、CSOに全体の状況を要約させ、CEOが今週末に実行すべき具体的なアクションプランを3つ提案させてください。\n'
      '4. 出力は必ず以下のJSON形式に従ってください。他のテキストは一切含めないでください。\n\n'
      '```json\n'
      '{\n'
      '  "messages": [\n'
      '    {\n'
      '      "role": "CKO",\n'
      '      "speaker_name": "AI CKO",\n'
      '      "content": "(ここにCKOの報告内容)"\n'
      '    },\n'
      '    {\n'
      '      "role": "CFO",\n'
      '      "speaker_name": "AI CFO",\n'
      '      "content": "(ここにCFOの報告内容)"\n'
      '    },\n'
      '    {\n'
      '      "role": "CHRO",\n'
      '      "speaker_name": "AI CHRO",\n'
      '      "content": "(ここにCHROの報告内容)"\n'
      '    },\n'
      '    {\n'
      '      "role": "CSO",\n'
      '      "speaker_name": "AI CSO",\n'
      '      "content": "(ここにCSOの最終提案内容)"\n'
      '    }\n'
      '  ],\n'
      '  "conclusion": "(ここにCSOが提案するアクションプラン3つをまとめた結論)"\n'
      '}\n'
      '```';
  // --- End of new state variables ---

  // Supabase client getter
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Changed from _fetchModels
  }

  // --- Start of new functions ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _geminiApiKey = prefs.getString('gemini_api_key');
        // A model saved for the daily report can be reused here for consistency
        final String? savedModel =
            prefs.getString('gemini_model_emergency_meeting');
        if (savedModel != null) {
          _selectedModel = savedModel;
        }
        // Ensure the selected model is in the list, if not, add it.
        if (!_selectableModels.contains(_selectedModel)) {
          _selectableModels.insert(0, _selectedModel);
        }
      });
    }
  }

  Future<List<String>> fetchGeminiModels(String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
        if (data['models'] != null) {
          return (data['models'] as List)
              .whereType<Map<String, dynamic>>()
              .where(
                (m) =>
                    (m['supportedGenerationMethods'] as List?)
                        ?.contains('generateContent') ??
                    false,
              )
              .map<String>(
                (m) => m['name'].toString().replaceFirst('models/', ''),
              )
              .where(
                (name) => !name.contains('tts') && !name.contains('embedding'),
              )
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    }
    return [];
  }

  Future<void> showSettingsDialog() async {
    final apiKeyController = TextEditingController(text: _geminiApiKey ?? '');
    String tempSelectedModel = _selectedModel;
    bool isFetchingModels = false;
    List<String> currentSelectableModels = List.from(_selectableModels);

    if (!currentSelectableModels.contains(tempSelectedModel)) {
      currentSelectableModels.add(tempSelectedModel);
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('AIモデル設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(),
                      hintText: 'APIキーを入力してください',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  if (isFetchingModels)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (apiKeyController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('APIキーを入力してください'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isFetchingModels = true);
                          final models =
                              await fetchGeminiModels(apiKeyController.text);
                          setDialogState(() {
                            isFetchingModels = false;
                            if (models.isNotEmpty) {
                              currentSelectableModels = models;
                              if (!currentSelectableModels
                                  .contains(tempSelectedModel)) {
                                tempSelectedModel =
                                    currentSelectableModels.first;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${models.length}個のモデルを取得しました'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('モデルの取得に失敗しました'),
                                ),
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('利用可能なモデル一覧を取得'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tempSelectedModel,
                    decoration: const InputDecoration(
                      labelText: '使用モデル',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: currentSelectableModels.toSet().map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          m,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tempSelectedModel = val);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'gemini_model_emergency_meeting',
                    tempSelectedModel,
                  );
                  if (apiKeyController.text.isNotEmpty) {
                    await prefs.setString(
                      'gemini_api_key',
                      apiKeyController.text,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _selectedModel = tempSelectedModel;
                      if (apiKeyController.text.isNotEmpty) {
                        _geminiApiKey = apiKeyController.text;
                      }
                      _selectableModels = currentSelectableModels;
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- End of new functions ---

  String? _errorMessage;

  // ... (initState and _fetchModels remain the same)

  Future<void> _conveneBoard() async {
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini APIキーを設定してください。')),
      );
      await showSettingsDialog();
      if (_geminiApiKey == null || _geminiApiKey!.isEmpty) return;
    }

    setState(() {
      _isLoading = true;
      _loadingStatus = '各部門からデータを収集中...';
      _errorMessage = null; // Clear previous errors
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in.');
      }

      final results = await Future.wait<dynamic>([
        _supabase.from('notes').count(CountOption.exact).eq('user_id', userId),
        _supabase
            .from('subscriptions')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0),
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle(),
        _supabase
            .from('danshari_items')
            .count(CountOption.exact)
            .eq('user_id', userId),
      ]);

      final noteCount = results[0] as int;
      final subCount = results[1] as int;
      final userStats = results[2] as Map<String, dynamic>?;
      final danshariCount = results[3] as int;
      final points = userStats?['total_points'] ?? 0;
      final level = userStats?['current_level'] ?? 1;

      final contextPrompt = _customPromptInstructions
          .replaceFirst('{userId}', userId)
          .replaceFirst('{noteCount}', noteCount.toString())
          .replaceFirst('{subCount}', subCount.toString())
          .replaceFirst('{points}', points.toString())
          .replaceFirst('{level}', level.toString())
          .replaceFirst('{danshariCount}', danshariCount.toString());

      setState(() => _loadingStatus = 'AI役員が分析中...');

      final aiService = AIService(null, _geminiApiKey);
      final responseText = await aiService.generateContent(
        model: _selectedModel,
        prompt: contextPrompt,
      );

      if (responseText == null) {
        throw Exception('AIからの応答がありません。');
      }

      setState(() => _loadingStatus = '議事録を解析中...');

      // Clean up potential markdown code block
      var responseJson = responseText.trim();
      final jsonStartIndex = responseJson.indexOf('{');
      final jsonEndIndex = responseJson.lastIndexOf('}');
      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        responseJson = responseJson.substring(
          jsonStartIndex,
          jsonEndIndex + 1,
        );
      }

      final decoded = jsonDecode(responseJson) as Map<String, dynamic>;
      final messageList = decoded['messages'] as List<dynamic>;
      final conclusion = decoded['conclusion'] as String;

      final messages = messageList.map((item) {
        final msg = item as Map<String, dynamic>;
        return BoardMessage(
          id: const Uuid().v4(),
          speakerName: msg['speaker_name'] as String,
          role: msg['role'] as String,
          content: msg['content'] as String,
          timestamp: DateTime.now(),
        );
      }).toList();

      final log = BoardMeetingLog(
        id: const Uuid().v4(),
        userId: userId,
        topic: '定期現状分析報告会',
        conclusion: conclusion,
        messages: messages,
        createdAt: DateTime.now(),
      );

      setState(() => _currentLog = log);
      await _saveMeetingToDb(log);
    } catch (e, s) {
      if (mounted) {
        final errString = e.toString();
        debugPrint('Failed to convene board: $e');
        debugPrint('Stack trace: $s');

        if (errString.contains('503') || errString.contains('UNAVAILABLE')) {
          _errorMessage = 'AIモデルが現在高負荷です。しばらくしてから再試行してください。';
        } else if (errString.contains('429') ||
            errString.contains('Quota') ||
            errString.contains('rate limit')) {
          _errorMessage = '「$_selectedModel」は利用上限に達しました。別のモデルを試してください。';
        } else if (errString.contains('400') &&
            errString.contains('API key not valid')) {
          _errorMessage = 'APIキーが無効です。設定を確認してください。';
        } else {
          _errorMessage = '会議エラー: $errString';
        }
        setState(() {}); // Update UI to show error
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMeetingToDb(BoardMeetingLog log) async {
    final meetingRes = await _supabase
        .from('board_meetings')
        .insert({
          'id': log.id,
          'user_id': log.userId,
          'topic': log.topic,
          'conclusion': log.conclusion,
          'created_at': log.createdAt.toIso8601String(),
        })
        .select()
        .single();

    final meetingId = meetingRes['id'];

    final messagesToInsert = log.messages.map((msg) {
      return {
        'meeting_id': meetingId,
        'speaker_name': msg.speakerName,
        'role': msg.role,
        'content': msg.content,
        'created_at': msg.timestamp.toIso8601String(),
      };
    }).toList();

    await _supabase.from('board_messages').insert(messagesToInsert);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('緊急役員会議 (経営分析)'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: showSettingsDialog,
            tooltip: 'AIモデル設定',
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          if (_currentLog == null && !_isLoading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_share,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '各部門からの報告を受理しますか？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'CFO, CKO, CSOなどの全AI役員が最新情報を分析し、CEOであるあなたに現状報告と次の一手を提案します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '使用モデル: ',
                              style: TextStyle(color: Colors.black54),
                            ),
                            Flexible(
                              child: Text(
                                _selectedModel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // --- Error Message Display ---
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // --- Convene Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _conveneBoard,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text(
                            '緊急招集する',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            disabledBackgroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '各部門のデータを集計しています...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: (_currentLog?.messages.length ?? 0) + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: Text(
                          '${_currentLog!.createdAt.year}年${_currentLog!.createdAt.month}月${_currentLog!.createdAt.day}日 臨時取締役会',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }
                  if (index == _currentLog!.messages.length + 1) {
                    return _buildConclusionCard();
                  }
                  final msg = _currentLog!.messages[index - 1];
                  return _buildMessageCard(msg);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(BoardMessage msg) {
    final isCeo = msg.role == 'CEO';
    final isCso = msg.role == 'CSO';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCso ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCso
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      color: isCeo ? Colors.blue[50] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(msg.role),
                  child: Icon(
                    _getRoleIcon(msg.role),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.speakerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      msg.role,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              msg.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionCard() {
    if (_currentLog?.conclusion == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rocket_launch, color: Colors.yellowAccent),
              SizedBox(width: 12),
              Text(
                'STRATEGIC DECISION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          Text(
            _currentLog!.conclusion,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return Colors.blue;
      case 'CSO':
        return Colors.orange[800]!;
      case 'CFO':
        return Colors.green[700]!;
      case 'CKO':
        return Colors.purple;
      case 'CMO':
        return Colors.pink;
      case 'CHO':
        return Colors.teal;
      case 'CHRO':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'CEO':
        return Icons.person;
      case 'CSO':
        return Icons.flag;
      case 'CFO':
        return Icons.attach_money;
      case 'CKO':
        return Icons.school;
      case 'CMO':
        return Icons.analytics;
      case 'CHO':
        return Icons.favorite;
      case 'CHRO':
        return Icons.diversity_3;
      default:
        return Icons.smart_toy;
    }
  }
}

// Add the BoardMeetingLog and BoardMessage models if they are not in a separate file.
// For the purpose of this file, I'm assuming they might look something like this.
// NOTE: I'm getting an error that BoardMeetingLog is not defined. I will define it.
