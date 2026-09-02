import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/asset_chat.dart';
import '../services/ai_hub_chat_service.dart';
import '../view_models/asset_chat_view_model.dart';

class AssetChatWidget extends StatefulWidget {
  final AiHubChatService? service;
  final AssetChatViewModel? viewModel;
  final VoidCallback? onOpenHistory;

  const AssetChatWidget({
    super.key,
    this.service,
    this.viewModel,
    this.onOpenHistory,
  });

  @override
  State<AssetChatWidget> createState() => _AssetChatWidgetState();
}

class _AssetChatWidgetState extends State<AssetChatWidget> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();

  late final AssetChatViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        AssetChatViewModel(service: widget.service ?? const AiHubChatService());
    _viewModel.addListener(_handleViewModelChanged);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    if (_ownsViewModel) {
      _viewModel.dispose();
    }
    _inputController.dispose();
    _messageScrollController.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  void _scrollToLatest() {
    if (!_messageScrollController.hasClients) return;
    _messageScrollController.jumpTo(
      _messageScrollController.position.maxScrollExtent,
    );
  }

  Future<void> _sendCurrentMessage() async {
    final message = _inputController.text.trim();
    if (message.isEmpty || _viewModel.isSending) return;
    final pending = _viewModel.sendMessage(message);
    if (_viewModel.isSending) {
      _inputController.clear();
    }
    await pending;
  }

  void _openHistory() {
    setState(() => _isOpen = false);
    final callback = widget.onOpenHistory;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).pushNamed('/asset-chat-history');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return FloatingActionButton.extended(
        key: const Key('asset_chat_open_button'),
        heroTag: null,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        tooltip: '資産AIチャットを開く',
        onPressed: () => setState(() => _isOpen = true),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('資産AIに相談'),
      );
    }

    final screenSize = MediaQuery.sizeOf(context);
    final panelWidth = math.min(400.0, math.max(240.0, screenSize.width - 32));
    final panelHeight = math.min(
      560.0,
      math.max(260.0, screenSize.height * 0.72),
    );
    final theme = Theme.of(context);

    return Material(
      key: const Key('asset_chat_panel'),
      color: theme.colorScheme.surface,
      elevation: 16,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildConversation()),
            if (_viewModel.errorMessage case final error?) _buildError(error),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ColoredBox(
      color: const Color(0xFF1B5E20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '資産AIチャット',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _viewModel.threadTitle ?? '資産スナップショットをもとに回答',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('asset_chat_history_button'),
              tooltip: 'チャット履歴を開く',
              onPressed: _openHistory,
              icon: const Icon(Icons.history, color: Colors.white),
            ),
            IconButton(
              key: const Key('asset_chat_close_button'),
              tooltip: '閉じる',
              onPressed: () => setState(() => _isOpen = false),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    final messages = _viewModel.messages;
    if (messages.isEmpty && !_viewModel.isSending) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 38,
                color: Color(0xFF2E7D32),
              ),
              SizedBox(height: 12),
              Text(
                '資産・負債・支払い予定について相談できます。',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, height: 1.45),
              ),
              SizedBox(height: 8),
              Text(
                '入力内容と資産スナップショットをAIへ送信します。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      key: const Key('asset_chat_message_list'),
      controller: _messageScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length + (_viewModel.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                key: Key('asset_chat_sending_indicator'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildMessageBubble(messages[index], index);
      },
    );
  }

  Widget _buildMessageBubble(AssetChatMessage message, int index) {
    final isUser = message.isUser;
    final usage = message.usage;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('asset_chat_message_$index'),
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2E7D32) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF0F172A),
                height: 1.45,
              ),
            ),
            if (usage != null) ...[
              const SizedBox(height: 7),
              Text(
                '入力 ${usage.tokensIn} / 出力 ${usage.tokensOut} tokens'
                ' · ${_formatCost(usage.estimatedCostUsd)}',
                key: Key('asset_chat_usage_$index'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCost(double cost) {
    if (cost == 0) return r'$0.00';
    if (cost < 0.01) return '\$${cost.toStringAsFixed(6)}';
    return '\$${cost.toStringAsFixed(4)}';
  }

  Widget _buildError(String error) {
    return Container(
      key: const Key('asset_chat_error'),
      width: double.infinity,
      color: const Color(0xFFFEF2F2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        error,
        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('asset_chat_input'),
                controller: _inputController,
                enabled: !_viewModel.isSending,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                buildCounter: (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendCurrentMessage(),
                decoration: const InputDecoration(
                  hintText: '例: 今月の支払いで注意すべき点は？',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const Key('asset_chat_send_button'),
              tooltip: '送信',
              onPressed: _viewModel.isSending ? null : _sendCurrentMessage,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
