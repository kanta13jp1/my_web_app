import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web_api;

import '../services/ai_fsrs_service.dart';

class AiUniversityVoicePage extends StatefulWidget {
  const AiUniversityVoicePage({super.key});

  @override
  State<AiUniversityVoicePage> createState() => _AiUniversityVoicePageState();
}

class _AiUniversityVoicePageState extends State<AiUniversityVoicePage> {
  final _supabase = Supabase.instance.client;
  final _fsrsService = AiFsrsService();

  String _selectedProvider = 'google';
  final List<String> _providers = [
    'google',
    'openai',
    'anthropic',
    'microsoft',
    'meta',
    'deepseek',
    'mistral',
    'perplexity',
    'groq',
  ];

  String _questionText = 'プロバイダーを選択してください。';
  String _ttsStatus = 'idle';
  String _feedbackText = '';
  bool _useTextInput = false;
  final _textController = TextEditingController();

  web_api.HTMLAudioElement? _audio;

  @override
  void dispose() {
    _audio?.pause();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _questionText = '読み込み中...';
      _ttsStatus = 'idle';
      _feedbackText = '';
    });
    try {
      final rows = await _supabase
          .from('ai_university_content')
          .select('title, content')
          .eq('provider', _selectedProvider)
          .eq('category', 'overview')
          .limit(1);
      if ((rows as List).isEmpty) {
        setState(() => _questionText = 'コンテンツがありません。');
        return;
      }
      final content = rows.first['content'] as String? ?? '';
      final excerpt =
          content.replaceAll(RegExp(r'#+ '), '').replaceAll('**', '');
      setState(
        () => _questionText =
            excerpt.length > 200 ? '${excerpt.substring(0, 200)}...' : excerpt,
      );
      await _playTts(_questionText);
    } catch (e) {
      setState(() => _questionText = 'エラー: $e');
    }
  }

  Future<void> _playTts(String text) async {
    setState(() => _ttsStatus = 'loading');
    try {
      final resp = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'voice.tts',
          'text': text,
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      final base64Audio = data?['audio_base64'] as String? ?? '';
      if (base64Audio.isEmpty) {
        setState(() => _ttsStatus = 'error');
        return;
      }
      // data URL で直接再生 (Blob/toJS 不要)
      _audio = web_api.HTMLAudioElement();
      _audio!.src = 'data:audio/mpeg;base64,$base64Audio';
      _audio!.play();
      setState(() => _ttsStatus = 'playing');
    } catch (_) {
      setState(() => _ttsStatus = 'error');
    }
  }

  Future<void> _submitAnswer(String answer) async {
    if (answer.trim().isEmpty) return;
    setState(() => _feedbackText = '評価中...');
    try {
      final resp = await _supabase.functions.invoke(
        'ai-hub',
        body: {
          'action': 'quiz.evaluate',
          'question': _questionText,
          'user_answer': answer,
          'correct_answer': _questionText,
        },
      );
      final data = resp.data as Map<String, dynamic>?;
      final result = data?['result'] as String? ?? 'incorrect';
      final grade = result == 'correct'
          ? 3
          : result == 'partial'
              ? 2
              : 1;
      final fsrsResult = await _fsrsService.gradeCard(
        provider: _selectedProvider,
        questionId: '${_selectedProvider}_voice',
        grade: grade,
      );
      final nextDueLabel = AiFsrsService.nextDueLabel(fsrsResult.nextDue);
      if (result == 'correct') {
        setState(() => _feedbackText = '正解！次回: $nextDueLabel');
      } else {
        final explResp = await _supabase.functions.invoke(
          'ai-hub',
          body: {
            'action': 'quiz.explain',
            'question': _questionText,
            'user_answer': answer,
            'correct_answer': _questionText,
            'provider': _selectedProvider,
          },
        );
        final explData = explResp.data as Map<String, dynamic>?;
        final explanation = explData?['explanation'] as String? ?? '';
        setState(
          () => _feedbackText = '不正解。次回: $nextDueLabel\n\n$explanation',
        );
      }
    } catch (e) {
      setState(() => _feedbackText = 'エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        title: const Text(
          'AI大学 音声学習',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // プロバイダー選択
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A2E),
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox.shrink(),
                items: _providers
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedProvider = v);
                },
              ),
            ),
            const SizedBox(height: 16),

            // 学習開始ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5AFE),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('このプロバイダーを学ぶ'),
                onPressed: _loadQuestion,
              ),
            ),
            const SizedBox(height: 20),

            // 問題文エリア
            if (_questionText.isNotEmpty &&
                _questionText != 'プロバイダーを選択してください。') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.volume_up,
                          color: Color(0xFF3D5AFE),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _ttsStatus == 'loading'
                              ? '音声生成中...'
                              : _ttsStatus == 'playing'
                                  ? '再生中...'
                                  : _ttsStatus == 'error'
                                      ? '音声エラー（テキスト表示）'
                                      : '問題文',
                          style: const TextStyle(
                            color: Color(0xFF3D5AFE),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_ttsStatus == 'loading') ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF3D5AFE),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _questionText,
                      style: const TextStyle(
                        color: Colors.white,
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 回答エリア
              if (!_useTextInput) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A2E),
                      side: const BorderSide(color: Color(0xFF3D5AFE)),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.mic, color: Color(0xFF3D5AFE)),
                    label: const Text(
                      '話して回答',
                      style: TextStyle(
                        color: Color(0xFF3D5AFE),
                        fontSize: 16,
                      ),
                    ),
                    onPressed: () => setState(() => _useTextInput = true),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _useTextInput = true),
                    child: const Text(
                      'テキスト入力に切替',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '回答を入力してください...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF3D5AFE)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D5AFE),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _submitAnswer(_textController.text),
                        child: const Text('送信'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _useTextInput = false),
                      child: const Text(
                        '音声に戻る',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ],

              // フィードバック
              if (_feedbackText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _feedbackText.startsWith('正解')
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                        : const Color(0xFFFF6B35).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _feedbackText.startsWith('正解')
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                          : const Color(0xFFFF6B35).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _feedbackText,
                    style: const TextStyle(color: Colors.white, height: 1.7),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
