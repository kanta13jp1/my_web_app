import 'dart:math';

import 'package:flutter/material.dart';
import 'package:my_web_app/services/memory_drill_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryDrillPage extends StatefulWidget {
  const MemoryDrillPage({
    super.key,
    this.service,
    this.nowProvider,
  });

  final MemoryDrillService? service;
  final DateTime Function()? nowProvider;

  @override
  State<MemoryDrillPage> createState() => _MemoryDrillPageState();
}

class _MemoryDrillPageState extends State<MemoryDrillPage> {
  late final MemoryDrillService _service;
  late MemoryDrillPack _selectedPack;
  late List<String> _displayItems;

  MemoryDrillStats _stats = MemoryDrillStats.empty();
  bool _isLoading = true;
  bool _showHints = true;
  bool _showAnswers = false;
  List<MemoryDrillPack> _customPacks = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MemoryDrillService();
    _selectedPack = MemoryDrillService.builtinPacks.first;
    _displayItems = List<String>.from(_selectedPack.items);
    _loadStats();
    _loadCustomPacks();
  }

  DateTime _now() => widget.nowProvider?.call() ?? DateTime.now();

  Future<void> _loadStats() async {
    final stats = await _service.loadStats(now: _now());
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  Future<void> _loadCustomPacks() async {
    final String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return;
    }
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('custom_memory_packs')
          .select()
          .eq('user_id', userId)
          .order('created_at');
      final rows = List<Map<String, dynamic>>.from(data as List);
      final packs = rows.map((row) {
        final rawItems = row['items'];
        final items = rawItems is List
            ? rawItems.map((e) => e.toString()).toList()
            : <String>[];
        return MemoryDrillPack(
          id: 'custom_${row['id']?.toString() ?? ''}',
          title: row['title']?.toString() ?? '',
          description: row['description']?.toString() ?? '',
          category: row['category']?.toString() ?? 'カスタム',
          items: items,
        );
      }).toList();
      if (mounted) setState(() => _customPacks = packs);
    } catch (e) {
      debugPrint('Custom packs load error: $e');
    }
  }

  Future<void> _addCustomPack() async {
    final titleCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'カスタム');
    final itemCtrls = List.generate(10, (_) => TextEditingController());

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('オリジナル暗記セットを作成'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'セット名 *',
                    hintText: '例: 世界の首都 10個',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    hintText: '例: 地理、音楽、歴史',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '10個の項目を入力:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  10,
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: TextField(
                      controller: itemCtrls[i],
                      decoration: InputDecoration(
                        labelText: '${i + 1}.',
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (result != true) return;

    final title = titleCtrl.text.trim();
    final items =
        itemCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (title.isEmpty || items.isEmpty) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('custom_memory_packs').insert({
        'user_id': userId,
        'title': title,
        'category': categoryCtrl.text.trim(),
        'description': '$title (${items.length}項目)',
        'items': items,
      });
      await _loadCustomPacks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$title」を作成しました')),
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

  void _selectPack(MemoryDrillPack pack) {
    setState(() {
      _selectedPack = pack;
      _displayItems = List<String>.from(pack.items);
      _showAnswers = false;
    });
  }

  void _shuffleItems() {
    final nextItems = List<String>.from(_selectedPack.items);
    nextItems.shuffle(Random(_now().millisecondsSinceEpoch));
    setState(() {
      _displayItems = nextItems;
    });
  }

  Future<void> _markTodayCompleted() async {
    final updated = await _service.markCompleted(
      _selectedPack.id,
      now: _now(),
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _stats = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('今日の暗記ドリルを記録しました: ${_selectedPack.title}'),
      ),
    );
  }

  String _buildHint(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'ヒントなし';
    }
    final first = trimmed.substring(0, 1);
    final last =
        trimmed.length > 1 ? trimmed.substring(trimmed.length - 1) : '';
    final charCount = trimmed.runes.length;
    if (last.isEmpty) {
      return '$first で始まる / $charCount文字';
    }
    return '$first ... $last / $charCount文字';
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case '地理':
        return Icons.public;
      case '音楽':
        return Icons.music_note;
      case '理科':
        return Icons.science;
      case '歴史':
        return Icons.account_balance;
      default:
        return Icons.memory_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case '地理':
        return const Color(0xFF3D5AFE);
      case '音楽':
        return const Color(0xFF3D5AFE);
      case '理科':
        return const Color(0xFFFF6B35);
      case '歴史':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF3D5AFE);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompletedToday = _stats.isCompletedToday(_selectedPack.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('暗記ドリル'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 20),
                Text(
                  '暗記セット',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...MemoryDrillService.builtinPacks.map(_buildPackCard),
                if (_customPacks.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'マイ暗記セット',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ..._customPacks.map(_buildPackCard),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addCustomPack,
                  icon: const Icon(Icons.add),
                  label: const Text('オリジナル暗記セットを作成'),
                ),
                const SizedBox(height: 20),
                _buildSelectedPackCard(isCompletedToday),
              ],
            ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0F172A),
            Color(0xFF1D4ED8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '毎日の丸暗記を固定する',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '世界の国、ビートルズの楽曲、元素などを10個ずつ反復して、列挙の速度を日課として鍛えます。',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatChip(
          icon: Icons.today,
          label: '今日の完了',
          value: '${_stats.completedTodayCount}セット',
          color: const Color(0xFF3D5AFE),
        ),
        _StatChip(
          icon: Icons.local_fire_department,
          label: '連続日数',
          value: '${_stats.currentStreak}日',
          color: const Color(0xFFFF6B35),
        ),
      ],
    );
  }

  Widget _buildPackCard(MemoryDrillPack pack) {
    final isSelected = pack.id == _selectedPack.id;
    final isCompletedToday = _stats.isCompletedToday(pack.id);
    final color = _colorForCategory(pack.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _selectPack(pack),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color
                  : Theme.of(context).dividerColor.withValues(alpha: 0.4),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.16),
                foregroundColor: color,
                child: Icon(_iconForCategory(pack.category)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pack.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (isCompletedToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '今日完了',
                              style: TextStyle(
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pack.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPackCard(bool isCompletedToday) {
    final accent = _colorForCategory(_selectedPack.category);

    return Container(
      key: const Key('memory_drill_selected_pack_card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPack.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedPack.description,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _selectedPack.category,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilterChip(
                label: const Text('ヒント'),
                key: const Key('memory_drill_show_hints_chip'),
                selected: _showHints,
                onSelected: (value) {
                  setState(() => _showHints = value);
                },
              ),
              FilterChip(
                label: const Text('答え'),
                key: const Key('memory_drill_show_answers_chip'),
                selected: _showAnswers,
                onSelected: (value) {
                  setState(() => _showAnswers = value);
                },
              ),
              OutlinedButton.icon(
                key: const Key('memory_drill_shuffle_button'),
                onPressed: _shuffleItems,
                icon: const Icon(Icons.shuffle),
                label: const Text('順番を入れ替え'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ..._displayItems.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final value = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: accent.withValues(alpha: 0.12),
                    foregroundColor: accent,
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _showAnswers ? value : '思い出してから答えを見る',
                          style: TextStyle(
                            fontWeight: _showAnswers
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _showAnswers
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        if (!_showAnswers && _showHints) ...[
                          const SizedBox(height: 6),
                          Text(
                            _buildHint(value),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('memory_drill_mark_completed_button'),
              onPressed: isCompletedToday ? null : _markTodayCompleted,
              icon: Icon(
                isCompletedToday ? Icons.check_circle : Icons.task_alt,
              ),
              label: Text(
                isCompletedToday ? '今日は完了済み' : '今日の暗記を完了',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.88),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
