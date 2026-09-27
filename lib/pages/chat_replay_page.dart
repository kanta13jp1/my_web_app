import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/asset_chat.dart';

/// Presents a frozen, already-loaded transcript. No service or callback that
/// could regenerate, fetch, save, or execute a message crosses this boundary.
class ChatReplayPage extends StatefulWidget {
  ChatReplayPage({
    super.key,
    required List<AssetChatStoredMessage> messages,
    this.hasOlderMessages = false,
  }) : messages = List.unmodifiable(messages);

  final List<AssetChatStoredMessage> messages;
  final bool hasOlderMessages;

  @override
  State<ChatReplayPage> createState() => _ChatReplayPageState();
}

class _ChatReplayPageState extends State<ChatReplayPage> {
  int _position = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int position) {
    final next = position.clamp(0, widget.messages.length);
    if (next == _position) return;
    setState(() => _position = next);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.messages.length;
    final message = _position == 0 ? null : widget.messages[_position - 1];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            () => _move(_position + 1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            () => _move(_position - 1),
        const SingleActivator(LogicalKeyboardKey.home): () => _move(0),
        const SingleActivator(LogicalKeyboardKey.escape):
            () => Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('会話の発表'),
            actions: [
              IconButton(
                tooltip: '発表を終了',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      '保存済み会話の再生',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text('AIへの再送信・追加取得・保存は行いません。'),
                    const SizedBox(height: 8),
                    if (widget.hasOlderMessages)
                      const Text(
                        '読み込み済みの範囲だけを再生します。以前の会話も含めるには、'
                        '終了して履歴で読み込んでください。',
                        key: Key('chat_replay_partial'),
                      ),
                    const SizedBox(height: 24),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        '$_position / $total 件',
                        key: const Key('chat_replay_progress'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : _position / total,
                      semanticsLabel: '会話の再生位置',
                    ),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message == null
                                  ? (total == 0 ? '再生する会話がありません' : '準備ができました')
                                  : (message.isUser ? 'あなた' : 'AIの保存済み回答'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            SelectableText(
                              message?.text ??
                                  (total == 0
                                      ? '終了して、履歴から会話を選んでください。'
                                      : '共有する内容を確認してから「次へ」を押してください。'
                                          '\n一度に一件ずつ表示します。'),
                              key: ValueKey('chat_replay_message_$_position'),
                              style: const TextStyle(fontSize: 22, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _position == 0 ? null : () => _move(_position - 1),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('前へ'),
                        ),
                        FilledButton.icon(
                          onPressed: _position == total ? null : () => _move(_position + 1),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('次へ'),
                        ),
                        TextButton.icon(
                          onPressed: _position == 0 ? null : () => _move(0),
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('最初に戻す'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _position == total && total > 0
                          ? '読み込み済みの会話はここまでです。'
                          : 'キーボード: ← 前へ / → 次へ / Home 最初 / Esc 終了',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
