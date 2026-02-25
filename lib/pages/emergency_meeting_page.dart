import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum MeetingFocus {
  balanced,
  continuation,
  abstinence,
}

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

  String? _geminiApiKey;
  String _selectedModel = 'gemma-3-4b-it';
  MeetingFocus _selectedFocus = MeetingFocus.balanced;
  List<String> _continuationPlan = <String>[];
  List<String> _abstinenceRules = <String>[];
  String? _riskAlert;
  List<String> _selectableModels = [
    'gemma-3-1b-it',
    'gemma-3-4b-it',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];
  final String _customPromptInstructions = _defaultPromptInstructions;
  static const String _defaultPromptInstructions =
      'あなたは「自分株式会社」の緊急役員会議ファシリテーターです。\n'
      'テーマは必ず「継続」と「禁欲」。感情論ではなく、実行しやすい行動に落とし込んでください。\n\n'
      '【会議フォーカス】\n'
      '- focusTheme: {focusTheme}\n'
      '- focusInstruction: {focusInstruction}\n\n'
      '【現状データ】\n'
      '- userId: {userId}\n'
      '- noteCount: {noteCount}\n'
      '- subCount: {subCount}\n'
      '- points: {points}\n'
      '- level: {level}\n'
      '- currentStreak: {currentStreak}\n'
      '- danshariCount: {danshariCount}\n'
      '- healthData: "データ未連携"\n'
      '- marketData: "データ未連携"\n'
      '- importUsed: "未確認"\n\n'
      '【役員構成】\n'
      '- CFO: 支出とサブスクの最適化\n'
      '- CKO: 学習と記録の継続設計\n'
      '- CHRO: 習慣維持とモチベーション管理\n'
      '- CSO: 全体戦略と実行計画の統合\n\n'
      '【出力ルール】\n'
      '1. messages は4〜6件。各役員が数字に触れて短く提言する。\n'
      '2. continuation_plan は「48時間以内に実行する継続アクション」を3件。\n'
      '3. abstinence_rules は「誘惑を断つ禁欲ルール」を3件。\n'
      '4. risk_alert は最大リスクを1文で示す。\n'
      '5. conclusion は CEO が今週やる最優先アクションを1〜2文で示す。\n'
      '6. 返答はJSONのみ。Markdownや説明文は不要。\n\n'
      '{\n'
      '  "messages": [\n'
      '    {"role":"CFO","speaker_name":"AI CFO","content":"..."},\n'
      '    {"role":"CKO","speaker_name":"AI CKO","content":"..."},\n'
      '    {"role":"CHRO","speaker_name":"AI CHRO","content":"..."},\n'
      '    {"role":"CSO","speaker_name":"AI CSO","content":"..."}\n'
      '  ],\n'
      '  "continuation_plan": ["...", "...", "..."],\n'
      '  "abstinence_rules": ["...", "...", "..."],\n'
      '  "risk_alert": "...",\n'
      '  "conclusion": "..."\n'
      '}';

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
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
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

  String? _errorMessage;

  String _focusLabel(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '継続 + 禁欲（両立）';
      case MeetingFocus.continuation:
        return '継続強化';
      case MeetingFocus.abstinence:
        return '禁欲強化';
    }
  }

  String _focusShortLabel(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '両立';
      case MeetingFocus.continuation:
        return '継続';
      case MeetingFocus.abstinence:
        return '禁欲';
    }
  }

  String _focusInstruction(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '継続と禁欲のバランスを重視し、両方の改善策を同じ優先度で提案する。';
      case MeetingFocus.continuation:
        return '継続率の改善を最優先。習慣化・再開しやすさ・反復設計に集中する。';
      case MeetingFocus.abstinence:
        return '禁欲の成功率を最優先。誘惑遮断・トリガー回避・事前ルール化に集中する。';
    }
  }

  Color _focusColor(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return Colors.blueGrey;
      case MeetingFocus.continuation:
        return Colors.blue;
      case MeetingFocus.abstinence:
        return Colors.redAccent;
    }
  }

  List<String> _extractStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _buildCodexCopyText() {
    final log = _currentLog;
    if (log == null) return '';

    final payload = <String, dynamic>{
      'meeting_id': log.id,
      'created_at': log.createdAt.toIso8601String(),
      'topic': log.topic,
      'focus': _focusLabel(_selectedFocus),
      'model': _selectedModel,
      'messages': log.messages
          .map(
            (msg) => <String, dynamic>{
              'role': msg.role,
              'speaker_name': msg.speakerName,
              'content': msg.content,
            },
          )
          .toList(),
      'continuation_plan': _continuationPlan,
      'abstinence_rules': _abstinenceRules,
      'risk_alert': _riskAlert,
      'conclusion': log.conclusion,
    };
    final jsonPayload = const JsonEncoder.withIndent('  ').convert(payload);

    return '''
【緊急役員会議 → Codex 連携データ】
この内容をもとに、次のPDCA改善（実装 + テスト）を提案・実装してください。

1. 継続アクションが実行しやすくなるUI/導線改善
2. 禁欲ルールの実行率を上げる抑止設計（通知・制限・可視化）
3. 次回会議で検証できる計測項目の追加

--- Meeting Result JSON ---
$jsonPayload
''';
  }

  Future<void> _copyMeetingForCodex() async {
    if (_currentLog == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コピーする会議結果がありません。')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: _buildCodexCopyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('会議結果をCodex貼り付け形式でコピーしました。')),
    );
  }

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
      _loadingStatus = '継続と禁欲に関するデータを収集中...';
      _errorMessage = null;
      _continuationPlan = <String>[];
      _abstinenceRules = <String>[];
      _riskAlert = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in.');
      }

// ▼ 修正: テーブルが存在しない(404)場合などにクラッシュさせず、0やnullを返すように catchError を追加
      final results = await Future.wait<dynamic>([
        _supabase
            .from('notes')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す
        _supabase
            .from('subscriptions')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle()
            .catchError((_) => null), // エラー時はnullを返す
        _supabase
            .from('danshari_items')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す（今回の原因）
      ]);

      final noteCount = results[0] as int;
      final subCount = results[1] as int;
      final userStats = results[2] as Map<String, dynamic>?;
      final danshariCount = results[3] as int;
      final points = userStats?['total_points'] ?? 0;
      final level = userStats?['current_level'] ?? 1;
      final currentStreak = userStats?['current_streak'] ?? 0;

      final contextPrompt = _customPromptInstructions
          .replaceFirst('{userId}', userId)
          .replaceFirst('{noteCount}', noteCount.toString())
          .replaceFirst('{subCount}', subCount.toString())
          .replaceFirst('{points}', points.toString())
          .replaceFirst('{level}', level.toString())
          .replaceFirst('{currentStreak}', currentStreak.toString())
          .replaceFirst('{danshariCount}', danshariCount.toString())
          .replaceFirst('{focusTheme}', _focusLabel(_selectedFocus))
          .replaceFirst(
            '{focusInstruction}',
            _focusInstruction(_selectedFocus),
          );

      setState(() => _loadingStatus = 'AI役員が継続・禁欲の改善策を議論中...');

      final aiService = AIService(null, _geminiApiKey);
      final responseText = await aiService.generateContent(
        model: _selectedModel,
        prompt: contextPrompt,
      );

      if (responseText == null) {
        throw Exception('AIからの応答がありません。');
      }

      setState(() => _loadingStatus = '会議結果を統合中...');

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
      final continuationPlan = _extractStringList(decoded['continuation_plan']);
      final abstinenceRules = _extractStringList(decoded['abstinence_rules']);
      final riskAlert = decoded['risk_alert']?.toString();
      final normalizedRiskAlert = riskAlert?.trim();

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
        topic: '緊急役員会議（${_focusLabel(_selectedFocus)}）',
        conclusion: conclusion,
        messages: messages,
        createdAt: DateTime.now(),
      );

      setState(() {
        _currentLog = log;
        _continuationPlan = continuationPlan;
        _abstinenceRules = abstinenceRules;
        _riskAlert =
            (normalizedRiskAlert == null || normalizedRiskAlert.isEmpty)
                ? null
                : normalizedRiskAlert;
      });
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
        title: const Text('緊急役員会議 (継続・禁欲)'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: (_isLoading || _currentLog == null)
                ? null
                : _copyMeetingForCodex,
            tooltip: 'Codex用にコピー',
          ),
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
                        '継続と禁欲を立て直す緊急会議を開始しますか？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI役員が継続率と誘惑リスクを分析し、48時間で実行できる再建プランを提示します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '会議フォーカス: ${_focusLabel(_selectedFocus)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MeetingFocus.values.map((focus) {
                          final isSelected = _selectedFocus == focus;
                          final chipColor = _focusColor(focus);
                          return ChoiceChip(
                            label: Text(_focusShortLabel(focus)),
                            selected: isSelected,
                            selectedColor: chipColor.withValues(alpha: 0.18),
                            side: BorderSide(
                              color:
                                  isSelected ? chipColor : Colors.grey.shade400,
                            ),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? chipColor : Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _selectedFocus = focus);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _focusInstruction(_selectedFocus),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.45,
                          ),
                        ),
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
                            '継続・禁欲プランを作成',
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
                      '継続と禁欲の打ち手を組み立てています...',
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
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.lightGreenAccent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '継続・禁欲 EXECUTION PLAN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: _copyMeetingForCodex,
                tooltip: '会議結果をコピー',
                icon: const Icon(
                  Icons.content_copy,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          if (_riskAlert != null) ...[
            _buildAlertChip(_riskAlert!),
            const SizedBox(height: 14),
          ],
          if (_continuationPlan.isNotEmpty) ...[
            _buildActionList(
              title: '継続アクション（48時間）',
              icon: Icons.trending_up,
              accentColor: Colors.lightBlueAccent,
              actions: _continuationPlan,
            ),
            const SizedBox(height: 14),
          ],
          if (_abstinenceRules.isNotEmpty) ...[
            _buildActionList(
              title: '禁欲ルール（誘惑遮断）',
              icon: Icons.block,
              accentColor: Colors.pinkAccent,
              actions: _abstinenceRules,
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            '最終決定',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentLog!.conclusion,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyMeetingForCodex,
              icon: const Icon(Icons.copy_all),
              label: const Text('Codexに貼り付ける結果をコピー'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionList({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<String> actions,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final action in actions.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '・$action',
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertChip(String alertText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alertText,
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
              ),
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
