// lib/pages/ai_assistant_chat_page.dart
// Voice AI チャットページ — Web Speech API + ai-hub my_agent.chat
import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

class AiAssistantChatPage extends StatefulWidget {
  const AiAssistantChatPage({super.key});

  @override
  State<AiAssistantChatPage> createState() => _AiAssistantChatPageState();
}

class _AiAssistantChatPageState extends State<AiAssistantChatPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechSupported = true;
  String _interimText = '';
  web.SpeechRecognition? _recognition;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _bg = Color(0xFF0A0A0A);
  static const _card = Color(0xFF1A1A2E);
  static const _orange = Color(0xFFFF6B35);
  static const _userBubble = Color(0xFFFF6B35);
  static const _aiBubble = Color(0xFF1E1E1E); // surface2

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.stop();
    _initSpeech();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _recognition?.abort();
    super.dispose();
  }

  void _initSpeech() {
    try {
      final recognition = web.SpeechRecognition();
      recognition.lang = 'ja-JP';
      recognition.continuous = false;
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;

      recognition.onresult = ((web.SpeechRecognitionEvent event) {
        final results = event.results;
        if (results.length == 0) return;
        final lastResult = results.item(results.length - 1);
        final transcript = lastResult.item(0).transcript;
        if (lastResult.isFinal) {
          setState(() {
            _inputCtrl.text = transcript;
            _interimText = '';
            _isListening = false;
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        } else {
          setState(() => _interimText = transcript);
        }
      }).toJS;

      recognition.onend = (() {
        if (mounted && _isListening) {
          setState(() {
            _isListening = false;
            _interimText = '';
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      }).toJS;

      recognition.onerror = ((web.SpeechRecognitionErrorEvent event) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _interimText = '';
          });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }
      }).toJS;

      _recognition = recognition;
    } catch (_) {
      _speechSupported = false;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final res = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'my_agent.history'},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final history = data['history'] as List<dynamic>? ?? [];
        final msgs = <Map<String, String>>[];
        for (final rawItem in history.reversed) {
          final item = rawItem as Map<String, dynamic>;
          final meta = item['metadata'] as Map<String, dynamic>? ?? {};
          final msg = meta['message'] as String? ?? '';
          final resp = meta['response'] as String? ?? '';
          if (msg.isNotEmpty) msgs.add({'role': 'user', 'content': msg});
          if (resp.isNotEmpty) msgs.add({'role': 'assistant', 'content': resp});
        }
        if (mounted) setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('history load error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _inputCtrl.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res = await _supabase.functions.invoke(
        'ai-hub',
        body: {'action': 'my_agent.chat', 'message': text},
      );
      final data = res.data as Map<String, dynamic>?;
      final response = data?['response'] as String? ?? 'エラーが発生しました。';
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': response});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'エラーが発生しました: $e'});
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _toggleVoice() {
    if (_recognition == null || !_speechSupported) {
      _showSnackBar('このブラウザは音声入力に対応していません');
      return;
    }
    if (_isListening) {
      _recognition!.stop();
      setState(() {
        _isListening = false;
        _interimText = '';
      });
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    } else {
      setState(() {
        _isListening = true;
        _interimText = '';
      });
      _pulseCtrl.repeat(reverse: true);
      try {
        _recognition!.start();
      } catch (e) {
        setState(() => _isListening = false);
        _pulseCtrl.stop();
        _pulseCtrl.reset();
        _showSnackBar('音声入力を開始できませんでした');
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF1A1A2E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        title: Row(
          children: [
            const Icon(Icons.smart_toy, color: _orange, size: 22),
            const SizedBox(width: 8),
            const Text(
              'AI アシスタント',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            if (_isListening) ...[
              const SizedBox(width: 8),
              ScaleTransition(
                scale: _pulseAnim,
                child: const Icon(Icons.mic, color: Colors.red, size: 16),
              ),
            ],
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white54),
            tooltip: '履歴クリア',
            onPressed: () => setState(() => _messages.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isListening)
            Container(
              width: double.infinity,
              color: Colors.red.withAlpha(20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _interimText.isEmpty ? '音声を認識中...' : _interimText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty && !_isLoading
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[i];
                      return _buildMessageBubble(
                        msg['content'] ?? '',
                        isUser: msg['role'] == 'user',
                      );
                    },
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          const Text(
            'AI アシスタントと話しましょう',
            style: TextStyle(color: Colors.white38, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            _speechSupported
                ? 'テキスト入力またはマイクボタンで話しかけてください'
                : 'テキストを入力して送信してください',
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, {required bool isUser}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1F2041),
              child: Icon(Icons.smart_toy, size: 18, color: _orange),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? _userBubble : _aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white.withAlpha(230),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF2A2A2A), // surface3
              child: Icon(Icons.person, size: 18, color: _orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF1F2041),
            child: Icon(Icons.smart_toy, size: 18, color: _orange),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: _aiBubble,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'メッセージを入力...',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                    height: 1.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: _orange, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2A2A2A), // surface3
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            if (_speechSupported)
              ScaleTransition(
                scale: _isListening
                    ? _pulseAnim
                    : const AlwaysStoppedAnimation(1.0),
                child: IconButton(
                  onPressed: _toggleVoice,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.white54,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: _isListening
                        ? Colors.red.withAlpha(30)
                        : Colors.transparent,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _orange,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: _orange),
              style: IconButton.styleFrom(
                backgroundColor: _orange.withAlpha(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<int> _dotCount;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _dotCount = IntTween(begin: 1, end: 3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCount,
      builder: (_, __) {
        return Text(
          '●' * _dotCount.value,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            height: 1.5,
          ),
        );
      },
    );
  }
}
