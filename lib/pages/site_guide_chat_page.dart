import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/site_guide_catalog_item.dart';
import '../services/ai_hub_chat_service.dart';
import '../services/cartesia_voice_client.dart';
import '../services/cartesia_voice_session_service.dart';
import '../services/home_tool_usage_service.dart';
import '../services/site_guide_chat_service.dart';
import '../widgets/ai_response_observability_panel.dart';

typedef SiteGuideOpenCallback = Future<void> Function(BuildContext context);

class SiteGuideActionEntry {
  final SiteGuideCatalogItem item;
  final SiteGuideOpenCallback onOpen;

  const SiteGuideActionEntry({
    required this.item,
    required this.onOpen,
  });
}

class SiteGuideChatPage extends StatefulWidget {
  final String? initialQuestion;
  final SiteGuideChatService? service;
  final List<SiteGuideActionEntry>? toolCatalog;
  final VoidCallback? onOpenUserManual;
  final CartesiaVoiceSessionService? voiceSessionService;
  final CartesiaVoiceClient? voiceClient;
  final bool Function()? isAuthenticated;

  const SiteGuideChatPage({
    super.key,
    this.initialQuestion,
    this.service,
    this.toolCatalog,
    this.onOpenUserManual,
    this.voiceSessionService,
    this.voiceClient,
    this.isAuthenticated,
  });

  @override
  State<SiteGuideChatPage> createState() => _SiteGuideChatPageState();
}

class _SiteGuideChatPageState extends State<SiteGuideChatPage> {
  static const List<String> _suggestedQuestions = <String>[
    'まず何から使えばいい？',
    '資産管理はどこ？',
    '統一地方選700必達管理室の見方は？',
    'AI大学の始め方は？',
    'ノート機能はどこ？',
  ];

  late final SiteGuideChatService _service;
  late final CartesiaVoiceSessionService _voiceSessionService;
  late final CartesiaVoiceClient _voiceClient;
  late final List<SiteGuideActionEntry> _toolCatalog;
  late final Map<String, SiteGuideActionEntry> _toolMap;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_SiteGuideMessage> _messages = <_SiteGuideMessage>[];
  final String _sessionId = const Uuid().v4();
  final List<CartesiaVoiceTranscriptEntry> _voiceTranscript =
      <CartesiaVoiceTranscriptEntry>[];

  bool _isSending = false;
  bool _isVoiceStarting = false;
  bool _isVoiceActive = false;
  bool _isVoiceFinishing = false;
  String _voiceStatus = 'idle';
  String? _voiceError;
  String? _voiceSessionId;
  String? _voiceTicketId;
  DateTime? _voiceStartedAt;
  Timer? _voiceTimer;
  int _voiceElapsedSeconds = 0;
  int _voiceMaxSeconds = 300;
  int _voiceAssistantCharacters = 0;
  CartesiaVoiceStyle? _lastVoiceStyle;

  @override
  void initState() {
    super.initState();
    _toolCatalog = widget.toolCatalog ?? const <SiteGuideActionEntry>[];
    _service = widget.service ??
        SiteGuideChatService(
          catalog: _toolCatalog.map((tool) => tool.item).toList(),
        );
    _voiceSessionService =
        widget.voiceSessionService ?? CartesiaVoiceSessionService();
    _voiceClient = widget.voiceClient ?? createCartesiaVoiceClient();
    _toolMap = <String, SiteGuideActionEntry>{
      for (final tool in _toolCatalog) tool.item.id: tool,
    };

    final initialQuestion = widget.initialQuestion?.trim();
    if (initialQuestion != null && initialQuestion.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendQuestion(initialQuestion);
      });
    }
  }

  @override
  void dispose() {
    _voiceTimer?.cancel();
    final startedAt = _voiceStartedAt;
    final voiceSessionId = _voiceSessionId;
    final transcript = List<CartesiaVoiceTranscriptEntry>.from(
      _voiceTranscript,
    );
    unawaited(_voiceClient.stop());
    if (startedAt != null &&
        voiceSessionId != null &&
        transcript.isNotEmpty &&
        _voiceTicketId == null) {
      unawaited(
        _voiceSessionService.finishSession(
          sessionId: voiceSessionId,
          duration: DateTime.now().difference(startedAt),
          assistantCharacterCount: _voiceAssistantCharacters,
          transcript: transcript,
        ),
      );
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendCurrentInput() async {
    await _sendQuestion(_inputController.text.trim());
  }

  Future<void> _sendQuestion(String question) async {
    final normalized = question.trim();
    if (normalized.isEmpty || _isSending) return;
    final bool isAnon;
    try {
      isAnon = !(widget.isAuthenticated?.call() ??
          (Supabase.instance.client.auth.currentUser != null));
    } catch (_) {
      return;
    }
    if (isAnon) {
      setState(() {
        _messages.add(
          _SiteGuideMessage.assistant('ログインが必要です', source: 'anon-guard'),
        );
      });
      return;
    }

    setState(() {
      _messages.add(_SiteGuideMessage.user(normalized));
      if (_isVoiceActive) {
        _voiceTranscript.add(
          CartesiaVoiceTranscriptEntry(
            role: 'user',
            text: normalized,
            recordedAt: DateTime.now(),
          ),
        );
      }
      _inputController.clear();
      _isSending = true;
    });
    _scrollToBottom();

    final answer = await _service.answerQuestion(
      normalized,
      sessionId: _sessionId,
    );
    if (!mounted) return;

    setState(() {
      _messages.add(
        _SiteGuideMessage.assistant(
          answer.text,
          source: answer.source,
          suggestions: answer.suggestions,
          isFallback: answer.isFallback,
          observability: answer.observability,
        ),
      );
      if (_isVoiceActive) {
        _voiceTranscript.add(
          CartesiaVoiceTranscriptEntry(
            role: 'assistant',
            text: answer.text,
            recordedAt: DateTime.now(),
          ),
        );
        _voiceAssistantCharacters += answer.text.length;
        _lastVoiceStyle = CartesiaVoiceStyle.infer(answer.text);
      }
      _isSending = false;
    });
    final voiceStyle = _lastVoiceStyle;
    if (_isVoiceActive && voiceStyle != null) {
      unawaited(_voiceClient.speak(answer.text, voiceStyle));
    }
    _scrollToBottom();
  }

  Future<void> _toggleVoiceSession() async {
    if (_isVoiceActive || _isVoiceStarting) {
      await _endVoiceSession();
      return;
    }
    if (!_voiceClient.isSupported) {
      setState(() {
        _voiceError = 'このブラウザは音声通話に対応していません。';
      });
      return;
    }
    setState(() {
      _isVoiceStarting = true;
      _voiceError = null;
      _voiceTicketId = null;
      _voiceStatus = 'connecting';
    });
    try {
      final config = await _voiceSessionService.createSession();
      final voiceSessionId = const Uuid().v4();
      await _voiceClient.start(
        config: config,
        onTranscript: (transcript) {
          if (!mounted || !_isVoiceActive) return;
          unawaited(_sendQuestion(transcript));
        },
        onStatus: (status) {
          if (mounted) setState(() => _voiceStatus = status);
        },
        onError: (message) {
          if (mounted) setState(() => _voiceError = message);
        },
      );
      if (!mounted) {
        await _voiceClient.stop();
        return;
      }
      setState(() {
        _isVoiceStarting = false;
        _isVoiceActive = true;
        _voiceSessionId = voiceSessionId;
        _voiceStartedAt = DateTime.now();
        _voiceMaxSeconds = config.maxSessionSeconds;
        _voiceElapsedSeconds = 0;
        _voiceAssistantCharacters = 0;
        _voiceTranscript.clear();
        _lastVoiceStyle = null;
        _voiceStatus = 'listening';
      });
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isVoiceActive) return;
        final startedAt = _voiceStartedAt;
        if (startedAt == null) return;
        final elapsed = DateTime.now().difference(startedAt).inSeconds;
        setState(() => _voiceElapsedSeconds = elapsed);
        if (elapsed >= _voiceMaxSeconds) {
          unawaited(_endVoiceSession());
        }
      });
    } catch (error) {
      await _voiceClient.stop();
      if (!mounted) return;
      setState(() {
        _isVoiceStarting = false;
        _isVoiceActive = false;
        _voiceStatus = 'idle';
        _voiceError = error.toString();
      });
    }
  }

  Future<void> _endVoiceSession() async {
    if (_isVoiceFinishing) return;
    final startedAt = _voiceStartedAt;
    final voiceSessionId = _voiceSessionId;
    final transcript = List<CartesiaVoiceTranscriptEntry>.from(
      _voiceTranscript,
    );
    setState(() {
      _isVoiceStarting = false;
      _isVoiceActive = false;
      _isVoiceFinishing = true;
      _voiceStatus = 'saving';
    });
    _voiceTimer?.cancel();
    await _voiceClient.stop();
    String? ticketId;
    String? syncError;
    if (startedAt != null && voiceSessionId != null && transcript.isNotEmpty) {
      try {
        ticketId = await _voiceSessionService.finishSession(
          sessionId: voiceSessionId,
          duration: DateTime.now().difference(startedAt),
          assistantCharacterCount: _voiceAssistantCharacters,
          transcript: transcript,
        );
      } catch (error) {
        syncError = '通話記録の保存に失敗しました: $error';
      }
    }
    if (!mounted) return;
    setState(() {
      _isVoiceFinishing = false;
      _voiceStatus = 'idle';
      _voiceTicketId = ticketId;
      _voiceError = syncError;
      _voiceStartedAt = null;
      _voiceSessionId = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openSuggestion(SiteGuideToolSuggestion suggestion) async {
    final entry = _toolMap[suggestion.id];
    if (entry == null) return;
    unawaited(HomeToolUsageService.recordToolUse(entry.item.id));
    await entry.onOpen(context);
  }

  void _openUserManual() {
    final callback = widget.onOpenUserManual;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).pushNamed('/user-manual');
  }

  void _leaveGuide() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final outlineColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: Navigator.of(context).canPop() ? '戻る' : 'ホーム',
          onPressed: _leaveGuide,
          icon: Icon(
            Navigator.of(context).canPop() ? Icons.arrow_back : Icons.home,
          ),
        ),
        title: const Text('サイト案内AI'),
        actions: [
          IconButton(
            tooltip: 'ユーザーマニュアル',
            onPressed: _openUserManual,
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!isCompact || _messages.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 12 : 16,
                  isCompact ? 8 : 12,
                  isCompact ? 12 : 16,
                  isCompact ? 8 : 12,
                ),
                child: _buildIntroCard(
                  cardColor,
                  outlineColor,
                  isDark,
                  isCompact,
                ),
              ),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 12 : 16,
                        0,
                        isCompact ? 12 : 16,
                        12,
                      ),
                      itemCount: _messages.length + (_isSending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildThinkingBubble(isDark);
                        }
                        final message = _messages[index];
                        return _buildMessageBubble(message, isDark);
                      },
                    ),
            ),
            _buildInputBar(cardColor, outlineColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(
    Color cardColor,
    Color outlineColor,
    bool isDark,
    bool isCompact,
  ) {
    final quickColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: outlineColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'このサイトの使い方をAIに聞く',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      if (!isCompact) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'どこを開けばいいか、何から始めればいいか、機能の違いは何かを案内します。',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (!isCompact) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: quickColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '例: 「資産管理はどこ？」「統一地方選700必達管理室の見方は？」「最初に使うべき機能は？」',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildVoiceControls(isDark),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions
                  .take(isCompact ? 3 : _suggestedQuestions.length)
                  .map((question) {
                return ActionChip(
                  label: Text(question),
                  onPressed: () => _sendQuestion(question),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceControls(bool isDark) {
    final isBusy = _isVoiceStarting || _isVoiceFinishing;
    final elapsedMinutes = (_voiceElapsedSeconds ~/ 60).toString();
    final elapsedSeconds =
        (_voiceElapsedSeconds % 60).toString().padLeft(2, '0');
    final progress = _voiceMaxSeconds <= 0
        ? 0.0
        : (_voiceElapsedSeconds / _voiceMaxSeconds).clamp(0.0, 1.0);
    final muted = isDark ? Colors.white70 : const Color(0xFF475569);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('site_guide_voice_toggle'),
            onPressed: isBusy ? null : _toggleVoiceSession,
            style: FilledButton.styleFrom(
              backgroundColor: _isVoiceActive
                  ? const Color(0xFFB91C1C)
                  : const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _isVoiceActive ? Icons.call_end : Icons.phone_in_talk,
                  ),
            label: Text(
              _isVoiceActive
                  ? '音声通話を終了'
                  : _isVoiceStarting
                      ? '接続中'
                      : _isVoiceFinishing
                          ? '通話記録を保存中'
                          : 'Cartesia 音声通話を開始',
            ),
          ),
        ),
        if (_isVoiceActive || isBusy) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _voiceStatus == 'speaking' ? Icons.graphic_eq : Icons.mic_none,
                size: 18,
                color: const Color(0xFF0F766E),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_voiceStatusLabel()}  $elapsedMinutes:$elapsedSeconds  '
                  '$_voiceAssistantCharacters 文字',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_lastVoiceStyle != null)
                Text(
                  '${_lastVoiceStyle!.emotion} '
                  '${_lastVoiceStyle!.speed.toStringAsFixed(2)}x',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            color: const Color(0xFF0F766E),
            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.12),
          ),
        ],
        if (_voiceError != null) ...[
          const SizedBox(height: 8),
          Text(
            _voiceError!,
            key: const Key('site_guide_voice_error'),
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ] else if (_voiceTicketId != null) ...[
          const SizedBox(height: 8),
          const Text(
            '通話記録をサポートチケットへ保存しました。',
            key: Key('site_guide_voice_saved'),
            style: TextStyle(
              color: Color(0xFF047857),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _voiceStatusLabel() {
    return switch (_voiceStatus) {
      'connected' => '接続済み',
      'listening' => '聞き取り中',
      'thinking' => '回答を準備中',
      'speaking' => 'AIが応答中',
      'saving' => '保存中',
      _ => '待機中',
    };
  }

  Widget _buildEmptyState(bool isDark) {
    final color = isDark ? Colors.white70 : const Color(0xFF334155);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 44,
              color: color.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 12),
            Text(
              '聞きたいことをそのまま入力してください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'おすすめの入口を1つに絞って、続けて手順まで案内します。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.78),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(_SiteGuideMessage message, bool isDark) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? const Color(0xFF4F46E5)
        : (isDark ? const Color(0xFF0F172A) : Colors.white);
    final textColor = isUser ? Colors.white : null;
    final borderColor = isUser
        ? Colors.transparent
        : (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : const Color(0xFFE2E8F0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: textColor,
                      ),
                    ),
                    if (!isUser && message.source != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5)
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              message.source!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4F46E5),
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (message.isFallback)
                            const Text(
                              'ローカル案内',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                                height: 1.4,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (!isUser && message.observability != null) ...[
                      const SizedBox(height: 10),
                      AiResponseObservabilityPanel(
                        observability: message.observability!,
                        isDark: isDark,
                        accentColor: const Color(0xFF4F46E5),
                        fallbackLabel: message.source,
                      ),
                    ],
                    if (!isUser && message.suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: message.suggestions.take(3).map((tool) {
                          return ActionChip(
                            key: Key('site_guide_open_${tool.id}'),
                            avatar: const Icon(Icons.open_in_new, size: 16),
                            label: Text(tool.title),
                            onPressed: () => _openSuggestion(tool),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark) {
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Color cardColor, Color outlineColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: outlineColor)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _sendCurrentInput(),
                decoration: InputDecoration(
                  hintText: 'このサイトでやりたいことを聞いてください',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: outlineColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFF8FAFC),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              key: const Key('site_guide_send'),
              onPressed: _isSending ? null : _sendCurrentInput,
              style: FilledButton.styleFrom(
                minimumSize: const Size(52, 52),
                padding: EdgeInsets.zero,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteGuideMessage {
  final bool isUser;
  final String text;
  final String? source;
  final bool isFallback;
  final List<SiteGuideToolSuggestion> suggestions;
  final AiHubChatObservability? observability;

  const _SiteGuideMessage._({
    required this.isUser,
    required this.text,
    this.source,
    this.isFallback = false,
    this.suggestions = const <SiteGuideToolSuggestion>[],
    this.observability,
  });

  factory _SiteGuideMessage.user(String text) {
    return _SiteGuideMessage._(isUser: true, text: text);
  }

  factory _SiteGuideMessage.assistant(
    String text, {
    String? source,
    bool isFallback = false,
    List<SiteGuideToolSuggestion> suggestions =
        const <SiteGuideToolSuggestion>[],
    AiHubChatObservability? observability,
  }) {
    return _SiteGuideMessage._(
      isUser: false,
      text: text,
      source: source,
      isFallback: isFallback,
      suggestions: suggestions,
      observability: observability,
    );
  }
}
