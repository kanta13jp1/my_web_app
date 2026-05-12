import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// コンテンツカレンダーページ
/// SNS投稿・ブログ記事・動画の制作スケジュールを可視化。コンテンツ戦略を一元管理。
class ContentCalendarPage extends StatefulWidget {
  const ContentCalendarPage({super.key});

  @override
  State<ContentCalendarPage> createState() => _ContentCalendarPageState();
}

class _ContentCalendarPageState extends State<ContentCalendarPage> {
  final _supabase = Supabase.instance.client;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  DateTime _focusedMonth = DateTime.now();

  static const _typeColors = {
    'blog': Color(0xFF3EA8FF),
    'twitter': Color(0xFF1D9BF0),
    'instagram': Color(0xFFE1306C),
    'youtube': Color(0xFFFF0000),
    'linkedin': Color(0xFF0077B5),
    'note': Color(0xFF41C9B4),
    'other': Color(0xFF6B7280),
  };
  static const _typeLabels = {
    'blog': 'ブログ',
    'twitter': 'X (Twitter)',
    'instagram': 'Instagram',
    'youtube': 'YouTube',
    'linkedin': 'LinkedIn',
    'note': 'note',
    'other': 'その他',
  };

  String _selectedType = 'blog';
  final _titleCtrl = TextEditingController();
  DateTime _scheduledDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
      final end = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
      final data = await _supabase
          .from('content_calendar_items')
          .select()
          .eq('user_id', userId)
          .gte('scheduled_at', start.toIso8601String())
          .lte('scheduled_at', end.toIso8601String())
          .order('scheduled_at');
      setState(
        () => _items = (data as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('content_calendar_items').insert({
        'user_id': userId,
        'title': _titleCtrl.text.trim(),
        'content_type': _selectedType,
        'scheduled_at': _scheduledDate.toIso8601String(),
        'status': 'planned',
      });
      _titleCtrl.clear();
      if (mounted) Navigator.pop(context);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('コンテンツカレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                );
              });
              _load();
            },
          ),
          TextButton(
            onPressed: () {
              setState(() => _focusedMonth = DateTime.now());
              _load();
            },
            child: Text(
              '${_focusedMonth.year}/${_focusedMonth.month}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month + 1,
                );
              });
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF3D5AFE),
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'content_calendar_items テーブルを作成すると\nコンテンツ計画が管理できます',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0B0B0),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('この月にコンテンツ計画がありません。\n+ ボタンから追加してください。'),
                    )
                  : _buildList(),
    );
  }

  void _showAddDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('コンテンツを追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'タイトル *'),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'タイプ',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: _typeLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _typeColors[e.key],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => _selectedType = v);
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx2,
                    initialDate: _scheduledDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2027),
                  );
                  if (picked != null) {
                    setDialogState(() => _scheduledDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  '${_scheduledDate.year}/${_scheduledDate.month}/${_scheduledDate.day}',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: _saving ? null : _addItem,
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        final type = item['content_type'] as String? ?? 'other';
        final color = _typeColors[type] ?? const Color(0xFF6B7280);
        final scheduledAt = item['scheduled_at'] as String? ?? '';
        return Card(
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
            title: Text(item['title'] as String? ?? ''),
            subtitle: Text(_typeLabels[type] ?? type),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  scheduledAt.length >= 10 ? scheduledAt.substring(5, 10) : '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                Text(
                  item['status'] as String? ?? 'planned',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB0B0B0),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
