import 'package:flutter/material.dart';
import '../main.dart';

class DanshariPage extends StatefulWidget {
  const DanshariPage({super.key});

  @override
  State<DanshariPage> createState() => _DanshariPageState();
}

class _DanshariPageState extends State<DanshariPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  // Colors
  final Color _navy = const Color(0xFF0F172A);
  final Color _gold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    // Initial greeting from the Demon
    _addMessage('デジタルゴミ屋敷の住人へ。\nスマホの容量が悲鳴を上げているぞ。何を捨てればいいか、正直に言ってみろ。', false);
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({'text': text, 'isUser': isUser});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _addMessage(text, true);
    _controller.clear();
    setState(() => _isLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {
          'action': 'digital_danshari_chat', //  Calling the Demon
          'content': text,
        },
      );

      if (response.status != 200) throw Exception('API Error');

      final data = response.data;
      if (data['success'] == true) {
        final result = data['result'];
        // Parse the JSON result from the demon
        final message = result['message'] ?? '...';
        final mission = result['mission'];

        String display = message;
        if (mission != null) {
          display += "\n\n 指令: $mission";
        }

        _addMessage(display, false);
      } else {
        _addMessage('通信エラーだ。言い訳する時間が増えたな。', false);
      }
    } catch (e) {
      _addMessage('エラー: $e', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('デジタル断捨離道場'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('履歴を消去しました')));
              setState(() => _messages.clear());
              _addMessage('逃げるのか？まあいい、最初からやり直せ。', false);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['isUser'];
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.white : _navy,
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomRight:
                            isUser ? Radius.zero : const Radius.circular(12),
                        bottomLeft:
                            isUser ? const Radius.circular(12) : Radius.zero,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1))
                      ],
                      border: isUser
                          ? Border.all(color: Colors.grey.shade200)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 16),
                              const SizedBox(width: 4),
                              Text("鬼コーチ",
                                  style: TextStyle(
                                      color: _gold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        if (!isUser) const SizedBox(height: 4),
                        Text(
                          msg['text'],
                          style: TextStyle(
                              color: isUser ? Colors.black87 : Colors.white,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('鬼コーチが激怒中...',
                  style: TextStyle(color: _navy, fontSize: 12)),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: '例: スクショが3000枚あります...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    backgroundColor: _navy,
                    mini: true,
                    child: Icon(Icons.send, color: _gold, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
