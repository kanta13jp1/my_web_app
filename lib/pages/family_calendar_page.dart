import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 家族カレンダーページ
/// 家族のスケジュール共有・タスク割当・イベント管理。Googleカレンダー家族共有対抗。
class FamilyCalendarPage extends StatefulWidget {
  const FamilyCalendarPage({super.key});

  @override
  State<FamilyCalendarPage> createState() => _FamilyCalendarPageState();
}

class _FamilyCalendarPageState extends State<FamilyCalendarPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = false;
  List<Map<String, dynamic>> _events = [];
  DateTime _selectedDate = DateTime.now();

  final _titleCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  String _category = '予定';
  bool _saving = false;

  static const _categories = ['予定', 'タスク', '誕生日', '記念日', '医療', 'その他'];
  static const _categoryColors = {
    '予定': Color(0xFF3D5AFE),
    'タスク': Color(0xFFFF6B35),
    '誕生日': Color(0xFFEC4899),
    '記念日': Color(0xFFE11D48),
    '医療': Color(0xFF4CAF50),
    'その他': Color(0xFF9CA3AF),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memberCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final monthStart = DateTime(_selectedDate.year, _selectedDate.month, 1).toIso8601String();
      final monthEnd = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59).toIso8601String();
      final data = await _supabase
          .from('family_events')
          .select()
          .eq('user_id', user.id)
          .gte('event_date', monthStart)
          .lte('event_date', monthEnd)
          .order('event_date');
      if (mounted) setState(() => _events = List<Map<String, dynamic>>.from(data));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('family_events').insert({
        'user_id': user.id,
        'title': title,
        'member': _memberCtrl.text.trim(),
        'category': _category,
        'event_date': _selectedDate.toIso8601String(),
      });
      _titleCtrl.clear();
      _memberCtrl.clear();
      if (mounted) Navigator.of(context).pop();
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

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('イベントを追加', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('タイトル *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _memberCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('担当メンバー'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF333333)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _category,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      setDialog(() => _category = v!);
                      setState(() => _category = v!);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF333333)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF6B35)),
        ),
      );

  String _monthLabel(DateTime d) => '${d.year}年${d.month}月';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('家族カレンダー', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 月ナビゲーション
          Container(
            color: const Color(0xFF121212),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: () {
                    setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1));
                    _load();
                  },
                ),
                Text(
                  _monthLabel(_selectedDate),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: () {
                    setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1));
                    _load();
                  },
                ),
              ],
            ),
          ),
          // イベント一覧
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
                : _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_outlined, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            const Text('この月のイベントはありません', style: TextStyle(color: Colors.white38)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('追加'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        itemBuilder: (_, i) {
                          final e = _events[i];
                          final cat = e['category'] as String? ?? 'その他';
                          final color = _categoryColors[cat] ?? const Color(0xFF9CA3AF);
                          final dateStr = e['event_date'] != null
                              ? DateTime.parse(e['event_date'].toString())
                                  .toLocal()
                                  .toString()
                                  .substring(0, 10)
                              : '';
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              title: Text(
                                e['title'] as String? ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(cat, style: TextStyle(color: color, fontSize: 11)),
                                  ),
                                  if ((e['member'] as String? ?? '').isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(e['member'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ],
                              ),
                              trailing: Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _events.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFFF6B35),
              onPressed: _showAddDialog,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
