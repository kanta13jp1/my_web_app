import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models/note.dart';

class DanshariPage extends StatefulWidget {
  const DanshariPage({super.key});

  @override
  State<DanshariPage> createState() => _DanshariPageState();
}

class _DanshariPageState extends State<DanshariPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- Chat State ---
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isChatLoading = false;

  // --- Memo Cleaner State ---
  List<Note> _notes = [];
  final Set<String> _selectedNoteIds = {};
  bool _isLoadingNotes = true;

  // Colors
  final Color _navy = const Color(0xFF0F172A);
  final Color _gold = const Color(0xFFD4AF37);
  final Color _red = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initial Greeting
    _addMessage('デジタルゴミ屋敷の住人へ。\n右の「メモ焼却炉」タブで、不要なメモを今すぐ捨てろ。迷うな。', false);

    _fetchNotes();
  }

  // ================= Chat Logic =================
  void _addMessage(String text, bool isUser) {
    if (!mounted) return;
    setState(() {
      _messages.add({'text': text, 'isUser': isUser});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _addMessage(text, true);
    _chatController.clear();
    setState(() => _isChatLoading = true);

    try {
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'digital_danshari_chat', 'content': text},
      );

      if (response.status != 200) throw Exception('API Error');
      final data = response.data;

      if (data['success'] == true) {
        final result = data['result'];
        final message = result['message'] ?? '...';
        final mission = result['mission'];
        String display = message;
        if (mission != null) display += "\n\n 指令: $mission";
        _addMessage(display, false);
      } else {
        _addMessage('通信エラーだ。言い訳する時間が増えたな。', false);
      }
    } catch (e) {
      _addMessage('エラー: $e', false);
    } finally {
      if (mounted) setState(() => _isChatLoading = false);
    }
  }

  // ================= Memo Cleaner Logic =================
  Future<void> _fetchNotes() async {
    setState(() => _isLoadingNotes = true);
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 古い順（放置されているもの）から取得
      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('updated_at', ascending: true)
          .limit(100);

      if (mounted) {
        setState(() {
          _notes = (response as List).map((n) => Note.fromJson(n)).toList();
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching notes: $e');
      if (mounted) setState(() => _isLoadingNotes = false);
    }
  }

  Future<void> _archiveSelected() async {
    if (_selectedNoteIds.isEmpty) return;

    final count = _selectedNoteIds.length;
    try {
      await supabase.from('notes').update({
        'is_archived': true,
        'updated_at': DateTime.now().toIso8601String()
      }).in_('id', _selectedNoteIds.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$count 件のメモを焼却しました '), backgroundColor: _red));
        setState(() {
          _selectedNoteIds.clear();
        });
        _fetchNotes();
        // 褒めてもらう
        _addMessage('$count 件のメモを処分したぞ。どうだ。', true);
        Future.delayed(const Duration(seconds: 1),
            () => _addMessage('悪くない。だが、まだ残っているはずだ。手を止めるな。', false));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  // ================= UI Builders =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('デジタル断捨離道場'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.psychology), text: '鬼コーチ'),
            Tab(icon: Icon(Icons.delete_sweep), text: 'メモ焼却炉'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildCleanerTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
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
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 2)
                    ],
                  ),
                  child: Text(
                    msg['text'],
                    style: TextStyle(
                        color: isUser ? Colors.black87 : Colors.white,
                        height: 1.4),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isChatLoading) const LinearProgressIndicator(minHeight: 2),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: const InputDecoration(
                    hintText: '言い訳を入力...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send, color: _navy)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCleanerTab() {
    if (_isLoadingNotes)
      return const Center(child: CircularProgressIndicator());
    if (_notes.isEmpty)
      return const Center(
          child: Text('処分するメモはありません。\n素晴らしい！',
              style: TextStyle(color: Colors.grey)));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.red.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.red),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('選択したメモは「アーカイブ（ゴミ箱）」に送られます。',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red))),
              if (_selectedNoteIds.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _archiveSelected,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _red, foregroundColor: Colors.white),
                  icon: const Icon(Icons.local_fire_department, size: 16),
                  label: Text('${_selectedNoteIds.length}件を焼却'),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _notes.length,
            itemBuilder: (context, index) {
              final note = _notes[index];
              final isSelected = _selectedNoteIds.contains(note.id);
              final date = DateFormat('yyyy/MM/dd').format(note.updatedAt);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                      color: isSelected ? _red : Colors.grey.shade300,
                      width: isSelected ? 2 : 1),
                ),
                color: isSelected ? _red.withOpacity(0.05) : Colors.white,
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    activeColor: _red,
                    onChanged: (val) {
                      setState(() {
                        if (val == true)
                          _selectedNoteIds.add(note.id);
                        else
                          _selectedNoteIds.remove(note.id);
                      });
                    },
                  ),
                  title: Text(note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$date - ${note.content}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () {
                    setState(() {
                      if (isSelected)
                        _selectedNoteIds.remove(note.id);
                      else
                        _selectedNoteIds.add(note.id);
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
