import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/site_guide_catalog_item.dart';
import '../services/ai_hub_chat_service.dart';
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

  const SiteGuideChatPage({
    super.key,
    this.initialQuestion,
    this.service,
    this.toolCatalog,
    this.onOpenUserManual,
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
  late final List<SiteGuideActionEntry> _toolCatalog;
  late final Map<String, SiteGuideActionEntry> _toolMap;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_SiteGuideMessage> _messages = <_SiteGuideMessage>[];
  final String _sessionId = const Uuid().v4();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _toolCatalog = widget.toolCatalog ?? const <SiteGuideActionEntry>[];
    _service = widget.service ??
        SiteGuideChatService(
          catalog: _toolCatalog.map((tool) => tool.item).toList(),
        );
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
      isAnon = Supabase.instance.client.auth.currentUser == null;
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
      _isSending = false;
    });
    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background =
        isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final outlineColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _buildIntroCard(cardColor, outlineColor, isDark),
            ),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

  Widget _buildIntroCard(Color cardColor, Color outlineColor, bool isDark) {
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
        padding: const EdgeInsets.all(16),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'このサイトの使い方をAIに聞く',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'どこを開けばいいか、何から始めればいいか、機能の違いは何かを案内します。',
                        style: TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestedQuestions.map((question) {
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

  Widget _buildEmptyState(bool isDark) {
    final color = isDark ? Colors.white70 : const Color(0xFF334155);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
