import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ブレインダンプページ
/// GTD式マインドクリアリング — 頭の中の全てを書き出し自動分類。Evernote対抗。
class BrainDumpPage extends StatefulWidget {
  const BrainDumpPage({super.key});

  @override
  State<BrainDumpPage> createState() => _BrainDumpPageState();
}

class _BrainDumpPageState extends State<BrainDumpPage> {
  final _supabase = Supabase.instance.client;
  final _textCtrl = TextEditingController();
  bool _saving = false;
  List<Map<String, dynamic>> _items = [];

  static const _categories = ['タスク', 'アイデア', '心配事', '目標', '買い物', 'その他'];
  String _selectedCategory = 'タスク';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final data = await _supabase
          .from('brain_dump_items')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(100);
      if (mounted) {
        setState(() => _items = List<Map<String, dynamic>>.from(data));
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('brain_dump_items').insert({
        'user_id': user.id,
        'content': text,
        'category': _selectedCategory,
        'is_processed': false,
      });
      _textCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(String id, bool current) async {
    await _supabase
        .from('brain_dump_items')
        .update({'is_processed': !current}).eq('id', id);
    await _load();
  }

  Future<void> _delete(String id) async {
    await _supabase.from('brain_dump_items').delete().eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('ブレインダンプ', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 入力エリア
            Card(
              color: const Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '頭の中を全部書き出す',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'タスク・アイデア・心配事・なんでも...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF333333)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF333333)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFFF6B35)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: const Color(0xFF333333)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              dropdownColor: const Color(0xFF1E1E1E),
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox.shrink(),
                              isExpanded: true,
                              items: _categories
                                  .map((c) => DropdownMenuItem(
                                      value: c, child: Text(c),),)
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedCategory = v!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
                            foregroundColor: Colors.white,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white,),)
                              : const Text('追加'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // アイテム一覧
            Expanded(
              child: _items.isEmpty
                  ? const Center(
                      child: Text(
                        '思いついたことを書き出してみよう',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final processed =
                            item['is_processed'] as bool? ?? false;
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: processed,
                              activeColor: const Color(0xFF4CAF50),
                              onChanged: (_) =>
                                  _toggle(item['id'].toString(), processed),
                            ),
                            title: Text(
                              item['content'] as String? ?? '',
                              style: TextStyle(
                                color:
                                    processed ? Colors.white38 : Colors.white,
                                decoration: processed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            subtitle: Text(
                              item['category'] as String? ?? '',
                              style: const TextStyle(
                                  color: Color(0xFFFF6B35), fontSize: 12,),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.white38, size: 18,),
                              onPressed: () => _delete(item['id'].toString()),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
