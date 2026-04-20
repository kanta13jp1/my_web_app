import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 「消化してから次を食え」WIP制限システム
///
/// 読書・勉強・プロジェクト等のカテゴリごとに
/// 「今やっていること」を1つだけ登録し、完了するまで次を始めない。
class WipLimitPage extends StatefulWidget {
  const WipLimitPage({super.key});

  @override
  State<WipLimitPage> createState() => _WipLimitPageState();
}

class _WipLimitPageState extends State<WipLimitPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  static const _categories = [
    ('📚', '読書', Color(0xFF795548)),
    ('📖', '勉強', Color(0xFF3D5AFE)),
    ('💻', 'プロジェクト', Color(0xFF3D5AFE)),
    ('🎮', 'ゲーム', Color(0xFF3D5AFE)),
    ('📺', 'アニメ・ドラマ', Color(0xFFE53935)),
    ('🎵', '音楽', Color(0xFFFF6B35)),
    ('🔧', 'スキル習得', Color(0xFFFF6B35)),
    ('📝', '資格・試験', Color(0xFF3D5AFE)),
    ('🏋️', 'トレーニング', Color(0xFF4CAF50)),
    ('🗂️', 'その他', Color(0xFFB0B0B0)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final data = await _supabase
          .from('wip_items')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data as List);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('WipLimit load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _hasActiveInCategory(String category) {
    return _items.any(
      (item) => item['category'] == category && item['status'] == 'active',
    );
  }

  Future<void> _addItem() async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = '📚';
    String selectedCategoryName = '読書';
    int progressPercent = 0;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final hasActive = _hasActiveInCategory(selectedCategoryName);

          return AlertDialog(
            title: const Text('今取り組んでいることを登録'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _categories.map((c) {
                      final isSelected = c.$2 == selectedCategoryName;
                      return ChoiceChip(
                        label: Text('${c.$1} ${c.$2}'),
                        selected: isSelected,
                        onSelected: (_) => setD(() {
                          selectedCategory = c.$1;
                          selectedCategoryName = c.$2;
                        }),
                      );
                    }).toList(),
                  ),
                  if (hasActive) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF9A9A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.block,
                            color: Color(0xFFC62828),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '⚠️ 「$selectedCategoryName」にはまだ消化中のものがあります。\n先にそれを完了させてください。',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC62828),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: '何に取り組んでいる？ *',
                      hintText: selectedCategoryName == '読書'
                          ? '例: 「人を動かす」デール・カーネギー'
                          : '例: React チュートリアル',
                      prefixIcon: const Icon(Icons.edit),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'メモ (任意)',
                      hintText: '例: 3章まで読了、残り7章',
                      prefixIcon: Icon(Icons.note),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        '進捗: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: progressPercent.toDouble(),
                          max: 100,
                          divisions: 20,
                          label: '$progressPercent%',
                          onChanged: (v) =>
                              setD(() => progressPercent = v.toInt()),
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: hasActive ? null : () => Navigator.pop(ctx, true),
                child: const Text('登録'),
              ),
            ],
          );
        },
      ),
    );
    if (result != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase.from('wip_items').insert({
        'user_id': userId,
        'category': selectedCategoryName,
        'emoji': selectedCategory,
        'title': title,
        'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        'progress_percent': progressPercent,
        'status': 'active',
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  Future<void> _updateProgress(Map<String, dynamic> item) async {
    final currentProgress = item['progress_percent'] as int? ?? 0;
    int newProgress = currentProgress;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('進捗更新: ${item['title']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: newProgress.toDouble(),
                max: 100,
                divisions: 20,
                label: '$newProgress%',
                onChanged: (v) => setD(() => newProgress = v.toInt()),
              ),
              Text(
                '$newProgress%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.5,
                ),
              ),
              if (newProgress >= 100) ...[
                const SizedBox(height: 8),
                const Text(
                  '🎉 完了！次を始められます',
                  style: TextStyle(
                    color: Color(0xFF4CAF50),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, newProgress),
              child: Text(newProgress >= 100 ? '完了にする' : '更新'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;

    try {
      await _supabase.from('wip_items').update({
        'progress_percent': result,
        'status': result >= 100 ? 'completed' : 'active',
        'completed_at': result >= 100 ? DateTime.now().toIso8601String() : null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', item['id']);
      await _load();
      if (mounted && result >= 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 「${item['title']}」を消化完了！次を始められます',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _items.where((i) => i['status'] == 'active').toList();
    final completed = _items.where((i) => i['status'] == 'completed').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('消化してから次を食え'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('登録'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 哲学カード
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.onSurface,
                        const Color(0xFF5D4037),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🍽️',
                        style: TextStyle(
                          fontSize: 36,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '食ったものを消化できてもいないのに\n新しいものを食わない',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '現在 ${active.length} 件を消化中',
                        style: const TextStyle(
                          color: Color(0xFFBCAAA4),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 消化中
                if (active.isNotEmpty) ...[
                  const Text(
                    '🔥 消化中 (完了するまで次を始めない)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...active.map((item) => _buildItemCard(item, true)),
                  const SizedBox(height: 20),
                ],

                if (active.isEmpty && completed.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 48,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '今取り組んでいることを登録してください。\n1カテゴリ1つまで。消化してから次。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 消化済み
                if (completed.isNotEmpty) ...[
                  Text(
                    '✅ 消化済み (${completed.length}件)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...completed.take(10).map(
                        (item) => _buildItemCard(item, false),
                      ),
                ],
              ],
            ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, bool isActive) {
    final emoji = item['emoji']?.toString() ?? '📦';
    final category = item['category']?.toString() ?? '';
    final title = item['title']?.toString() ?? '';
    final note = item['note']?.toString();
    final progress = item['progress_percent'] as int? ?? 0;
    final completedAt = item['completed_at'] != null
        ? DateTime.tryParse(item['completed_at'].toString())
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isActive ? const Color(0xFFFFB74D) : const Color(0xFFA5D6A7),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isActive ? () => _updateProgress(item) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration:
                                !isActive ? TextDecoration.lineThrough : null,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$progress%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: progress >= 100
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF57C00),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(
                    progress >= 100
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF6B35),
                  ),
                  minHeight: 6,
                ),
              ),
              if (completedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '消化完了: ${DateFormat('yyyy/MM/dd').format(completedAt.toLocal())}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF388E3C),
                    height: 1.5,
                  ),
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: 4),
                const Text(
                  'タップして進捗を更新',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFB8C00),
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
