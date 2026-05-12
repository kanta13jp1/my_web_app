import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// チームチャット — Discord/LINE 対抗
/// app-hub:chat.* と連携してリアルタイムチャンネルメッセージング
class TeamChatPage extends StatefulWidget {
  const TeamChatPage({super.key});

  @override
  State<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends State<TeamChatPage> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _messages = [];
  String? _selectedChannelId;
  String? _selectedChannelName;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchChannels() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'chat.list_channels'},
      );
      final data = res.data;
      if (data is Map && data['channels'] is List) {
        final channels =
            List<Map<String, dynamic>>.from(data['channels'] as List);
        setState(() {
          _channels = channels;
          if (channels.isNotEmpty && _selectedChannelId == null) {
            _selectedChannelId = channels.first['id']?.toString();
            _selectedChannelName = channels.first['name']?.toString();
          }
        });
        if (_selectedChannelId != null) {
          await _fetchMessages(_selectedChannelId!);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'チャンネル取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMessages(String channelId) async {
    try {
      final res = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'chat.get_messages', 'channel_id': channelId},
      );
      final data = res.data;
      if (data is Map && data['messages'] is List) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data['messages'] as List);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _selectedChannelId == null) return;
    setState(() => _isSending = true);
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'chat.send',
          'channel_id': _selectedChannelId,
          'content': text,
        },
      );
      _messageController.clear();
      await _fetchMessages(_selectedChannelId!);
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _selectChannel(Map<String, dynamic> ch) {
    setState(() {
      _selectedChannelId = ch['id']?.toString();
      _selectedChannelName = ch['name']?.toString();
      _messages = [];
    });
    _fetchMessages(_selectedChannelId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedChannelName != null ? '# $_selectedChannelName' : 'チームチャット',
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _fetchChannels,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Builder(
              builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark
                      ? const Color(0xFF3A1010)
                      : const Color(0xFFFFEBEE),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFEF9A9A)
                          : const Color(0xFFC62828),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                );
              },
            ),
          Expanded(
            child: Row(
              children: [
                // チャンネルサイドバー
                SizedBox(
                  width: 180,
                  child: _ChannelSidebar(
                    channels: _channels,
                    selectedId: _selectedChannelId,
                    onSelect: _selectChannel,
                  ),
                ),
                const VerticalDivider(width: 1),
                // メッセージエリア
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'メッセージがありません',
                                  style: TextStyle(
                                    color: Colors.black45,
                                    height: 1.5,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(12),
                                itemCount: _messages.length,
                                itemBuilder: (_, i) =>
                                    _MessageBubble(message: _messages[i]),
                              ),
                      ),
                      _MessageInput(
                        controller: _messageController,
                        isSending: _isSending,
                        onSend: _sendMessage,
                        channelName: _selectedChannelName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelSidebar extends StatelessWidget {
  const _ChannelSidebar({
    required this.channels,
    required this.selectedId,
    required this.onSelect,
  });
  final List<Map<String, dynamic>> channels;
  final String? selectedId;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'チャンネル',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: channels.map((ch) {
                final isSelected = ch['id']?.toString() == selectedId;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor:
                      const Color(0xFF3D5AFE).withValues(alpha: 0.1),
                  leading: const Text(
                    '#',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D5AFE),
                      height: 1.5,
                    ),
                  ),
                  title: Text(
                    ch['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  onTap: () => onSelect(ch),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final sender = message['sender_name']?.toString() ?? 'ユーザー';
    final content = message['content']?.toString() ?? '';
    final sentAt = message['sent_at']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFC5CAE9),
            child: Text(
              sender.isNotEmpty ? sender[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF303F9F),
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sender,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sentAt,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.channelName,
  });
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String? channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: channelName != null
                    ? '#$channelName にメッセージを送信'
                    : 'メッセージを入力',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, color: Color(0xFF3D5AFE)),
            tooltip: '送信',
          ),
        ],
      ),
    );
  }
}
