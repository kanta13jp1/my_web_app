import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asset_chat.dart';
import '../services/asset_chat_history_repository.dart';
import '../view_models/asset_chat_history_view_model.dart';
import '../widgets/critical_action_dialog.dart';

class AssetChatHistoryPage extends StatefulWidget {
  final AssetChatHistoryRepository? repository;
  final AssetChatHistoryViewModel? viewModel;

  const AssetChatHistoryPage({
    super.key,
    this.repository,
    this.viewModel,
  });

  @override
  State<AssetChatHistoryPage> createState() => _AssetChatHistoryPageState();
}

class _AssetChatHistoryPageState extends State<AssetChatHistoryPage> {
  static const double _wideBreakpoint = 760;

  final TextEditingController _searchController = TextEditingController();
  late final AssetChatHistoryViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _showMobileDetail = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        AssetChatHistoryViewModel(
          repository: widget.repository ?? SupabaseAssetChatHistoryRepository(),
        );
    _searchController.text = _viewModel.searchQuery;
    _viewModel.addListener(_handleViewModelChanged);
    if (_viewModel.threads.isEmpty && !_viewModel.isLoadingThreads) {
      unawaited(_viewModel.initialize());
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleViewModelChanged);
    if (_ownsViewModel) _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleViewModelChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectThread(AssetChatThreadSummary thread) async {
    setState(() => _showMobileDetail = true);
    await _viewModel.selectThread(thread);
  }

  Future<void> _confirmDelete(AssetChatThreadSummary thread) async {
    final confirmed = await showCriticalActionDialog(
      context: context,
      title: 'チャットを削除しますか？',
      impact: '「${thread.title}」のメッセージをすべて削除します。'
          'この操作は元に戻せません。',
      actionLabel: '削除する',
      confirmationPhrase: '削除する',
      confirmButtonKey: const Key('asset_chat_delete_confirm_button'),
    );
    if (!confirmed || !mounted) return;
    final deleted = await _viewModel.deleteThread(thread);
    if (!mounted) return;
    if (deleted && _showMobileDetail) {
      setState(() => _showMobileDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('資産AIチャット履歴'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (_viewModel.errorMessage case final error?)
            MaterialBanner(
              key: const Key('asset_chat_history_error'),
              content: Text(error),
              leading: const Icon(Icons.error_outline),
              actions: [
                TextButton(
                  onPressed: _viewModel.clearError,
                  child: const Text('閉じる'),
                ),
                TextButton(
                  onPressed: () => _viewModel.loadThreads(reset: true),
                  child: const Text('再試行'),
                ),
              ],
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _wideBreakpoint) {
                  return Row(
                    key: const Key('asset_chat_history_wide_layout'),
                    children: [
                      SizedBox(width: 360, child: _buildThreadPane()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildDetailPane()),
                    ],
                  );
                }
                return KeyedSubtree(
                  key: const Key('asset_chat_history_narrow_layout'),
                  child: _showMobileDetail && _viewModel.selectedThread != null
                      ? _buildDetailPane(showBackButton: true)
                      : _buildThreadPane(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: TextField(
            key: const Key('asset_chat_history_search_input'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _viewModel.search,
            decoration: InputDecoration(
              labelText: 'スレッド名を検索',
              hintText: '例: 支払い相談',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _viewModel.searchQuery.isEmpty
                  ? IconButton(
                      key: const Key('asset_chat_history_search_button'),
                      tooltip: '検索',
                      onPressed: () =>
                          _viewModel.search(_searchController.text),
                      icon: const Icon(Icons.arrow_forward),
                    )
                  : IconButton(
                      key: const Key('asset_chat_history_clear_search_button'),
                      tooltip: '検索をクリア',
                      onPressed: () {
                        _searchController.clear();
                        unawaited(_viewModel.clearSearch());
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_viewModel.searchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '「${_viewModel.searchQuery}」の検索結果',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        Expanded(child: _buildThreadList()),
      ],
    );
  }

  Widget _buildThreadList() {
    if (_viewModel.isLoadingThreads && _viewModel.threads.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('asset_chat_history_loading_threads'),
        ),
      );
    }
    if (_viewModel.threads.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _viewModel.loadThreads(reset: true),
        child: ListView(
          key: const Key('asset_chat_history_empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 96),
            Icon(Icons.forum_outlined, size: 48, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              'チャット履歴はありません',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              '資産管理画面の「資産AIに相談」から会話を始められます。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final itemCount = _viewModel.threads.length +
        (_viewModel.hasMoreThreads || _viewModel.isLoadingThreads ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () => _viewModel.loadThreads(reset: true),
      child: ListView.separated(
        key: const Key('asset_chat_history_thread_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _viewModel.threads.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: _viewModel.isLoadingThreads
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : OutlinedButton(
                        key: const Key('asset_chat_history_load_more_threads'),
                        onPressed: _viewModel.loadThreads,
                        child: const Text('さらに表示'),
                      ),
              ),
            );
          }
          final thread = _viewModel.threads[index];
          return ListTile(
            key: Key('asset_chat_thread_${thread.id}'),
            selected: _viewModel.selectedThread?.id == thread.id,
            leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
            title: Text(
              thread.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('最終更新 ${_formatDateTime(thread.lastMessageAt)}'),
            trailing: IconButton(
              key: Key('asset_chat_delete_${thread.id}'),
              tooltip: 'このチャットを削除',
              onPressed:
                  _viewModel.isDeleting ? null : () => _confirmDelete(thread),
              icon: const Icon(Icons.delete_outline),
            ),
            onTap: () => _selectThread(thread),
          );
        },
      ),
    );
  }

  Widget _buildDetailPane({bool showBackButton = false}) {
    final thread = _viewModel.selectedThread;
    if (thread == null) {
      return const Center(
        key: Key('asset_chat_history_no_selection'),
        child: Text('スレッドを選択するとメッセージを表示します。'),
      );
    }
    return Column(
      key: const Key('asset_chat_history_detail'),
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: ListTile(
            leading: showBackButton
                ? IconButton(
                    key: const Key('asset_chat_history_back_to_list'),
                    tooltip: '履歴一覧へ戻る',
                    onPressed: () => setState(() => _showMobileDetail = false),
                    icon: const Icon(Icons.arrow_back),
                  )
                : const Icon(Icons.chat),
            title: Text(
              thread.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('開始 ${_formatDateTime(thread.createdAt)}'),
            trailing: IconButton(
              key: const Key('asset_chat_history_detail_delete'),
              tooltip: 'このチャットを削除',
              onPressed:
                  _viewModel.isDeleting ? null : () => _confirmDelete(thread),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildMessages()),
      ],
    );
  }

  Widget _buildMessages() {
    if (_viewModel.isLoadingMessages && _viewModel.messages.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('asset_chat_history_loading_messages'),
        ),
      );
    }
    if (_viewModel.messages.isEmpty) {
      return const Center(
        key: Key('asset_chat_history_empty_messages'),
        child: Text('このスレッドにはメッセージがありません。'),
      );
    }

    final showOlder = _viewModel.hasOlderMessages ||
        (_viewModel.isLoadingMessages && _viewModel.messages.isNotEmpty);
    return ListView.builder(
      key: const Key('asset_chat_history_message_list'),
      padding: const EdgeInsets.all(16),
      itemCount: _viewModel.messages.length + (showOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (showOlder && index == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _viewModel.isLoadingMessages
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : OutlinedButton.icon(
                      key: const Key('asset_chat_history_load_older_messages'),
                      onPressed: _viewModel.loadOlderMessages,
                      icon: const Icon(Icons.expand_less),
                      label: const Text('以前のメッセージを表示'),
                    ),
            ),
          );
        }
        final messageIndex = index - (showOlder ? 1 : 0);
        return _buildMessage(_viewModel.messages[messageIndex]);
      },
    );
  }

  Widget _buildMessage(AssetChatStoredMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('asset_chat_history_message_${message.id}'),
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2E7D32)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              message.text,
              style: TextStyle(
                color: isUser ? Colors.white : null,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              [
                _formatDateTime(message.createdAt),
                if (!isUser && message.model != null) message.model!,
                if (!isUser && message.tokensIn + message.tokensOut > 0)
                  '${message.tokensIn + message.tokensOut} tokens',
              ].join(' · '),
              style: TextStyle(
                color: isUser ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
