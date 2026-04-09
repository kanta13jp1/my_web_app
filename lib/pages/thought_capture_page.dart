import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ThoughtCapturePage extends StatefulWidget {
  const ThoughtCapturePage({super.key});

  @override
  State<ThoughtCapturePage> createState() => _ThoughtCapturePageState();
}

class _ThoughtCapturePageState extends State<ThoughtCapturePage> {
  final _supabase = Supabase.instance.client;
  final _quickInputController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _thoughts = [];
  String _filterStatus = 'captured';
  String? _filterType;

  static const Map<String, String> _typeLabels = {
    'idea': '💡 ひらめき',
    'worry': '😟 不安',
    'todo': '✅ やること',
    'insight': '🔍 気づき',
    'random': '🌀 雑念',
    'question': '❓ 疑問',
    'memory': '🧠 記憶',
  };

  static const Map<String, String> _statusLabels = {
    'captured': '📥 捕獲',
    'reviewed': '👁 振り返り済',
    'acted': '⚡ 行動済',
    'archived': '📦 保管',
    'discarded': '🗑 破棄',
  };

  static const Map<String, Color> _typeColors = {
    'idea': Color(0xFFF59E0B),
    'worry': Color(0xFFEF4444),
    'todo': Color(0xFF10B981),
    'insight': Color(0xFF6366F1),
    'random': Color(0xFF8B5CF6),
    'question': Color(0xFF3B82F6),
    'memory': Color(0xFF06B6D4),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quickInputController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      var query = _supabase
          .from('thought_captures')
          .select()
          .eq('user_id', userId)
          .neq('status', 'discarded');

      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }
      if (_filterType != null) {
        query = query.eq('thought_type', _filterType!);
      }

      final data = await query.order('captured_at', ascending: false).limit(50);
      if (mounted) {
        setState(() {
          _thoughts = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickCapture() async {
    final text = _quickInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('thought_captures').insert({
        'user_id': userId,
        'content': text,
        'thought_type': 'random',
        'status': 'captured',
      });
      _quickInputController.clear();
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

  Future<void> _showDetailDialog(Map<String, dynamic> thought) async {
    final contentCtrl =
        TextEditingController(text: thought['content'] as String? ?? '');
    final reflectionCtrl =
        TextEditingController(text: thought['reflection'] as String? ?? '');
    String selectedType = thought['thought_type'] as String? ?? 'random';
    String selectedStatus = thought['status'] as String? ?? 'captured';
    int importance = thought['importance'] as int? ?? 3;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('思考を整理'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: '思考の内容',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: '種類',
                    border: OutlineInputBorder(),
                  ),
                  items: _typeLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),)
                      .toList(),
                  onChanged: (v) => setS(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'ステータス',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusLabels.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),)
                      .toList(),
                  onChanged: (v) => setS(() => selectedStatus = v!),
                ),
                const SizedBox(height: 12),
                Text('重要度: $importance', style: const TextStyle(fontSize: 13)),
                Slider(
                  value: importance.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$importance',
                  onChanged: (v) => setS(() => importance = v.toInt()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reflectionCtrl,
                  decoration: const InputDecoration(
                    labelText: '深掘りメモ (任意)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () async {
                await _supabase.from('thought_captures').update({
                  'content': contentCtrl.text.trim(),
                  'thought_type': selectedType,
                  'status': selectedStatus,
                  'importance': importance,
                  'reflection': reflectionCtrl.text.trim().isEmpty
                      ? null
                      : reflectionCtrl.text.trim(),
                  'processed_at': selectedStatus != 'captured'
                      ? DateTime.now().toIso8601String()
                      : null,
                }).eq('id', thought['id'] as String);
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _discard(String id) async {
    await _supabase
        .from('thought_captures')
        .update({'status': 'discarded'}).eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('思考キャプチャ'),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick capture bar
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickInputController,
                    decoration: InputDecoration(
                      hintText: '今浮かんだことを即記録...',
                      hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10,),
                    ),
                    onSubmitted: (_) => _quickCapture(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _quickCapture,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white,),)
                      : const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          // Filters
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                      '全て',
                      _filterStatus == 'all',
                      () => setState(() {
                            _filterStatus = 'all';
                            _load();
                          }),),
                  _filterChip(
                      '捕獲',
                      _filterStatus == 'captured',
                      () => setState(() {
                            _filterStatus = 'captured';
                            _load();
                          }),),
                  _filterChip(
                      '振り返り済',
                      _filterStatus == 'reviewed',
                      () => setState(() {
                            _filterStatus = 'reviewed';
                            _load();
                          }),),
                  _filterChip(
                      '行動済',
                      _filterStatus == 'acted',
                      () => setState(() {
                            _filterStatus = 'acted';
                            _load();
                          }),),
                  const SizedBox(width: 8),
                  const VerticalDivider(width: 1),
                  const SizedBox(width: 8),
                  ..._typeLabels.entries.map((e) => _filterChip(
                        e.value.split(' ').last,
                        _filterType == e.key,
                        () => setState(() {
                          _filterType = _filterType == e.key ? null : e.key;
                          _load();
                        }),
                        color: _typeColors[e.key],
                      ),),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _thoughts.isEmpty
                    ? _buildEmpty(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _thoughts.length,
                        itemBuilder: (ctx, i) =>
                            _buildThoughtCard(_thoughts[i], card, isDark),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap,
      {Color? color,}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? (color ?? const Color(0xFF6366F1))
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : Colors.grey[600],
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThoughtCard(
      Map<String, dynamic> thought, Color cardColor, bool isDark,) {
    final type = thought['thought_type'] as String? ?? 'random';
    final status = thought['status'] as String? ?? 'captured';
    final content = thought['content'] as String? ?? '';
    final reflection = thought['reflection'] as String?;
    final importance = thought['importance'] as int? ?? 3;
    final capturedAt = thought['captured_at'] as String?;
    final color = _typeColors[type] ?? Colors.grey;

    return Card(
      color: cardColor,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withAlpha(60),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetailDialog(thought),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _typeLabels[type] ?? type,
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _statusLabels[status] ?? status,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                        5,
                        (i) => Icon(
                              Icons.star,
                              size: 12,
                              color: i < importance
                                  ? const Color(0xFFF59E0B)
                                  : Colors.grey[300],
                            ),),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _discard(thought['id'] as String),
                    child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              if (reflection != null && reflection.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '💭 $reflection',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (capturedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('MM/dd HH:mm').format(
                      DateTime.tryParse(capturedAt)?.toLocal() ??
                          DateTime.now(),),
                  style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bubble_chart_outlined, size: 64, color: Theme.of(context).colorScheme.surfaceContainerHighest),
          const SizedBox(height: 16),
          Text(
            '思考を捕まえよう',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),),
          ),
          const SizedBox(height: 8),
          Text(
            '上のテキストボックスに\n浮かんだことを入力してください',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
